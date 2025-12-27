"use client";

import { BrowserMultiFormatReader, type IScannerControls } from "@zxing/browser";
import { useEffect, useMemo, useRef, useState } from "react";

export type QrScannerProps = {
  onDecoded: (raw: string) => void;
};

type DeviceOption = { deviceId: string; label: string };

export function QrScanner({ onDecoded }: QrScannerProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const controlsRef = useRef<IScannerControls | null>(null);
  const reader = useMemo(() => new BrowserMultiFormatReader(undefined, { delayBetweenScanAttempts: 80 }), []);

  const [devices, setDevices] = useState<DeviceOption[]>([]);
  const [deviceId, setDeviceId] = useState<string>("");
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string>("");

  const lastRef = useRef<{ raw: string; ts: number }>({ raw: "", ts: 0 });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const list = await BrowserMultiFormatReader.listVideoInputDevices();
        if (cancelled) return;
        const opts = list.map((d) => ({ deviceId: d.deviceId, label: d.label || "Kamera" }));
        setDevices(opts);

        // prefer "back" / "rear" if present
        const preferred =
          opts.find((d) => /back|rear|environment/i.test(d.label))?.deviceId ?? (opts[opts.length - 1]?.deviceId ?? "");
        setDeviceId(preferred);
      } catch (e) {
        if (!cancelled) {
          setError("Nepodarilo sa načítať kamery. Skontroluj povolenia pre kameru v prehliadači.");
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  async function stop() {
    controlsRef.current?.stop();
    controlsRef.current = null;
    setRunning(false);
  }

  async function start() {
    setError("");
    if (!videoRef.current) {
      setError("Video element nie je pripravený.");
      return;
    }
    if (!deviceId) {
      setError("Nie je vybraná kamera.");
      return;
    }

    // Ensure stopped first
    await stop();

    try {
      const controls = await reader.decodeFromVideoDevice(deviceId, videoRef.current, (result, err) => {
        if (result) {
          const raw = result.getText().trim();
          if (!raw) return;

          // throttle duplicates
          const now = Date.now();
          const last = lastRef.current;
          if (raw === last.raw && now - last.ts < 1200) return;
          lastRef.current = { raw, ts: now };

          onDecoded(raw);
        } else if (err) {
          // ignore NotFound (no qr in frame)
          const name = (err as any)?.name as string | undefined;
          if (name && /NotFound/i.test(name)) return;
        }
      });
      controlsRef.current = controls;
      setRunning(true);
    } catch (e) {
      setError("Nepodarilo sa spustiť kameru. Skontroluj povolenia (HTTPS) a či ju nepoužíva iná appka.");
      setRunning(false);
    }
  }

  useEffect(() => {
    return () => {
      controlsRef.current?.stop();
    };
  }, []);

  return (
    <div className="panel">
      <div className="panelHeader">
        <div>
          <p className="title" style={{ margin: 0 }}>
            Kamera
          </p>
          <p className="sub">Na mobile použi zadnú kameru (environment).</p>
        </div>
        <div className="controls">
          <button className="primary" onClick={running ? stop : start} type="button">
            {running ? "Stop" : "Start"}
          </button>
        </div>
      </div>

      <div className="grid2" style={{ marginBottom: 10 }}>
        <div>
          <label className="small muted">Kamera</label>
          <select value={deviceId} onChange={(e) => setDeviceId(e.target.value)} disabled={running}>
            {devices.length === 0 ? <option value="">(žiadna kamera)</option> : null}
            {devices.map((d) => (
              <option key={d.deviceId} value={d.deviceId}>
                {d.label}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="small muted">Stav</label>
          <div className="badge">
            <strong>{running ? "Skenujem" : "Zastavené"}</strong>
            <span className="muted">{running ? "namier na QR" : "klikni Start"}</span>
          </div>
        </div>
      </div>

      <div className="videoWrap">
        <video ref={videoRef} muted playsInline />
      </div>

      {error ? (
        <p style={{ marginTop: 10 }} className="small">
          <span style={{ color: "var(--warn)" }}>⚠</span> {error}
        </p>
      ) : null}
    </div>
  );
}



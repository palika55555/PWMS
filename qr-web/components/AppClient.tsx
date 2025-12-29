"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  applyScan,
  countsByProduct,
  emptyState,
  loadState,
  removePallet,
  saveState,
  type InventoryStateV1,
  type ScanMode
} from "../lib/inventory";
import { parseQr } from "../lib/qr";
import { apiEvents, apiListPallets, apiScan, isApiConfigured } from "../lib/api";
import { QrScanner } from "./QrScanner";

function downloadJson(filename: string, data: unknown) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function isoToLocal(iso: string) {
  try {
    const d = new Date(iso);
    return d.toLocaleString();
  } catch {
    return iso;
  }
}

export function AppClient() {
  const [mode, setMode] = useState<ScanMode>("receive");
  const [productCode, setProductCode] = useState("");
  const [state, setState] = useState<InventoryStateV1>(() => emptyState());
  const [last, setLast] = useState<{ raw: string; parsed: string } | null>(null);
  const [message, setMessage] = useState<string>("");
  const [filter, setFilter] = useState<{ q: string; status: "in_stock" | "issued" | "all" }>({ q: "", status: "in_stock" });
  const manualRef = useRef<HTMLInputElement | null>(null);
  const [backendEnabled, setBackendEnabled] = useState<boolean>(false);
  const [backendStatus, setBackendStatus] = useState<"not_configured" | "connecting" | "connected" | "error">("not_configured");

  useEffect(() => {
    const s = loadState();
    setState(s);
    const savedProduct = window.localStorage.getItem("pwms_qr_last_product") ?? "";
    setProductCode(savedProduct);

    const configured = isApiConfigured();
    setBackendEnabled(configured);
    setBackendStatus(configured ? "connecting" : "not_configured");
  }, []);

  useEffect(() => {
    saveState(state);
  }, [state]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    window.localStorage.setItem("pwms_qr_last_product", productCode);
  }, [productCode]);

  const totals = useMemo(() => {
    let inStockPallets = 0;
    let issuedPallets = 0;
    let inStockQty = 0;
    let issuedQty = 0;
    for (const it of Object.values(state.items)) {
      const q = (it as any).quantity ?? 1;
      if (it.status === "in_stock") {
        inStockPallets += 1;
        inStockQty += q;
      } else {
        issuedPallets += 1;
        issuedQty += q;
      }
    }
    return { pallets: Object.keys(state.items).length, inStockPallets, issuedPallets, inStockQty, issuedQty };
  }, [state.items]);

  const byProduct = useMemo(() => countsByProduct(state), [state]);

  // If backend is enabled, refresh from server (source of truth)
  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!backendEnabled) return;
      try {
        setBackendStatus("connecting");
        const [items, evs] = await Promise.all([apiListPallets({ limit: 2000 }), apiEvents(200)]);
        if (cancelled) return;
        // Convert backend -> local state shape (so UI stays the same)
        const next: InventoryStateV1 = {
          version: 1,
          items: Object.fromEntries(
            items.map((it) => [
              it.palletId,
              {
                palletId: it.palletId,
                productCode: it.productCode,
                quantity: (it as any).quantity ?? 1,
                status: it.status,
                firstSeenAt: it.firstSeenAt,
                lastSeenAt: it.lastSeenAt,
                lastRaw: it.lastRaw ?? ""
              }
            ])
          ),
          events: evs.map((e) => ({
            id: String(e.id),
            ts: e.createdAt,
            mode: e.mode,
            raw: e.raw ?? "",
            palletId: e.palletId,
            productCode: e.productCode ?? ""
          }))
        };
        setState(next);
        setBackendStatus("connected");
      } catch (e) {
        if (!cancelled) setBackendStatus("error");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [backendEnabled]);

  const filteredItems = useMemo(() => {
    const q = filter.q.trim().toLowerCase();
    const status = filter.status;
    return Object.values(state.items)
      .filter((it) => (status === "all" ? true : it.status === status))
      .filter((it) => {
        if (!q) return true;
        return (
          it.palletId.toLowerCase().includes(q) ||
          it.productCode.toLowerCase().includes(q) ||
          it.lastRaw.toLowerCase().includes(q)
        );
      })
      .sort((a, b) => b.lastSeenAt.localeCompare(a.lastSeenAt));
  }, [state.items, filter.q, filter.status]);

  function handleScan(raw: string) {
    setMessage("");
    const parsed = parseQr(raw);
    setLast({ raw, parsed: `${parsed.kind}` });

    const localRes = applyScan(state, { mode, qrRaw: raw, fallbackProductCode: productCode });
    if (!localRes.ok) {
      if (localRes.reason === "MISSING_PRODUCT") {
        setMessage("QR neobsahuje produkt. Vyplň 'Produkt (napr. DT20)' a skús znovu.");
        return;
      }
      if (localRes.reason === "MISSING_PALLET") {
        setMessage("QR nemá identifikátor palety (palletId). Skontroluj formát QR kódu.");
        return;
      }
      setMessage("Neplatný/ prázdny QR kód.");
      return;
    }

    // Optimistic local update (works even offline); if backend is enabled, also persist server-side
    setState(localRes.state);

    (async () => {
      if (!backendEnabled) {
        setMessage(
          mode === "receive"
            ? `Príjem OK (lokálne): ${localRes.item.productCode} / ${localRes.item.palletId}`
            : `Výdaj OK (lokálne): ${localRes.item.productCode} / ${localRes.item.palletId}`
        );
        return;
      }
      try {
        await apiScan({
          mode: mode === "receive" ? "receive" : "issue",
          palletId: localRes.item.palletId,
          productCode: localRes.item.productCode,
          raw: localRes.event.raw,
          quantity: (localRes.item as any).quantity ?? 1
        });
        // refresh quick (keeps other devices in sync when you reload)
        const [items, evs] = await Promise.all([apiListPallets({ limit: 2000 }), apiEvents(200)]);
        const next: InventoryStateV1 = {
          version: 1,
          items: Object.fromEntries(
            items.map((it) => [
              it.palletId,
              {
                palletId: it.palletId,
                productCode: it.productCode,
                quantity: (it as any).quantity ?? 1,
                status: it.status,
                firstSeenAt: it.firstSeenAt,
                lastSeenAt: it.lastSeenAt,
                lastRaw: it.lastRaw ?? ""
              }
            ])
          ),
          events: evs.map((e) => ({
            id: String(e.id),
            ts: e.createdAt,
            mode: e.mode,
            raw: e.raw ?? "",
            palletId: e.palletId,
            productCode: e.productCode ?? ""
          }))
        };
        setState(next);
        setBackendStatus("connected");
        setMessage(
          mode === "receive"
            ? `Príjem OK (backend): ${localRes.item.productCode} / ${localRes.item.palletId}`
            : `Výdaj OK (backend): ${localRes.item.productCode} / ${localRes.item.palletId}`
        );
      } catch {
        setBackendStatus("error");
        setMessage(
          `Lokálne OK, ale backend sa nepodarilo uložiť. Skontroluj API URL a či backend beží (CORS/HTTPS).`
        );
      }
    })();
  }

  async function onImportFile(file: File) {
    const text = await file.text();
    try {
      const parsed = JSON.parse(text) as any;
      if (!parsed || parsed.version !== 1 || typeof parsed.items !== "object" || !Array.isArray(parsed.events)) {
        setMessage("Import zlyhal: neplatný formát súboru.");
        return;
      }
      setState(parsed as InventoryStateV1);
      setMessage("Import OK.");
    } catch {
      setMessage("Import zlyhal: súbor nie je JSON.");
    }
  }

  return (
    <div className="container">
      <div className="panel" style={{ marginBottom: 16 }}>
        <div className="panelHeader">
          <div>
            <h1 className="title">PWMS – QR skener paliet</h1>
            <p className="sub">
              Režim <strong>{mode === "receive" ? "Príjem" : "Výdaj/Odčítanie"}</strong>. Dáta sa ukladajú lokálne do prehliadača
              (localStorage).
            </p>
          </div>
          <div className="controls">
            <span className="badge">
              <strong>{totals.inStockPallets}</strong> paliet na sklade
            </span>
            <span className="badge">
              <strong>{totals.issuedPallets}</strong> paliet vydané
            </span>
            <span className="badge">
              <strong>{totals.inStockQty}</strong> ks na sklade
            </span>
            <span className="badge">
              <strong>{totals.issuedQty}</strong> ks vydané
            </span>
            <span className="badge">
              <strong>{totals.pallets}</strong> paliet spolu
            </span>
          </div>
        </div>

        <div className="controls" style={{ justifyContent: "space-between" }}>
          <div className="controls">
            <div className="segmented" role="tablist" aria-label="Režim">
              <button type="button" data-active={mode === "receive"} onClick={() => setMode("receive")}>
                Príjem (pridaj)
              </button>
              <button type="button" data-active={mode === "issue"} onClick={() => setMode("issue")}>
                Výdaj (odčítaj)
              </button>
            </div>
            <span className="badge">
              <strong>Backend</strong>{" "}
              <span className="muted">
                {backendStatus === "not_configured"
                  ? "nenastavený"
                  : backendStatus === "connecting"
                    ? "pripájam…"
                    : backendStatus === "connected"
                      ? "OK"
                      : "chyba"}
              </span>
            </span>
            <label className="badge" style={{ cursor: isApiConfigured() ? "pointer" : "not-allowed", opacity: isApiConfigured() ? 1 : 0.6 }}>
              <input
                type="checkbox"
                checked={backendEnabled}
                disabled={!isApiConfigured()}
                onChange={(e) => setBackendEnabled(e.target.checked)}
                style={{ width: 16, height: 16 }}
              />
              Použiť backend
            </label>
          </div>

          <div className="controls">
            <button
              type="button"
              className="primary"
              onClick={() => downloadJson(`pwms-qr-inventory-${new Date().toISOString().slice(0, 10)}.json`, state)}
            >
              Export JSON
            </button>
            <label className="primary" style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
              Import JSON
              <input
                type="file"
                accept="application/json"
                style={{ display: "none" }}
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) onImportFile(f);
                  e.currentTarget.value = "";
                }}
              />
            </label>
            <button
              type="button"
              className="danger"
              onClick={() => {
                if (confirm("Vymazať všetky lokálne dáta inventára v tomto prehliadači?")) {
                  setState(emptyState());
                  setMessage("Vymazané.");
                }
              }}
            >
              Vymazať všetko
            </button>
          </div>
        </div>
      </div>

      <div className="row">
        <div>
          <QrScanner onDecoded={handleScan} />

          <div className="panel" style={{ marginTop: 16 }}>
            <div className="panelHeader">
              <div>
                <p className="title" style={{ margin: 0 }}>
                  Rýchle zadanie
                </p>
                <p className="sub">Ak QR nemá produkt, vyplň produkt a potom skenuj (alebo vlož text ručne).</p>
              </div>
            </div>

            <div className="grid2">
              <div>
                <label className="small muted">Produkt (napr. DT20)</label>
                <input value={productCode} onChange={(e) => setProductCode(e.target.value)} placeholder="DT20" />
              </div>
              <div>
                <label className="small muted">Manuálne QR (text)</label>
                <input ref={manualRef} placeholder="napr. DT20|PAL123 alebo len PAL123" />
              </div>
            </div>

            <div className="controls" style={{ marginTop: 10 }}>
              <button
                type="button"
                className="primary"
                onClick={() => {
                  const v = manualRef.current?.value ?? "";
                  if (!v.trim()) return;
                  handleScan(v);
                  if (manualRef.current) manualRef.current.value = "";
                }}
              >
                Spracovať manuálne
              </button>
              {last ? (
                <span className="badge">
                  <strong>Last</strong> <span className="mono">{last.raw.slice(0, 28)}{last.raw.length > 28 ? "…" : ""}</span>{" "}
                  <span className="muted">({last.parsed})</span>
                </span>
              ) : (
                <span className="badge">
                  <strong>Tip</strong> podporované formáty: <span className="mono">{"{...json...}"}</span> alebo{" "}
                  <span className="mono">DT20|PAL123</span> alebo len <span className="mono">PAL123</span>
                </span>
              )}
            </div>

            {message ? (
              <p className="small" style={{ marginTop: 10 }}>
                {message}
              </p>
            ) : null}
          </div>
        </div>

        <div>
          <div className="panel">
            <div className="panelHeader">
              <div>
                <p className="title" style={{ margin: 0 }}>
                  Prehľad podľa produktu
                </p>
                <p className="sub">Počty paliet aj ks „na sklade“ a „vydané“.</p>
              </div>
            </div>

            <table className="table">
              <thead>
                <tr>
                  <th>Produkt</th>
                  <th>Palety (sklad)</th>
                  <th>Palety (vyd.)</th>
                  <th>Ks (sklad)</th>
                  <th>Ks (vyd.)</th>
                </tr>
              </thead>
              <tbody>
                {byProduct.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="muted">
                      Zatiaľ nič naskenované.
                    </td>
                  </tr>
                ) : (
                  byProduct.map((r) => (
                    <tr key={r.productCode}>
                      <td className="mono">{r.productCode}</td>
                      <td>{r.inStockPallets}</td>
                      <td>{r.issuedPallets}</td>
                      <td>{r.inStockQty}</td>
                      <td>{r.issuedQty}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          <div className="panel" style={{ marginTop: 16 }}>
            <div className="panelHeader">
              <div>
                <p className="title" style={{ margin: 0 }}>
                  Palety
                </p>
                <p className="sub">Zoznam paliet (klik odstráni len lokálne).</p>
              </div>
            </div>

            <div className="grid2" style={{ marginBottom: 10 }}>
              <div>
                <label className="small muted">Filter</label>
                <input value={filter.q} onChange={(e) => setFilter((f) => ({ ...f, q: e.target.value }))} placeholder="hľadaj: DT20, PAL123…" />
              </div>
              <div>
                <label className="small muted">Stav</label>
                <select
                  value={filter.status}
                  onChange={(e) => setFilter((f) => ({ ...f, status: e.target.value as any }))}
                >
                  <option value="in_stock">Na sklade</option>
                  <option value="issued">Vydané</option>
                  <option value="all">Všetko</option>
                </select>
              </div>
            </div>

            <table className="table">
              <thead>
                <tr>
                  <th>Paleta</th>
                  <th>Produkt</th>
                  <th>Ks</th>
                  <th>Stav</th>
                  <th>Naposledy</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {filteredItems.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="muted">
                      Žiadne výsledky.
                    </td>
                  </tr>
                ) : (
                  filteredItems.slice(0, 120).map((it) => (
                    <tr key={it.palletId}>
                      <td className="mono">{it.palletId}</td>
                      <td className="mono">{it.productCode}</td>
                      <td>{(it as any).quantity ?? 1}</td>
                      <td>{it.status === "in_stock" ? "na sklade" : "vydané"}</td>
                      <td className="small">{isoToLocal(it.lastSeenAt)}</td>
                      <td style={{ width: 1, whiteSpace: "nowrap" }}>
                        <button
                          type="button"
                          className="danger"
                          onClick={() => {
                            if (confirm(`Odstrániť paletu ${it.palletId} (len lokálne)?`)) {
                              setState((s) => removePallet(s, it.palletId));
                            }
                          }}
                        >
                          Odstrániť
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
            {filteredItems.length > 120 ? <p className="small muted">Zobrazených prvých 120 výsledkov…</p> : null}
          </div>

          <div className="panel" style={{ marginTop: 16 }}>
            <div className="panelHeader">
              <div>
                <p className="title" style={{ margin: 0 }}>
                  História skenov
                </p>
                <p className="sub">Posledných 20 udalostí.</p>
              </div>
            </div>

            <table className="table">
              <thead>
                <tr>
                  <th>Čas</th>
                  <th>Režim</th>
                  <th>Produkt</th>
                  <th>Paleta</th>
                </tr>
              </thead>
              <tbody>
                {state.events.slice(0, 20).map((e) => (
                  <tr key={e.id}>
                    <td className="small">{isoToLocal(e.ts)}</td>
                    <td>{e.mode === "receive" ? "príjem" : "výdaj"}</td>
                    <td className="mono">{e.productCode}</td>
                    <td className="mono">{e.palletId}</td>
                  </tr>
                ))}
                {state.events.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="muted">
                      Zatiaľ nič.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <p className="small muted" style={{ marginTop: 18 }}>
        Poznámka: Kamera funguje len cez HTTPS (Vercel je OK). Ak chceš ukladať dáta centrálne (pre viacerých ľudí/telefónov),
        nastav `NEXT_PUBLIC_API_BASE_URL` na URL tvojho backendu a zapni „Použiť backend“.
      </p>
    </div>
  );
}



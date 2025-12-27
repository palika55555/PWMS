export type ParsedQr =
  | {
      kind: "json";
      raw: string;
      palletId?: string;
      productCode?: string;
      quantity?: number;
      lot?: string;
      location?: string;
      extra: Record<string, unknown>;
    }
  | {
      kind: "delimited";
      raw: string;
      palletId?: string;
      productCode?: string;
      quantity?: number;
      lot?: string;
      location?: string;
    }
  | {
      kind: "raw";
      raw: string;
    };

function asNumber(v: unknown): number | undefined {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string" && v.trim() !== "") {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return undefined;
}

function pickFirst(obj: Record<string, unknown>, keys: string[]): string | undefined {
  for (const k of keys) {
    const v = obj[k];
    if (typeof v === "string" && v.trim() !== "") return v.trim();
    if (typeof v === "number" && Number.isFinite(v)) return String(v);
  }
  return undefined;
}

export function parseQr(rawInput: string): ParsedQr {
  const raw = rawInput.trim();
  if (!raw) return { kind: "raw", raw: "" };

  // 1) JSON (preferované, dá sa rozšíriť do budúcna)
  if ((raw.startsWith("{") && raw.endsWith("}")) || (raw.startsWith("[") && raw.endsWith("]"))) {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        const obj = parsed as Record<string, unknown>;
        const palletId = pickFirst(obj, ["palletId", "pallet_id", "paleta", "pallet", "id", "palletCode"]);
        const productCode = pickFirst(obj, ["productCode", "product_code", "product", "code", "sku", "vyrobok"]);
        const quantity = asNumber(obj.quantity ?? obj.qty ?? obj.ks ?? obj.pcs);
        const lot = pickFirst(obj, ["lot", "batch", "sarza", "batch_id"]);
        const location = pickFirst(obj, ["location", "loc", "warehouse", "sklad"]);
        return {
          kind: "json",
          raw,
          palletId,
          productCode,
          quantity,
          lot,
          location,
          extra: obj
        };
      }
    } catch {
      // fallback nižšie
    }
  }

  // 2) Delimitované: "DT20|PAL123" alebo "DT20;PAL123;40"
  const delims = ["|", ";", ","];
  for (const d of delims) {
    if (raw.includes(d)) {
      const parts = raw
        .split(d)
        .map((p) => p.trim())
        .filter(Boolean);

      // Heuristika:
      // - ak sú 2 časti: product|pallet
      // - ak sú 3+: product|pallet|qty|lot|location...
      const productCode = parts[0];
      const palletId = parts[1];
      const quantity = parts.length >= 3 ? asNumber(parts[2]) : undefined;
      const lot = parts.length >= 4 ? parts[3] : undefined;
      const location = parts.length >= 5 ? parts[4] : undefined;
      return { kind: "delimited", raw, palletId, productCode, quantity, lot, location };
    }
  }

  // 3) Raw: berieme celé ako identifikátor palety (najjednoduchší variant)
  return { kind: "raw", raw };
}



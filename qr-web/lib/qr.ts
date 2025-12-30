// ====================================================================
// QR PARSER - Univerzálny parser pre QR kódy
// ====================================================================
// Tento súbor parsuje rôzne formáty QR kódov používané v PWMS
// Podporuje: JSON, delimited (|;,), raw formáty
// Kompatibilný s QrPayload z Flutter appky

// ====================================================================
// TYPE DEFINITIONS
// ====================================================================

/**
 * Výsledok parsovania QR kódu
 * Môže byť jeden z troch typov podľa formátu vstupu
 */
export type ParsedQr =
  // JSON formát - najbohatší, podporuje extra dáta
  | {
      kind: "json";
      raw: string;                    // Pôvodný text z QR kódu
      palletId?: string;              // Identifikátor palety
      productCode?: string;           // Kód produktu
      quantity?: number;              // Množstvo
      lot?: string;                   // Šarža/lot
      location?: string;             // Lokácia
      extra: Record<string, unknown>; // Extra dáta z JSON
    }
  // Delimited formát - jednoduchý, oddelený znakmi
  | {
      kind: "delimited";
      raw: string;        // Pôvodný text
      palletId?: string;  // Identifikátor palety
      productCode?: string; // Kód produktu
      quantity?: number;  // Množstvo
      lot?: string;       // Šarža/lot
      location?: string; // Lokácia
    }
  // Raw formát - len surový text
  | {
      kind: "raw";
      raw: string; // Celý text ako identifikátor
    };

// ====================================================================
// HELPER FUNCTIONS
// ====================================================================

/**
 * Bezpečná konverzia na číslo
 * @param v - hodnota na konverziu
 * @returns číslo alebo undefined ak nie je platné
 */
function asNumber(v: unknown): number | undefined {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string" && v.trim() !== "") {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return undefined;
}

/**
 * Vyberie prvú nenulovú hodnotu z zoznamu kľúčov
 * Používa sa pre flexibilitu - rôzne QR kódy môžu používať rôzne názvy polí
 * @param obj - objekt s dátami
 * @param keys - zoznam možných kľúčov v poradí priority
 * @returns hodnota alebo undefined
 */
function pickFirst(obj: Record<string, unknown>, keys: string[]): string | undefined {
  for (const k of keys) {
    const v = obj[k];
    if (typeof v === "string" && v.trim() !== "") return v.trim();
    if (typeof v === "number" && Number.isFinite(v)) return String(v);
  }
  return undefined;
}

// ====================================================================
// MAIN PARSER FUNCTION
// ====================================================================

/**
 * Univerzálny parser pre QR kódy
 * Podporuje 3 formáty v poradí priority:
 * 1. JSON - najbohatší, preferovaný
 * 2. Delimited - jednoduchý, oddelený | ; ,
 * 3. Raw - fallback, len surový text
 * 
 * @param rawInput - surový text z QR skenera
 * @returns ParsedQr - parsovaný výsledok
 */
export function parseQr(rawInput: string): ParsedQr {
  const raw = rawInput.trim();
  if (!raw) return { kind: "raw", raw: "" };

  // ====================================================================
  // 1) JSON FORMÁT - preferovaný, najviac extenzibilný
  // ====================================================================
  // Očakávaný formát: {"t":"pallet","palletId":"PAL-123","productCode":"DT20",...}
  // Kompatibilný s QrPayload.pallet() z Flutter appky
  if ((raw.startsWith("{") && raw.endsWith("}")) || (raw.startsWith("[") && raw.endsWith("]"))) {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        const obj = parsed as Record<string, unknown>;
        
        // Flexibilné mapovanie kľúčov - podporuje rôzne varianty
        const palletId = pickFirst(obj, [
          "palletId", "pallet_id", "paleta", "pallet", "id", "palletCode"
        ]);
        const productCode = pickFirst(obj, [
          "productCode", "product_code", "product", "code", "sku", "vyrobok"
        ]);
        const quantity = asNumber(obj.quantity ?? obj.qty ?? obj.ks ?? obj.pcs);
        const lot = pickFirst(obj, [
          "lot", "batch", "sarza", "batch_id", "batchNumber"
        ]);
        const location = pickFirst(obj, [
          "location", "loc", "warehouse", "sklad"
        ]);
        
        return {
          kind: "json",
          raw,
          palletId,
          productCode,
          quantity,
          lot,
          location,
          extra: obj // Uchovaj celé JSON pre budúce použitie
        };
      }
    } catch {
      // Ak JSON nie je platný, fallback na ďalšie formáty
    }
  }

  // ====================================================================
  // 2) DELIMITED FORMÁT - jednoduchý, oddelený znakmi
  // ====================================================================
  // Príklady: "DT20|PAL123|40" alebo "DT20;PAL123;40;BATCH001"
  // Heuristika: product|pallet|qty|lot|location
  const delims = ["|", ";", ","];
  for (const d of delims) {
    if (raw.includes(d)) {
      const parts = raw
        .split(d)
        .map((p) => p.trim())
        .filter(Boolean); // Odstráni prázdne časti

      // Mapovanie podľa počtu častí:
      // 2: product|pallet
      // 3: product|pallet|qty
      // 4: product|pallet|qty|lot
      // 5+: product|pallet|qty|lot|location...
      const productCode = parts[0];
      const palletId = parts[1];
      const quantity = parts.length >= 3 ? asNumber(parts[2]) : undefined;
      const lot = parts.length >= 4 ? parts[3] : undefined;
      const location = parts.length >= 5 ? parts[4] : undefined;
      
      return { kind: "delimited", raw, palletId, productCode, quantity, lot, location };
    }
  }

  // ====================================================================
  // 3) RAW FORMÁT - fallback, najjednoduchší
  // ====================================================================
  // Všetko ostatné považujeme za surový identifikátor palety
  return { kind: "raw", raw };
}

// ====================================================================
// PRÍKLADY POUŽITIA
// ====================================================================
/*
// JSON formát (preferovaný):
const qr1 = '{"t":"pallet","palletId":"PAL-001","productCode":"DT20","qty":40}';
const parsed1 = parseQr(qr1);
// → { kind: "json", palletId: "PAL-001", productCode: "DT20", quantity: 40, ... }

// Delimited formát:
const qr2 = "DT20|PAL-001|40";
const parsed2 = parseQr(qr2);
// → { kind: "delimited", palletId: "PAL-001", productCode: "DT20", quantity: 40 }

// Raw formát:
const qr3 = "PAL-001";
const parsed3 = parseQr(qr3);
// → { kind: "raw", raw: "PAL-001" }
*/








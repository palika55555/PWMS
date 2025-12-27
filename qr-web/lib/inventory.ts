import { parseQr } from "./qr";

export type ScanMode = "receive" | "issue";

export type InventoryStatus = "in_stock" | "issued";

export type InventoryEvent = {
  id: string;
  ts: string; // ISO
  mode: ScanMode;
  raw: string;
  palletId: string;
  productCode: string;
};

export type InventoryItem = {
  palletId: string;
  productCode: string;
  quantity: number; // ks on pallet
  status: InventoryStatus;
  firstSeenAt: string; // ISO
  lastSeenAt: string; // ISO
  lastRaw: string;
};

export type InventoryStateV1 = {
  version: 1;
  items: Record<string, InventoryItem>; // key: palletId
  events: InventoryEvent[]; // newest first
};

const STORAGE_KEY = "pwms_qr_inventory_v1";

function nowIso(): string {
  return new Date().toISOString();
}

function uid(): string {
  // good enough for local event ids
  return `${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

export function emptyState(): InventoryStateV1 {
  return { version: 1, items: {}, events: [] };
}

export function loadState(): InventoryStateV1 {
  if (typeof window === "undefined") return emptyState();
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return emptyState();
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object") return emptyState();
    const s = parsed as Partial<InventoryStateV1>;
    if (s.version !== 1 || !s.items || !s.events) return emptyState();
    return {
      version: 1,
      items: s.items as Record<string, InventoryItem>,
      events: s.events as InventoryEvent[]
    };
  } catch {
    return emptyState();
  }
}

export function saveState(state: InventoryStateV1): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

export type ApplyScanInput = {
  mode: ScanMode;
  qrRaw: string;
  fallbackProductCode?: string; // keď QR neobsahuje product
};

export type ApplyScanResult =
  | { ok: true; state: InventoryStateV1; event: InventoryEvent; item: InventoryItem }
  | { ok: false; reason: "EMPTY_QR" | "MISSING_PALLET" | "MISSING_PRODUCT"; parsedRaw: string };

export function applyScan(prev: InventoryStateV1, input: ApplyScanInput): ApplyScanResult {
  const parsed = parseQr(input.qrRaw);
  const parsedRaw = parsed.raw;
  if (!parsedRaw) return { ok: false, reason: "EMPTY_QR", parsedRaw: "" };

  // palletId
  const palletId =
    parsed.kind === "raw"
      ? parsed.raw
      : (parsed.palletId ?? (parsed.kind === "delimited" ? parsed.palletId : undefined));

  if (!palletId) return { ok: false, reason: "MISSING_PALLET", parsedRaw };

  // productCode
  const productCode =
    parsed.kind === "raw"
      ? (input.fallbackProductCode?.trim() || "")
      : (parsed.productCode?.trim() || input.fallbackProductCode?.trim() || "");

  if (!productCode) return { ok: false, reason: "MISSING_PRODUCT", parsedRaw };

  const ts = nowIso();
  const existing = prev.items[palletId];

  const nextStatus: InventoryStatus = input.mode === "receive" ? "in_stock" : "issued";
  const qty = parsed.kind === "raw" ? 1 : (parsed.quantity ?? 1);
  const qtySafe = Number.isFinite(qty) && qty > 0 ? qty : 1;
  const item: InventoryItem = existing
    ? {
        ...existing,
        productCode,
        quantity: qtySafe,
        status: nextStatus,
        lastSeenAt: ts,
        lastRaw: parsedRaw
      }
    : {
        palletId,
        productCode,
        quantity: qtySafe,
        status: nextStatus,
        firstSeenAt: ts,
        lastSeenAt: ts,
        lastRaw: parsedRaw
      };

  const event: InventoryEvent = {
    id: uid(),
    ts,
    mode: input.mode,
    raw: parsedRaw,
    palletId,
    productCode
  };

  const next: InventoryStateV1 = {
    version: 1,
    items: { ...prev.items, [palletId]: item },
    events: [event, ...prev.events].slice(0, 500) // cap history
  };

  return { ok: true, state: next, event, item };
}

export function setPalletProduct(state: InventoryStateV1, palletId: string, productCode: string): InventoryStateV1 {
  const item = state.items[palletId];
  if (!item) return state;
  const updated: InventoryItem = { ...item, productCode, lastSeenAt: nowIso() };
  return { ...state, items: { ...state.items, [palletId]: updated } };
}

export function removePallet(state: InventoryStateV1, palletId: string): InventoryStateV1 {
  const nextItems = { ...state.items };
  delete nextItems[palletId];
  return { ...state, items: nextItems };
}

export function countsByProduct(state: InventoryStateV1): Array<{
  productCode: string;
  inStockPallets: number;
  issuedPallets: number;
  inStockQty: number;
  issuedQty: number;
}> {
  const map = new Map<string, { inStockPallets: number; issuedPallets: number; inStockQty: number; issuedQty: number }>();
  for (const item of Object.values(state.items)) {
    const key = item.productCode || "NEZNÁME";
    const cur = map.get(key) ?? { inStockPallets: 0, issuedPallets: 0, inStockQty: 0, issuedQty: 0 };
    if (item.status === "in_stock") {
      cur.inStockPallets += 1;
      cur.inStockQty += item.quantity ?? 1;
    } else {
      cur.issuedPallets += 1;
      cur.issuedQty += item.quantity ?? 1;
    }
    map.set(key, cur);
  }
  return [...map.entries()]
    .map(([productCode, v]) => ({
      productCode,
      inStockPallets: v.inStockPallets,
      issuedPallets: v.issuedPallets,
      inStockQty: v.inStockQty,
      issuedQty: v.issuedQty
    }))
    .sort((a, b) => a.productCode.localeCompare(b.productCode));
}



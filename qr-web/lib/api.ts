export type ApiPalletItem = {
  id: number;
  palletId: string;
  productCode: string;
  status: "in_stock" | "issued";
  firstSeenAt: string;
  lastSeenAt: string;
  lastRaw: string | null;
  source: string | null;
  createdAt: string;
  updatedAt: string;
};

export type ApiPalletEvent = {
  id: number;
  palletId: string;
  productCode: string | null;
  mode: "receive" | "issue";
  raw: string | null;
  source: string | null;
  createdAt: string;
};

export type ApiSummary = {
  totals: { in_stock: number; issued: number; total: number };
  byProduct: Array<{ productCode: string; inStock: number; issued: number; total: number }>;
};

function baseUrl() {
  const u = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
  return u ? u.replace(/\/+$/, "") : "";
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const b = baseUrl();
  if (!b) throw new Error("API_BASE_URL_NOT_CONFIGURED");
  const res = await fetch(`${b}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...(init?.headers || {}) },
    cache: "no-store",
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP_${res.status}: ${text || res.statusText}`);
  }
  return (await res.json()) as T;
}

export function isApiConfigured() {
  return !!baseUrl();
}

export async function apiScan(input: { mode: "receive" | "issue"; palletId: string; productCode: string; raw: string }) {
  return await request<{ item: ApiPalletItem; event: ApiPalletEvent }>("/api/pallets/scan", {
    method: "POST",
    body: JSON.stringify({ ...input, source: "qr-web" }),
  });
}

export async function apiListPallets(params?: { status?: string; q?: string; limit?: number }) {
  const q = new URLSearchParams();
  if (params?.status) q.set("status", params.status);
  if (params?.q) q.set("q", params.q);
  if (params?.limit) q.set("limit", String(params.limit));
  const s = q.toString();
  return await request<ApiPalletItem[]>(`/api/pallets${s ? `?${s}` : ""}`);
}

export async function apiEvents(limit = 20) {
  return await request<ApiPalletEvent[]>(`/api/pallets/events?limit=${encodeURIComponent(String(limit))}`);
}

export async function apiSummary() {
  return await request<ApiSummary>("/api/pallets/summary");
}



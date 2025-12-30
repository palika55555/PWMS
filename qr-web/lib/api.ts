// Typy pre API odpovede z backendu (Railway Express server)
// Tieto typy definujú štruktúru dát, ktoré prichádzajú z backendu

/**
 * Produktová paleta - jednotlivý záznam palety na sklade
 * - id: unikátne ID v databáze
 * - palletId: identifikátor palety (z QR kódu)
 * - productCode: kód produktu
 * - quantity: množstvo na palete
 * - status: stav (na sklade | vydané)
 * - firstSeenAt/lastSeenAt: kedy bola paleta prvýkrát/poslednýkrát videná
 * - lastRaw: surové dáta z posledného QR skenu
 * - source: zdroj zmeny (qr-web, app, atď.)
 */
export type ApiPalletItem = {
  id: number;
  palletId: string;
  productCode: string;
  quantity: number;
  status: "in_stock" | "issued";
  firstSeenAt: string;
  lastSeenAt: string;
  lastRaw: string | null;
  source: string | null;
  createdAt: string;
  updatedAt: string;
};

/**
 * Event palety - záznam o zmene stavu palety
 * - id: unikátne ID eventu
 * - palletId: identifikátor palety
 * - productCode: kód produktu (môže byť null pri starých záznamoch)
 * - mode: typ operácie (príjem | výdaj)
 * - quantity: množstvo (môže byť null)
 * - raw: surové dáta z QR kódu
 * - source: zdroj eventu
 * - createdAt: kedy event nastal
 */
export type ApiPalletEvent = {
  id: number;
  palletId: string;
  productCode: string | null;
  mode: "receive" | "issue";
  quantity: number | null;
  raw: string | null;
  source: string | null;
  createdAt: string;
};

/**
 * Prehľad palet - súhrnné statistiky
 * - totals: celkové štatistiky (počty a množstvá)
 * - byProduct: štatistiky rozdelené podľa produktov
 */
export type ApiSummary = {
  totals: {
    in_stock_pallets: number;    // počet paliet na sklade
    issued_pallets: number;     // počet vydaných paliet
    total_pallets: number;      // celkový počet paliet
    in_stock_qty: number;       // množstvo na sklade
    issued_qty: number;         // vydané množstvo
    total_qty: number;          // celkové množstvo
  };
  byProduct: Array<{
    productCode: string;
    inStockPallets: number;
    issuedPallets: number;
    totalPallets: number;
    inStockQty: number;
    issuedQty: number;
    totalQty: number;
  }>;
};

// ====================================================================
// API KONFIGURÁCIA A HELPER FUNKCIE
// ====================================================================

/**
 * Získanie base URL pre backend API
 * 1. Skúší načítať z environment premennej NEXT_PUBLIC_API_BASE_URL
 * 2. Ak nie je nastavená, použije fallback na Railway URL
 * 3. Odstráni koncové lomítka pre konzistentné URL
 */
function baseUrl() {
  const u = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
  // Fallback na Railway URL ak env premenná nie je nastavená
  // Toto zabezpečí, že aplikácia funguje aj bez nastavenej env premennej
  return u ? u.replace(/\/+$/, "") : "https://pwms-production.up.railway.app";
}

/**
 * Univerzálna funkcia pre HTTP requesty na backend
 * - Používa fetch API s JSON headers
 * - cache: "no-store" zabezpečí vždy čerstvé dáta
 * - Automaticky spracováva chyby a status kódy
 * - Generic typ <T> pre type-safe odpovede
 */
async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const b = baseUrl();
  if (!b) throw new Error("API_BASE_URL_NOT_CONFIGURED");
  
  // Vytvorenie HTTP requestu na backend
  const res = await fetch(`${b}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...(init?.headers || {}) },
    cache: "no-store", // Zakázanie cache pre vždy aktuálne dáta
  });
  
  // Error handling - ak response nie je OK (2xx)
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP_${res.status}: ${text || res.statusText}`);
  }
  
  // Parsovanie JSON odpovede s typovou bezpečnosťou
  return (await res.json()) as T;
}

/**
 * Kontrola, či je API nakonfigurované
 * Používa sa v UI pre zobrazenie statusu "Backend OK" alebo "Backend nenastavený"
 */
export function isApiConfigured() {
  return !!baseUrl();
}

// ====================================================================
// API FUNKCIE PRE PALETY
// ====================================================================

/**
 * Odoslanie skenovanej palety na backend
 * Vytvorí alebo aktualizuje záznam palety a zároveň pridá event
 * 
 * @param input - dáta z QR skenu
 *   - mode: "receive" (príjem) | "issue" (výdaj)
 *   - palletId: identifikátor palety
 *   - productCode: kód produktu
 *   - raw: surové dáta z QR kódu
 *   - quantity: voliteľné množstvo
 * 
 * @returns { item: ApiPalletItem, event: ApiPalletEvent } - vytvorený záznam a event
 */
export async function apiScan(input: {
  mode: "receive" | "issue";
  palletId: string;
  productCode: string;
  raw: string;
  quantity?: number;
}) {
  return await request<{ item: ApiPalletItem; event: ApiPalletEvent }>("/api/pallets/scan", {
    method: "POST",
    body: JSON.stringify({ 
      ...input, 
      source: "qr-web" // Označenie zdroja zmeny
    }),
  });
}

/**
 * Získanie zoznamu paliet z backendu
 * Podporuje filtrovanie a limitovanie výsledkov
 * 
 * @param params - voliteľné filtre
 *   - status: "in_stock" | "issued" - filtrovanie podľa stavu
 *   - q: search query - vyhľadávanie podľa palletId, productCode alebo lastRaw
 *   - limit: maximálny počet výsledkov (default 500, max 2000)
 * 
 * @returns ApiPalletItem[] - zoznam paliet
 */
export async function apiListPallets(params?: { status?: string; q?: string; limit?: number }) {
  // Vytvorenie query string z parametrov
  const q = new URLSearchParams();
  if (params?.status) q.set("status", params.status);
  if (params?.q) q.set("q", params.q);
  if (params?.limit) q.set("limit", String(params.limit));
  const s = q.toString();
  
  return await request<ApiPalletItem[]>(`/api/pallets${s ? `?${s}` : ""}`);
}

/**
 * Získanie posledných eventov palet
 * Zobrazí históriu zmien stavu paliet
 * 
 * @param limit - maximálny počet eventov (default 20, max 500)
 * 
 * @returns ApiPalletEvent[] - zoznam eventov zoradený podľa createdAt (najnovšie prvé)
 */
export async function apiEvents(limit = 20) {
  return await request<ApiPalletEvent[]>(`/api/pallets/events?limit=${encodeURIComponent(String(limit))}`);
}

/**
 * Získanie súhrnných štatistík palet
 * Používa sa pre dashboard a prehľady
 * 
 * @returns ApiSummary - celkové štatistiky a štatistiky podľa produktov
 */
export async function apiSummary() {
  return await request<ApiSummary>("/api/pallets/summary");
}



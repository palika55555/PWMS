# Storage Configuration for Vercel

## Problém s resetovaním dát po deploy

API endpointy používajú storage helper (`api/storage.js`), ktorý automaticky detekuje a používa Vercel KV ak je dostupné, inak používa in-memory storage (dáta sa stratia po redeploy).

## Riešenie: Nastavenie Vercel KV (Odporúčané)

Pre trvalé ukladanie dát bez resetovania po deploy:

1. **Nainštalujte Vercel KV** v projekte:
   ```bash
   vercel kv create
   ```

2. **Pridajte environment variable** v Vercel dashboard:
   - `KV_REST_API_URL`
   - `KV_REST_API_TOKEN`
   - `KV_REST_API_READ_ONLY_TOKEN`

3. **Storage helper automaticky použije Vercel KV** ak sú tieto premenné nastavené.

## Alternatíva: Externá databáza

Ak nemáte prístup k Vercel KV, môžete použiť:
- PostgreSQL (napr. Supabase, Neon)
- MongoDB (napr. MongoDB Atlas)
- Iný cloud storage

Upravte `api/storage.js` pre použitie vašej databázy.

## Aktuálny stav

- ✅ Storage helper implementovaný
- ✅ Automatická detekcia Vercel KV
- ✅ Fallback na in-memory storage
- ⚠️ **Bez Vercel KV sa dáta stratia po redeploy**


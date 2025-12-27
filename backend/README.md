# ProBlock PWMS Backend

Backend API pre Production and Warehouse Management System.

## Technológie

- Node.js
- Express.js
- PostgreSQL
- Railway (hosting)

## API Endpoints

### Materials

- `GET /api/materials` - Získať všetky materiály
- `GET /api/materials/:id` - Získať materiál podľa ID
- `POST /api/materials` - Vytvoriť nový materiál
- `PUT /api/materials/:id` - Aktualizovať materiál
- `DELETE /api/materials/:id` - Vymazať materiál

### Recipes

- `GET /api/recipes` - Získať všetky receptúry
- `GET /api/recipes/:id` - Získať receptúru podľa ID
- `POST /api/recipes` - Vytvoriť novú receptúru
- `PUT /api/recipes/:id` - Aktualizovať receptúru

### Batches

- `GET /api/batches` - Získať všetky šarže (query: `?date=YYYY-MM-DD`)
- `GET /api/batches/:id` - Získať šaržu podľa ID
- `POST /api/batches` - Vytvoriť novú šaržu
- `PUT /api/batches/:id` - Aktualizovať šaržu

### Products

- `GET /api/products` - Získať všetky produkty (query: `?batch_id=ID`)
- `GET /api/products/qr/:qrCode` - Získať produkt podľa QR kódu
- `POST /api/products` - Vytvoriť nový produkt

### Pallets (produktové palety – web QR)

- `POST /api/pallets/scan` - Uložiť sken palety (upsert stav: `in_stock|issued`) + uložiť event
- `GET /api/pallets` - Zoznam paliet (query: `?status=in_stock|issued&q=...&limit=...`)
- `GET /api/pallets/summary` - Prehľad počtov podľa produktu
- `GET /api/pallets/events` - Posledné eventy (query: `?limit=...`)

## Migrácie

Migrácie sa spúšťajú automaticky pri spustení servera. Systém kontroluje existenciu tabuliek a vytvára len tie, ktoré ešte neexistujú.

Pre manuálne spustenie:
```bash
npm run migrate
```

## Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `PORT` - Port pre server (default: 3000)
- `NODE_ENV` - Environment (development/production)

## Railway deploy (Postgres + Backend)

1. V Railway vytvor nový projekt a pridaj **PostgreSQL** plugin.
2. V službe backend nastav **Root Directory** na repo root (nechaj tak) – deploy používa `railway.toml` + `nixpacks.toml` a spúšťa `cd backend && npm start`.
3. Environment variables:
   - **DATABASE_URL**: Railway ho zvyčajne nastaví automaticky z Postgres pluginu (necommituj ho do kódu).  
     Pozn.: interný host `postgres.railway.internal` funguje iba v rámci Railway siete.
   - **NODE_ENV**: `production`
4. Deploy: build fáza spustí `npm run migrate || true` (best-effort).
5. Po deploy backend beží na tvojej doméne (napr. `pwms-production.up.railway.app`). Skontroluj `GET /health`.

### Flutter app (Windows)
V appke v inštalačnom sprievodcovi nastav Server URL na `https://pwms-production.up.railway.app` (bez koncového lomítka).










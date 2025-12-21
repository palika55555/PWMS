# Railway Deployment Setup

## Nastavenie v Railway Dashboard

### 1. Root Directory
V Railway settings pre backend service nastav:
- **Root Directory**: `backend`

### 2. Environment Variables
Nastav tieto premenné prostredia:
- **DATABASE_URL**: PostgreSQL connection string (Railway automaticky vytvorí)
- **PORT**: Railway nastaví automaticky (nepotrebuješ)

### 3. Start Command
Nastav **Start Command** na:
```
npm run start:railway
```

Tento príkaz:
1. Spustí migrácie databázy (`npm run migrate:up`)
2. Spustí server (`npm run start`)

### 4. Build Settings
Railway by mal automaticky rozpoznať Node.js projekt v `backend/` priečinku a:
- Nainštalovať závislosti (`npm ci`)
- Spustiť build (`npm run build`)
- Spustiť server

## Alternatíva: Railway.json
Ak Root Directory nepomôže, Railway použije `railway.json` v root priečinku, ktorý už existuje a ukazuje Railway, kde je backend kód.

## Health Check
Po deploymente by mal fungovať:
- Health check: `GET /health`
- API: `GET /v1`

## Poznámky
- Migrácie sa spustia automaticky pri každom deploymente cez `start:railway` script
- `postinstall` script automaticky spustí `npm run build` po `npm ci`


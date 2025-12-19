# Railway Backend Setup

Tento backend je navrhnutý pre Railway platformu s PostgreSQL databázou pre perzistentné ukladanie dát.

## Požiadavky

- Railway účet (https://railway.app)
- Node.js 18+ (nastavené automaticky v Railway)

## Inštalácia na Railway

### 1. Vytvorenie projektu na Railway

1. Prihláste sa do Railway (https://railway.app)
2. Kliknite na "New Project"
3. Vyberte "Deploy from GitHub repo" alebo "Empty Project"

### 2. Pridanie PostgreSQL databázy

1. V Railway projekte kliknite na "+ New"
2. Vyberte "Database" → "Add PostgreSQL"
3. Railway automaticky vytvorí PostgreSQL databázu a nastaví `DATABASE_URL` environment variable

### 3. Konfigurácia environment variables

Railway automaticky nastaví:
- `DATABASE_URL` - PostgreSQL connection string
- `PORT` - Port pre server (defaultne 3000)
- `RAILWAY_PUBLIC_DOMAIN` - Public domain pre váš service (ak je nastavený public domain)

Môžete pridať ďalšie:
- `NODE_ENV=production`

### 4. Deploy

1. Railway automaticky detekuje `package.json` a `server.js`
2. Spustí `npm install` a potom `npm start`
3. Backend bude dostupný na `https://your-app-name.up.railway.app`

### 5. Nastavenie Public Domain (voliteľné)

1. V Railway projekte kliknite na váš service
2. Prejdite na "Settings" → "Networking"
3. Kliknite na "Generate Domain" alebo pridajte vlastný custom domain

## API Endpoints

Po nasadení budú dostupné tieto endpointy:

- `GET /` - API informácie
- `GET /health` - Health check
- `GET /api/quality?batchNumber=XXX` - Získanie kvality pre šaržu
- `POST /api/quality` - Uloženie kvality
- `GET /api/shipment?batchNumber=XXX` - Získanie expedovania pre šaržu
- `POST /api/shipment` - Uloženie expedovania
- `GET /api/sync?since=ISO_DATE&batchNumber=XXX` - Získanie zmien
- `POST /api/sync` - Registrácia zmeny

## Databázové schémy

Backend automaticky vytvorí tieto tabuľky pri prvom spustení:

- `quality` - Kvalita šarží
- `shipments` - Expedovanie šarží
- `sync_changes` - História zmien pre synchronizáciu

## Aktualizácia Flutter aplikácie

Flutter aplikácia je už nakonfigurovaná na použitie Railway backendu.

API URL je nastavený v `lib/config/api_config.dart`:
- Default URL: `https://pwms-production.up.railway.app`
- Všetky služby (`quality_sync_service.dart`, `shipment_sync_service.dart`, `realtime_sync_service.dart`) používajú tento konfiguračný súbor

Ak potrebujete zmeniť URL, upravte `API_BASE_URL` v `lib/config/api_config.dart` alebo použite environment variable pri buildovaní:
```bash
flutter build --dart-define=API_BASE_URL=https://your-custom-domain.com
```

## Lokálne testovanie

Pre lokálne testovanie:

1. Nainštalujte dependencies:
```bash
npm install
```

2. Nastavte `DATABASE_URL` v `.env` súbore (alebo použite Railway PostgreSQL URL)

3. Spustite server:
```bash
npm start
```

Server bude bežať na `http://localhost:3000`

## Monitoring

Railway poskytuje:
- Logs v reálnom čase
- Metrics (CPU, Memory, Network)
- Deployment history

Všetko je dostupné v Railway dashboarde.


# ProBlock (PWMS)

Monorepo:
- `apps/problock_flutter/` — Flutter aplikácia (Výroba / Sklad / QR)
- `backend/` — Node.js + TypeScript API (Railway + Postgres)

## Windows podpora (Flutter desktop)

### Predpoklady
- Flutter SDK
- Visual Studio 2022 + workload **Desktop development with C++** (kvôli Windows runneru)

### Spustenie na Windows
V PowerShell:

```powershell
cd .\apps\problock_flutter
flutter pub get
flutter run -d windows
```

## Backend (Windows lokálne)

### Predpoklady
- Node.js (už máš)
- Postgres (lokálne) alebo **public** Postgres URL

Poznámka: `postgres.railway.internal` funguje len v Railway. Lokálne potrebuješ buď lokálny Postgres, alebo Railway public connection string.

### Spustenie

```powershell
cd .\backend
npm install

# nastav DB (príklad)
$env:DATABASE_URL="postgresql://user:pass@localhost:5432/problock"

npm run migrate:up
npm run dev
```

Healthcheck:
- `GET http://localhost:3000/health`




# PWMS - Production and Warehouse Management System

Systém na evidenciu dát výroby betónových prvkov (tvárnice, dlažba, atď.) s podporou offline režimu a synchronizáciou s Railway PostgreSQL.

## Funkcie

- **Výroba (Production)**: Evidencia výroby betónových prvkov
- **Sklad (Warehouse)**: Správa zásob materiálov (štrk, cement, voda, atď.)
- **QR Kódy**: Automatické generovanie QR kódov pre výrobky
- **Offline podpora**: Aplikácia funguje lokálne bez internetu
- **Synchronizácia**: Automatická synchronizácia dát s Railway PostgreSQL
- **Desktop aplikácia**: Flutter desktopová aplikácia pre Windows

## Architektúra

### Backend
- Node.js + Express
- SQLite (lokálna databáza)
- PostgreSQL (Railway - cloud databáza)
- REST API

### Frontend
- Flutter Desktop (Windows)
- Material Design
- Offline-first prístup

## Inštalácia Backendu

1. Nainštalujte závislosti:
```bash
npm install
```

2. Vytvorte `.env` súbor z `env.example`:
```bash
copy env.example .env
```

3. Nastavte Railway PostgreSQL connection string v `.env`:
```
DATABASE_URL=postgresql://user:password@hostname:port/database
```

4. Inicializujte databázové schémy:
```bash
npm run migrate:local
npm run migrate:remote
```

5. Nastavte GitHub Secrets pre automatické migrácie:
   - V GitHub repozitári: **Settings** → **Secrets and variables** → **Actions**
   - Pridajte secret `DATABASE_URL` s Railway PostgreSQL connection stringom
   - Viac informácií v `DEPLOYMENT.md`

## Spustenie Backendu

### Vývojový režim:
```bash
npm run dev
```

### Produkčný režim:
```bash
npm start
```

Server beží na `http://localhost:3000`

## Inštalácia Frontendu (Flutter)

Pozri `FLUTTER_SETUP.md` pre podrobné inštrukcie.

### Rýchly štart:
```bash
flutter pub get
flutter run -d windows
```

## API Endpoints

### Materiály (Materials)
- `GET /api/materials` - Zoznam všetkých materiálov
- `GET /api/materials/:id` - Detail materiálu
- `POST /api/materials` - Vytvorenie nového materiálu
- `PUT /api/materials/:id` - Aktualizácia materiálu
- `DELETE /api/materials/:id` - Vymazanie materiálu

### Sklad (Warehouse)
- `GET /api/warehouse` - Zoznam všetkých položiek na sklade
- `GET /api/warehouse/:id` - Detail položky na sklade
- `POST /api/warehouse` - Pridanie/aktualizácia položky na sklade
- `PUT /api/warehouse/:id` - Aktualizácia množstva
- `PATCH /api/warehouse/material/:materialId/adjust` - Upravenie množstva (+/-)
- `DELETE /api/warehouse/:id` - Vymazanie položky

### Výroba (Production)
- `GET /api/production/types` - Zoznam typov výroby
- `POST /api/production/types` - Vytvorenie typu výroby
- `GET /api/production` - Zoznam všetkých výrob
- `GET /api/production/:id` - Detail výroby
- `POST /api/production` - Vytvorenie novej výroby
  ```json
  {
    "productionTypeId": "uuid",
    "quantity": 100,
    "materials": [
      {
        "materialId": "uuid",
        "quantity": 50
      }
    ],
    "notes": "Poznámky",
    "productionDate": "2024-01-01T00:00:00Z"
  }
  ```
- `PUT /api/production/:id` - Aktualizácia výroby
- `DELETE /api/production/:id` - Vymazanie výroby

### Synchronizácia (Sync)
- `GET /api/sync/status` - Stav synchronizácie
- `POST /api/sync` - Manuálna synchronizácia

## Offline režim

Backend používa SQLite databázu (`local.db`) pre lokálne ukladanie dát. Všetky operácie sa najprv ukladajú lokálne a automaticky sa pridávajú do synchronizačnej fronty.

Keď je dostupné internetové pripojenie a Railway databáza, dáta sa automaticky synchronizujú podľa nastavenia `AUTO_SYNC` a `SYNC_INTERVAL` v `.env` súbore.

## Synchronizácia

Synchronizácia funguje automaticky v pozadí (ak je zapnutá) alebo môžete spustiť manuálnu synchronizáciu:

```bash
npm run sync
```

Alebo cez API:
```bash
POST http://localhost:3000/api/sync
```

## Automatické Migrácie

Po pushnutí na `main` vetvu sa automaticky spustia migrácie databázy cez GitHub Actions.

**Nastavenie:**
1. V GitHub repozitári: **Settings** → **Secrets and variables** → **Actions**
2. Pridajte secret `DATABASE_URL` s Railway PostgreSQL connection stringom
3. Viac informácií v `DEPLOYMENT.md`

## Build Flutter aplikácie

### Windows Release Build:
```bash
flutter build windows --release
```

Výstupný `.exe` súbor bude v `build/windows/x64/runner/Release/pwms.exe`

## Štruktúra projektu

```
PWMS/
├── lib/                          # Flutter aplikácia
│   ├── main.dart
│   ├── models/
│   ├── screens/
│   └── services/
├── config/                       # Backend konfigurácia
├── models/                       # Backend modely
├── routes/                       # API routes
├── scripts/                      # Utility skripty
├── services/                     # Backend služby
├── server.js                     # Hlavný server
└── package.json                  # Backend dependencies
```

## Poznámky

- Lokálna databáza (`local.db`) sa vytvorí automaticky pri prvom spustení backendu
- Všetky dáta sa najprv ukladajú lokálne, potom sa synchronizujú s Railway
- QR kódy sa generujú automaticky pre každý výrobok
- Pri odstránení výroby sa materiály automaticky vracajú na sklad
- Automatické migrácie sa spúšťajú pri pushnutí na `main` vetvu (ak sú zmeny v `models/`, `scripts/` alebo `package.json`)

## Dokumentácia

- `FLUTTER_SETUP.md` - Návod na nastavenie Flutter prostredia
- `DEPLOYMENT.md` - Návod na deployment a automatické migrácie
- `SETUP.md` - Podrobný setup backendu

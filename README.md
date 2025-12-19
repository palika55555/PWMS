# PWMS - Production and Warehouse Management System

Systém na evidenciu dát výroby betónových prvkov (tvárnice, dlažba, atď.) s podporou offline režimu a synchronizáciou s Railway PostgreSQL.

## Funkcie

- **Výroba (Production)**: Evidencia výroby betónových prvkov
- **Sklad (Warehouse)**: Správa zásob materiálov (štrk, cement, voda, atď.)
- **QR Kódy**: Automatické generovanie QR kódov pre výrobky
- **Offline podpora**: Aplikácia funguje lokálne bez internetu
- **Synchronizácia**: Automatická synchronizácia dát s Railway PostgreSQL

## Technológie

- Node.js + Express
- SQLite (lokálna databáza)
- PostgreSQL (Railway - cloud databáza)
- QR Code generovanie

## Inštalácia

1. Nainštalujte závislosti:
```bash
npm install
```

2. Vytvorte `.env` súbor z `.env.example`:
```bash
cp .env.example .env
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

## Spustenie

### Vývojový režim:
```bash
npm run dev
```

### Produkčný režim:
```bash
npm start
```

Server beží na `http://localhost:3000`

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

Aplikácia používa SQLite databázu (`local.db`) pre lokálne ukladanie dát. Všetky operácie sa najprv ukladajú lokálne a automaticky sa pridávajú do synchronizačnej fronty.

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

## Príklady použitia

### 1. Vytvorenie materiálu
```bash
POST /api/materials
{
  "name": "Cement",
  "unit": "kg"
}
```

### 2. Pridanie materiálu na sklad
```bash
POST /api/warehouse
{
  "materialId": "material-uuid",
  "quantity": 1000
}
```

### 3. Vytvorenie typu výroby
```bash
POST /api/production/types
{
  "name": "Tvárnice",
  "description": "Betónové tvárnice"
}
```

### 4. Vytvorenie výroby
```bash
POST /api/production
{
  "productionTypeId": "type-uuid",
  "quantity": 50,
  "materials": [
    {
      "materialId": "cement-uuid",
      "quantity": 500
    },
    {
      "materialId": "water-uuid",
      "quantity": 200
    }
  ],
  "notes": "Výroba tvárnic pre projekt X"
}
```

Materiály sa automaticky odpočítajú zo skladu pri vytváraní výroby.

## Štruktúra projektu

```
PWMS/
├── config/
│   └── database.js          # Databázové pripojenia
├── models/
│   ├── database-schema.js   # Databázové schémy
│   ├── Material.js          # Model materiálov
│   ├── Warehouse.js         # Model skladu
│   └── Production.js        # Model výroby
├── routes/
│   ├── materials.js         # API routes pre materiály
│   ├── warehouse.js         # API routes pre sklad
│   ├── production.js        # API routes pre výrobu
│   └── sync.js              # API routes pre synchronizáciu
├── services/
│   └── sync-service.js      # Synchronizačná služba
├── scripts/
│   ├── migrate-local.js     # Migrácia lokálnej DB
│   ├── migrate-remote.js    # Migrácia vzdialenej DB
│   └── sync-to-remote.js    # Manuálna synchronizácia
├── server.js                # Hlavný server súbor
└── package.json
```

## Poznámky

- Lokálna databáza (`local.db`) sa vytvorí automaticky pri prvom spustení
- Všetky dáta sa najprv ukladajú lokálne, potom sa synchronizujú s Railway
- QR kódy sa generujú automaticky pre každý výrobok
- Pri odstránení výroby sa materiály automaticky vracajú na sklad

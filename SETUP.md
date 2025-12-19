# Inštalácia a Nastavenie

## 1. Inštalácia závislostí

```bash
npm install
```

## 2. Konfigurácia

Vytvorte súbor `.env` (môžete skopírovať `env.example`):

```bash
# Railway PostgreSQL Configuration
DATABASE_URL=postgresql://user:password@hostname:port/database

# Local Configuration
NODE_ENV=development
PORT=3000

# Sync Configuration
SYNC_ENABLED=true
SYNC_INTERVAL=300000  # 5 minút v milisekundách
AUTO_SYNC=true        # Automatická synchronizácia
```

**Dôležité**: Nahraďte `DATABASE_URL` skutočným connection stringom z Railway PostgreSQL databázy.

## 3. Inicializácia databáz

### Lokálna databáza (SQLite)
Lokálna databáza sa vytvorí automaticky pri prvom spustení servera, alebo môžete spustiť:

```bash
npm run migrate:local
```

### Vzdialená databáza (Railway PostgreSQL)
```bash
npm run migrate:remote
```

## 4. Spustenie servera

### Vývojový režim (s auto-reload):
```bash
npm run dev
```

### Produkčný režim:
```bash
npm start
```

Server bude bežať na `http://localhost:3000`

## 5. Manuálna synchronizácia

Ak chcete manuálne synchronizovať dáta na Railway:

```bash
npm run sync
```

Alebo cez API:
```bash
POST http://localhost:3000/api/sync
```

## Testovanie API

### Príklad: Vytvorenie materiálu
```bash
curl -X POST http://localhost:3000/api/materials \
  -H "Content-Type: application/json" \
  -d '{"name":"Cement","unit":"kg"}'
```

### Príklad: Vytvorenie typu výroby
```bash
curl -X POST http://localhost:3000/api/production/types \
  -H "Content-Type: application/json" \
  -d '{"name":"Tvárnice","description":"Betónové tvárnice"}'
```

### Príklad: Pridanie materiálu na sklad
```bash
curl -X POST http://localhost:3000/api/warehouse \
  -H "Content-Type: application/json" \
  -d '{"materialId":"material-uuid","quantity":1000}'
```

### Príklad: Vytvorenie výroby
```bash
curl -X POST http://localhost:3000/api/production \
  -H "Content-Type: application/json" \
  -d '{
    "productionTypeId":"type-uuid",
    "quantity":50,
    "materials":[
      {"materialId":"cement-uuid","quantity":500},
      {"materialId":"water-uuid","quantity":200}
    ],
    "notes":"Výroba tvárnic"
  }'
```

## Poznámky

- Aplikácia funguje **offline** pomocou lokálnej SQLite databázy
- Všetky zmeny sa automaticky pridávajú do synchronizačnej fronty
- Keď je dostupné pripojenie, dáta sa synchronizujú na Railway PostgreSQL
- QR kódy sa generujú automaticky pre každú výrobu
- Materiály sa automaticky odpočítavajú zo skladu pri vytváraní výroby


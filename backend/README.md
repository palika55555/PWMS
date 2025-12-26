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








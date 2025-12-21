# Railway setup (backend)

## 1) Service URL (API)
- **HTTP**: `pwms-production.up.railway.app`
- Healthcheck: `GET /health`
- API root: `GET /v1`

## 2) Environment variables
V Railway (Variables) nastav:

- **DATABASE_URL**: `postgresql://postgres:yugXsabFsVVtksksXJEAPfIhHnZUnrZg@postgres.railway.internal:5432/railway`
- **PORT**: netreba nastavovať (Railway nastaví automaticky), ale môžeš.

Poznámka: `postgres.railway.internal` funguje **iba v rámci Railway siete**. Pre lokálny vývoj potrebuješ public connection string z Railway (alebo lokálny Postgres).

## 3) Start command (migrácie + server)
Nastav **Start Command** na:

- `npm run start:railway`

Tento príkaz spustí:
- `node-pg-migrate up` (bezpečné; vytvorí tabuľky len ak neexistujú)
- `node dist/server.js`

## 4) Deploy
Po deploy:
- Railway logy by mali obsahovať migrácie a potom `API listening on :<PORT>`




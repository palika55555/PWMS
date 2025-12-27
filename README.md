# ProBlock PWMS - Production and Warehouse Management System

Systém na riadenie výroby a skladu pre firmu ProBlock, ktorá sa zaoberá výrobou betónových prvkov (tvárnice, dlažba, atď.).

## Funkcie

### 📱 Flutter Aplikácia

Aplikácia obsahuje 3 hlavné moduly:

1. **Výroba**
   - Zaznamenávanie výroby produktov
   - Správa receptúr (pomery materiálov: cement, štrk rôznych frakcií, voda, plastifikátor)
   - Schvaľovanie kvality šarží za daný deň
   - Prehľad šarží podľa dátumu

2. **Sklad**
   - Prehľad materiálov a ich zásob
   - Upozornenia na nedostatok materiálov
   - Sledovanie minimálnych stavov

3. **QR Kód**
   - Skenovanie QR kódov produktov
   - Generovanie QR kódov

### 🌐 QR Web (Vercel)

V priečinku `qr-web/` je samostatná web appka (Next.js) určená na **skenovanie QR kódov paliet** a **jednoduchú evidenciu paliet na sklade** (Príjem/Výdaj).
Návod na deploy je v `qr-web/README.md`.

### 🔄 Offline Režim

Aplikácia funguje aj bez pripojenia na internet pomocou lokálnej SQLite databázy. Po obnovení pripojenia sa údaje automaticky synchronizujú so serverom.

### 🚂 Backend (Railway)

- Node.js/Express API
- PostgreSQL databáza
- Automatické migrácie pri nasadení
- Ošetrenie existujúcich tabuliek (nebudú sa vytvárať duplikáty)

## Inštalácia a Spustenie

### Flutter Aplikácia

#### Windows

1. Nainštalujte Flutter SDK a Visual Studio (pozri [WINDOWS_SETUP.md](WINDOWS_SETUP.md))

2. Spustite aplikáciu:
```cmd
run_windows.bat
```

Alebo manuálne:
```cmd
flutter pub get
flutter run -d windows
```

3. Build aplikácie:
```cmd
build_windows.bat
```

#### Android/iOS

1. Nainštalujte Flutter dependencies:
```bash
flutter pub get
```

2. Spustite aplikáciu:
```bash
flutter run
```

### Backend

1. Prejdite do priečinka backend:
```bash
cd backend
```

2. Nainštalujte dependencies:
```bash
npm install
```

3. Vytvorte `.env` súbor (skopírujte z `.env.example`):
```bash
cp .env.example .env
```

4. Nastavte `DATABASE_URL` v `.env` súbore:
```
DATABASE_URL=postgresql://user:password@localhost:5432/problock_pwms
```

5. Spustite server:
```bash
npm start
```

Pre development s automatickým reloadom:
```bash
npm run dev
```

## Nasadenie na Railway

### 1. Vytvorenie projektu na Railway

1. Prihláste sa na [Railway](https://railway.app)
2. Vytvorte nový projekt
3. Pridajte PostgreSQL databázu
4. Skopírujte `DATABASE_URL` z Railway dashboardu

### 2. Konfigurácia

1. V Railway projekte nastavte environment variable:
   - `DATABASE_URL` - URL PostgreSQL databázy (automaticky nastavené Railway)
   - `NODE_ENV=production`
   - `PORT` - Railway automaticky nastaví port

2. Railway automaticky detekuje `railway.toml` a spustí migrácie pri nasadení

### 3. Deploy

1. Pushnite kód na Git:
```bash
git add .
git commit -m "Initial commit"
git push origin main
```

2. Railway automaticky:
   - Detekuje zmeny
   - Zostaví projekt
   - Spustí migrácie databázy
   - Spustí server

### 4. Konfigurácia Flutter aplikácie

V `lib/config/api_config.dart` nastavte URL vášho Railway projektu:
```dart
static const String baseUrl = 'https://your-app-name.railway.app';
```

Alebo použite environment variable pri buildovaní:
```bash
flutter build apk --dart-define=API_BASE_URL=https://your-app-name.railway.app
```

## Štruktúra Databázy

### Hlavné tabuľky:

- **materials** - Materiály (cement, štrk, voda, plastifikátor)
- **aggregate_fractions** - Frakcie štrku
- **recipes** - Receptúry pre výrobu
- **recipe_aggregates** - Vzťah medzi receptúrami a agregátmi
- **batches** - Výrobné šarže
- **batch_materials** - Materiály použitých v šarži
- **quality_tests** - Testy kvality
- **products** - Hotové produkty s QR kódmi
- **sync_queue** - Fronta na synchronizáciu (lokálna DB)

## Migrácie

Migrácie sa spúšťajú automaticky pri spustení servera. Systém kontroluje existenciu tabuliek a vytvára len tie, ktoré ešte neexistujú.

Pre manuálne spustenie migrácií:
```bash
cd backend
npm run migrate
```

## Synchronizácia

Aplikácia automaticky synchronizuje údaje medzi lokálnou SQLite a serverovou PostgreSQL databázou:

- Pri vytvorení nového záznamu sa uloží lokálne s `synced = 0`
- Pri obnovení pripojenia sa spustí synchronizácia
- Neúspešné synchronizácie sa ukladajú do `sync_queue` na opätovný pokus

## Platformy

### Windows
- ✅ Plná podpora desktop aplikácie
- ✅ SQLite databáza funguje bez problémov
- ✅ QR scanner: manuálne zadanie alebo vloženie zo schránky
- 📖 Pozri [WINDOWS_SETUP.md](WINDOWS_SETUP.md) pre detailný návod

### Android/iOS
- ✅ Plná podpora mobilných aplikácií
- ✅ QR scanner s kamerou
- ✅ Offline režim s SQLite

### Web
- ⚠️ Čiastočná podpora (vývoj)

## Technológie

- **Frontend**: Flutter/Dart
- **Platformy**: Windows, Android, iOS, Web (čiastočná podpora)
- **Backend**: Node.js/Express
- **Databáza**: PostgreSQL (produkcia), SQLite (lokálna)
- **Hosting**: Railway
- **State Management**: Provider
- **QR Kódy**: qr_flutter, mobile_scanner (mobilné), manuálne zadanie (Windows)

## Licencia

Vlastníctvo firmy ProBlock

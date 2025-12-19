# PWMS - Production Warehouse Management System

Aplikácia na manažovanie výroby s lokálnou SQLite databázou pre Windows.

## Funkcie

- **Výroba** - Sledovanie spotreby materiálov a počtu vyrobených produktov
  - Zobrazenie aktuálneho stavu zásob (štrk rôznych veľkostí, cement, plastifikátor, voda)
  - Výrobný prehľad s celkovým počtom vyrobených produktov
  - Zaznamenávanie výroby dlažby a tvárnic
  - Automatické odčítanie spotrebovaných materiálov
  - História výroby
- **Sklad** - Správa materiálov a zásob
- **QR Kód** - Skenovanie a generovanie QR kódov
  - Generovanie QR kódov pre každý deň výroby
  - Web zobrazenie podrobností po naskenovaní QR kódu (iPhone/Android)

## Požiadavky

- Flutter SDK (3.10.4 alebo novší)
- Windows 10/11
- Visual Studio s Windows desktop development tools

## Inštalácia

1. Nainštalujte závislosti:
```bash
flutter pub get
```

2. Spustite aplikáciu:
```bash
flutter run -d windows
```

## Štruktúra projektu

```
lib/
├── main.dart                 # Vstupný bod aplikácie
├── database/
│   └── database_helper.dart  # SQLite databázový helper
├── models/                   # Data modely
│   ├── material.dart
│   ├── product.dart
│   └── production_log.dart
├── services/                 # Business logika
│   ├── material_service.dart
│   └── production_service.dart
└── screens/                  # UI obrazovky
    ├── home_screen.dart      # Úvodný výber možností
    ├── production_screen.dart # Výroba s prehľadom zásob
    ├── warehouse_screen.dart
    └── qrcode_screen.dart
```

## Databáza

Aplikácia používa SQLite databázu, ktorá sa automaticky vytvorí pri prvom spustení. Databáza obsahuje:

- **materials** - Materiály a zásoby
  - Štrk 0-4 mm, 4-8 mm, 8-16 mm, 16-32 mm
  - Cement
  - Plastifikátor
  - Voda
- **products** - Produkty (Dlažba, Tvárnice)
- **production_batches** - Výrobné šarže
- **production_logs** - Záznamy o spotrebe materiálov pri výrobe

## Použitie

### Výroba

1. Otvorte sekciu **Výroba** z hlavnej obrazovky
2. Zobrazí sa aktuálny stav zásob všetkých materiálov
3. Pre zaznamenanie výroby kliknite na tlačidlo **+** v pravom hornom rohu
4. Vyberte produkt (Dlažba alebo Tvárnice)
5. Zadajte množstvo a spotrebu materiálov
6. Voliteľne pridajte poznámky
7. Uložte výrobu - materiály sa automaticky odčítajú zo zásob

## Nasadenie na Vercel

Aplikácia je pripravená na nasadenie na Vercel. Existujú dva spôsoby:

### Metóda 1: Automatický build na Vercel (odporúčané)

1. Pushnite kód do Git repozitára (GitHub, GitLab, Bitbucket)
2. Pripojte repozitár k Vercel projektu
3. Vercel automaticky použije `vercel.json` konfiguráciu
4. Build môže trvať 5-10 minút (inštalácia Flutter SDK)

**Poznámka:** Ak build timeoutne, použite Metódu 2.

### Metóda 2: Pre-built deployment (rýchlejšie)

1. Lokálne zostavte aplikáciu:
```bash
flutter build web --release
```

2. Commitnite `build/web` priečinok do Git:
```bash
git add build/web
git commit -m "Add pre-built web files"
git push
```

3. Upravte `vercel.json` - zmeňte `buildCommand` na:
```json
"buildCommand": "echo 'Using pre-built files'"
```

4. Pushnite zmeny - Vercel použije už zostavené súbory

## Vývoj

Aplikácia je pripravená na ďalší vývoj. Môžete pridať:
- CRUD operácie pre materiály a produkty v sekcii Sklad
- QR kód skenovanie a generovanie
- Reporty a štatistiky
- Export dát
- Viac produktov a materiálov

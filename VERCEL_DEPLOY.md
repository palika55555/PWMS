# Nasadenie na Vercel

## Krok 1: Vytvorenie buildu

Spustite:
```bash
flutter build web --release
```

Alebo na Windows:
```bash
build_vercel.bat
```

## Krok 2: Inštalácia Vercel CLI (voliteľné)

```bash
npm install -g vercel
```

## Krok 3: Nasadenie

### Možnosť A: Cez Vercel CLI

1. Prihláste sa:
```bash
vercel login
```

2. Nasadenie:
```bash
vercel --prod
```

Alebo priamo z priečinka `build/web`:
```bash
cd build/web
vercel --prod
```

### Možnosť B: Cez Vercel Dashboard (odporúčané)

1. Prejdite na https://vercel.com
2. Prihláste sa (GitHub, GitLab, alebo email)
3. Kliknite na "Add New Project"
4. Buď:
   - Pripojte GitHub/GitLab repozitár a Vercel automaticky detekuje Flutter
   - Alebo použite "Import" a nahrajte priečinok `build/web`

5. Nastavenia projektu:
   - **Framework Preset**: Other
   - **Root Directory**: `build/web` (ak importujete z root)
   - **Build Command**: `flutter build web --release`
   - **Output Directory**: `build/web`

6. Kliknite "Deploy"

## Krok 4: Konfigurácia (dôležité pre QR scanner)

Vercel automaticky poskytuje HTTPS, čo je potrebné pre prístup ku kamere.

### Environment Variables (ak potrebujete)

V Vercel dashboard → Settings → Environment Variables môžete pridať:
- Žiadne špeciálne premenné nie sú potrebné pre základnú funkcionalitu

## Krok 5: Automatické nasadenie (voliteľné)

Ak máte projekt na GitHube:

1. V Vercel dashboard → Settings → Git
2. Pripojte repozitár
3. Vercel automaticky nasadí pri každom push

### Build Settings:
- **Build Command**: `flutter build web --release`
- **Output Directory**: `build/web`
- **Install Command**: `flutter pub get`

## Poznámky:

1. **HTTPS**: Vercel automaticky poskytuje HTTPS, čo je potrebné pre webkameru
2. **QR Scanner**: Web verzia má obmedzenú podporu - odporúča sa použiť mobilnú aplikáciu
3. **Databáza**: SQLite na web funguje cez IndexedDB (automaticky cez sqflite)
4. **CORS**: Vercel automaticky nastaví správne CORS hlavičky
5. **Lokálna databáza**: Na web sa databáza ukladá lokálne v prehliadači (IndexedDB), každý používateľ má svoju vlastnú databázu

## Dôležité upozornenie:

**Databáza na web je lokálna v prehliadači!** To znamená:
- Každý používateľ má svoju vlastnú databázu
- Dáta sa nezdielajú medzi používateľmi
- Ak vymažete cache prehliadača, stratíte dáta
- Pre zdieľanie dát medzi používateľmi potrebujete backend API

Ak chcete zdieľať dáta medzi používateľmi, môžem implementovať:
- Backend API na Vercel Functions
- Cloud databázu (Supabase, Firebase)
- Synchronizáciu cez HTTP server


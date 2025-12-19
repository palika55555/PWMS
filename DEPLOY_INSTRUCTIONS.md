# Inštrukcie na nasadenie na Vercel

## Rýchle nasadenie (Odporúčané)

### Krok 1: Build lokálne

```bash
flutter build web --release
```

### Krok 2: Nasadenie cez Vercel CLI

```bash
# Nainštalujte Vercel CLI (ak nemáte)
npm install -g vercel

# Prihláste sa
vercel login

# Nasadenie z build/web priečinka
cd build/web
vercel --prod
```

Alebo jednoducho:
```bash
cd build/web && vercel --prod
```

## Alternatíva: Commitnúť build/web do Git

Ak chcete automatické nasadenie cez GitHub:

1. Build lokálne:
```bash
flutter build web --release
```

2. Commitnite build/web:
```bash
git add build/web
git commit -m "Add built web files for Vercel"
git push
```

3. Vercel automaticky nasadí (bez buildCommand, len použije build/web)

## Poznámka

`vercel.json` je nastavený tak, aby používal už buildnuté súbory z `build/web` bez potreby buildovať na Vercel.


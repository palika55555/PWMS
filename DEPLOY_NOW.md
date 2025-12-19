# Rýchle nasadenie na Vercel

## Problém: 404 chyba

Vercel nenašiel súbory. Najrýchlejšie riešenie je nasadiť priamo cez Vercel CLI.

## Riešenie: Nasadenie cez Vercel CLI

### Krok 1: Nainštalujte Vercel CLI (ak nemáte)

```bash
npm install -g vercel
```

### Krok 2: Prihláste sa

```bash
vercel login
```

### Krok 3: Nasadenie z build/web

```bash
cd build/web
vercel --prod
```

Toto nasadí aplikáciu priamo z lokálneho `build/web` priečinka a obíde problém s Git.

## Alternatíva: Vercel Dashboard

1. **Settings** → **Build and Deployment**
2. **Output Directory**: `build/web` (Override ZAPNUTÝ)
3. **Build Command**: prázdne (Override ZAPNUTÝ)
4. **Redeploy** posledný deployment

## Po nasadení

- `https://pwms.vercel.app` - hlavná aplikácia
- `https://pwms.vercel.app/production?data=...` - QR kód stránka


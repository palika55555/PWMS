# Nastavenie Vercel pre Flutter Web

## Nastavenia v Vercel Dashboard

### Krok 1: Prejdite do Settings
Vercel Dashboard → Váš projekt → **Settings** → **Build and Deployment**

### Krok 2: Nastavte Framework Settings

#### Output Directory:
1. Zapnite **Override** toggle
2. Zadajte: `build/web`
3. Toto povie Vercel, kde nájsť už buildnuté súbory

#### Build Command:
1. Zapnite **Override** toggle  
2. Nechajte **prázdne** alebo zadajte: `echo "Build done locally"`
3. Toto vypne buildovanie na Vercel (buildujeme lokálne)

#### Install Command:
- Môžete nechať **vypnuté** (Override OFF)

### Krok 3: Uložte zmeny
Kliknite na **Save** tlačidlo vpravo dole

## Postup nasadenia

### Možnosť A: Commitnúť build/web do Git (Odporúčané)

1. **Build lokálne:**
```bash
flutter build web --release
```

2. **Commitnite build/web:**
```bash
git add build/web
git commit -m "Add built web files"
git push
```

3. **Vercel automaticky nasadí** pri push do main branch

### Možnosť B: Nasadenie cez Vercel CLI

1. **Build lokálne:**
```bash
flutter build web --release
```

2. **Nasadenie:**
```bash
cd build/web
vercel --prod
```

## Poznámka

Ak commitnete `build/web` do Git, Vercel použije už buildnuté súbory a nepotrebuje Flutter nainštalovaný.


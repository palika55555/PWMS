# Rýchle riešenie pre Vercel

## Problém
Vercel hovorí: "No Output Directory named 'web' found"

## Riešenie

### Krok 1: Commitnite build/web do Git

```bash
git add build/web
git commit -m "Add built web files for Vercel deployment"
git push
```

### Krok 2: V Vercel Dashboard

1. Settings → Build and Deployment
2. **Output Directory**: Zapnite Override → `build/web`
3. **Build Command**: Zapnite Override → prázdne alebo `echo "Build done locally"`
4. Kliknite **Save**

### Krok 3: Vytvorte nový deployment

Vercel automaticky vytvorí nový deployment po push do Git, alebo môžete vytvoriť manuálne.

## Alternatíva: Nasadenie cez Vercel CLI

Ak nechcete commitnúť build/web do Git:

```bash
cd build/web
vercel --prod
```

Toto nasadí priamo z lokálneho build/web priečinka.


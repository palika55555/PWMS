# Oprava Railway Deploy problému

## Problém
Railway sa pokúšal buildovať Flutter projekt (kvôli `pubspec.yaml`), ale backend je Node.js server.

## Riešenie

Vytvoril som tieto súbory:

1. **`nixpacks.toml`** - Explicitne hovorí Railway, že toto je Node.js projekt
2. **`railway.toml`** - Alternatívna Railway konfigurácia
3. **`.railwayignore`** - Ignoruje Flutter súbory pri buildovaní

## Čo sa zmenilo

- Railway teraz builduje len Node.js backend
- Flutter súbory sú ignorované pri buildovaní
- Backend sa spustí pomocou `node server.js`

## Ďalšie kroky

1. Commitnite a pushnite tieto zmeny do GitHubu
2. Railway automaticky detekuje zmeny a spustí nový build
3. Build by mal teraz prebehnúť úspešne

## Alternatívne riešenie (ak problém pretrváva)

Ak Railway stále detekuje Flutter projekt, môžete:

1. V Railway dashboarde → Settings → Build
2. Nastaviť "Build Command" na: `npm install`
3. Nastaviť "Start Command" na: `node server.js`
4. V "Root Directory" nechať prázdne (alebo nastaviť na `.`)

## Overenie

Po úspešnom deployi by ste mali vidieť v Railway logoch:
```
Server running on port 3000
Environment: production
Database initialized successfully
```


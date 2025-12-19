# Nastavenie verejného prístupu na Vercel

## Problém

Keď naskenujete QR kód, Vercel žiada o meno a heslo. To je kvôli **Password Protection** (Deployment Protection), ktorá je zapnutá.

## Riešenie: Vypnúť Password Protection

### Krok 1: Vercel Dashboard

1. Prejdite na https://vercel.com
2. Prihláste sa do svojho účtu
3. Vyberte svoj projekt (PWMS)

### Krok 2: Nastavenia projektu

1. Kliknite na **Settings** (Nastavenia)
2. V ľavom menu vyberte **Deployment Protection**
3. Nájdite možnosť **Password Protection** alebo **Deployment Protection**
4. **Vypnite** túto možnosť (alebo nastavte na "None")

### Krok 3: Alternatívne riešenie

Ak chcete mať ochranu len pre hlavnú aplikáciu, ale nie pre `/production` endpoint:

1. V **Settings** → **Deployment Protection**
2. Nastavte **Password Protection** len pre konkrétne cesty
3. Alebo vytvorte **Environment Variables** pre verejné stránky

## Alternatíva: Vytvorenie verejnej stránky

Ak chcete mať ochranu pre hlavnú aplikáciu, ale verejnú stránku pre QR kódy:

1. Vytvorte samostatný projekt na Vercel len pre `/production` stránku
2. Alebo použite **Vercel Edge Config** pre verejné stránky

## Rýchle riešenie

Najjednoduchšie je **vypnúť Password Protection** úplne:

1. Vercel Dashboard → Váš projekt
2. Settings → Deployment Protection
3. Vypnite **Password Protection**
4. Uložte zmeny

Po vypnutí bude stránka verejne dostupná a QR kódy budú fungovať bez hesla.

## Poznámka

Ak chcete mať ochranu pre hlavnú aplikáciu, ale nie pre QR kód stránky, môžem implementovať:
- Samostatnú verejnú stránku len pre QR kód zobrazenie
- Alebo použiť Vercel Edge Functions pre verejné API


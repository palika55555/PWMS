# PWMS QR Web (Vercel)

Jednoduchá web stránka na **skenovanie QR kódov paliet** a **evidenciu paliet na sklade**.

## Funkcie

- **Príjem**: naskenovanie pridá/označí paletu ako *na sklade*
- **Výdaj/Odčítanie**: naskenovanie označí paletu ako *vydané*
- **Prehľad**: počty podľa produktu + zoznam paliet
- **História**: posledné skeny
- **Export/Import**: JSON (na zálohu / prenos do iného zariadenia)

> Dáta sa ukladajú lokálne do prehliadača (localStorage). Ak chceš centrálne ukladanie (viac telefónov), doplníme API napojenie na backend.

## Podporované formáty QR

Aplikácia vie rozpoznať viac formátov:

1) **JSON** (odporúčané do budúcna)

Príklad:

```json
{
  "productCode": "DT20",
  "palletId": "PAL-000123"
}
```

Podporované kľúče (aliasy): `productCode/product_code/product/sku` a `palletId/pallet_id/pallet/paleta/id`.

2) **Delimitované**

- `DT20|PAL-000123`
- `DT20;PAL-000123;40` (tretia hodnota môže byť qty, zatiaľ je len informatívna)

3) **Raw**

- `PAL-000123`

V tomto prípade musíš mať vyplnené pole **Produkt (napr. DT20)**.

## Lokálne spustenie

V koreňi repo:

```bash
cd qr-web
npm install
npm run dev
```

## Deploy na Vercel

Najjednoduchšie:

1. V Vercel vytvor nový projekt z tohto Git repozitára.
2. Nastav **Root Directory** na `qr-web`.
3. Build príkazy:
   - Install: `npm install`
   - Build: `npm run build`
   - Output: (Next.js auto)
4. Deploy.

Kamera funguje len cez **HTTPS** (Vercel je OK).

## Napojenie na backend (centrálne dáta)

Ak chceš, aby sa stav paliet zdieľal medzi viacerými zariadeniami, nastav na Verceli env premennú:

- `NEXT_PUBLIC_API_BASE_URL` = URL tvojho backendu (napr. `https://pwms-production.up.railway.app`)

Potom v appke zapni prepínač **„Použiť backend“**.



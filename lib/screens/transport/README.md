# Doprava - Výpočet dopravy

## ✅ Používa OpenStreetMap + OSRM (ZADARMO, bez API kľúča!)

Aplikácia používa **OpenStreetMap** a **OSRM** (Open Source Routing Machine) pre výpočet vzdialenosti. Toto riešenie je:
- ✅ **Úplne zdarma** - žiadne API kľúče, žiadne limity
- ✅ **Bez registrácie** - nie je potrebný Google účet
- ✅ **Dobrá presnosť** - používa reálne mapové dáta
- ✅ **Legálne použiteľné** - OpenStreetMap je open source

## Ako to funguje

1. **Geokódovanie adries** - Adresy sa prevádzajú na súradnice pomocou Nominatim (OpenStreetMap geocoding)
2. **Výpočet vzdialenosti** - OSRM vypočíta vzdialenosť po cestách medzi súradnicami
3. **Výpočet ceny** - Na základe vzdialenosti, spotreby a ceny paliva sa vypočíta cena dopravy

## Použitie

1. Spustite aplikáciu
2. Prejdite do **"Doprava"**
3. Zadajte adresy:
   - **Adresa odkiaľ** (napr. "Bratislava" alebo "Božčice 38")
   - **Adresa kam** (napr. "Košice" alebo "Hudcovce 99")
4. Zadajte **spotrebu paliva** (l/100 km) - predvolená hodnota: 6.5
5. Zadajte **cenu paliva** (€/l) - predvolená hodnota: 1.70
6. Kliknite na **"Vypočítať dopravu"**

## Výsledky

Aplikácia zobrazí:
- **Vzdialenosť** v kilometroch
- **Spotrebované palivo** v litroch
- **Cena dopravy** v eurách

## Technické detaily

- **Nominatim API**: `https://nominatim.openstreetmap.org/` - geokódovanie adries
- **OSRM API**: `https://router.project-osrm.org/` - výpočet trás a vzdialenosti

## Poznámky

- Nominatim má mierne obmedzenia na počet požiadaviek (1 požiadavka/sekundu)
- Pre produkčné použitie odporúčame vlastnú inštanciu Nominatim alebo OSRM servera
- Adresy môžu byť v slovenčine, češtine alebo angličtine


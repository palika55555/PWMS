# QR Kód - Web Zobrazenie Podrobností

## Ako to funguje

Keď naskenujete QR kód fotoaparátom na iPhone (alebo akomkoľvek mobile), automaticky sa otvorí web stránka s podrobnosťami o výrobe.

## Funkcionalita

1. **Generovanie QR kódu**:
   - V sekcii **Výroba** kliknite na ikonu QR kódu pri konkrétnom dni
   - QR kód obsahuje URL s dátami o výrobe

2. **Skenovanie QR kódu**:
   - Použite fotoaparát na iPhone/Android
   - Automaticky sa otvorí web stránka s podrobnosťami

3. **Zobrazenie podrobností**:
   - Dátum výroby
   - Počet šarží
   - Celkom vyrobených kusov
   - Zoznam produktov s množstvami
   - Čísla šarží

## Nastavenie pre Desktop aplikáciu

Ak používate desktop aplikáciu (Windows), QR kód obsahuje placeholder URL:
```
https://your-app.vercel.app/production?data=...
```

**Po nasadení na Vercel:**
1. Získajte svoju Vercel URL (napr. `https://pwms.vercel.app`)
2. Nahraďte `your-app.vercel.app` v QR kóde svojou URL
3. Alebo upravte kód v `lib/screens/production_screen.dart` na riadku 1137

## Web verzia

Na web verzií aplikácie sa automaticky používa aktuálna URL, takže QR kódy fungujú okamžite po nasadení na Vercel.

## Príklad URL

QR kód obsahuje URL v tomto formáte:
```
https://your-app.vercel.app/production?data=eyJkYXRlIjoiMjAyNS0xMi0xOVQwMDowMDowMC4wMDBaIiwiYmF0Y2hlcyI6MSwidG90YWxfcXVhbnRpdHkiOjIsInByb2R1Y3RzIjp7IkRsYcWZw6JhIjoyfSwiYmF0Y2hfbnVtYmVycyI6WyJCTi0yMDI1MTIxOS0wMDAxIl19
```

Dáta sú base64 encoded JSON, ktorý obsahuje:
- Dátum výroby
- Počet šarží
- Celkom vyrobených
- Produkty
- Čísla šarží

## Testovanie

1. **Lokálne testovanie**:
   ```bash
   flutter run -d chrome
   ```
   Otvorte QR kód a naskenujte ho mobile fotoaparátom (musíte byť na rovnakej sieti)

2. **Po nasadení na Vercel**:
   - QR kódy fungujú automaticky
   - Stačí naskenovať QR kód a otvorí sa web stránka s podrobnosťami

## Poznámky

- QR kód funguje len na HTTPS alebo localhost (kvôli bezpečnosti prehliadača)
- Po nasadení na Vercel sa automaticky poskytuje HTTPS
- Dáta v QR kóde sú base64 encoded, takže sú bezpečné pre URL


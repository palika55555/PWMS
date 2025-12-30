// ====================================================================
// QR PAYLOAD UTILITY - Flutter appka
// ====================================================================
// Tento súbor generuje JSON payloady pre QR kódy
// Používa sa vo Flutter appke pre generovanie QR kódov pre šarže a palety
// Kompatibilné s qr-web/lib/qr.ts parserom

import 'dart:convert';

// ====================================================================
// QR PAYLOAD FORMÁTY
// ====================================================================

/**
 * QR payload pre výrobnú šaržu
 * Používa sa pri vytváraní novej šarže vo Flutter appke
 * QR web tento formát vie parsovať a zobraziť detaily šarže
 * 
 * Príklad JSON:
 * {
 *   "t":"batch",
 *   "batchNumber":"BATCH-20251227-123456",
 *   "productCode":"DT20",
 *   "qty":1200,
 *   "productionDate":"2025-12-27",
 *   "recipeId": 5,
 *   "dryingDays": 7,
 *   "curingStartDate": "2025-12-27T10:00:00.000Z",
 *   "curingEndDate": "2026-01-03T10:00:00.000Z",
 *   "productionTemperature": 20.5,
 *   "productionHumidity": 55.0,
 *   "notes": "Batch notes"
 * }
 */

/**
 * QR payload pre produktovú paletu
 * Používa sa pri balení produktov do paliet vo Flutter appke
 * QR web tento formát vie parsovať a pridať paletu do systému
 * 
 * Príklad JSON:
 * {
 *   "t":"pallet",
 *   "palletId":"PAL-000123",
 *   "productCode":"DT20",
 *   "batchNumber":"BATCH-20251227-123456",
 *   "qty":40,
 *   "packedAt":"2025-12-27T21:30:00.000Z"
 * }
 */

// ====================================================================
// QR PAYLOAD GENERATOR CLASS
// ====================================================================

class QrPayload {
  
  /**
   * Generuje QR payload pre výrobnú šaržu
   * 
   * @param batchNumber - unikátne číslo šarže (napr. "BATCH-20251227-123456")
   * @param productCode - kód produktu (napr. "DT20")
   * @param qty - vyrobené množstvo (v kg alebo ks)
   * @param productionDate - dátum výroby vo formáte yyyy-MM-dd
   * @param recipeId - voliteľné ID receptúry
   * @param dryingDays - voliteľné dni sušenia
   * @param curingStartDate - voliteľný začiatok tvrdnutia (ISO format)
   * @param curingEndDate - voliteľný koniec tvrdnutia (ISO format)
   * @param productionTemperature - voliteľná teplota výroby (°C)
   * @param productionHumidity - voliteľná vlhkosť výroby (%)
   * @param notes - voliteľné poznámky k šarži
   * 
   * @returns JSON string pre QR kód
   */
  static String batch({
    required String batchNumber,
    required String productCode,
    required int qty,
    required String productionDate, // yyyy-MM-dd
    int? recipeId,
    int? dryingDays,
    String? curingStartDate,
    String? curingEndDate,
    double? productionTemperature,
    double? productionHumidity,
    String? notes,
  }) {
    // Vytvorenie základného payloadu s povinnými poliami
    final Map<String, dynamic> payload = {
      't': 'batch', // Typ identifikátor - dôležité pre parser
      'batchNumber': batchNumber,
      'productCode': productCode,
      'qty': qty,
      'productionDate': productionDate,
    };

    // Pridanie voliteľných polí len ak nie sú null/prázdne
    if (recipeId != null) payload['recipeId'] = recipeId;
    if (dryingDays != null) payload['dryingDays'] = dryingDays;
    if (curingStartDate != null) payload['curingStartDate'] = curingStartDate;
    if (curingEndDate != null) payload['curingEndDate'] = curingEndDate;
    if (productionTemperature != null) payload['productionTemperature'] = productionTemperature;
    if (productionHumidity != null) payload['productionHumidity'] = productionHumidity;
    if (notes != null && notes.isNotEmpty) payload['notes'] = notes;

    // Konverzia na JSON string pre QR kód
    return jsonEncode(payload);
  }

  /**
   * Generuje QR payload pre produktovú paletu
   * 
   * @param palletId - unikátne ID palety (napr. "PAL-000123")
   * @param productCode - kód produktu (napr. "DT20")
   * @param batchNumber - voliteľné číslo šarže (pre sledovateľnosť)
   * @param qty - množstvo na palete (v ks alebo kg)
   * @param packedAtIso - voliteľný dátum a čas balenia (ISO 8601 format)
   * 
   * @returns JSON string pre QR kód
   */
  static String pallet({
    required String palletId,
    required String productCode,
    String? batchNumber,
    required int qty,
    String? packedAtIso,
  }) {
    // Vytvorenie payloadu pre paletu
    return jsonEncode({
      't': 'pallet', // Typ identifikátor - dôležité pre parser
      'palletId': palletId,
      'productCode': productCode,
      if (batchNumber != null) 'batchNumber': batchNumber, // Pridané len ak nie je null
      'qty': qty,
      if (packedAtIso != null) 'packedAt': packedAtIso, // Pridané len ak nie je null
    });
  }
}

// ====================================================================
// POUŽITIE V APLIKÁCII
// ====================================================================
/*
// Príklad generovania QR kódu pre šaržu:
final batchQr = QrPayload.batch(
  batchNumber: 'BATCH-20251227-123456',
  productCode: 'DT20',
  qty: 1200,
  productionDate: '2025-12-27',
  recipeId: 5,
  dryingDays: 7,
  notes: 'Štandardná výroba',
);

// Príklad generovania QR kódu pre paletu:
final palletQr = QrPayload.pallet(
  palletId: 'PAL-000123',
  productCode: 'DT20',
  batchNumber: 'BATCH-20251227-123456',
  qty: 40,
  packedAtIso: DateTime.now().toIso8601String(),
);

// Výsledné QR kódy môžu byť:
// 1. Skenované QR webom (pridá paletu do systému)
// 2. Skenované Flutter appkou (zobrazí detaily)
// 3. Uložené pre budúcu referenciu
*/

// ====================================================================
// KOMPATIBILITA S QR WEB
// ====================================================================
// Tieto payloady sú plne kompatibilné s qr-web/lib/qr.ts parserom:
// - JSON formát je detekovaný ako "kind: json"
// - Všetky kľúče sú mapované (palletId, productCode, qty, atď.)
// - Extra dáta sú zachované v "extra" poli
// 
// Toto zabezpečuje, že QR kódy generované Flutter appkou
// budú správne parsované a spracované QR webom.








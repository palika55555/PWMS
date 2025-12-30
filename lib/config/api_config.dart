// ====================================================================
// API CONFIGURATION - Flutter appka
// ====================================================================
// Tento súbor definuje konfiguráciu pre komunikáciu s backendom
// Používa sa v SyncProvider a ostatných častiach appky pre API volania

class ApiConfig {
  /**
   * Base URL pre backend API server
   * 
   * Možnosti nastavenia:
   * 1. Environment premenná: API_BASE_URL (odporúčané pre produkciu)
   * 2. UI nastavenie: Nastavenia → Synchronizácia → Backend URL
   * 3. Default: http://localhost:3000 (pre lokálny development)
   * 
   * Príklady:
   * - Produkcia: https://pwms-production.up.railway.app
   * - Lokálne: http://localhost:3000
   * - Testovanie: http://192.168.1.100:3000
   */
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000', // Lokálny development server
  );
  
  /**
   * Google Places API Key pre geolokáciu a mapy
   * Používa sa pre dopravu a logistiku (ak implementované)
   * 
   * Ako získať API kľúč:
   * 1. Choď na: https://console.cloud.google.com/
   * 2. Vytvor nový projekt
   * 3. Povoľ "Directions API" a "Geocoding API"
   * 4. Vytvor API kľúč
   * 
   * SPÔSOB 1: Environment premenná (odporúčané pre produkciu)
   * Windows PowerShell: $env:GOOGLE_PLACES_API_KEY="your-key-here"; flutter run
   * Linux/Mac: export GOOGLE_PLACES_API_KEY="your-key-here"; flutter run
   * 
   * SPÔSOB 2: Priame nastavenie (iba pre testovanie, nekommituj do Git!)
   * Nahraďte 'YOUR_GOOGLE_PLACES_API_KEY' vaším skutočným API kľúčom
   */
  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: 'YOUR_GOOGLE_PLACES_API_KEY', // Sem zadajte váš API kľúč pre testovanie
  );
  
  /**
   * Timeout pre API volania
   * 30 sekúnd je rozumný default pre väčšinu operácií
   * Môže sa upraviť podľa potreby (napr. pre pomalé siete)
   */
  static const Duration timeout = Duration(seconds: 30);
}

// ====================================================================
// POUŽITIE V APLIKÁCII
// ====================================================================
// 
// 1. SyncProvider používa ApiConfig.baseUrl pre všetky API volania
// 2. V UI môžeš zmeniť URL cez AppSettingsProvider (uloží sa do SharedPreferences)
// 3. Environment premenné majú prioritu pred UI nastavením
//
// Príklad volania:
// ```dart
// final response = await dio.get('${ApiConfig.baseUrl}/api/materials');
// ```
//
// ====================================================================

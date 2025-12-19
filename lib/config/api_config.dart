// API konfigurácia pre backend
// Railway backend URL - automaticky nastavený Railway
class ApiConfig {
  // Railway backend URL
  // Používa Railway public domain: pwms-production.up.railway.app
  static const String API_BASE_URL = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pwms-production.up.railway.app',
  );

  // Helper metóda pre získanie API URL
  static String getApiUrl() {
    return API_BASE_URL;
  }

  // Helper metódy pre konkrétne endpointy
  static String getQualityUrl() {
    return '$API_BASE_URL/api/quality';
  }

  static String getShipmentUrl() {
    return '$API_BASE_URL/api/shipment';
  }

  static String getSyncUrl() {
    return '$API_BASE_URL/api/sync';
  }
}


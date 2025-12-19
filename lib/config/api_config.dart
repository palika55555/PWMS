// API konfigurácia pre backend
// Pre Railway backend nastavte API_BASE_URL na váš Railway domain
class ApiConfig {
  // Railway backend URL - zmeňte na váš Railway domain
  // Príklad: 'https://pwms-production.up.railway.app'
  static const String API_BASE_URL = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pwms.vercel.app',
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


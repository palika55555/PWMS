class ApiConfig {
  // This will be set from environment variables or config
  // For Railway, use: https://your-app-name.railway.app
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  
  // Google Places API Key
  // Get your API key from: https://console.cloud.google.com/
  // Enable Directions API in Google Cloud Console
  // 
  // SPÔSOB 1: Nastavenie cez environment premennú (odporúčané pre produkciu)
  // Windows PowerShell: $env:GOOGLE_PLACES_API_KEY="your-key-here"; flutter run
  // Linux/Mac: export GOOGLE_PLACES_API_KEY="your-key-here"; flutter run
  //
  // SPÔSOB 2: Nastavenie priamo tu (iba pre testovanie)
  // Nahraďte 'YOUR_GOOGLE_PLACES_API_KEY' vaším skutočným API kľúčom
  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: 'YOUR_GOOGLE_PLACES_API_KEY', // Sem zadajte váš API kľúč pre testovanie
  );
  
  static const Duration timeout = Duration(seconds: 30);
}


import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class RealtimeSyncService {
  static const String API_BASE_URL = 'https://pwms.vercel.app/api';
  Timer? _syncTimer;
  DateTime? _lastSyncTime;
  Function(Map<String, dynamic>)? _onChangeCallback;

  // Získať správnu API URL - na webe použiť aktuálnu origin
  String get _apiBaseUrl {
    if (kIsWeb) {
      try {
        return '${html.window.location.origin}/api';
      } catch (e) {
        // Fallback na hardcoded URL ak sa nedá získať origin
        return API_BASE_URL;
      }
    }
    return API_BASE_URL;
  }

  // Spustenie real-time synchronizácie
  void startRealtimeSync({
    required Function(Map<String, dynamic>) onChange,
    Duration interval = const Duration(seconds: 5),
  }) {
    _onChangeCallback = onChange;
    _lastSyncTime = DateTime.now().subtract(const Duration(minutes: 1));
    
    // Okamžitá synchronizácia
    _syncChanges();
    
    // Pravidelná synchronizácia
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      _syncChanges();
    });
  }

  // Zastavenie synchronizácie
  void stopRealtimeSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _onChangeCallback = null;
  }

  // Synchronizácia zmien
  Future<void> _syncChanges() async {
    try {
      final since = _lastSyncTime?.toIso8601String();
      final url = since != null
          ? '$_apiBaseUrl/sync?since=$since'
          : '$_apiBaseUrl/sync';

      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      // Skontrolovať, či je odpoveď JSON
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        // Ak nie je JSON, pravdepodobne je to HTML (404 stránka)
        print('Warning: API returned non-JSON response (${response.statusCode}): ${contentType}');
        if (response.statusCode == 404) {
          print('API endpoint /api/sync not found. Make sure it is deployed to Vercel.');
        }
        return;
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['changes'] != null) {
            final changes = data['changes'] as List;
            
            if (changes.isNotEmpty && _onChangeCallback != null) {
              for (var change in changes) {
                _onChangeCallback!(change as Map<String, dynamic>);
              }
            }

            // Aktualizovať čas poslednej synchronizácie
            if (data['lastUpdate'] != null) {
              _lastSyncTime = DateTime.parse(data['lastUpdate']);
            }
          }
        } catch (e) {
          print('Error parsing JSON response: $e');
          print('Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        }
      } else {
        print('API returned status ${response.statusCode}');
      }
    } catch (e) {
      // Ignorovať network chyby - nie sú kritické
      if (e.toString().contains('FormatException')) {
        print('Warning: API returned invalid JSON. Endpoint may not be deployed yet.');
      } else {
        print('Error syncing changes: $e');
      }
      // Nezastaviť synchronizáciu pri chybe
    }
  }

  // Registrácia zmeny (volané z aplikácie alebo webu)
  Future<void> registerChange({
    required String type,
    required String batchNumber,
    required Map<String, dynamic> changeData,
    String source = 'app',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'batchNumber': batchNumber,
          'data': changeData,
          'source': kIsWeb ? 'web' : source,
        }),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      // Skontrolovať, či je odpoveď JSON
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        print('Warning: API returned non-JSON response when registering change');
        return;
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            print('Change registered: ${data['changeId']}');
          }
        } catch (e) {
          print('Error parsing JSON when registering change: $e');
        }
      }
    } catch (e) {
      // Ignorovať network chyby - nie sú kritické
      if (e.toString().contains('FormatException')) {
        print('Warning: API returned invalid JSON. Endpoint may not be deployed yet.');
      } else {
        print('Error registering change: $e');
      }
      // Nezastaviť aplikáciu pri chybe
    }
  }

  // Získanie posledného timestampu
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/sync'),
      ).timeout(
        const Duration(seconds: 5),
      );

      // Skontrolovať, či je odpoveď JSON
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        print('Warning: API returned non-JSON response when getting last update time');
        return null;
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['lastUpdate'] != null) {
            return DateTime.parse(data['lastUpdate']);
          }
        } catch (e) {
          print('Error parsing JSON when getting last update time: $e');
        }
      }
    } catch (e) {
      // Ignorovať network chyby - nie sú kritické
      if (e.toString().contains('FormatException')) {
        print('Warning: API returned invalid JSON. Endpoint may not be deployed yet.');
      } else {
        print('Error getting last update time: $e');
      }
    }
    return null;
  }
}


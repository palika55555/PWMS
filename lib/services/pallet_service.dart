// ====================================================================
// PALLET SERVICE - Flutter appka
// ====================================================================
// Tento service spravuje komunikáciu s backendom pre produktové palety
// Používa rovnaké API endpointy ako QR web

import 'package:dio/dio.dart';
import '../models/product_pallet.dart';

/// Service pre komunikáciu s backendom pre produktové palety
/// Poskytuje metódy pre CRUD operácie a synchronizáciu
class PalletService {
  static Dio _dioFor(String baseUrl) {
    final b = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Dio(
      BaseOptions(
        baseUrl: b,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Získanie zoznamu produktových paliet z backendu
  /// Podporuje filtrovanie a limitovanie výsledkov
  /// 
  /// [status] - filtrovanie podľa stavu ("in_stock" | "issued")
  /// [query] - vyhľadávanie podľa palletId, productCode alebo lastRaw
  /// [limit] - maximálny počet výsledkov (default 500, max 2000)
  /// 
  /// Vráti zoznam ProductPallet objektov
  static Future<List<ProductPallet>> getPallets({
    required String baseUrl,
    String? status,
    String? query,
    int? limit,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      // Vytvorenie query parametrov
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (query != null && query.isNotEmpty) queryParams['q'] = query;
      if (limit != null) queryParams['limit'] = limit;

      final response = await dio.get('/api/pallets', queryParameters: queryParams);
      
      // Konverzia JSON na ProductPallet objekty
      final List<dynamic> data = response.data;
      return data.map((json) => ProductPallet.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Získanie detailov jednej palety podľa ID
  /// 
  /// [id] - ID palety v databáze
  /// 
  /// Vráti ProductPallet objekt alebo hádže výnimku ak neexistuje
  static Future<ProductPallet> getPalletById({
    required String baseUrl,
    required int id,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      final response = await dio.get('/api/pallets/$id');
      return ProductPallet.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Získanie palety podľa palletId (identifikátora z QR kódu)
  /// 
  /// [palletId] - identifikátor palety (napr. "PAL-001")
  /// 
  /// Vráti ProductPallet objekt alebo null ak neexistuje
  static Future<ProductPallet?> getPalletByPalletId({
    required String baseUrl,
    required String palletId,
  }) async {
    try {
      final pallets = await getPallets(baseUrl: baseUrl, query: palletId, limit: 1);
      return pallets.isNotEmpty ? pallets.first : null;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Odoslanie skenovanej palety na backend
  /// Vytvorí alebo aktualizuje záznam palety a zároveň pridá event
  /// 
  /// [mode] - typ operácie ("receive" | "issue")
  /// [palletId] - identifikátor palety
  /// [productCode] - kód produktu
  /// [raw] - surové dáta z QR kódu
  /// [quantity] - voliteľné množstvo
  /// 
  /// Vráti vytvorený/aktualizovaný záznam a event
  static Future<PalletScanResult> scanPallet({
    required String baseUrl,
    required String mode,
    required String palletId,
    required String productCode,
    required String raw,
    int? quantity,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      final response = await dio.post('/api/pallets/scan', data: {
        'mode': mode,
        'palletId': palletId,
        'productCode': productCode,
        'raw': raw,
        if (quantity != null) 'quantity': quantity,
        'source': 'flutter-app', // Označenie zdroja
      });

      final data = response.data as Map<String, dynamic>;
      return PalletScanResult(
        item: ProductPallet.fromJson(data['item'] as Map<String, dynamic>),
        event: ProductPalletEvent.fromJson(data['event'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Získanie posledných eventov palet
  /// Zobrazí históriu zmien stavu paliet
  /// 
  /// [limit] - maximálny počet eventov (default 20, max 500)
  /// 
  /// Vráti zoznam ProductPalletEvent objektov
  static Future<List<ProductPalletEvent>> getPalletEvents({
    required String baseUrl,
    int limit = 20,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      final response = await dio.get('/api/pallets/events', queryParameters: {
        'limit': limit,
      });

      final List<dynamic> data = response.data;
      return data.map((json) => ProductPalletEvent.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Získanie súhrnných štatistík palet
  /// Používa sa pre dashboard a prehľady
  /// 
  /// Vráti PalletSummary s celkovými štatistikami a štatistikami podľa produktov
  static Future<PalletSummary> getPalletSummary({
    required String baseUrl,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      final response = await dio.get('/api/pallets/summary');
      return PalletSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Aktualizácia stavu palety (príjem/výdaj)
  /// 
  /// [palletId] - identifikátor palety
  /// [newStatus] - nový stav ("in_stock" | "issued")
  /// 
  /// Vráti aktualizovaný ProductPallet objekt
  static Future<ProductPallet> updatePalletStatus({
    required String baseUrl,
    required String palletId,
    required String newStatus,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      final response = await dio.patch('/api/pallets/$palletId', data: {
        'status': newStatus,
        'source': 'flutter-app',
      });

      return ProductPallet.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Vymazanie palety (len pre admin funkcie)
  /// 
  /// [palletId] - identifikátor palety na vymazanie
  /// 
  /// Vráti true ak vymazanie prebehlo úspešne
  static Future<bool> deletePallet({
    required String baseUrl,
    required String palletId,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      await dio.delete('/api/pallets/$palletId');
      return true;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Vytvorenie novej produktovej palety na sklade
  /// Používa sa pri generovaní štítkov pre automatické pridanie na sklad
  /// 
  /// [palletId] - unikátne ID palety
  /// [productCode] - kód produktu (napr. "PB-DT30")
  /// [quantity] - počet kusov na palete
  /// [batchNumber] - číslo šarže
  /// [notes] - voliteľné poznámky
  /// 
  /// Vráti vytvorený ProductPallet objekt
  static Future<ProductPallet> createPallet({
    required String baseUrl,
    required String palletId,
    required String productCode,
    required int quantity,
    String? batchNumber,
    String? notes,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      final response = await dio.post('/api/pallets', data: {
        'palletId': palletId,
        'productCode': productCode,
        'quantity': quantity,
        if (batchNumber != null) 'batchNumber': batchNumber,
        if (notes != null) 'notes': notes,
        'source': 'flutter-app',
      });

      return ProductPallet.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Hromadné vytvorenie viacerých palet naraz
  /// Používa sa pri generovaní štítkov pre viac palet
  /// 
  /// [pallets] - zoznam dát pre vytvorenie palet
  /// 
  /// Vráti zoznam vytvorených ProductPallet objektov
  static Future<List<ProductPallet>> createMultiplePallets({
    required String baseUrl,
    required List<Map<String, dynamic>> pallets,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      final response = await dio.post('/api/pallets/batch', data: {
        'pallets': pallets,
        'source': 'flutter-app',
      });

      final palletsList = response.data['pallets'] as List;
      return palletsList
          .map((p) => ProductPallet.fromJson(p as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Testovanie pripojenia k backendu
  /// 
  /// Vráti true ak backend odpovedá
  static Future<bool> testConnection({
    required String baseUrl,
  }) async {
    try {
      final dio = _dioFor(baseUrl);
      final response = await dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Spracovanie Dio chýb a konverzia na user-friendly správy
  static Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return Exception('Timeout pri pripájaní k serveru');
      case DioExceptionType.sendTimeout:
        return Exception('Timeout pri odosielaní dát');
      case DioExceptionType.receiveTimeout:
        return Exception('Timeout pri prijímaní dát');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] ?? 'Neznáma chyba';
        
        switch (statusCode) {
          case 400:
            return Exception('Chybná požiadavka: $message');
          case 401:
            return Exception('Neautorizovaný prístup');
          case 403:
            return Exception('Prístup zakázaný');
          case 404:
            return Exception('Záznam nebol nájdený');
          case 500:
            return Exception('Chyba servera: $message');
          default:
            return Exception('HTTP $statusCode: $message');
        }
      case DioExceptionType.cancel:
        return Exception('Požiadavka zrušená');
      case DioExceptionType.connectionError:
        return Exception('Chyba pripojenia k serveru');
      case DioExceptionType.unknown:
      default:
        return Exception('Neznáma chyba: ${e.message}');
    }
  }
}

/// Výsledok skenovania palety
/// Obsahuje vytvorený/aktualizovaný záznam a event
class PalletScanResult {
  final ProductPallet item;
  final ProductPalletEvent event;

  const PalletScanResult({
    required this.item,
    required this.event,
  });
}

/// Pomocná trieda pre prácu s QR dátami
class PalletQrData {
  final String palletId;
  final String productCode;
  final String raw;
  final int? quantity;
  final String? batchNumber;

  const PalletQrData({
    required this.palletId,
    required this.productCode,
    required this.raw,
    this.quantity,
    this.batchNumber,
  });

  /// Vytvorí PalletQrData z JSON QR payloadu
  /// Podporuje formát z QrPayload.pallet()
  factory PalletQrData.fromJson(Map<String, dynamic> json) {
    return PalletQrData(
      palletId: json['palletId'] as String,
      productCode: json['productCode'] as String,
      raw: json.toString(),
      quantity: json['quantity'] as int?,
      batchNumber: json['batchNumber'] as String?,
    );
  }

  /// Vytvorí PalletQrData z delimited formátu
  /// Podporuje formát: "product|pallet|qty|batch"
  factory PalletQrData.fromDelimited(String raw) {
    final parts = raw.split('|').map((p) => p.trim()).toList();
    
    return PalletQrData(
      palletId: parts.length > 1 ? parts[1] : parts[0],
      productCode: parts.isNotEmpty ? parts[0] : 'UNKNOWN',
      raw: raw,
      quantity: parts.length > 2 ? int.tryParse(parts[2]) : null,
      batchNumber: parts.length > 3 ? parts[3] : null,
    );
  }

  /// Vytvorí PalletQrData z raw formátu
  factory PalletQrData.fromRaw(String raw) {
    return PalletQrData(
      palletId: raw,
      productCode: 'UNKNOWN',
      raw: raw,
    );
  }
}

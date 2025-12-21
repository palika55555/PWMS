import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        baseUrl = const String.fromEnvironment(
          'PROBLOCK_API_BASE_URL',
          defaultValue: 'http://localhost:3000',
        );

  final http.Client _http;
  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final res = await _http.get(_uri(path, queryParameters));
    return _decode(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final res = await _http.post(
      _uri(path),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final res = await _http.patch(
      _uri(path),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<void> deleteJson(String path) async {
    final res = await _http.delete(_uri(path));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw ApiException(
      statusCode: res.statusCode,
      message: 'HTTP_${res.statusCode}',
      body: res.body,
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    final decoded = jsonDecode(res.body) as Object?;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (decoded as Map<String, dynamic>?) ?? <String, dynamic>{};
    }
    final msg = decoded is Map<String, dynamic>
        ? (decoded['error']?.toString() ?? 'HTTP_${res.statusCode}')
        : 'HTTP_${res.statusCode}';
    throw ApiException(statusCode: res.statusCode, message: msg, body: decoded);
  }
}

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.body});

  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() => 'ApiException($statusCode): $message';
}



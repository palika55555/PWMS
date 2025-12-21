import '../models/batch.dart';
import 'api_client.dart';

class BatchesApi {
  BatchesApi(this._client);

  final ApiClient _client;

  Future<List<Batch>> list({String? date}) async {
    final queryParams = date != null ? {'date': date} : <String, String>{};
    final json = await _client.getJson('/v1/batches', queryParameters: queryParams.isEmpty ? null : queryParams);
    final items = (json['items'] as List<dynamic>? ?? const []);
    return items
        .map((e) => Batch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Batch> get(String id) async {
    final json = await _client.getJson('/v1/batches/$id');
    return Batch.fromJson(json);
  }

  Future<Batch> create({
    required String batchDate,
    String? recipeId,
    String? status,
    String? notes,
  }) async {
    final json = await _client.postJson(
      '/v1/batches',
      body: {
        'batchDate': batchDate,
        if (recipeId != null) 'recipeId': recipeId,
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      },
    );
    return Batch.fromJson(json);
  }

  Future<Batch> update(
    String id, {
    String? batchDate,
    String? recipeId,
    String? status,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (batchDate != null) body['batchDate'] = batchDate;
    if (recipeId != null) body['recipeId'] = recipeId;
    if (status != null) body['status'] = status;
    if (notes != null) body['notes'] = notes;

    final json = await _client.patchJson('/v1/batches/$id', body: body);
    return Batch.fromJson(json);
  }

  Future<void> delete(String id) async {
    await _client.deleteJson('/v1/batches/$id');
  }

  Future<Map<String, dynamic>> addProductionEntry(
    String batchId, {
    required double quantity,
    String unit = 'ks',
  }) async {
    return await _client.postJson(
      '/v1/batches/$batchId/production-entries',
      body: {
        'quantity': quantity,
        'unit': unit,
      },
    );
  }

  Future<Map<String, dynamic>> addQualityCheck(
    String batchId, {
    required bool approved,
    String? checkedBy,
    String? notes,
  }) async {
    return await _client.postJson(
      '/v1/batches/$batchId/quality-checks',
      body: {
        'approved': approved,
        if (checkedBy != null) 'checkedBy': checkedBy,
        if (notes != null) 'notes': notes,
      },
    );
  }
}


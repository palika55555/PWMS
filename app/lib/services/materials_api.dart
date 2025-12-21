import '../models/material.dart';
import 'api_client.dart';

class MaterialsApi {
  MaterialsApi(this._client);

  final ApiClient _client;

  Future<List<Material>> list() async {
    final json = await _client.getJson('/v1/materials');
    final items = (json['items'] as List<dynamic>? ?? const []);
    return items
        .map((e) => Material.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}


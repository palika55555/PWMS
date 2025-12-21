import '../models/product.dart';
import 'api_client.dart';

class ProductsApi {
  ProductsApi(this._client);

  final ApiClient _client;

  Future<List<Product>> list() async {
    final json = await _client.getJson('/v1/products');
    final items = (json['items'] as List<dynamic>? ?? const []);
    return items
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Product> create({
    required String name,
    String? description,
    bool active = true,
  }) async {
    final json = await _client.postJson(
      '/v1/products',
      body: {
        'name': name,
        'description': description,
        'active': active,
      },
    );
    return Product.fromJson(json);
  }
}



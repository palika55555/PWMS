import '../models/recipe.dart';
import 'api_client.dart';

class RecipesApi {
  RecipesApi(this._client);

  final ApiClient _client;

  Future<List<Recipe>> list() async {
    final json = await _client.getJson('/v1/recipes');
    final items = (json['items'] as List<dynamic>? ?? const []);
    return items
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Recipe> get(String id) async {
    final json = await _client.getJson('/v1/recipes/$id');
    return Recipe.fromJson(json);
  }

  Future<Recipe> create({
    required String name,
    String? productId,
  }) async {
    final json = await _client.postJson(
      '/v1/recipes',
      body: {
        'name': name,
        'productId': productId,
      },
    );
    return Recipe.fromJson(json);
  }

  Future<Map<String, dynamic>> addRecipeItem(
    String recipeId, {
    required String materialId,
    required double amount,
    String unit = 'kg',
  }) async {
    return await _client.postJson(
      '/v1/recipes/$recipeId/items',
      body: {
        'materialId': materialId,
        'amount': amount,
        'unit': unit,
      },
    );
  }

  Future<void> deleteRecipeItem(String recipeId, String itemId) async {
    await _client.deleteJson('/v1/recipes/$recipeId/items/$itemId');
  }
}



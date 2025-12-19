import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_helper.dart';
import '../models/recipe.dart';

class RecipeService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Získanie receptúry pre produkt
  Future<List<Recipe>> getRecipeForProduct(int productId) async {
    final db = await _db.database;
    final maps = await db.query(
      'recipes',
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    return List.generate(maps.length, (i) => Recipe.fromMap(maps[i]));
  }

  // Výpočet spotreby materiálov na základe receptúry
  Future<Map<int, double>> calculateMaterialUsage(int productId, int quantity) async {
    final recipes = await getRecipeForProduct(productId);
    final usage = <int, double>{};

    for (var recipe in recipes) {
      usage[recipe.materialId] = recipe.quantityPerUnit * quantity;
    }

    return usage;
  }

  // Uloženie alebo aktualizácia receptúry
  Future<int> saveRecipe(Recipe recipe) async {
    final db = await _db.database;
    return await db.insert(
      'recipes',
      recipe.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Odstránenie receptúry
  Future<int> deleteRecipe(int id) async {
    final db = await _db.database;
    return await db.delete(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}


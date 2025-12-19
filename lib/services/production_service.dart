import '../database/database_helper.dart';
import '../models/product.dart';
import 'recipe_service.dart';

class ProductionBatch {
  final int? id;
  final int productId;
  final String productName;
  final String batchNumber;
  final int quantity;
  final String productionDate;
  final String? notes;
  final String qualityStatus; // 'pending', 'passed', 'failed', 'warning'
  final String? qualityNotes;

  ProductionBatch({
    this.id,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.quantity,
    required this.productionDate,
    this.notes,
    this.qualityStatus = 'pending',
    this.qualityNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'production_date': productionDate,
      'notes': notes,
    };
  }

  factory ProductionBatch.fromMap(Map<String, dynamic> map, String productName) {
    return ProductionBatch(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      productName: productName,
      batchNumber: map['batch_number'] as String? ?? 'N/A',
      quantity: map['quantity'] as int,
      productionDate: map['production_date'] as String,
      notes: map['notes'] as String?,
      qualityStatus: map['quality_status'] as String? ?? 'pending',
      qualityNotes: map['quality_notes'] as String?,
    );
  }
}

class ProductionService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final RecipeService _recipeService = RecipeService();

  // Získanie všetkých produktov
  Future<List<Product>> getAllProducts() async {
    final db = await _db.database;
    final maps = await db.query(
      'products',
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  // Získanie produktu podľa ID
  Future<Product?> getProductById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  // Generovanie čísla šarže
  String _generateBatchNumber(int productId) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'BATCH-$productId-$dateStr-$timeStr';
  }

  // Zaznamenanie výroby
  Future<Map<String, dynamic>> recordProduction({
    required int productId,
    required int quantity,
    Map<int, double>? materialsUsed, // materialId -> quantity (voliteľné, ak nie je, použije sa receptúra)
    String? notes,
    bool useRecipe = true, // Použiť receptúru pre automatický výpočet
  }) async {
    final db = await _db.database;
    
    try {
      // Ak sa má použiť receptúra a nie sú zadané materiály
      Map<int, double> finalMaterialsUsed = materialsUsed ?? {};
      if (useRecipe && finalMaterialsUsed.isEmpty) {
        finalMaterialsUsed = await _recipeService.calculateMaterialUsage(productId, quantity);
      }
      
      // Kontrola dostatočných zásob
      if (finalMaterialsUsed.isEmpty) {
        return {'success': false, 'error': 'Nie sú zadané materiály alebo receptúra je prázdna'};
      }
      
      // Kontrola dostupných zásob (pred transakciou)
      final insufficientMaterials = <String>[];
      for (var entry in finalMaterialsUsed.entries) {
        final material = await db.rawQuery(
          'SELECT name, quantity FROM materials WHERE id = ?',
          [entry.key],
        );
        
        if (material.isNotEmpty) {
          final availableQty = (material.first['quantity'] as num).toDouble();
          if (availableQty < entry.value) {
            insufficientMaterials.add('${material.first['name']}: potrebné ${entry.value.toStringAsFixed(2)}, dostupné ${availableQty.toStringAsFixed(2)}');
          }
        } else {
          insufficientMaterials.add('Materiál s ID ${entry.key} nebol nájdený');
        }
      }
      
      if (insufficientMaterials.isNotEmpty) {
        return {
          'success': false,
          'error': 'Nedostatočné zásoby:\n${insufficientMaterials.join('\n')}',
        };
      }
      
      final batchNumber = _generateBatchNumber(productId);
      
      await db.transaction((txn) async {
        // Vytvorenie výrobného záznamu
        final batchId = await txn.insert(
          'production_batches',
          {
            'product_id': productId,
            'batch_number': batchNumber,
            'quantity': quantity,
            'production_date': DateTime.now().toIso8601String(),
            'notes': notes,
            'quality_status': 'pending',
          },
        );

        // Zaznamenanie spotreby materiálov
        for (var entry in finalMaterialsUsed.entries) {
          await txn.insert(
            'production_logs',
            {
              'batch_id': batchId,
              'material_id': entry.key,
              'quantity_used': entry.value,
            },
          );

          // Odčítanie spotrebovaného množstva z materiálu
          await txn.rawUpdate(
            'UPDATE materials SET quantity = quantity - ? WHERE id = ?',
            [entry.value, entry.key],
          );
        }

        // Aktualizácia počtu produktov
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [quantity, productId],
        );
      });

      return {'success': true, 'batchNumber': batchNumber};
    } catch (e) {
      return {'success': false, 'error': 'Chyba pri zaznamenávaní: ${e.toString()}'};
    }
  }

  // Získanie výrobných záznamov
  Future<List<ProductionBatch>> getProductionBatches({int? limit}) async {
    final db = await _db.database;
    final maps = await db.query(
      'production_batches',
      orderBy: 'production_date DESC',
      limit: limit,
    );

    final batches = <ProductionBatch>[];
    for (var map in maps) {
      final product = await getProductById(map['product_id'] as int);
      if (product != null) {
        batches.add(ProductionBatch.fromMap(map, product.name));
      }
    }

    return batches;
  }

  // Získanie výroby podľa dní
  Future<Map<String, List<ProductionBatch>>> getProductionByDays({int? days}) async {
    final db = await _db.database;
    final now = DateTime.now();
    final startDate = days != null 
        ? now.subtract(Duration(days: days))
        : DateTime(now.year, now.month, now.day - 30); // Posledných 30 dní
    
    final maps = await db.query(
      'production_batches',
      where: 'production_date >= ?',
      whereArgs: [startDate.toIso8601String()],
      orderBy: 'production_date DESC',
    );

    final batchesByDay = <String, List<ProductionBatch>>{};
    
    for (var map in maps) {
      final product = await getProductById(map['product_id'] as int);
      if (product != null) {
        final batch = ProductionBatch.fromMap(map, product.name);
        final date = DateTime.parse(batch.productionDate);
        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        batchesByDay.putIfAbsent(dayKey, () => []).add(batch);
      }
    }

    return batchesByDay;
  }

  // Získanie výroby pre konkrétny deň
  Future<List<ProductionBatch>> getProductionForDay(DateTime day) async {
    final db = await _db.database;
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final maps = await db.query(
      'production_batches',
      where: 'production_date >= ? AND production_date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'production_date DESC',
    );

    final batches = <ProductionBatch>[];
    for (var map in maps) {
      final product = await getProductById(map['product_id'] as int);
      if (product != null) {
        batches.add(ProductionBatch.fromMap(map, product.name));
      }
    }

    return batches;
  }

  // Získanie spotreby materiálov pre výrobný záznam
  Future<Map<String, double>> getMaterialUsageForBatch(int batchId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT m.name, pl.quantity_used
      FROM production_logs pl
      JOIN materials m ON pl.material_id = m.id
      WHERE pl.batch_id = ?
    ''', [batchId]);

    final usage = <String, double>{};
    for (var map in maps) {
      usage[map['name'] as String] = map['quantity_used'] as double;
    }

    return usage;
  }
}


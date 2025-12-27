import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Batch;
import '../database/local_database.dart';
import '../models/models.dart';
import '../services/receipt_number_service.dart';
import '../services/sync_queue_service.dart';

class DatabaseProvider with ChangeNotifier {
  final LocalDatabase _db = LocalDatabase.instance;
  final SyncQueueService _syncQueue = SyncQueueService();
  
  Map<String, dynamic> _withSynced0(Map<String, dynamic> map) {
    final m = Map<String, dynamic>.from(map);
    m['synced'] = 0;
    return m;
  }
  
  // Expose database for advanced queries
  Future<Database> getDatabase() async {
    return await _db.database;
  }

  // Materials
  Future<List<Material>> getMaterials() async {
    final db = await _db.database;
    final maps = await db.query('materials', orderBy: 'name');
    return maps.map((map) => Material.fromMap(map)).toList();
  }

  /// Vyhľadá materiál podľa PLU alebo EAN kódu
  Future<Material?> findMaterialByCode(String code) async {
    final db = await _db.database;
    final maps = await db.query(
      'materials',
      where: 'plu_code = ? OR ean_code = ?',
      whereArgs: [code, code],
      limit: 1,
    );
    
    if (maps.isEmpty) {
      return null;
    }
    
    return Material.fromMap(maps.first);
  }

  /// Vyhľadá materiály podľa názvu (čiastočná zhoda)
  Future<List<Material>> searchMaterialsByName(String name) async {
    final db = await _db.database;
    final maps = await db.query(
      'materials',
      where: 'name LIKE ?',
      whereArgs: ['%$name%'],
      orderBy: 'name ASC',
      limit: 10,
    );
    
    return maps.map((map) => Material.fromMap(map)).toList();
  }

  Future<int> insertMaterial(Material material) async {
    final db = await _db.database;
    final data = _withSynced0(material.toMap());
    final id = await db.insert('materials', data);
    await _syncQueue.enqueueUpsert(table: 'materials', recordId: id, data: data);
    return id;
  }

  Future<int> updateMaterial(Material material) async {
    final db = await _db.database;
    final data = _withSynced0(material.toMap());
    final result = await db.update(
      'materials',
      data,
      where: 'id = ?',
      whereArgs: [material.id],
    );
    if (material.id != null) {
      await _syncQueue.enqueueUpsert(table: 'materials', recordId: material.id!, data: data);
    }
    return result;
  }

  Future<void> deleteMaterial(int id) async {
    final db = await _db.database;
    await db.delete(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncQueue.enqueueDelete(table: 'materials', recordId: id);
  }

  Future<void> deleteAllData() async {
    await _db.deleteDatabase();
    notifyListeners();
  }

  // Recipes
  Future<List<Recipe>> getRecipes() async {
    final db = await _db.database;
    final maps = await db.query('recipes', orderBy: 'name');
    return maps.map((map) => Recipe.fromMap(map)).toList();
  }

  Future<Recipe?> getRecipe(int id) async {
    final db = await _db.database;
    final maps = await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Recipe.fromMap(maps.first);
  }

  Future<int> insertRecipe(Recipe recipe) async {
    final db = await _db.database;
    final data = _withSynced0(recipe.toMap());
    final id = await db.insert('recipes', data);
    await _syncQueue.enqueueUpsert(table: 'recipes', recordId: id, data: data);
    return id;
  }

  Future<void> insertRecipeAggregate(
    int recipeId,
    int materialId,
    int? fractionId,
    double amount,
  ) async {
    final db = await _db.database;
    final data = {
      'recipe_id': recipeId,
      'material_id': materialId,
      'fraction_id': fractionId,
      'amount': amount,
      'synced': 0,
    };
    final id = await db.insert('recipe_aggregates', data);
    await _syncQueue.enqueueUpsert(table: 'recipe_aggregates', recordId: id, data: data);
  }

  // Batches
  Future<List<Batch>> getBatches({DateTime? date}) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs;

    if (date != null) {
      where = 'production_date = ?';
      whereArgs = [date.toIso8601String().split('T')[0]];
    }

    final maps = await db.query(
      'batches',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'production_date DESC, created_at DESC',
    );
    return maps.map((map) => Batch.fromMap(map)).toList();
  }

  Future<Batch?> getBatch(int id) async {
    final db = await _db.database;
    final maps = await db.query('batches', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Batch.fromMap(maps.first);
  }

  Future<int> insertBatch(Batch batch) async {
    final db = await _db.database;
    final data = _withSynced0(batch.toMap());
    final id = await db.insert('batches', data);
    await _syncQueue.enqueueUpsert(table: 'batches', recordId: id, data: data);
    return id;
  }

  Future<int> updateBatch(Batch batch) async {
    final db = await _db.database;
    final data = _withSynced0(batch.toMap());
    final result = await db.update(
      'batches',
      data,
      where: 'id = ?',
      whereArgs: [batch.id],
    );
    if (batch.id != null) {
      await _syncQueue.enqueueUpsert(table: 'batches', recordId: batch.id!, data: data);
    }
    return result;
  }

  // Check material stock levels
  Future<List<Material>> checkLowStock() async {
    final materials = await getMaterials();
    return materials.where((m) => m.currentStock <= m.minStock).toList();
  }

  // Recipe Aggregates
  Future<List<Map<String, dynamic>>> getRecipeAggregates(int recipeId) async {
    final db = await _db.database;
    final maps = await db.query(
      'recipe_aggregates',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
    
    // Join with materials and fractions
    final List<Map<String, dynamic>> result = [];
    for (final map in maps) {
      final materialId = map['material_id'] as int;
      final material = await getMaterial(materialId);
      final fractionId = map['fraction_id'] as int?;
      
      Map<String, dynamic>? fraction;
      if (fractionId != null) {
        final fractionMaps = await db.query(
          'aggregate_fractions',
          where: 'id = ?',
          whereArgs: [fractionId],
        );
        if (fractionMaps.isNotEmpty) {
          fraction = fractionMaps.first;
        }
      }
      
      result.add({
        'id': map['id'],
        'recipe_id': map['recipe_id'],
        'material': material,
        'fraction': fraction,
        'amount': map['amount'],
      });
    }
    
    return result;
  }

  Future<Material?> getMaterial(int id) async {
    final db = await _db.database;
    final maps = await db.query('materials', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Material.fromMap(maps.first);
  }

  // Batch Materials
  Future<List<Map<String, dynamic>>> getBatchMaterials(int batchId) async {
    final db = await _db.database;
    final maps = await db.query(
      'batch_materials',
      where: 'batch_id = ?',
      whereArgs: [batchId],
    );
    
    final List<Map<String, dynamic>> result = [];
    for (final map in maps) {
      final materialId = map['material_id'] as int;
      final material = await getMaterial(materialId);
      final fractionId = map['fraction_id'] as int?;
      
      Map<String, dynamic>? fraction;
      if (fractionId != null) {
        final fractionMaps = await db.query(
          'aggregate_fractions',
          where: 'id = ?',
          whereArgs: [fractionId],
        );
        if (fractionMaps.isNotEmpty) {
          fraction = fractionMaps.first;
        }
      }
      
      result.add({
        'id': map['id'],
        'batch_id': map['batch_id'],
        'material': material,
        'fraction': fraction,
        'planned_amount': map['planned_amount'],
        'actual_amount': map['actual_amount'],
      });
    }
    
    return result;
  }

  Future<void> insertBatchMaterial(Map<String, dynamic> batchMaterial) async {
    final db = await _db.database;
    final data = {
      'batch_id': batchMaterial['batch_id'],
      'material_id': batchMaterial['material_id'],
      'fraction_id': batchMaterial['fraction_id'],
      'planned_amount': batchMaterial['planned_amount'],
      'actual_amount': batchMaterial['actual_amount'],
      'synced': 0,
    };
    final id = await db.insert('batch_materials', data);
    await _syncQueue.enqueueUpsert(table: 'batch_materials', recordId: id, data: data);
  }

  Future<void> updateBatchMaterial(int id, double actualAmount) async {
    final db = await _db.database;
    await db.update(
      'batch_materials',
      {'actual_amount': actualAmount, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncQueue.enqueueUpsert(
      table: 'batch_materials',
      recordId: id,
      data: {'actual_amount': actualAmount, 'synced': 0},
    );
  }

  // Quality Tests
  Future<List<QualityTest>> getQualityTests(int batchId) async {
    final db = await _db.database;
    final maps = await db.query(
      'quality_tests',
      where: 'batch_id = ?',
      whereArgs: [batchId],
      orderBy: 'test_date DESC',
    );
    return maps.map((map) => QualityTest.fromMap(map)).toList();
  }

  Future<int> insertQualityTest(QualityTest test) async {
    final db = await _db.database;
    final data = _withSynced0(test.toMap());
    final id = await db.insert('quality_tests', data);
    await _syncQueue.enqueueUpsert(table: 'quality_tests', recordId: id, data: data);
    return id;
  }

  Future<void> deleteQualityTest(int id) async {
    final db = await _db.database;
    await db.delete('quality_tests', where: 'id = ?', whereArgs: [id]);
    await _syncQueue.enqueueDelete(table: 'quality_tests', recordId: id);
  }

  // Stock Movements
  Future<List<StockMovement>> getStockMovements({
    int? materialId,
    int? supplierId,
    String? movementType,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    String? dateFrom,
    String? dateTo,
  }) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs = [];

    if (materialId != null) {
      where = 'material_id = ?';
      whereArgs.add(materialId);
    }

    if (supplierId != null) {
      if (where != null) {
        where += ' AND supplier_id = ?';
      } else {
        where = 'supplier_id = ?';
      }
      whereArgs.add(supplierId);
    }

    if (movementType != null) {
      if (where != null) {
        where += ' AND movement_type = ?';
      } else {
        where = 'movement_type = ?';
      }
      whereArgs.add(movementType);
    }
    
    if (status != null) {
      if (where != null) {
        where += ' AND status = ?';
      } else {
        where = 'status = ?';
      }
      whereArgs.add(status);
    }
    
    // Support both DateTime and String date formats
    String? fromDateStr = dateFrom;
    if (fromDate != null && fromDateStr == null) {
      fromDateStr = fromDate.toIso8601String().split('T')[0];
    }
    
    String? toDateStr = dateTo;
    if (toDate != null && toDateStr == null) {
      toDateStr = toDate.toIso8601String().split('T')[0];
    }

    if (fromDateStr != null) {
      if (where != null) {
        where += ' AND movement_date >= ?';
      } else {
        where = 'movement_date >= ?';
      }
      whereArgs.add(fromDateStr);
    }

    if (toDateStr != null) {
      if (where != null) {
        where += ' AND movement_date <= ?';
      } else {
        where = 'movement_date <= ?';
      }
      whereArgs.add(toDateStr);
    }

    final maps = await db.query(
      'stock_movements',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'movement_date DESC, created_at DESC',
    );
    return maps.map((map) => StockMovement.fromMap(map)).toList();
  }

  Future<int> insertStockMovement(StockMovement movement) async {
    final db = await _db.database;
    
    // Generate receipt number if it's a receipt and doesn't have one
    StockMovement movementToInsert = movement;
    if (movement.movementType == 'receipt' && movement.receiptNumber == null) {
      final receiptNumberService = ReceiptNumberService();
      final receiptNumber = await receiptNumberService.generateReceiptNumber();
      movementToInsert = movement.copyWith(receiptNumber: receiptNumber);
    }
    
    final data = _withSynced0(movementToInsert.toMap());
    final id = await db.insert('stock_movements', data);
    await _syncQueue.enqueueUpsert(table: 'stock_movements', recordId: id, data: data);
    
    // Update material stock only if movement is approved
    if (movementToInsert.status == 'approved' && movementToInsert.materialId != null) {
      await _updateMaterialStockFromMovement(movementToInsert);
    }
    
    return id;
  }

  Future<void> _updateMaterialStockFromMovement(StockMovement movement) async {
    if (movement.materialId == null) return;
    
    final material = await getMaterial(movement.materialId!);
    if (material != null) {
      double newStock = material.currentStock;
      if (movement.movementType == 'receipt' || movement.movementType == 'inventory_adjustment') {
        newStock += movement.quantity;
      } else if (movement.movementType == 'issue') {
        newStock -= movement.quantity;
      }
      
      await updateMaterial(material.copyWith(
        currentStock: newStock < 0 ? 0 : newStock,
        updatedAt: DateTime.now().toIso8601String(),
      ));
    }
  }

  Future<void> approveStockMovement(int movementId, String approvedBy, {String? notes}) async {
    final db = await _db.database;
    final movement = await getStockMovement(movementId);
    if (movement == null) return;
    
    // Update movement status
    await db.update(
      'stock_movements',
      {
        'status': 'approved',
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [movementId],
    );
    await _syncQueue.enqueueUpsert(
      table: 'stock_movements',
      recordId: movementId,
      data: {
        'status': 'approved',
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
    );
    
    // Update material stock
    final approvedMovement = movement.copyWith(
      status: 'approved',
      approvedBy: approvedBy,
      approvedAt: DateTime.now().toIso8601String(),
    );
    await _updateMaterialStockFromMovement(approvedMovement);
    
    // Create price history and update weighted average price if it's a receipt with prices
    if (approvedMovement.movementType == 'receipt' &&
        approvedMovement.purchasePriceWithoutVat != null &&
        approvedMovement.purchasePriceWithVat != null &&
        approvedMovement.materialId != null) {
      // Calculate missing price if only one is provided
      double? finalPriceWithoutVat = approvedMovement.purchasePriceWithoutVat;
      double? finalPriceWithVat = approvedMovement.purchasePriceWithVat;
      double vatRate = approvedMovement.vatRate ?? 20.0;
      
      if (finalPriceWithoutVat == null && finalPriceWithVat != null) {
        // Calculate price without VAT from price with VAT
        if (vatRate == 0) {
          finalPriceWithoutVat = finalPriceWithVat;
        } else {
          finalPriceWithoutVat = finalPriceWithVat / (1 + vatRate / 100);
        }
      } else if (finalPriceWithoutVat != null && finalPriceWithVat == null) {
        // Calculate price with VAT from price without VAT
        if (vatRate == 0) {
          finalPriceWithVat = finalPriceWithoutVat;
        } else {
          finalPriceWithVat = finalPriceWithoutVat * (1 + vatRate / 100);
        }
      }
      
      // Create price history entry for approved receipt
      if (finalPriceWithoutVat != null && finalPriceWithVat != null) {
        final priceHistory = PriceHistory(
          materialId: approvedMovement.materialId!,
          supplierId: approvedMovement.supplierId,
          quantity: approvedMovement.quantity,
          purchasePriceWithoutVat: finalPriceWithoutVat,
          purchasePriceWithVat: finalPriceWithVat,
          vatRate: vatRate,
          priceDate: approvedMovement.movementDate,
          documentNumber: approvedMovement.documentNumber ?? approvedMovement.receiptNumber,
          notes: approvedMovement.notes,
          createdAt: DateTime.now().toIso8601String(),
        );
        await insertPriceHistory(priceHistory);
      }
      
      // Update weighted average price
      await _updateMaterialWeightedAverage(approvedMovement.materialId!);
    }
  }

  Future<void> rejectStockMovement(int movementId, String rejectedBy, String reason) async {
    final db = await _db.database;
    await db.update(
      'stock_movements',
      {
        'status': 'rejected',
        'approved_by': rejectedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [movementId],
    );
    await _syncQueue.enqueueUpsert(
      table: 'stock_movements',
      recordId: movementId,
      data: {
        'status': 'rejected',
        'approved_by': rejectedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
        'synced': 0,
      },
    );
  }

  Future<void> cancelStockMovement(int movementId, String cancelledBy, String reason, {bool returnStock = false}) async {
    final db = await _db.database;
    final movement = await getStockMovement(movementId);
    if (movement == null) return;
    
    // If movement was approved and user wants to return stock, reverse the stock change
    if (movement.status == 'approved' && returnStock && movement.materialId != null) {
      await _reverseMaterialStockFromMovement(movement);
    }
    
    // Update movement status to cancelled
    await db.update(
      'stock_movements',
      {
        'status': 'cancelled',
        'approved_by': cancelledBy,
        'approved_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [movementId],
    );
    await _syncQueue.enqueueUpsert(
      table: 'stock_movements',
      recordId: movementId,
      data: {
        'status': 'cancelled',
        'approved_by': cancelledBy,
        'approved_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
        'synced': 0,
      },
    );
  }

  Future<int> updateStockMovement(StockMovement updatedMovement) async {
    final db = await _db.database;
    
    // Get original movement before update
    final originalMovement = await getStockMovement(updatedMovement.id!);
    if (originalMovement == null) {
      throw Exception('Stock movement not found');
    }
    
    // If original was approved and material was involved, we need to reverse the stock change
    if (originalMovement.status == 'approved' && originalMovement.materialId != null) {
      await _reverseMaterialStockFromMovement(originalMovement);
    }
    
    // Update the movement in database
    final data = _withSynced0(updatedMovement.toMap());
    final result = await db.update(
      'stock_movements',
      data,
      where: 'id = ?',
      whereArgs: [updatedMovement.id],
    );
    if (updatedMovement.id != null) {
      await _syncQueue.enqueueUpsert(table: 'stock_movements', recordId: updatedMovement.id!, data: data);
    }
    
    // If updated movement is approved and material is involved, apply the new stock change
    if (updatedMovement.status == 'approved' && updatedMovement.materialId != null) {
      await _updateMaterialStockFromMovement(updatedMovement);
      
      // Update weighted average price if it's a receipt with prices
      if (updatedMovement.movementType == 'receipt' &&
          updatedMovement.purchasePriceWithoutVat != null &&
          updatedMovement.purchasePriceWithVat != null) {
        await _updateMaterialWeightedAverage(updatedMovement.materialId!);
      }
    }
    
    return result;
  }
  
  Future<void> _reverseMaterialStockFromMovement(StockMovement movement) async {
    if (movement.materialId == null) return;
    
    final material = await getMaterial(movement.materialId!);
    if (material != null) {
      double newStock = material.currentStock;
      // Reverse the original movement
      if (movement.movementType == 'receipt' || movement.movementType == 'inventory_adjustment') {
        newStock -= movement.quantity; // Subtract what was added
      } else if (movement.movementType == 'issue') {
        newStock += movement.quantity; // Add back what was subtracted
      }
      
      await updateMaterial(material.copyWith(
        currentStock: newStock < 0 ? 0 : newStock,
        updatedAt: DateTime.now().toIso8601String(),
      ));
    }
  }

  Future<StockMovement?> getStockMovement(int id) async {
    final db = await _db.database;
    final maps = await db.query('stock_movements', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return StockMovement.fromMap(maps.first);
  }

  // Inventories
  Future<List<Inventory>> getInventories({String? status}) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs;

    if (status != null) {
      where = 'status = ?';
      whereArgs = [status];
    }

    final maps = await db.query(
      'inventories',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'inventory_date DESC',
    );
    return maps.map((map) => Inventory.fromMap(map)).toList();
  }

  Future<Inventory?> getInventory(int id) async {
    final db = await _db.database;
    final maps = await db.query('inventories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Inventory.fromMap(maps.first);
  }

  Future<int> insertInventory(Inventory inventory) async {
    final db = await _db.database;
    final data = _withSynced0(inventory.toMap());
    final id = await db.insert('inventories', data);
    await _syncQueue.enqueueUpsert(table: 'inventories', recordId: id, data: data);
    return id;
  }

  Future<void> updateInventory(Inventory inventory) async {
    final db = await _db.database;
    final data = _withSynced0(inventory.toMap());
    await db.update(
      'inventories',
      data,
      where: 'id = ?',
      whereArgs: [inventory.id],
    );
    if (inventory.id != null) {
      await _syncQueue.enqueueUpsert(table: 'inventories', recordId: inventory.id!, data: data);
    }
  }

  // Inventory Items
  Future<List<InventoryItem>> getInventoryItems(int inventoryId) async {
    final db = await _db.database;
    final maps = await db.query(
      'inventory_items',
      where: 'inventory_id = ?',
      whereArgs: [inventoryId],
    );
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<int> insertInventoryItem(InventoryItem item) async {
    final db = await _db.database;
    final data = _withSynced0(item.toMap());
    final id = await db.insert('inventory_items', data);
    await _syncQueue.enqueueUpsert(table: 'inventory_items', recordId: id, data: data);
    return id;
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final db = await _db.database;
    final data = _withSynced0(item.toMap());
    await db.update(
      'inventory_items',
      data,
      where: 'id = ?',
      whereArgs: [item.id],
    );
    if (item.id != null) {
      await _syncQueue.enqueueUpsert(table: 'inventory_items', recordId: item.id!, data: data);
    }
  }

  Future<void> deleteInventoryItem(int id) async {
    final db = await _db.database;
    await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
    await _syncQueue.enqueueDelete(table: 'inventory_items', recordId: id);
  }

  // Apply inventory adjustments
  Future<void> applyInventoryAdjustments(int inventoryId) async {
    final items = await getInventoryItems(inventoryId);
    
    for (final item in items) {
      if (item.difference != 0) {
        final movement = StockMovement(
          movementType: 'inventory_adjustment',
          materialId: item.materialId,
          quantity: item.difference.abs(),
          unit: item.unit,
          reason: 'Inventúra - ${item.difference > 0 ? "nárast" : "úbytok"}',
          movementDate: DateTime.now().toIso8601String(),
          createdBy: 'System',
          createdAt: DateTime.now().toIso8601String(),
        );
        await insertStockMovement(movement);
      }
    }
  }

  // Suppliers
  Future<List<Supplier>> getSuppliers() async {
    final db = await _db.database;
    final maps = await db.query('suppliers', orderBy: 'name');
    return maps.map((map) => Supplier.fromMap(map)).toList();
  }

  Future<Supplier?> getSupplier(int id) async {
    final db = await _db.database;
    final maps = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Supplier.fromMap(maps.first);
  }

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await _db.database;
    final data = _withSynced0(supplier.toMap());
    final id = await db.insert('suppliers', data);
    await _syncQueue.enqueueUpsert(table: 'suppliers', recordId: id, data: data);
    return id;
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await _db.database;
    final data = _withSynced0(supplier.toMap());
    final result = await db.update(
      'suppliers',
      data,
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    if (supplier.id != null) {
      await _syncQueue.enqueueUpsert(table: 'suppliers', recordId: supplier.id!, data: data);
    }
    return result;
  }

  Future<void> deleteSupplier(int id) async {
    final db = await _db.database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    await _syncQueue.enqueueDelete(table: 'suppliers', recordId: id);
  }

  // Warehouses
  Future<List<Warehouse>> getWarehouses({bool? activeOnly}) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs;
    
    if (activeOnly == true) {
      where = 'is_active = ?';
      whereArgs = [1];
    }
    
    final maps = await db.query(
      'warehouses',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name',
    );
    return maps.map((map) => Warehouse.fromMap(map)).toList();
  }

  Future<Warehouse?> getWarehouse(int id) async {
    final db = await _db.database;
    final maps = await db.query('warehouses', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Warehouse.fromMap(maps.first);
  }

  Future<int> insertWarehouse(Warehouse warehouse) async {
    final db = await _db.database;
    final data = _withSynced0(warehouse.toMap());
    final id = await db.insert('warehouses', data);
    await _syncQueue.enqueueUpsert(table: 'warehouses', recordId: id, data: data);
    return id;
  }

  Future<int> updateWarehouse(Warehouse warehouse) async {
    final db = await _db.database;
    final data = _withSynced0(warehouse.toMap());
    final result = await db.update(
      'warehouses',
      data,
      where: 'id = ?',
      whereArgs: [warehouse.id],
    );
    if (warehouse.id != null) {
      await _syncQueue.enqueueUpsert(table: 'warehouses', recordId: warehouse.id!, data: data);
    }
    return result;
  }

  Future<void> deleteWarehouse(int id) async {
    final db = await _db.database;
    await db.delete('warehouses', where: 'id = ?', whereArgs: [id]);
    await _syncQueue.enqueueDelete(table: 'warehouses', recordId: id);
  }

  // Price History
  Future<List<PriceHistory>> getPriceHistory({
    int? materialId,
    int? supplierId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs = [];

    if (materialId != null) {
      where = 'material_id = ?';
      whereArgs.add(materialId);
    }

    if (supplierId != null) {
      if (where != null) {
        where += ' AND supplier_id = ?';
      } else {
        where = 'supplier_id = ?';
      }
      whereArgs.add(supplierId);
    }

    if (fromDate != null) {
      if (where != null) {
        where += ' AND price_date >= ?';
      } else {
        where = 'price_date >= ?';
      }
      whereArgs.add(fromDate.toIso8601String().split('T')[0]);
    }

    if (toDate != null) {
      if (where != null) {
        where += ' AND price_date <= ?';
      } else {
        where = 'price_date <= ?';
      }
      whereArgs.add(toDate.toIso8601String().split('T')[0]);
    }

    final maps = await db.query(
      'price_history',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'price_date DESC, created_at DESC',
    );
    return maps.map((map) => PriceHistory.fromMap(map)).toList();
  }

  Future<int> insertPriceHistory(PriceHistory priceHistory) async {
    final db = await _db.database;
    final data = _withSynced0(priceHistory.toMap());
    final id = await db.insert('price_history', data);
    await _syncQueue.enqueueUpsert(table: 'price_history', recordId: id, data: data);
    
    // Don't update material prices here - they will be updated when receipt is approved
    // This ensures prices only change after approval
    
    return id;
  }

  // Calculate and update weighted average price for material
  // This is called only when receipt is approved
  Future<void> _updateMaterialWeightedAverage(int materialId) async {
    final priceHistory = await getPriceHistory(materialId: materialId);
    
    if (priceHistory.isEmpty) return;
    
    // Calculate weighted average: sum(price * quantity) / sum(quantity)
    double totalValueWithoutVat = 0;
    double totalValueWithVat = 0;
    double totalQuantity = 0;
    double? latestSalePrice; // Use the most recent sale price if available
    
    for (final price in priceHistory) {
      totalValueWithoutVat += price.purchasePriceWithoutVat * price.quantity;
      totalValueWithVat += price.purchasePriceWithVat * price.quantity;
      totalQuantity += price.quantity;
      
      // Use the most recent sale price (priceHistory is ordered by date DESC)
      if (latestSalePrice == null && price.salePrice != null) {
        latestSalePrice = price.salePrice;
      }
    }
    
    if (totalQuantity > 0) {
      final avgWithoutVat = totalValueWithoutVat / totalQuantity;
      final avgWithVat = totalValueWithVat / totalQuantity;
      
      final material = await getMaterial(materialId);
      if (material != null) {
        await updateMaterial(material.copyWith(
          averagePurchasePriceWithoutVat: avgWithoutVat,
          averagePurchasePriceWithVat: avgWithVat,
          salePrice: latestSalePrice, // Update sale price if available in price history
          updatedAt: DateTime.now().toIso8601String(),
        ));
      }
    }
  }

  // Customers
  Future<List<Customer>> getCustomers({bool? activeOnly}) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs;
    
    if (activeOnly == true) {
      where = 'is_active = ?';
      whereArgs = [1];
    }
    
    final maps = await db.query(
      'customers',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name',
    );
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomer(int id) async {
    final db = await _db.database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await _db.database;
    final data = _withSynced0(customer.toMap());
    final id = await db.insert('customers', data);
    await _syncQueue.enqueueUpsert(table: 'customers', recordId: id, data: data);
    return id;
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await _db.database;
    final data = _withSynced0(customer.toMap());
    final result = await db.update(
      'customers',
      data,
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    if (customer.id != null) {
      await _syncQueue.enqueueUpsert(table: 'customers', recordId: customer.id!, data: data);
    }
    return result;
  }

  Future<void> deleteCustomer(int id) async {
    final db = await _db.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    await _syncQueue.enqueueDelete(table: 'customers', recordId: id);
  }

  // Warehouse Locations
  Future<List<WarehouseLocation>> getWarehouseLocations({bool? activeOnly}) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs;
    
    if (activeOnly == true) {
      where = 'is_active = ?';
      whereArgs = [1];
    }
    
    final maps = await db.query(
      'warehouse_locations',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'is_default DESC, name',
    );
    return maps.map((map) => WarehouseLocation.fromMap(map)).toList();
  }

  Future<WarehouseLocation?> getWarehouseLocation(int id) async {
    final db = await _db.database;
    final maps = await db.query('warehouse_locations', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WarehouseLocation.fromMap(maps.first);
  }

  Future<int> insertWarehouseLocation(WarehouseLocation location) async {
    final db = await _db.database;
    // If this is set as default, unset other defaults
    if (location.isDefault) {
      await db.update('warehouse_locations', {'is_default': 0, 'synced': 0});
    }
    final data = _withSynced0(location.toMap());
    final id = await db.insert('warehouse_locations', data);
    await _syncQueue.enqueueUpsert(table: 'warehouse_locations', recordId: id, data: data);
    return id;
  }

  Future<int> updateWarehouseLocation(WarehouseLocation location) async {
    final db = await _db.database;
    // If this is set as default, unset other defaults
    if (location.isDefault) {
      await db.update(
        'warehouse_locations',
        {'is_default': 0, 'synced': 0},
        where: 'id != ?',
        whereArgs: [location.id],
      );
    }
    final data = _withSynced0(location.toMap());
    final result = await db.update(
      'warehouse_locations',
      data,
      where: 'id = ?',
      whereArgs: [location.id],
    );
    if (location.id != null) {
      await _syncQueue.enqueueUpsert(table: 'warehouse_locations', recordId: location.id!, data: data);
    }
    return result;
  }

  // Unit Conversions
  Future<List<UnitConversion>> getUnitConversions(int materialId) async {
    final db = await _db.database;
    final maps = await db.query(
      'unit_conversions',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'is_default DESC',
    );
    return maps.map((map) => UnitConversion.fromMap(map)).toList();
  }

  Future<int> insertUnitConversion(UnitConversion conversion) async {
    final db = await _db.database;
    // If this is set as default, unset other defaults for this material
    if (conversion.isDefault) {
      await db.update(
        'unit_conversions',
        {'is_default': 0},
        where: 'material_id = ?',
        whereArgs: [conversion.materialId],
      );
    }
    final data = _withSynced0(conversion.toMap());
    final id = await db.insert('unit_conversions', data);
    await _syncQueue.enqueueUpsert(table: 'unit_conversions', recordId: id, data: data);
    return id;
  }

  // Product Variants
  Future<List<ProductVariant>> getProductVariants(int materialId) async {
    final db = await _db.database;
    final maps = await db.query(
      'product_variants',
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'variant_type, variant_value',
    );
    return maps.map((map) => ProductVariant.fromMap(map)).toList();
  }

  Future<int> insertProductVariant(ProductVariant variant) async {
    final db = await _db.database;
    final data = _withSynced0(variant.toMap());
    final id = await db.insert('product_variants', data);
    await _syncQueue.enqueueUpsert(table: 'product_variants', recordId: id, data: data);
    return id;
  }

  // Product Accessories
  Future<List<ProductAccessory>> getProductAccessories(int materialId) async {
    final db = await _db.database;
    final maps = await db.query(
      'product_accessories',
      where: 'material_id = ?',
      whereArgs: [materialId],
    );
    return maps.map((map) => ProductAccessory.fromMap(map)).toList();
  }

  Future<int> insertProductAccessory(ProductAccessory accessory) async {
    final db = await _db.database;
    final data = _withSynced0(accessory.toMap());
    final id = await db.insert('product_accessories', data);
    await _syncQueue.enqueueUpsert(table: 'product_accessories', recordId: id, data: data);
    return id;
  }

  // Purchase Price Lists
  Future<List<PurchasePriceList>> getPurchasePriceLists({int? supplierId, bool? activeOnly}) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs = [];
    
    if (supplierId != null) {
      where = 'supplier_id = ?';
      whereArgs.add(supplierId);
    }
    
    if (activeOnly == true) {
      if (where != null) {
        where += ' AND is_active = ?';
      } else {
        where = 'is_active = ?';
      }
      whereArgs.add(1);
    }
    
    final maps = await db.query(
      'purchase_price_lists',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'valid_from DESC',
    );
    return maps.map((map) => PurchasePriceList.fromMap(map)).toList();
  }

  Future<int> insertPurchasePriceList(PurchasePriceList priceList) async {
    final db = await _db.database;
    final data = _withSynced0(priceList.toMap());
    final id = await db.insert('purchase_price_lists', data);
    await _syncQueue.enqueueUpsert(table: 'purchase_price_lists', recordId: id, data: data);
    return id;
  }

  Future<List<PurchasePriceListItem>> getPurchasePriceListItems(int priceListId) async {
    final db = await _db.database;
    final maps = await db.query(
      'purchase_price_list_items',
      where: 'price_list_id = ?',
      whereArgs: [priceListId],
    );
    return maps.map((map) => PurchasePriceListItem.fromMap(map)).toList();
  }

  Future<int> insertPurchasePriceListItem(PurchasePriceListItem item) async {
    final db = await _db.database;
    final data = _withSynced0(item.toMap());
    final id = await db.insert('purchase_price_list_items', data);
    await _syncQueue.enqueueUpsert(table: 'purchase_price_list_items', recordId: id, data: data);
    return id;
  }

  // Auto Orders - Generate suggested orders based on min/max stock
  Future<List<AutoOrder>> generateAutoOrders() async {
    final materials = await getMaterials();
    final autoOrders = <AutoOrder>[];
    final now = DateTime.now().toIso8601String();
    
    for (final material in materials) {
      if (material.currentStock <= material.minStock && material.defaultSupplierId != null) {
        // Calculate suggested quantity (bring to max stock if set, otherwise 2x min stock)
        final suggestedQty = material.minStock * 2; // Default: order 2x min stock
        
        final autoOrder = AutoOrder(
          materialId: material.id!,
          supplierId: material.defaultSupplierId!,
          suggestedQuantity: suggestedQty,
          currentStock: material.currentStock,
          minStock: material.minStock,
          reason: material.currentStock < material.minStock ? 'below_min' : 'low_stock',
          createdAt: now,
        );
        
        autoOrders.add(autoOrder);
      }
    }
    
    // Save to database
    final db = await _db.database;
    for (final order in autoOrders) {
      final data = _withSynced0(order.toMap());
      final id = await db.insert('auto_orders', data);
      await _syncQueue.enqueueUpsert(table: 'auto_orders', recordId: id, data: data);
    }
    
    return autoOrders;
  }

  Future<List<AutoOrder>> getAutoOrders({String? status}) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs;
    
    if (status != null) {
      where = 'status = ?';
      whereArgs = [status];
    }
    
    final maps = await db.query(
      'auto_orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AutoOrder.fromMap(map)).toList();
  }

  Future<void> updateAutoOrderStatus(int id, String status, {String? notes}) async {
    final db = await _db.database;
    final updates = <String, dynamic>{
      'status': status,
      'synced': 0,
    };
    if (status == 'ordered') {
      updates['ordered_at'] = DateTime.now().toIso8601String();
    }
    if (notes != null) {
      updates['notes'] = notes;
    }
    await db.update('auto_orders', updates, where: 'id = ?', whereArgs: [id]);
    await _syncQueue.enqueueUpsert(table: 'auto_orders', recordId: id, data: updates);
  }

  // Warehouse Closings
  Future<List<WarehouseClosing>> getWarehouseClosings() async {
    final db = await _db.database;
    final maps = await db.query(
      'warehouse_closings',
      orderBy: 'closing_date DESC',
    );
    return maps.map((map) => WarehouseClosing.fromMap(map)).toList();
  }

  Future<int> insertWarehouseClosing(WarehouseClosing closing) async {
    final db = await _db.database;
    // Close all open closings first
    await db.update(
      'warehouse_closings',
      {'status': 'closed', 'synced': 0},
      where: 'status = ?',
      whereArgs: ['open'],
    );
    final data = _withSynced0(closing.toMap());
    final id = await db.insert('warehouse_closings', data);
    await _syncQueue.enqueueUpsert(table: 'warehouse_closings', recordId: id, data: data);
    return id;
  }

  Future<void> closeWarehouseClosing(int id) async {
    final db = await _db.database;
    await db.update(
      'warehouse_closings',
      {
        'status': 'closed',
        'closed_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _syncQueue.enqueueUpsert(
      table: 'warehouse_closings',
      recordId: id,
      data: {
        'status': 'closed',
        'closed_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
    );
  }

  // Audit Log
  Future<int> insertAuditLog(AuditLog log) async {
    final db = await _db.database;
    final data = _withSynced0(log.toMap());
    final id = await db.insert('audit_logs', data);
    await _syncQueue.enqueueUpsert(table: 'audit_logs', recordId: id, data: data);
    return id;
  }

  Future<List<AuditLog>> getAuditLogs({
    String? entityType,
    String? action,
    int? entityId,
    int? limit,
  }) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs = [];
    
    if (entityType != null) {
      where = 'entity_type = ?';
      whereArgs.add(entityType);
    }
    
    if (action != null) {
      if (where != null) {
        where += ' AND action = ?';
      } else {
        where = 'action = ?';
      }
      whereArgs.add(action);
    }
    
    if (entityId != null) {
      if (where != null) {
        where += ' AND entity_id = ?';
      } else {
        where = 'entity_id = ?';
      }
      whereArgs.add(entityId);
    }
    
    final maps = await db.query(
      'audit_logs',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }
}


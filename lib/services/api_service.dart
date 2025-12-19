import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/material.dart';
import '../models/warehouse.dart';
import '../models/production_type.dart';
import '../models/production.dart';
import '../models/batch.dart';
import '../models/quality_control.dart';
import '../models/production_plan.dart';
import '../models/notification.dart';
import '../config/api_config.dart';

class ApiService extends ChangeNotifier {
  static const String baseUrl = ApiConfig.baseUrl;
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ApiService() {
    checkConnection();
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      _isOnline = response.statusCode == 200;
    } catch (e) {
      _isOnline = false;
    }
    notifyListeners();
    return _isOnline;
  }

  // Materials
  Future<List<Material>> getMaterials() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/materials'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Material.fromJson(json)).toList();
      }
      throw Exception('Failed to load materials');
    } catch (e) {
      debugPrint('Error loading materials: $e');
      rethrow;
    }
  }

  Future<Material> createMaterial(String name, String unit) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/materials'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'unit': unit}),
    );
    if (response.statusCode == 201) {
      return Material.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create material');
  }

  Future<Material> updateMaterial(String id, String name, String unit) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/materials/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'unit': unit}),
    );
    if (response.statusCode == 200) {
      return Material.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to update material');
  }

  Future<void> deleteMaterial(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/materials/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete material');
    }
  }

  // Warehouse
  Future<List<Warehouse>> getWarehouse() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/warehouse'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Warehouse.fromJson(json)).toList();
      }
      throw Exception('Failed to load warehouse');
    } catch (e) {
      debugPrint('Error loading warehouse: $e');
      rethrow;
    }
  }

  Future<Warehouse> createWarehouseEntry(String materialId, double quantity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/warehouse'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'materialId': materialId, 'quantity': quantity}),
    );
    if (response.statusCode == 201) {
      return Warehouse.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create warehouse entry');
  }

  Future<Warehouse> updateWarehouseQuantity(String id, double quantity) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/warehouse/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'quantity': quantity}),
    );
    if (response.statusCode == 200) {
      return Warehouse.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to update warehouse');
  }

  // Production Types
  Future<List<ProductionType>> getProductionTypes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/production/types'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ProductionType.fromJson(json)).toList();
      }
      throw Exception('Failed to load production types');
    } catch (e) {
      debugPrint('Error loading production types: $e');
      rethrow;
    }
  }

  Future<ProductionType> createProductionType(String name, String? description) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/production/types'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'description': description}),
    );
    if (response.statusCode == 201) {
      return ProductionType.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create production type');
  }

  // Production
  Future<List<Production>> getProductions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/production'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Production.fromJson(json)).toList();
      }
      throw Exception('Failed to load productions');
    } catch (e) {
      debugPrint('Error loading productions: $e');
      rethrow;
    }
  }

  Future<Production> createProduction({
    required String productionTypeId,
    required double quantity,
    required List<Map<String, dynamic>> materials,
    String? notes,
    DateTime? productionDate,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/production'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'productionTypeId': productionTypeId,
        'quantity': quantity,
        'materials': materials,
        'notes': notes,
        'productionDate': productionDate?.toIso8601String(),
      }),
    );
    if (response.statusCode == 201) {
      return Production.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create production');
  }

  Future<void> deleteProduction(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/production/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete production');
    }
  }

  // Recipes
  Future<List<dynamic>> getRecipes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/recipes'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load recipes');
    } catch (e) {
      debugPrint('Error loading recipes: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getRecipesByProductionType(String productionTypeId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/recipes/type/$productionTypeId')
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load recipes');
    } catch (e) {
      debugPrint('Error loading recipes: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRecipeById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/recipes/$id'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load recipe');
    } catch (e) {
      debugPrint('Error loading recipe: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> calculateRecipeMaterials(String recipeId, double quantity) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recipes/$recipeId/calculate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'quantity': quantity}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to calculate materials');
    } catch (e) {
      debugPrint('Error calculating materials: $e');
      rethrow;
    }
  }

  Future<dynamic> createRecipe({
    required String productionTypeId,
    required String name,
    String? description,
    required List<Map<String, dynamic>> materials,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recipes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'productionTypeId': productionTypeId,
          'name': name,
          'description': description,
          'materials': materials,
        }),
      );
      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to create recipe');
    } catch (e) {
      debugPrint('Error creating recipe: $e');
      rethrow;
    }
  }

  Future<dynamic> updateRecipe({
    required String id,
    required String name,
    String? description,
    required List<Map<String, dynamic>> materials,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/recipes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'description': description,
          'materials': materials,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to update recipe');
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      rethrow;
    }
  }

  Future<void> deleteRecipe(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/api/recipes/$id'));
      if (response.statusCode != 200) {
        throw Exception('Failed to delete recipe');
      }
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      rethrow;
    }
  }

  // Sync
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/sync/status'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get sync status');
    } catch (e) {
      debugPrint('Error getting sync status: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sync() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/api/sync'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to sync');
    } catch (e) {
      debugPrint('Error syncing: $e');
      rethrow;
    }
  }

  // Batches
  Future<List<Batch>> getBatches() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/batches'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Batch.fromJson(json)).toList();
      }
      throw Exception('Failed to load batches');
    } catch (e) {
      debugPrint('Error loading batches: $e');
      rethrow;
    }
  }

  // Get batches grouped by days
  Future<Map<String, List<Batch>>> getBatchesByDays({int days = 30}) async {
    try {
      final batches = await getBatches();
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: days));
      
      final Map<String, List<Batch>> grouped = {};
      
      for (final batch in batches) {
        if (batch.createdAt != null && batch.createdAt!.isAfter(cutoffDate)) {
          final dayKey = '${batch.createdAt!.year}-${batch.createdAt!.month.toString().padLeft(2, '0')}-${batch.createdAt!.day.toString().padLeft(2, '0')}';
          grouped.putIfAbsent(dayKey, () => []).add(batch);
        }
      }
      
      return grouped;
    } catch (e) {
      debugPrint('Error loading batches by days: $e');
      rethrow;
    }
  }

  // Check low stock materials
  Future<List<Map<String, dynamic>>> checkLowStock({double threshold = 100}) async {
    try {
      final warehouse = await getWarehouse();
      final materials = await getMaterials();
      final alerts = <Map<String, dynamic>>[];
      
      for (final item in warehouse) {
        final material = materials.firstWhere(
          (m) => m.id == item.materialId,
          orElse: () => Material(id: item.materialId, name: 'Neznámy', unit: ''),
        );
        
        if (item.quantity == 0) {
          alerts.add({
            'type': 'critical_stock',
            'material': material,
            'message': 'Kritický nedostatok - zásoby sú na nule!',
            'quantity': item.quantity,
          });
        } else if (item.quantity < threshold) {
          alerts.add({
            'type': 'low_stock',
            'material': material,
            'message': 'Nízke zásoby - ${item.quantity.toStringAsFixed(2)} ${material.unit}',
            'quantity': item.quantity,
          });
        }
      }
      
      return alerts;
    } catch (e) {
      debugPrint('Error checking low stock: $e');
      return [];
    }
  }

  // Add material quantity to warehouse
  Future<Warehouse> addMaterialQuantity(String materialId, double quantity) async {
    try {
      final warehouse = await getWarehouse();
      final existing = warehouse.firstWhere(
        (w) => w.materialId == materialId,
        orElse: () => Warehouse(
          id: '',
          materialId: materialId,
          quantity: 0,
        ),
      );
      
      if (existing.id.isEmpty) {
        return await createWarehouseEntry(materialId, quantity);
      } else {
        return await updateWarehouseQuantity(existing.id, existing.quantity + quantity);
      }
    } catch (e) {
      debugPrint('Error adding material quantity: $e');
      rethrow;
    }
  }

  Future<dynamic> createBatch({
    required String productionId,
    required String batchNumber,
    required double quantity,
    String? qrCode,
    String? warehouseLocation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/batches'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'production_id': productionId,
          'batch_number': batchNumber,
          'quantity': quantity,
          'qr_code': qrCode,
          'warehouse_location': warehouseLocation,
        }),
      );
      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to create batch');
    } catch (e) {
      debugPrint('Error creating batch: $e');
      rethrow;
    }
  }

  // Quality Control
  Future<List<QualityControl>> getQualityTests(String batchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/quality-control/batch/$batchId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => QualityControl.fromJson(json)).toList();
      }
      throw Exception('Failed to load quality tests');
    } catch (e) {
      debugPrint('Error loading quality tests: $e');
      rethrow;
    }
  }

  // Update batch quality status
  Future<bool> updateBatchQualityStatus(
    String batchId,
    String status, {
    String? notes,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/batches/$batchId/quality'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': status,
          'notes': notes,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating batch quality status: $e');
      return false;
    }
  }

  Future<void> createQualityTest({
    required String batchId,
    required String testType,
    required String testName,
    double? resultValue,
    String? resultText,
    required bool passed,
    String? testedBy,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/quality-control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'batch_id': batchId,
          'test_type': testType,
          'test_name': testName,
          'result_value': resultValue,
          'result_text': resultText,
          'passed': passed,
          'tested_by': testedBy,
          'notes': notes,
        }),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to create quality test');
      }
    } catch (e) {
      debugPrint('Error creating quality test: $e');
      rethrow;
    }
  }

  // Production Plans
  Future<List<ProductionPlan>> getProductionPlans() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/production-plans'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ProductionPlan.fromJson(json)).toList();
      }
      throw Exception('Failed to load production plans');
    } catch (e) {
      debugPrint('Error loading production plans: $e');
      rethrow;
    }
  }

  Future<void> createProductionPlan({
    required String productionTypeId,
    required double plannedQuantity,
    required DateTime plannedDate,
    String priority = 'normal',
    String? assignedRecipeId,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/production-plans'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'production_type_id': productionTypeId,
          'planned_quantity': plannedQuantity,
          'planned_date': plannedDate.toIso8601String().split('T')[0],
          'priority': priority,
          'assigned_recipe_id': assignedRecipeId,
          'notes': notes,
        }),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to create production plan');
      }
    } catch (e) {
      debugPrint('Error creating production plan: $e');
      rethrow;
    }
  }

  Future<void> deleteProductionPlan(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/production-plans/$id'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete production plan');
      }
    } catch (e) {
      debugPrint('Error deleting production plan: $e');
      rethrow;
    }
  }

  // Reports
  Future<Map<String, dynamic>> getReport({
    required String period,
    required DateTime date,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/reports')
            .replace(queryParameters: {
          'period': period,
          'date': date.toIso8601String().split('T')[0],
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get report');
    } catch (e) {
      debugPrint('Error getting report: $e');
      rethrow;
    }
  }

  // Notifications
  Future<List<Notification>> getNotifications() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/notifications'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Notification.fromJson(json)).toList();
      }
      throw Exception('Failed to load notifications');
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/notifications/$id/read'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'read': true}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read');
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }
}


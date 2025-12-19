import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/material.dart';
import '../models/warehouse.dart';
import '../models/production_type.dart';
import '../models/production.dart';
import 'app_state.dart';

class ApiService extends ChangeNotifier {
  static const String baseUrl = 'http://localhost:3000';
  
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
}


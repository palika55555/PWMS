import 'material.dart';

class Warehouse {
  final String id;
  final String materialId;
  final String? materialName;
  final String? unit;
  final double quantity;
  final DateTime? lastUpdated;
  final bool synced;

  Warehouse({
    required this.id,
    required this.materialId,
    this.materialName,
    this.unit,
    required this.quantity,
    this.lastUpdated,
    this.synced = false,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] as String,
      materialId: json['material_id'] as String,
      materialName: json['material_name'] as String?,
      unit: json['unit'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_id': materialId,
      'quantity': quantity,
      'last_updated': lastUpdated?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  Warehouse copyWith({
    String? id,
    String? materialId,
    String? materialName,
    String? unit,
    double? quantity,
    DateTime? lastUpdated,
    bool? synced,
  }) {
    return Warehouse(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      synced: synced ?? this.synced,
    );
  }
}


class ProductionMaterial {
  final String id;
  final String materialId;
  final String? materialName;
  final String? unit;
  final double quantity;

  ProductionMaterial({
    required this.id,
    required this.materialId,
    this.materialName,
    this.unit,
    required this.quantity,
  });

  factory ProductionMaterial.fromJson(Map<String, dynamic> json) {
    return ProductionMaterial(
      id: json['id'] as String? ?? '',
      materialId: json['material_id'] as String,
      materialName: json['material_name'] as String?,
      unit: json['unit'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material_id': materialId,
      'quantity': quantity,
    };
  }
}

class Production {
  final String id;
  final String productionTypeId;
  final String? productionTypeName;
  final double quantity;
  final DateTime? productionDate;
  final String? notes;
  final String? qrCode;
  final String? status;
  final String? recipeId;
  final DateTime? createdAt;
  final bool synced;
  final List<ProductionMaterial> materials;

  Production({
    required this.id,
    required this.productionTypeId,
    this.productionTypeName,
    required this.quantity,
    this.productionDate,
    this.notes,
    this.qrCode,
    this.status,
    this.recipeId,
    this.createdAt,
    this.synced = false,
    this.materials = const [],
  });

  factory Production.fromJson(Map<String, dynamic> json) {
    return Production(
      id: json['id'] as String,
      productionTypeId: json['production_type_id'] as String,
      productionTypeName: json['production_type_name'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      productionDate: json['production_date'] != null
          ? DateTime.parse(json['production_date'])
          : null,
      notes: json['notes'] as String?,
      qrCode: json['qr_code'] as String?,
      status: json['status'] as String?,
      recipeId: json['recipe_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
      materials: json['materials'] != null
          ? (json['materials'] as List)
              .map((m) => ProductionMaterial.fromJson(m))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'production_type_id': productionTypeId,
      'quantity': quantity,
      'production_date': productionDate?.toIso8601String(),
      'notes': notes,
      'materials': materials.map((m) => m.toJson()).toList(),
    };
  }

  Production copyWith({
    String? id,
    String? productionTypeId,
    String? productionTypeName,
    double? quantity,
    DateTime? productionDate,
    String? notes,
    String? qrCode,
    String? status,
    String? recipeId,
    DateTime? createdAt,
    bool? synced,
    List<ProductionMaterial>? materials,
  }) {
    return Production(
      id: id ?? this.id,
      productionTypeId: productionTypeId ?? this.productionTypeId,
      productionTypeName: productionTypeName ?? this.productionTypeName,
      quantity: quantity ?? this.quantity,
      productionDate: productionDate ?? this.productionDate,
      notes: notes ?? this.notes,
      qrCode: qrCode ?? this.qrCode,
      status: status ?? this.status,
      recipeId: recipeId ?? this.recipeId,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      materials: materials ?? this.materials,
    );
  }
}


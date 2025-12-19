class RecipeMaterial {
  final String materialId;
  final double quantityPerUnit; // množstvo na 1 jednotku výroby (napr. na 1 m² alebo na 1 kus)

  RecipeMaterial({
    required this.materialId,
    required this.quantityPerUnit,
  });

  factory RecipeMaterial.fromJson(Map<String, dynamic> json) {
    return RecipeMaterial(
      materialId: json['material_id'] as String,
      quantityPerUnit: (json['quantity_per_unit'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'material_id': materialId,
      'quantity_per_unit': quantityPerUnit,
    };
  }
}

class Recipe {
  final String id;
  final String productionTypeId;
  final String name;
  final String? description;
  final List<RecipeMaterial> materials;
  final DateTime? createdAt;
  final bool synced;

  Recipe({
    required this.id,
    required this.productionTypeId,
    required this.name,
    this.description,
    this.materials = const [],
    this.createdAt,
    this.synced = false,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      productionTypeId: json['production_type_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      materials: json['materials'] != null
          ? (json['materials'] as List)
              .map((m) => RecipeMaterial.fromJson(m))
              .toList()
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'production_type_id': productionTypeId,
      'name': name,
      'description': description,
      'materials': materials.map((m) => m.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  Recipe copyWith({
    String? id,
    String? productionTypeId,
    String? name,
    String? description,
    List<RecipeMaterial>? materials,
    DateTime? createdAt,
    bool? synced,
  }) {
    return Recipe(
      id: id ?? this.id,
      productionTypeId: productionTypeId ?? this.productionTypeId,
      name: name ?? this.name,
      description: description ?? this.description,
      materials: materials ?? this.materials,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  // Vypočíta potrebné materiály pre dané množstvo výroby
  List<Map<String, dynamic>> calculateMaterials(double productionQuantity) {
    return materials.map((recipeMaterial) {
      return {
        'materialId': recipeMaterial.materialId,
        'quantity': recipeMaterial.quantityPerUnit * productionQuantity,
      };
    }).toList();
  }
}

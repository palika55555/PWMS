class Recipe {
  final int? id;
  final int productId;
  final int materialId;
  final double quantityPerUnit;
  final String unit;

  Recipe({
    this.id,
    required this.productId,
    required this.materialId,
    required this.quantityPerUnit,
    required this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'material_id': materialId,
      'quantity_per_unit': quantityPerUnit,
      'unit': unit,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      materialId: map['material_id'] as int,
      quantityPerUnit: map['quantity_per_unit'] as double,
      unit: map['unit'] as String,
    );
  }
}


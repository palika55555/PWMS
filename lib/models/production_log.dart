class ProductionLog {
  final int? id;
  final int productId;
  final int materialId;
  final double quantityUsed;
  final String productionDate;

  ProductionLog({
    this.id,
    required this.productId,
    required this.materialId,
    required this.quantityUsed,
    required this.productionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'material_id': materialId,
      'quantity_used': quantityUsed,
      'production_date': productionDate,
    };
  }

  factory ProductionLog.fromMap(Map<String, dynamic> map) {
    return ProductionLog(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      materialId: map['material_id'] as int,
      quantityUsed: map['quantity_used'] as double,
      productionDate: map['production_date'] as String,
    );
  }
}


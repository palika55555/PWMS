class Material {
  final int? id;
  final String name;
  final String unit;
  final double quantity;
  final double minQuantity;
  final String createdAt;

  Material({
    this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    this.minQuantity = 10.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'created_at': createdAt,
    };
  }

  factory Material.fromMap(Map<String, dynamic> map) {
    final minQty = map['min_quantity'];
    double minQuantityValue = 10.0;
    if (minQty != null) {
      if (minQty is double) {
        minQuantityValue = minQty;
      } else if (minQty is int) {
        minQuantityValue = minQty.toDouble();
      } else if (minQty is num) {
        minQuantityValue = minQty.toDouble();
      }
    }
    
    return Material(
      id: map['id'] as int?,
      name: map['name'] as String,
      unit: map['unit'] as String,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      minQuantity: minQuantityValue,
      createdAt: map['created_at'] as String,
    );
  }

  Material copyWith({
    int? id,
    String? name,
    String? unit,
    double? quantity,
    double? minQuantity,
    String? createdAt,
  }) {
    return Material(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isLowStock => quantity < (minQuantity > 0 ? minQuantity : 10.0);
}


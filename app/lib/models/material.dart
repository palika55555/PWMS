class Material {
  const Material({
    required this.id,
    required this.name,
    required this.category,
    this.fraction,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String? fraction;
  final String unit;
  final double currentStock;
  final double minStock;
  final String createdAt;
  final String updatedAt;

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      fraction: json['fraction'] as String?,
      unit: json['unit'] as String,
      currentStock: (json['currentStock'] as num).toDouble(),
      minStock: (json['minStock'] as num).toDouble(),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'CEMENT':
        return 'Cement';
      case 'WATER':
        return 'Voda';
      case 'PLASTICIZER':
        return 'Plastifikátor';
      case 'GRAVEL':
        return 'Štrk';
      case 'OTHER':
        return 'Iné';
      default:
        return category;
    }
  }

  String get displayName {
    if (fraction != null && fraction!.isNotEmpty) {
      return '$name (frakcia: $fraction)';
    }
    return name;
  }
}


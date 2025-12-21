class RecipeItem {
  const RecipeItem({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.materialCategory,
    this.materialFraction,
    required this.amount,
    required this.unit,
  });

  final String id;
  final String materialId;
  final String materialName;
  final String materialCategory;
  final String? materialFraction;
  final double amount;
  final String unit;

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    return RecipeItem(
      id: json['id'] as String,
      materialId: json['materialId'] as String,
      materialName: json['materialName'] as String,
      materialCategory: json['materialCategory'] as String,
      materialFraction: json['materialFraction'] as String?,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  String get categoryLabel {
    switch (materialCategory) {
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
        return materialCategory;
    }
  }
}


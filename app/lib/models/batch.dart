class Batch {
  const Batch({
    required this.id,
    required this.batchDate,
    this.recipeId,
    this.recipeName,
    this.productName,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.recipeItems = const [],
    this.productionEntries = const [],
    this.qualityChecks = const [],
  });

  final String id;
  final String batchDate;
  final String? recipeId;
  final String? recipeName;
  final String? productName;
  final String status;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final List<RecipeItem> recipeItems;
  final List<ProductionEntry> productionEntries;
  final List<QualityCheck> qualityChecks;

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['id'] as String,
      batchDate: json['batchDate'] as String,
      recipeId: json['recipeId'] as String?,
      recipeName: json['recipeName'] as String?,
      productName: json['productName'] as String?,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      recipeItems: (json['recipeItems'] as List<dynamic>?)
              ?.map((e) => RecipeItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      productionEntries: (json['productionEntries'] as List<dynamic>?)
              ?.map((e) => ProductionEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      qualityChecks: (json['qualityChecks'] as List<dynamic>?)
              ?.map((e) => QualityCheck.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'DRAFT':
        return 'Koncept';
      case 'PRODUCED':
        return 'Vyrobené';
      case 'QC_PENDING':
        return 'Čaká na kontrolu';
      case 'APPROVED':
        return 'Schválené';
      case 'REJECTED':
        return 'Zamietnuté';
      default:
        return status;
    }
  }
}

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

class ProductionEntry {
  const ProductionEntry({
    required this.id,
    required this.quantity,
    required this.unit,
    required this.createdAt,
  });

  final String id;
  final double quantity;
  final String unit;
  final String createdAt;

  factory ProductionEntry.fromJson(Map<String, dynamic> json) {
    return ProductionEntry(
      id: json['id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class QualityCheck {
  const QualityCheck({
    required this.id,
    required this.approved,
    this.checkedBy,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final bool approved;
  final String? checkedBy;
  final String? notes;
  final String createdAt;

  factory QualityCheck.fromJson(Map<String, dynamic> json) {
    return QualityCheck(
      id: json['id'] as String,
      approved: json['approved'] as bool,
      checkedBy: json['checkedBy'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }
}


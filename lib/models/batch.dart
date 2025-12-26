class Batch {
  final int? id;
  final String batchNumber;
  final int recipeId;
  final String productionDate;
  final int quantity;
  final String qualityStatus; // pending, approved, rejected
  final String? qualityApprovedBy;
  final String? qualityApprovedAt;
  final String? notes;
  final int? dryingDays; // Doba sušenia v dňoch
  final String? curingStartDate; // Začiatok zrenia
  final String? curingEndDate; // Koniec zrenia (vypočítaný)
  final double? productionTemperature; // Teplota pri výrobe (°C)
  final double? productionHumidity; // Vlhkosť pri výrobe (%)
  final int synced;
  final String createdAt;
  final String updatedAt;

  Batch({
    this.id,
    required this.batchNumber,
    required this.recipeId,
    required this.productionDate,
    required this.quantity,
    this.qualityStatus = 'pending',
    this.qualityApprovedBy,
    this.qualityApprovedAt,
    this.notes,
    this.dryingDays,
    this.curingStartDate,
    this.curingEndDate,
    this.productionTemperature,
    this.productionHumidity,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_number': batchNumber,
      'recipe_id': recipeId,
      'production_date': productionDate,
      'quantity': quantity,
      'quality_status': qualityStatus,
      'quality_approved_by': qualityApprovedBy,
      'quality_approved_at': qualityApprovedAt,
      'notes': notes,
      'drying_days': dryingDays,
      'curing_start_date': curingStartDate,
      'curing_end_date': curingEndDate,
      'production_temperature': productionTemperature,
      'production_humidity': productionHumidity,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id'] as int?,
      batchNumber: map['batch_number'] as String,
      recipeId: map['recipe_id'] as int,
      productionDate: map['production_date'] as String,
      quantity: map['quantity'] as int,
      qualityStatus: map['quality_status'] as String? ?? 'pending',
      qualityApprovedBy: map['quality_approved_by'] as String?,
      qualityApprovedAt: map['quality_approved_at'] as String?,
      notes: map['notes'] as String?,
      dryingDays: map['drying_days'] as int?,
      curingStartDate: map['curing_start_date'] as String?,
      curingEndDate: map['curing_end_date'] as String?,
      productionTemperature: (map['production_temperature'] as num?)?.toDouble(),
      productionHumidity: (map['production_humidity'] as num?)?.toDouble(),
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Batch copyWith({
    int? id,
    String? batchNumber,
    int? recipeId,
    String? productionDate,
    int? quantity,
    String? qualityStatus,
    String? qualityApprovedBy,
    String? qualityApprovedAt,
    String? notes,
    int? dryingDays,
    String? curingStartDate,
    String? curingEndDate,
    double? productionTemperature,
    double? productionHumidity,
    int? synced,
    String? createdAt,
    String? updatedAt,
  }) {
    return Batch(
      id: id ?? this.id,
      batchNumber: batchNumber ?? this.batchNumber,
      recipeId: recipeId ?? this.recipeId,
      productionDate: productionDate ?? this.productionDate,
      quantity: quantity ?? this.quantity,
      qualityStatus: qualityStatus ?? this.qualityStatus,
      qualityApprovedBy: qualityApprovedBy ?? this.qualityApprovedBy,
      qualityApprovedAt: qualityApprovedAt ?? this.qualityApprovedAt,
      notes: notes ?? this.notes,
      dryingDays: dryingDays ?? this.dryingDays,
      curingStartDate: curingStartDate ?? this.curingStartDate,
      curingEndDate: curingEndDate ?? this.curingEndDate,
      productionTemperature: productionTemperature ?? this.productionTemperature,
      productionHumidity: productionHumidity ?? this.productionHumidity,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


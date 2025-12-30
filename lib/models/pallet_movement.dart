class PalletMovement {
  final int? id;
  final int customerId;
  final String direction; // issued | returned
  final double quantity;
  final String movementDate; // yyyy-MM-dd
  final String? notes;
  final String createdBy;
  final int synced;
  final String createdAt;
  final String updatedAt;

  PalletMovement({
    this.id,
    required this.customerId,
    required this.direction,
    required this.quantity,
    required this.movementDate,
    this.notes,
    required this.createdBy,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'direction': direction,
      'quantity': quantity,
      'movement_date': movementDate,
      'notes': notes,
      'created_by': createdBy,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory PalletMovement.fromMap(Map<String, dynamic> map) {
    return PalletMovement(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int,
      direction: map['direction'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      movementDate: map['movement_date'] as String,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: (map['updated_at'] as String?) ?? (map['created_at'] as String),
    );
  }

  PalletMovement copyWith({
    int? id,
    int? customerId,
    String? direction,
    double? quantity,
    String? movementDate,
    String? notes,
    String? createdBy,
    int? synced,
    String? createdAt,
    String? updatedAt,
  }) {
    return PalletMovement(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      direction: direction ?? this.direction,
      quantity: quantity ?? this.quantity,
      movementDate: movementDate ?? this.movementDate,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}








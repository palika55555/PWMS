class Batch {
  final String id;
  final String productionId;
  final String batchNumber;
  final String? qrCode;
  final double quantity;
  final String status; // pending, in_progress, completed, shipped
  final String? warehouseLocation;
  final DateTime? createdAt;
  final DateTime? shippedAt;
  final bool synced;

  Batch({
    required this.id,
    required this.productionId,
    required this.batchNumber,
    this.qrCode,
    required this.quantity,
    this.status = 'pending',
    this.warehouseLocation,
    this.createdAt,
    this.shippedAt,
    this.synced = false,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['id'] as String,
      productionId: json['production_id'] as String,
      batchNumber: json['batch_number'] as String,
      qrCode: json['qr_code'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      warehouseLocation: json['warehouse_location'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      shippedAt: json['shipped_at'] != null
          ? DateTime.parse(json['shipped_at'])
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'production_id': productionId,
      'batch_number': batchNumber,
      'qr_code': qrCode,
      'quantity': quantity,
      'status': status,
      'warehouse_location': warehouseLocation,
      'created_at': createdAt?.toIso8601String(),
      'shipped_at': shippedAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  Batch copyWith({
    String? id,
    String? productionId,
    String? batchNumber,
    String? qrCode,
    double? quantity,
    String? status,
    String? warehouseLocation,
    DateTime? createdAt,
    DateTime? shippedAt,
    bool? synced,
  }) {
    return Batch(
      id: id ?? this.id,
      productionId: productionId ?? this.productionId,
      batchNumber: batchNumber ?? this.batchNumber,
      qrCode: qrCode ?? this.qrCode,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      warehouseLocation: warehouseLocation ?? this.warehouseLocation,
      createdAt: createdAt ?? this.createdAt,
      shippedAt: shippedAt ?? this.shippedAt,
      synced: synced ?? this.synced,
    );
  }
}


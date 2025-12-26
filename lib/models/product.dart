class Product {
  final int? id;
  final int batchId;
  final String? productCode;
  final String? qrCode;
  final String? serialNumber; // Sériové číslo
  final String? productionNumber; // Výrobné číslo
  final String? expirationDate; // Dátum expirácie
  final String status; // produced, in_stock, shipped, etc.
  final String? location;
  final int? warehouseLocationId; // ID skladovej lokality
  final int synced;
  final String createdAt;

  Product({
    this.id,
    required this.batchId,
    this.productCode,
    this.qrCode,
    this.serialNumber,
    this.productionNumber,
    this.expirationDate,
    this.status = 'produced',
    this.location,
    this.warehouseLocationId,
    this.synced = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batch_id': batchId,
      'product_code': productCode,
      'qr_code': qrCode,
      'serial_number': serialNumber,
      'production_number': productionNumber,
      'expiration_date': expirationDate,
      'status': status,
      'location': location,
      'warehouse_location_id': warehouseLocationId,
      'synced': synced,
      'created_at': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      batchId: map['batch_id'] as int,
      productCode: map['product_code'] as String?,
      qrCode: map['qr_code'] as String?,
      serialNumber: map['serial_number'] as String?,
      productionNumber: map['production_number'] as String?,
      expirationDate: map['expiration_date'] as String?,
      status: map['status'] as String? ?? 'produced',
      location: map['location'] as String?,
      warehouseLocationId: map['warehouse_location_id'] as int?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
    );
  }
}


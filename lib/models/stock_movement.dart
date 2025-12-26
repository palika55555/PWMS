class StockMovement {
  final int? id;
  final String movementType; // receipt, issue, inventory_adjustment, transfer
  final int? materialId;
  final double quantity;
  final String unit;
  final String? documentNumber; // Číslo dokladu (dodacieho listu, výdajky, atď.)
  final String? receiptNumber; // Interné číslo príjemky (napr. PR-2025-001)
  final String? supplierName; // Názov dodávateľa (pre príjem)
  final String? recipientName; // Názov príjemcu (pre výdaj)
  final String? reason; // Dôvod výdaju alebo úpravy
  final String? location; // Miesto skladu
  final String? notes;
  final String? productNote; // Poznámka k produktu
  final String? expirationDate; // Dátum expirácie produktu
  // Ceny pri príjme tovaru
  final double? purchasePriceWithoutVat; // Nákupná cena bez DPH
  final double? purchasePriceWithVat; // Nákupná cena s DPH
  final double? vatRate; // Sadzba DPH
  final int? supplierId; // ID dodávateľa
  final int? warehouseId; // ID skladu
  final String movementDate; // Dátum príjmu/výdaju
  final String? deliveryDate; // Dátum dodania (môže byť iný ako dátum príjmu)
  final String createdBy;
  final String status; // 'pending', 'approved', 'rejected'
  final String? approvedBy; // Kto schválil
  final String? approvedAt; // Kedy schválil
  final String? rejectionReason; // Dôvod zamietnutia
  final int synced;
  final String createdAt;

  StockMovement({
    this.id,
    required this.movementType,
    this.materialId,
    required this.quantity,
    required this.unit,
    this.documentNumber,
    this.receiptNumber,
    this.supplierName,
    this.recipientName,
    this.reason,
    this.location,
    this.notes,
    this.productNote,
    this.expirationDate,
    this.purchasePriceWithoutVat,
    this.purchasePriceWithVat,
    this.vatRate,
    this.supplierId,
    this.warehouseId,
    required this.movementDate,
    this.deliveryDate,
    required this.createdBy,
    this.status = 'pending', // Default: pending approval
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.synced = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'movement_type': movementType,
      'material_id': materialId,
      'quantity': quantity,
      'unit': unit,
      'document_number': documentNumber,
      'receipt_number': receiptNumber,
      'supplier_name': supplierName,
      'recipient_name': recipientName,
      'reason': reason,
      'location': location,
      'notes': notes,
      'product_note': productNote,
      'expiration_date': expirationDate,
      'purchase_price_without_vat': purchasePriceWithoutVat,
      'purchase_price_with_vat': purchasePriceWithVat,
      'vat_rate': vatRate,
      'supplier_id': supplierId,
      'warehouse_id': warehouseId,
      'movement_date': movementDate,
      'delivery_date': deliveryDate,
      'created_by': createdBy,
      'status': status,
      'approved_by': approvedBy,
      'approved_at': approvedAt,
      'rejection_reason': rejectionReason,
      'synced': synced,
      'created_at': createdAt,
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int?,
      movementType: map['movement_type'] as String,
      materialId: map['material_id'] as int?,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      documentNumber: map['document_number'] as String?,
      receiptNumber: map['receipt_number'] as String?,
      supplierName: map['supplier_name'] as String?,
      recipientName: map['recipient_name'] as String?,
      reason: map['reason'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      productNote: map['product_note'] as String?,
      expirationDate: map['expiration_date'] as String?,
      purchasePriceWithoutVat: (map['purchase_price_without_vat'] as num?)?.toDouble(),
      purchasePriceWithVat: (map['purchase_price_with_vat'] as num?)?.toDouble(),
      vatRate: (map['vat_rate'] as num?)?.toDouble(),
      supplierId: map['supplier_id'] as int?,
      warehouseId: map['warehouse_id'] as int?,
      movementDate: map['movement_date'] as String,
      deliveryDate: map['delivery_date'] as String?,
      createdBy: map['created_by'] as String,
      status: map['status'] as String? ?? 'pending',
      approvedBy: map['approved_by'] as String?,
      approvedAt: map['approved_at'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
    );
  }

  StockMovement copyWith({
    int? id,
    String? movementType,
    int? materialId,
    double? quantity,
    String? unit,
    String? documentNumber,
    String? receiptNumber,
    String? supplierName,
    String? recipientName,
    String? reason,
    String? location,
    String? notes,
    String? productNote,
    String? expirationDate,
    double? purchasePriceWithoutVat,
    double? purchasePriceWithVat,
    double? vatRate,
        int? supplierId,
        int? warehouseId,
        String? movementDate,
        String? deliveryDate,
        String? createdBy,
    String? status,
    String? approvedBy,
    String? approvedAt,
    String? rejectionReason,
    int? synced,
    String? createdAt,
  }) {
    return StockMovement(
      id: id ?? this.id,
      movementType: movementType ?? this.movementType,
      materialId: materialId ?? this.materialId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      documentNumber: documentNumber ?? this.documentNumber,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      supplierName: supplierName ?? this.supplierName,
      recipientName: recipientName ?? this.recipientName,
      reason: reason ?? this.reason,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      productNote: productNote ?? this.productNote,
      expirationDate: expirationDate ?? this.expirationDate,
      purchasePriceWithoutVat: purchasePriceWithoutVat ?? this.purchasePriceWithoutVat,
      purchasePriceWithVat: purchasePriceWithVat ?? this.purchasePriceWithVat,
      vatRate: vatRate ?? this.vatRate,
          supplierId: supplierId ?? this.supplierId,
          warehouseId: warehouseId ?? this.warehouseId,
          movementDate: movementDate ?? this.movementDate,
          deliveryDate: deliveryDate ?? this.deliveryDate,
          createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Inventory {
  final int? id;
  final String inventoryDate;
  final String status; // planned, in_progress, completed
  final String? location;
  final String? notes;
  final String createdBy;
  final int synced;
  final String createdAt;
  final String updatedAt;

  Inventory({
    this.id,
    required this.inventoryDate,
    this.status = 'planned',
    this.location,
    this.notes,
    required this.createdBy,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventory_date': inventoryDate,
      'status': status,
      'location': location,
      'notes': notes,
      'created_by': createdBy,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'] as int?,
      inventoryDate: map['inventory_date'] as String,
      status: map['status'] as String? ?? 'planned',
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Inventory copyWith({
    int? id,
    String? inventoryDate,
    String? status,
    String? location,
    String? notes,
    String? createdBy,
    int? synced,
    String? createdAt,
    String? updatedAt,
  }) {
    return Inventory(
      id: id ?? this.id,
      inventoryDate: inventoryDate ?? this.inventoryDate,
      status: status ?? this.status,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class InventoryItem {
  final int? id;
  final int inventoryId;
  final int materialId;
  final double recordedQuantity; // Zaznamenané množstvo
  final double actualQuantity; // Skutočné množstvo
  final double difference; // Rozdiel
  final String unit;
  final String? notes;
  final int synced;
  final String createdAt;

  InventoryItem({
    this.id,
    required this.inventoryId,
    required this.materialId,
    required this.recordedQuantity,
    required this.actualQuantity,
    required this.difference,
    required this.unit,
    this.notes,
    this.synced = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventory_id': inventoryId,
      'material_id': materialId,
      'recorded_quantity': recordedQuantity,
      'actual_quantity': actualQuantity,
      'difference': difference,
      'unit': unit,
      'notes': notes,
      'synced': synced,
      'created_at': createdAt,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int?,
      inventoryId: map['inventory_id'] as int,
      materialId: map['material_id'] as int,
      recordedQuantity: (map['recorded_quantity'] as num).toDouble(),
      actualQuantity: (map['actual_quantity'] as num).toDouble(),
      difference: (map['difference'] as num).toDouble(),
      unit: map['unit'] as String,
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
    );
  }
}


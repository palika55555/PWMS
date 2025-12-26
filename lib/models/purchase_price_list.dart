/// Model pre nákupné cenníky od dodávateľov
class PurchasePriceList {
  final int? id;
  final int supplierId; // ID dodávateľa
  final String name; // Názov cenníka
  final String? code; // Kód cenníka
  final String validFrom; // Platnosť od
  final String? validTo; // Platnosť do
  final bool isActive;
  final String? notes;
  final int synced;
  final String createdAt;
  final String updatedAt;

  PurchasePriceList({
    this.id,
    required this.supplierId,
    required this.name,
    this.code,
    required this.validFrom,
    this.validTo,
    this.isActive = true,
    this.notes,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'name': name,
      'code': code,
      'valid_from': validFrom,
      'valid_to': validTo,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory PurchasePriceList.fromMap(Map<String, dynamic> map) {
    return PurchasePriceList(
      id: map['id'] as int?,
      supplierId: map['supplier_id'] as int,
      name: map['name'] as String,
      code: map['code'] as String?,
      validFrom: map['valid_from'] as String,
      validTo: map['valid_to'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}

/// Model pre položky v nákupnom cenníku
class PurchasePriceListItem {
  final int? id;
  final int priceListId;
  final int materialId;
  final double priceWithoutVat; // Cena bez DPH
  final double priceWithVat; // Cena s DPH
  final double vatRate; // Sadzba DPH
  final double? minQuantity; // Minimálne množstvo pre túto cenu
  final String? notes;
  final int synced;
  final String createdAt;
  final String updatedAt;

  PurchasePriceListItem({
    this.id,
    required this.priceListId,
    required this.materialId,
    required this.priceWithoutVat,
    required this.priceWithVat,
    required this.vatRate,
    this.minQuantity,
    this.notes,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'price_list_id': priceListId,
      'material_id': materialId,
      'price_without_vat': priceWithoutVat,
      'price_with_vat': priceWithVat,
      'vat_rate': vatRate,
      'min_quantity': minQuantity,
      'notes': notes,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory PurchasePriceListItem.fromMap(Map<String, dynamic> map) {
    return PurchasePriceListItem(
      id: map['id'] as int?,
      priceListId: map['price_list_id'] as int,
      materialId: map['material_id'] as int,
      priceWithoutVat: (map['price_without_vat'] as num).toDouble(),
      priceWithVat: (map['price_with_vat'] as num).toDouble(),
      vatRate: (map['vat_rate'] as num?)?.toDouble() ?? 20.0,
      minQuantity: (map['min_quantity'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}







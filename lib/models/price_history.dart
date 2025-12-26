class PriceHistory {
  final int? id;
  final int materialId;
  final int? supplierId;
  final double quantity; // Množstvo pri ktorej sa cena zmenila
  final double purchasePriceWithoutVat; // Nákupná cena bez DPH
  final double purchasePriceWithVat; // Nákupná cena s DPH
  final double? salePrice; // Predajná cena
  final double vatRate; // Sadzba DPH (napr. 20 pre 20%)
  final String priceDate; // Dátum zmeny ceny
  final String? documentNumber; // Číslo dokladu (faktúra, atď.)
  final String? notes;
  final int synced;
  final String createdAt;

  PriceHistory({
    this.id,
    required this.materialId,
    this.supplierId,
    required this.quantity,
    required this.purchasePriceWithoutVat,
    required this.purchasePriceWithVat,
    this.salePrice,
    this.vatRate = 20.0,
    required this.priceDate,
    this.documentNumber,
    this.notes,
    this.synced = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'supplier_id': supplierId,
      'quantity': quantity,
      'purchase_price_without_vat': purchasePriceWithoutVat,
      'purchase_price_with_vat': purchasePriceWithVat,
      'sale_price': salePrice,
      'vat_rate': vatRate,
      'price_date': priceDate,
      'document_number': documentNumber,
      'notes': notes,
      'synced': synced,
      'created_at': createdAt,
    };
  }

  factory PriceHistory.fromMap(Map<String, dynamic> map) {
    return PriceHistory(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      supplierId: map['supplier_id'] as int?,
      quantity: (map['quantity'] as num).toDouble(),
      purchasePriceWithoutVat: (map['purchase_price_without_vat'] as num).toDouble(),
      purchasePriceWithVat: (map['purchase_price_with_vat'] as num).toDouble(),
      salePrice: (map['sale_price'] as num?)?.toDouble(),
      vatRate: (map['vat_rate'] as num?)?.toDouble() ?? 20.0,
      priceDate: map['price_date'] as String,
      documentNumber: map['document_number'] as String?,
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
    );
  }
}







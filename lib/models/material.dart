class Material {
  final int? id;
  final String name;
  final String type; // cement, aggregate, water, plasticizer
  final String category; // warehouse, production, retail - kde sa používa materiál
  final String unit; // kg, m3, l
  final double currentStock;
  final double minStock;
  final String? pluCode; // PLU kód
  final String? eanCode; // EAN kód
  final double? averagePurchasePriceWithoutVat; // Vážený priemer nákupnej ceny bez DPH
  final double? averagePurchasePriceWithVat; // Vážený priemer nákupnej ceny s DPH
  final double? salePrice; // Predajná cena
  final double? vatRate; // Sadzba DPH
  final bool hasRecyclingFee; // Má recyklačný poplatok
  final double? recyclingFee; // Suma recyklačného poplatku
  final int? defaultSupplierId; // Predvolený dodávateľ
  final String? warehouseNumber; // Poradové číslo produktu na sklade
  final int synced;
  final String createdAt;
  final String updatedAt;

  Material({
    this.id,
    required this.name,
    required this.type,
    this.category = 'warehouse', // warehouse, production, retail
    required this.unit,
    this.currentStock = 0,
    this.minStock = 0,
    this.pluCode,
    this.eanCode,
    this.averagePurchasePriceWithoutVat,
    this.averagePurchasePriceWithVat,
    this.salePrice,
    this.vatRate = 20.0,
    this.hasRecyclingFee = false,
    this.recyclingFee,
    this.defaultSupplierId,
    this.warehouseNumber,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'category': category,
      'unit': unit,
      'current_stock': currentStock,
      'min_stock': minStock,
      'plu_code': pluCode,
      'ean_code': eanCode,
      'average_purchase_price_without_vat': averagePurchasePriceWithoutVat,
      'average_purchase_price_with_vat': averagePurchasePriceWithVat,
      'sale_price': salePrice,
      'vat_rate': vatRate,
      'has_recycling_fee': hasRecyclingFee ? 1 : 0,
      'recycling_fee': recyclingFee,
      'default_supplier_id': defaultSupplierId,
      'warehouse_number': warehouseNumber,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Material.fromMap(Map<String, dynamic> map) {
    return Material(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      category: map['category'] as String? ?? 'warehouse',
      unit: map['unit'] as String,
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      pluCode: map['plu_code'] as String?,
      eanCode: map['ean_code'] as String?,
      averagePurchasePriceWithoutVat: (map['average_purchase_price_without_vat'] as num?)?.toDouble(),
      averagePurchasePriceWithVat: (map['average_purchase_price_with_vat'] as num?)?.toDouble(),
      salePrice: (map['sale_price'] as num?)?.toDouble(),
      vatRate: (map['vat_rate'] as num?)?.toDouble() ?? 20.0,
      hasRecyclingFee: (map['has_recycling_fee'] as int?) == 1,
      recyclingFee: (map['recycling_fee'] as num?)?.toDouble(),
      defaultSupplierId: map['default_supplier_id'] as int?,
      warehouseNumber: map['warehouse_number'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Material copyWith({
    int? id,
    String? name,
    String? type,
    String? category,
    String? unit,
    double? currentStock,
    double? minStock,
    String? pluCode,
    String? eanCode,
    double? averagePurchasePriceWithoutVat,
    double? averagePurchasePriceWithVat,
    double? salePrice,
    double? vatRate,
    bool? hasRecyclingFee,
    double? recyclingFee,
    int? defaultSupplierId,
    String? warehouseNumber,
    int? synced,
    String? createdAt,
    String? updatedAt,
  }) {
    return Material(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category != null ? category : this.category,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      pluCode: pluCode ?? this.pluCode,
      eanCode: eanCode ?? this.eanCode,
      averagePurchasePriceWithoutVat: averagePurchasePriceWithoutVat ?? this.averagePurchasePriceWithoutVat,
      averagePurchasePriceWithVat: averagePurchasePriceWithVat ?? this.averagePurchasePriceWithVat,
      salePrice: salePrice ?? this.salePrice,
      vatRate: vatRate ?? this.vatRate,
      hasRecyclingFee: hasRecyclingFee ?? this.hasRecyclingFee,
      recyclingFee: recyclingFee ?? this.recyclingFee,
      defaultSupplierId: defaultSupplierId ?? this.defaultSupplierId,
      warehouseNumber: warehouseNumber ?? this.warehouseNumber,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


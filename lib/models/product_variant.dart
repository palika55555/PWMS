/// Model pre varianty produktu (farby, veľkosti, atď.)
class ProductVariant {
  final int? id;
  final int materialId; // ID základného materiálu
  final String variantType; // 'color', 'size', 'material', atď.
  final String variantValue; // 'červená', 'XL', atď.
  final String? variantCode; // Kód variantu
  final String? eanCode; // EAN kód pre variant
  final double? additionalPrice; // Príplatok k základnej cene
  final bool isActive;
  final int synced;
  final String createdAt;
  final String updatedAt;

  ProductVariant({
    this.id,
    required this.materialId,
    required this.variantType,
    required this.variantValue,
    this.variantCode,
    this.eanCode,
    this.additionalPrice,
    this.isActive = true,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'variant_type': variantType,
      'variant_value': variantValue,
      'variant_code': variantCode,
      'ean_code': eanCode,
      'additional_price': additionalPrice,
      'is_active': isActive ? 1 : 0,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      variantType: map['variant_type'] as String,
      variantValue: map['variant_value'] as String,
      variantCode: map['variant_code'] as String?,
      eanCode: map['ean_code'] as String?,
      additionalPrice: (map['additional_price'] as num?)?.toDouble(),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}








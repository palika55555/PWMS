class Recipe {
  final int? id;
  final String name;
  final String productType; // tvarnice, dlazba, etc.
  final String? description;
  final double cementAmount;
  final double waterAmount;
  final double? plasticizerAmount;
  final double? wcRatio; // water/cement ratio
  final double? mixerCapacity; // Kapacita miešačky v litroch
  final int? productsPerMixer; // Počet produktov z jednej miešačky
  final int synced;
  final String createdAt;
  final String updatedAt;

  Recipe({
    this.id,
    required this.name,
    required this.productType,
    this.description,
    required this.cementAmount,
    required this.waterAmount,
    this.plasticizerAmount,
    this.wcRatio,
    this.mixerCapacity,
    this.productsPerMixer,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'product_type': productType,
      'description': description,
      'cement_amount': cementAmount,
      'water_amount': waterAmount,
      'plasticizer_amount': plasticizerAmount,
      'wc_ratio': wcRatio,
      'mixer_capacity': mixerCapacity,
      'products_per_mixer': productsPerMixer,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as int?,
      name: map['name'] as String,
      productType: map['product_type'] as String,
      description: map['description'] as String?,
      cementAmount: (map['cement_amount'] as num).toDouble(),
      waterAmount: (map['water_amount'] as num).toDouble(),
      plasticizerAmount: (map['plasticizer_amount'] as num?)?.toDouble(),
      wcRatio: (map['wc_ratio'] as num?)?.toDouble(),
      mixerCapacity: (map['mixer_capacity'] as num?)?.toDouble(),
      productsPerMixer: map['products_per_mixer'] as int?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}


/// Model pre prepočty medzi rôznymi mernými jednotkami
class UnitConversion {
  final int? id;
  final int materialId;
  final String fromUnit; // Zdrojová jednotka
  final String toUnit; // Cieľová jednotka
  final double conversionFactor; // Konverzný faktor (napr. 1 paleta = 20 kartónov)
  final bool isDefault; // Je toto predvolená konverzia
  final int synced;
  final String createdAt;
  final String updatedAt;

  UnitConversion({
    this.id,
    required this.materialId,
    required this.fromUnit,
    required this.toUnit,
    required this.conversionFactor,
    this.isDefault = false,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'from_unit': fromUnit,
      'to_unit': toUnit,
      'conversion_factor': conversionFactor,
      'is_default': isDefault ? 1 : 0,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory UnitConversion.fromMap(Map<String, dynamic> map) {
    return UnitConversion(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      fromUnit: map['from_unit'] as String,
      toUnit: map['to_unit'] as String,
      conversionFactor: (map['conversion_factor'] as num).toDouble(),
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// Prepočíta množstvo z fromUnit na toUnit
  double convert(double quantity) {
    return quantity * conversionFactor;
  }

  /// Prepočíta množstvo z toUnit na fromUnit
  double convertReverse(double quantity) {
    return quantity / conversionFactor;
  }
}







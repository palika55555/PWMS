/// Model pre príslušenstvo a alternatívy produktov
class ProductAccessory {
  final int? id;
  final int materialId; // ID hlavného produktu
  final int accessoryMaterialId; // ID príslušenstva/alternatívy
  final String relationType; // 'accessory', 'alternative', 'complement', 'replacement'
  final int? quantity; // Množstvo príslušenstva (napr. 2 kusy)
  final String? notes;
  final int synced;
  final String createdAt;
  final String updatedAt;

  ProductAccessory({
    this.id,
    required this.materialId,
    required this.accessoryMaterialId,
    required this.relationType,
    this.quantity,
    this.notes,
    this.synced = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'accessory_material_id': accessoryMaterialId,
      'relation_type': relationType,
      'quantity': quantity,
      'notes': notes,
      'synced': synced,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ProductAccessory.fromMap(Map<String, dynamic> map) {
    return ProductAccessory(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      accessoryMaterialId: map['accessory_material_id'] as int,
      relationType: map['relation_type'] as String,
      quantity: map['quantity'] as int?,
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}








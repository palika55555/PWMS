/// Model pre automatické generovanie objednávok
class AutoOrder {
  final int? id;
  final int materialId;
  final int supplierId;
  final double suggestedQuantity; // Navrhované množstvo
  final double currentStock; // Aktuálny stav v čase generovania
  final double minStock; // Minimálny stav
  final double maxStock; // Maximálny stav
  final String reason; // Dôvod generovania ('low_stock', 'below_min', atď.)
  final String status; // 'pending', 'approved', 'rejected', 'ordered'
  final String? notes;
  final int synced;
  final String createdAt;
  final String? orderedAt; // Dátum objednania

  AutoOrder({
    this.id,
    required this.materialId,
    required this.supplierId,
    required this.suggestedQuantity,
    required this.currentStock,
    required this.minStock,
    this.maxStock = 0,
    required this.reason,
    this.status = 'pending',
    this.notes,
    this.synced = 0,
    required this.createdAt,
    this.orderedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_id': materialId,
      'supplier_id': supplierId,
      'suggested_quantity': suggestedQuantity,
      'current_stock': currentStock,
      'min_stock': minStock,
      'max_stock': maxStock,
      'reason': reason,
      'status': status,
      'notes': notes,
      'synced': synced,
      'created_at': createdAt,
      'ordered_at': orderedAt,
    };
  }

  factory AutoOrder.fromMap(Map<String, dynamic> map) {
    return AutoOrder(
      id: map['id'] as int?,
      materialId: map['material_id'] as int,
      supplierId: map['supplier_id'] as int,
      suggestedQuantity: (map['suggested_quantity'] as num).toDouble(),
      currentStock: (map['current_stock'] as num).toDouble(),
      minStock: (map['min_stock'] as num).toDouble(),
      maxStock: (map['max_stock'] as num?)?.toDouble() ?? 0,
      reason: map['reason'] as String,
      status: map['status'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      orderedAt: map['ordered_at'] as String?,
    );
  }
}







/// Model pre skladové uzávierky
class WarehouseClosing {
  final int? id;
  final String closingDate; // Dátum uzávierky
  final String periodFrom; // Obdobie od
  final String periodTo; // Obdobie do
  final String status; // 'open', 'closed', 'cancelled'
  final String? notes;
  final String createdBy;
  final int synced;
  final String createdAt;
  final String? closedAt; // Dátum uzavretia

  WarehouseClosing({
    this.id,
    required this.closingDate,
    required this.periodFrom,
    required this.periodTo,
    this.status = 'open',
    this.notes,
    required this.createdBy,
    this.synced = 0,
    required this.createdAt,
    this.closedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'closing_date': closingDate,
      'period_from': periodFrom,
      'period_to': periodTo,
      'status': status,
      'notes': notes,
      'created_by': createdBy,
      'synced': synced,
      'created_at': createdAt,
      'closed_at': closedAt,
    };
  }

  factory WarehouseClosing.fromMap(Map<String, dynamic> map) {
    return WarehouseClosing(
      id: map['id'] as int?,
      closingDate: map['closing_date'] as String,
      periodFrom: map['period_from'] as String,
      periodTo: map['period_to'] as String,
      status: map['status'] as String? ?? 'open',
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
      closedAt: map['closed_at'] as String?,
    );
  }
}








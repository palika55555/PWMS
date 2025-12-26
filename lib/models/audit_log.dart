/// Model pre audit log - sledovanie zmien v systéme
class AuditLog {
  final int? id;
  final String entityType; // 'material', 'batch', 'stock_movement', atď.
  final int? entityId; // ID entity
  final String action; // 'create', 'update', 'delete', 'view'
  final String? oldValue; // JSON string s predchádzajúcimi hodnotami
  final String? newValue; // JSON string s novými hodnotami
  final String userId; // ID používateľa
  final String userName; // Meno používateľa
  final String? ipAddress; // IP adresa
  final String? userAgent; // User agent
  final String? notes; // Poznámky
  final int synced;
  final String createdAt;

  AuditLog({
    this.id,
    required this.entityType,
    this.entityId,
    required this.action,
    this.oldValue,
    this.newValue,
    required this.userId,
    required this.userName,
    this.ipAddress,
    this.userAgent,
    this.notes,
    this.synced = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'old_value': oldValue,
      'new_value': newValue,
      'user_id': userId,
      'user_name': userName,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'notes': notes,
      'synced': synced,
      'created_at': createdAt,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as int?,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as int?,
      action: map['action'] as String,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      ipAddress: map['ip_address'] as String?,
      userAgent: map['user_agent'] as String?,
      notes: map['notes'] as String?,
      synced: map['synced'] as int? ?? 0,
      createdAt: map['created_at'] as String,
    );
  }
}







class Notification {
  final String id;
  final String type; // low_stock, maintenance_due, quality_issue, etc.
  final String title;
  final String message;
  final String severity; // info, warning, critical
  final bool read;
  final DateTime? createdAt;
  final String? relatedId; // ID related entity (material_id, batch_id, etc.)
  final bool synced;

  Notification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.severity = 'info',
    this.read = false,
    this.createdAt,
    this.relatedId,
    this.synced = false,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      severity: json['severity'] as String? ?? 'info',
      read: json['read'] == 1 || json['read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      relatedId: json['related_id'] as String?,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'severity': severity,
      'read': read ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'related_id': relatedId,
      'synced': synced ? 1 : 0,
    };
  }

  Notification copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    String? severity,
    bool? read,
    DateTime? createdAt,
    String? relatedId,
    bool? synced,
  }) {
    return Notification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      relatedId: relatedId ?? this.relatedId,
      synced: synced ?? this.synced,
    );
  }
}


class Machine {
  final String id;
  final String name;
  final String? type;
  final String status; // operational, maintenance, breakdown
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final String? notes;
  final DateTime? createdAt;
  final bool synced;

  Machine({
    required this.id,
    required this.name,
    this.type,
    this.status = 'operational',
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.notes,
    this.createdAt,
    this.synced = false,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      status: json['status'] as String? ?? 'operational',
      lastMaintenanceDate: json['last_maintenance_date'] != null
          ? DateTime.parse(json['last_maintenance_date'])
          : null,
      nextMaintenanceDate: json['next_maintenance_date'] != null
          ? DateTime.parse(json['next_maintenance_date'])
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'status': status,
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
      'next_maintenance_date': nextMaintenanceDate?.toIso8601String(),
      'notes': notes,
      'synced': synced ? 1 : 0,
    };
  }

  Machine copyWith({
    String? id,
    String? name,
    String? type,
    String? status,
    DateTime? lastMaintenanceDate,
    DateTime? nextMaintenanceDate,
    String? notes,
    DateTime? createdAt,
    bool? synced,
  }) {
    return Machine(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }
}

class MachineMaintenance {
  final String id;
  final String machineId;
  final String? machineName;
  final String maintenanceType; // planned, unplanned
  final String? description;
  final DateTime? performedAt;
  final String? performedBy;
  final int? durationMinutes;
  final double? cost;
  final bool synced;

  MachineMaintenance({
    required this.id,
    required this.machineId,
    this.machineName,
    required this.maintenanceType,
    this.description,
    this.performedAt,
    this.performedBy,
    this.durationMinutes,
    this.cost,
    this.synced = false,
  });

  factory MachineMaintenance.fromJson(Map<String, dynamic> json) {
    return MachineMaintenance(
      id: json['id'] as String,
      machineId: json['machine_id'] as String,
      machineName: json['machine_name'] as String?,
      maintenanceType: json['maintenance_type'] as String,
      description: json['description'] as String?,
      performedAt: json['performed_at'] != null
          ? DateTime.parse(json['performed_at'])
          : null,
      performedBy: json['performed_by'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'machine_id': machineId,
      'maintenance_type': maintenanceType,
      'description': description,
      'performed_at': performedAt?.toIso8601String(),
      'performed_by': performedBy,
      'duration_minutes': durationMinutes,
      'cost': cost,
      'synced': synced ? 1 : 0,
    };
  }
}


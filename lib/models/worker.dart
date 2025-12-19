class Worker {
  final String id;
  final String name;
  final String? position;
  final String? shift; // morning, afternoon, night
  final bool active;
  final DateTime? createdAt;
  final bool synced;

  Worker({
    required this.id,
    required this.name,
    this.position,
    this.shift,
    this.active = true,
    this.createdAt,
    this.synced = false,
  });

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String?,
      shift: json['shift'] as String?,
      active: json['active'] == 1 || json['active'] == true,
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
      'position': position,
      'shift': shift,
      'active': active ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  Worker copyWith({
    String? id,
    String? name,
    String? position,
    String? shift,
    bool? active,
    DateTime? createdAt,
    bool? synced,
  }) {
    return Worker(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      shift: shift ?? this.shift,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }
}

class ProductionAssignment {
  final String id;
  final String productionId;
  final String workerId;
  final String? workerName;
  final String? shift;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool synced;

  ProductionAssignment({
    required this.id,
    required this.productionId,
    required this.workerId,
    this.workerName,
    this.shift,
    this.startTime,
    this.endTime,
    this.synced = false,
  });

  factory ProductionAssignment.fromJson(Map<String, dynamic> json) {
    return ProductionAssignment(
      id: json['id'] as String,
      productionId: json['production_id'] as String,
      workerId: json['worker_id'] as String,
      workerName: json['worker_name'] as String?,
      shift: json['shift'] as String?,
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : null,
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'])
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'production_id': productionId,
      'worker_id': workerId,
      'shift': shift,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }
}


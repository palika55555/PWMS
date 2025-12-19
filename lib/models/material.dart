class Material {
  final String id;
  final String name;
  final String unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool synced;

  Material({
    required this.id,
    required this.name,
    required this.unit,
    this.createdAt,
    this.updatedAt,
    this.synced = false,
  });

  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  Material copyWith({
    String? id,
    String? name,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return Material(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}

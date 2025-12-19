class ProductionType {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;
  final bool synced;

  ProductionType({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.synced = false,
  });

  factory ProductionType.fromJson(Map<String, dynamic> json) {
    return ProductionType(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
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
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  ProductionType copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    bool? synced,
  }) {
    return ProductionType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }
}


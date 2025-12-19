class ProductionPlan {
  final String id;
  final String productionTypeId;
  final String? productionTypeName;
  final double plannedQuantity;
  final DateTime plannedDate;
  final String priority; // urgent, normal, low
  final String status; // planned, in_progress, completed, cancelled
  final String? assignedRecipeId;
  final String? assignedRecipeName;
  final String? notes;
  final DateTime? createdAt;
  final bool synced;

  ProductionPlan({
    required this.id,
    required this.productionTypeId,
    this.productionTypeName,
    required this.plannedQuantity,
    required this.plannedDate,
    this.priority = 'normal',
    this.status = 'planned',
    this.assignedRecipeId,
    this.assignedRecipeName,
    this.notes,
    this.createdAt,
    this.synced = false,
  });

  factory ProductionPlan.fromJson(Map<String, dynamic> json) {
    return ProductionPlan(
      id: json['id'] as String,
      productionTypeId: json['production_type_id'] as String,
      productionTypeName: json['production_type_name'] as String?,
      plannedQuantity: (json['planned_quantity'] as num).toDouble(),
      plannedDate: DateTime.parse(json['planned_date']),
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'planned',
      assignedRecipeId: json['assigned_recipe_id'] as String?,
      assignedRecipeName: json['assigned_recipe_name'] as String?,
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
      'production_type_id': productionTypeId,
      'planned_quantity': plannedQuantity,
      'planned_date': plannedDate.toIso8601String().split('T')[0],
      'priority': priority,
      'status': status,
      'assigned_recipe_id': assignedRecipeId,
      'notes': notes,
      'synced': synced ? 1 : 0,
    };
  }

  ProductionPlan copyWith({
    String? id,
    String? productionTypeId,
    String? productionTypeName,
    double? plannedQuantity,
    DateTime? plannedDate,
    String? priority,
    String? status,
    String? assignedRecipeId,
    String? assignedRecipeName,
    String? notes,
    DateTime? createdAt,
    bool? synced,
  }) {
    return ProductionPlan(
      id: id ?? this.id,
      productionTypeId: productionTypeId ?? this.productionTypeId,
      productionTypeName: productionTypeName ?? this.productionTypeName,
      plannedQuantity: plannedQuantity ?? this.plannedQuantity,
      plannedDate: plannedDate ?? this.plannedDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedRecipeId: assignedRecipeId ?? this.assignedRecipeId,
      assignedRecipeName: assignedRecipeName ?? this.assignedRecipeName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }
}


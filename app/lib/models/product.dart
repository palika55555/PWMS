class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.active,
  });

  final String id;
  final String name;
  final String? description;
  final bool active;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      active: (json['active'] as bool?) ?? true,
    );
  }
}



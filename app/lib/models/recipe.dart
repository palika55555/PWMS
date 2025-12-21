class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.productId,
    required this.productName,
  });

  final String id;
  final String name;
  final String? productId;
  final String? productName;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
    );
  }
}



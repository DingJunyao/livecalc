class IngredientCategory {
  final int id;
  final String name;
  final String displayName;
  final String? description;

  const IngredientCategory({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
  });

  factory IngredientCategory.fromJson(Map<String, dynamic> json) {
    return IngredientCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ??
          json['name'] as String? ??
          '',
      description: json['description'] as String?,
    );
  }
}

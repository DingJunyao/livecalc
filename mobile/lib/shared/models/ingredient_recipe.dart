double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class RecipeUsage {
  final double quantity;
  final String? unit;
  final double? originalQuantity;

  const RecipeUsage({
    this.quantity = 0,
    this.unit,
    this.originalQuantity,
  });

  factory RecipeUsage.fromJson(Map<String, dynamic> json) {
    return RecipeUsage(
      quantity: _toDouble(json['quantity']) ?? 0,
      unit: json['unit'] as String?,
      originalQuantity: _toDouble(json['original_quantity']),
    );
  }

  String get display {
    final q = originalQuantity ?? quantity;
    final qs = q == q.truncateToDouble()
        ? q.toInt().toString()
        : q.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
    return '$qs${(unit?.isNotEmpty ?? false) ? ' $unit' : ''}';
  }
}

/// 包含指定原料的菜谱（GET /nutrition/ingredients/{id}/recipes）。
class IngredientRecipeRef {
  final int id;
  final String name;
  final String? category;
  final String? difficulty;
  final int servings;
  final int? totalTimeMinutes;
  final List<String> tags;
  final List<RecipeUsage> usages;

  const IngredientRecipeRef({
    required this.id,
    required this.name,
    this.category,
    this.difficulty,
    this.servings = 1,
    this.totalTimeMinutes,
    this.tags = const [],
    this.usages = const [],
  });

  factory IngredientRecipeRef.fromJson(Map<String, dynamic> json) {
    return IngredientRecipeRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      difficulty: json['difficulty'] as String?,
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      totalTimeMinutes:
          (json['total_time_minutes'] as num?)?.toInt(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      usages: ((json['usages'] as List?) ?? const [])
          .map((e) => RecipeUsage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

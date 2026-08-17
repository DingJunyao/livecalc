import '../../features/recipes/models/recipe_detail.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// 数字格式化：整数不带小数点，小数去掉多余 0
String _fmtNum(double v) => v == v.truncateToDouble()
    ? v.toInt().toString()
    : v
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

class RecipeUsage {
  final double quantity;
  final QuantityRange? quantityRange;
  final String? unit;
  final String? originalQuantity;

  const RecipeUsage({
    this.quantity = 0,
    this.quantityRange,
    this.unit,
    this.originalQuantity,
  });

  factory RecipeUsage.fromJson(Map<String, dynamic> json) {
    return RecipeUsage(
      quantity: _toDouble(json['quantity']) ?? 0,
      quantityRange: json['quantity_range'] != null
          ? QuantityRange.fromJson(json['quantity_range'])
          : null,
      unit: json['unit'] as String?,
      originalQuantity: json['original_quantity'] as String?,
    );
  }

  /// 单条用量文本，对齐 Web IngredientDetail.formatUsageText：
  /// 区间+精确 →「100~200 g（推荐 150 g）」；仅精确 →「150 g」；
  /// 仅区间 →「100~200 g」；模糊量（适量/少许）原样；无 →「-」
  String get display {
    final hasQty = quantity > 0;
    final range = quantityRange;
    final hasRange = range != null && (range.min > 0 || range.max > 0);
    final unitText = (unit?.isNotEmpty ?? false) ? ' $unit' : '';
    if (hasQty && hasRange) {
      return '${_fmtNum(range.min)}~${_fmtNum(range.max)}$unitText'
          '（推荐 ${_fmtNum(quantity)}$unitText）';
    }
    if (hasQty) return '${_fmtNum(quantity)}$unitText';
    if (hasRange) {
      return '${_fmtNum(range.min)}~${_fmtNum(range.max)}$unitText';
    }
    if (originalQuantity != null && originalQuantity!.isNotEmpty) {
      return originalQuantity!;
    }
    return '-';
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
      totalTimeMinutes: (json['total_time_minutes'] as num?)?.toInt(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      usages: ((json['usages'] as List?) ?? const [])
          .map((e) => RecipeUsage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

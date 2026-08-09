import '../../features/recipes/utils/nutrition_labels.dart';

/// 单个营养素条目（键已由后端转为中文展示名）。
class NutrientEntry {
  final String key;
  final String label;
  final double value;
  final String unit;
  final double? nrvPct;
  final String? originalKey;

  const NutrientEntry({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
    this.nrvPct,
    this.originalKey,
  });

  factory NutrientEntry.fromJson(String key, dynamic json) {
    if (json is! Map) {
      return NutrientEntry(key: key, label: key, value: 0, unit: '');
    }
    return NutrientEntry(
      key: key,
      label: (json['display_name'] as String?) ??
          (json['name'] as String?) ??
          key,
      value: _toDouble(json['value']) ?? 0,
      unit: json['unit'] as String? ?? '',
      nrvPct: _toDouble(json['nrp_pct']),
      originalKey: json['original_key'] as String?,
    );
  }
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// 原料/商品营养数据（每 100g 基准）。
class NutritionInfo {
  final int entityId;
  final String? entityName;
  final double baseQuantity;
  final String baseUnit;
  final String? source;
  final List<NutrientEntry> nutrients;

  const NutritionInfo({
    required this.entityId,
    this.entityName,
    this.baseQuantity = 100,
    this.baseUnit = 'g',
    this.source,
    this.nutrients = const [],
  });

  bool get hasData => nutrients.isNotEmpty;

  /// 从 GET /nutrition/... 响应解析（ingredient/product 结构一致：
  /// nutrition.core_nutrients / nutrition.all_nutrients）。
  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    final nutrition = (json['nutrition'] is Map)
        ? json['nutrition'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final core = (nutrition['core_nutrients'] is Map)
        ? nutrition['core_nutrients'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final all = (nutrition['all_nutrients'] is Map)
        ? nutrition['all_nutrients'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final entries = <NutrientEntry>[];
    final seen = <String>{};
    // 核心营养素按展示顺序排前
    for (final key in defaultNutrientKeys) {
      final data = core[key] ?? all[key];
      if (data == null) continue;
      seen.add(key);
      entries.add(NutrientEntry.fromJson(key, data));
    }
    final restKeys = all.keys.where((k) => !seen.contains(k)).toList()
      ..sort(compareNutrients);
    for (final key in restKeys) {
      final data = all[key];
      if (data is! Map || data['value'] == null) continue;
      entries.add(NutrientEntry.fromJson(key, data));
    }

    return NutritionInfo(
      entityId: (json['ingredient_id'] ?? json['product_id'] ?? 0) as int,
      entityName: json['ingredient_name'] as String? ??
          json['product_name'] as String?,
      baseQuantity: _toDouble(json['base_quantity']) ?? 100,
      baseUnit: json['base_unit'] as String? ?? json['unit'] as String? ?? 'g',
      source: json['source'] as String?,
      nutrients: entries,
    );
  }
}

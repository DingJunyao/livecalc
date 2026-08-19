import '../../features/recipes/utils/nutrition_labels.dart';
import 'entity_pending_proposal.dart';

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
      label:
          (json['display_name'] as String?) ?? (json['name'] as String?) ?? key,
      value: _toDouble(json['value']) ?? 0,
      unit: json['unit'] as String? ?? '',
      nrvPct: _toDouble(json['nrp_pct']),
      originalKey: (json['original_key'] ?? json['key']) as String?,
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
  final EntityPendingProposal? pendingProposal;

  const NutritionInfo({
    required this.entityId,
    this.entityName,
    this.baseQuantity = 100,
    this.baseUnit = 'g',
    this.source,
    this.nutrients = const [],
    this.pendingProposal,
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

    return NutritionInfo(
      entityId: (json['ingredient_id'] ?? json['product_id'] ?? 0) as int,
      entityName:
          json['ingredient_name'] as String? ?? json['product_name'] as String?,
      baseQuantity: _toDouble(json['base_quantity']) ?? 100,
      baseUnit: json['base_unit'] as String? ?? json['unit'] as String? ?? 'g',
      source: json['source'] as String?,
      nutrients: _parseNutrients(core, all),
      pendingProposal: json['pending_proposal'] is Map<String, dynamic>
          ? EntityPendingProposal.fromJson(
              json['pending_proposal'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Builds a proposer's manual draft when no official nutrition table exists.
  factory NutritionInfo.fromPendingProposal({
    required int entityId,
    required EntityPendingProposal proposal,
  }) {
    if (proposal.action != 'update') {
      return NutritionInfo(
        entityId: entityId,
        pendingProposal: proposal,
      );
    }
    final data = proposal.updateData;
    final custom = _pendingNutritionData(data);
    return NutritionInfo(
      entityId: entityId,
      baseQuantity: _toDouble(data['base_quantity']) ?? 100,
      baseUnit: data['base_unit']?.toString() ?? 'g',
      source: data['custom_nutrition_source']?.toString() ??
          data['source']?.toString(),
      nutrients: _parseNutrients(
        _stringKeyMap(custom['core_nutrients']),
        _stringKeyMap(custom['all_nutrients']),
      ),
      pendingProposal: proposal,
    );
  }

  NutritionInfo mergedWithPending() {
    final proposal = pendingProposal;
    if (proposal?.action != 'update') return this;
    final data = proposal!.updateData;
    final custom = _pendingNutritionData(data);
    if (custom.isEmpty) return this;
    return NutritionInfo(
      entityId: entityId,
      entityName: entityName,
      baseQuantity: _toDouble(data['base_quantity']) ?? baseQuantity,
      baseUnit: data['base_unit']?.toString() ?? baseUnit,
      source: data.containsKey('custom_nutrition_source')
          ? data['custom_nutrition_source']?.toString()
          : data['source']?.toString() ?? source,
      nutrients: _parseNutrients(
        _stringKeyMap(custom['core_nutrients']),
        _stringKeyMap(custom['all_nutrients']),
      ),
      pendingProposal: proposal,
    );
  }

  static Map<String, dynamic> _pendingNutritionData(
    Map<String, dynamic> payload,
  ) {
    final custom = payload['custom_nutrition_data'] ?? payload['nutrients'];
    return custom is Map ? _stringKeyMap(custom) : const {};
  }

  static Map<String, dynamic> _stringKeyMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<NutrientEntry> _parseNutrients(
    Map<String, dynamic> core,
    Map<String, dynamic> all,
  ) {
    final entries = <NutrientEntry>[];
    final seen = <String>{};
    for (final key in defaultNutrientKeys) {
      final data = core[key] ?? all[key];
      if (data == null) continue;
      seen.add(key);
      final entry = NutrientEntry.fromJson(key, data);
      final originalKey = entry.originalKey;
      if (originalKey != null && originalKey.isNotEmpty) seen.add(originalKey);
      entries.add(entry);
    }
    final restKeys = all.keys.where((k) => !seen.contains(k)).toList()
      ..sort(compareNutrients);
    for (final key in restKeys) {
      final data = all[key];
      if (data is! Map || data['value'] == null) continue;
      entries.add(NutrientEntry.fromJson(key, data));
    }
    return entries;
  }
}

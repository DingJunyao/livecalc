// 营养基准（「每 X 单位」）的纯函数：默认行、单位候选、可折算判定。
//
// 无网络依赖，取数部分见 `entity_unit_names.dart` 的 loadNutritionBasisUnitNames。
// 与 web 端 `frontend/src/utils/nutritionBasis.ts` 同口径：
//   - 默认基准 100 g；新建时预填能量 kJ / 蛋白质 / 脂肪 / 碳水化合物 / 钠 mg；
//   - 基准单位可以是全局质量/体积单位，也可以是本实体**可折算**的自定义单位
//     （如「1 袋 = 250 g」）。折算不出来的单位不列出：后端缩放会退化成
//     「按克」口径，让用户选它等于埋雷。

/// 默认基准：每 100 g。
const double kDefaultNutritionBasisAmount = 100;
const String kDefaultNutritionBasisUnit = 'g';

/// 新建营养时预填的营养素（营养成分表常见五项）。
const List<String> kDefaultNutrientLabels = [
  '能量',
  '蛋白质',
  '脂肪',
  '碳水化合物',
  '钠',
];

/// 预填行的固定默认单位（**能量不在其中** —— 它跟随用户能量单位偏好，
/// 见 [defaultNutrientUnit]）。
const Map<String, String> kDefaultNutrientUnits = {
  '蛋白质': 'g',
  '脂肪': 'g',
  '碳水化合物': 'g',
  '钠': 'mg',
};

/// 能量单位偏好归一化：只认 kJ（大小写不敏感），其余（null/未知）回退 kcal
/// —— 与两端 useUserUnits / authProvider.unitPreferences 的回退一致。
String normalizeEnergyUnit(String? raw) =>
    (raw ?? '').trim().toLowerCase() == 'kj' ? 'kJ' : 'kcal';

/// 新建默认行的单位：能量跟随用户能量单位偏好（kcal | kJ，缺省 kcal），
/// 钠 mg，其余 g。返回值一定在对应营养素的可选单位列表里
/// （能量的可选单位是 ['kcal', 'kJ']）。
String defaultNutrientUnit(String label, {String? energyUnit}) {
  if (label == '能量') {
    return normalizeEnergyUnit(energyUnit);
  }
  return kDefaultNutrientUnits[label] ?? 'g';
}

/// 营养基准（「每 X 单位」）。
class NutritionBasis {
  final double amount;
  final String unit;

  const NutritionBasis({
    this.amount = kDefaultNutritionBasisAmount,
    this.unit = kDefaultNutritionBasisUnit,
  });

  static NutritionBasis fromJson(Map? json) => readNutritionBasisFromJson(json);

  @override
  bool operator ==(Object other) =>
      other is NutritionBasis && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);

  @override
  String toString() => '${formatBasisAmount(amount)}$unit';
}

/// 基准量归一化：正数直接用，其余回落到 100。
double normalizeBasisAmount(Object? raw) {
  final value = switch (raw) {
    num v => v.toDouble(),
    String v => double.tryParse(v.trim()),
    _ => null,
  };
  if (value == null || !value.isFinite || value <= 0) {
    return kDefaultNutritionBasisAmount;
  }
  return value;
}

/// 基准单位归一化：空值回落到 g。
String normalizeBasisUnit(Object? raw) {
  final unit = (raw ?? '').toString().trim();
  return unit.isEmpty ? kDefaultNutritionBasisUnit : unit;
}

/// 基准量展示：去掉多余小数位（100 / 2.5）。
String formatBasisAmount(Object? raw) {
  final value = normalizeBasisAmount(raw);
  if (value == value.roundToDouble()) return value.toInt().toString();
  final rounded = (value * 1000).round() / 1000;
  return rounded.toString();
}

/// 从营养响应里读基准：reference_amount/reference_unit 优先（原料与商品的统一
/// 字段），其次商品自定义数据里的同名字段，再退到 base_quantity/base_unit，
/// 最后 100 g。
NutritionBasis readNutritionBasisFromJson(Map? json) {
  final root = json ?? const {};
  final customRaw = root['custom_nutrition_data'] ?? root['nutrients'];
  final custom = customRaw is Map ? customRaw : const {};
  final amount = root['reference_amount'] ??
      custom['reference_amount'] ??
      root['base_quantity'];
  final unit =
      root['reference_unit'] ?? custom['reference_unit'] ?? root['base_unit'];
  return NutritionBasis(
    amount: normalizeBasisAmount(amount),
    unit: normalizeBasisUnit(unit),
  );
}

const int _maxOverrideChainDepth = 8;

bool _isResolvableRow(
  Map row,
  Map<int, Map> rowsById,
  Map<int, String> unitTypeById, {
  int depth = 0,
  Set<int>? seen,
}) {
  if (depth > _maxOverrideChainDepth) return false;
  final visited = seen ?? <int>{};
  final id = _asInt(row['id']);
  if (id != null) {
    if (visited.contains(id)) return false;
    visited.add(id);
  }

  final refId = _asInt(row['weight_unit_override_id']);
  if (refId != null) {
    final ref = rowsById[refId];
    if (ref != null &&
        _asInt(ref['id']) != id &&
        _isResolvableRow(ref, rowsById, unitTypeById,
            depth: depth + 1, seen: visited)) {
      // 嵌套行自身的 weight_per_unit 缺省按 1（后端口径），不阻塞
      return true;
    }
    // 引用悬空/不可解析：只有本行另有 weight_per_unit 时后端才退化到全局单位路径
    return _asDouble(row['weight_per_unit']) != null;
  }

  if (_asDouble(row['weight_per_unit']) == null) return false;
  final weightUnitId = _asInt(row['weight_unit_id']);
  if (weightUnitId != null) {
    final type = unitTypeById[weightUnitId];
    // 量纲必须是质量或体积；未知的全局单位（列表没拉到）不臆断
    if (type != null && type != 'mass' && type != 'volume') return false;
  }
  return true;
}

/// 可作营养基准的自定义单位名（已过滤折算不出来的行，保持传入顺序、按名去重）。
List<String> resolvableBasisUnitNames(
  List<Map> rows,
  List<Map> globalUnits,
) {
  final rowsById = <int, Map>{};
  final unitTypeById = <int, String>{};
  for (final row in rows) {
    final id = _asInt(row['id']);
    if (id != null) rowsById[id] = row;
  }
  for (final unit in globalUnits) {
    final id = _asInt(unit['id']);
    if (id != null) unitTypeById[id] = (unit['unit_type'] ?? '').toString();
  }

  final names = <String>[];
  for (final row in rows) {
    final name = (row['unit_name'] ?? row['name'] ?? '').toString().trim();
    if (name.isEmpty || names.contains(name)) continue;
    if (!_isResolvableRow(row, rowsById, unitTypeById)) continue;
    names.add(name);
  }
  return names;
}

/// 基准单位候选：自定义单位在前，全局单位在后，按名去重（自定义优先）。
List<String> mergeBasisUnitOptions(
  List<String> globalUnits,
  List<String> customNames,
) {
  final options = <String>[];
  for (final name in [...customNames, ...globalUnits]) {
    final value = name.trim();
    if (value.isEmpty || options.contains(value)) continue;
    options.add(value);
  }
  return options;
}

/// 把「当前值」补进候选（数据里的基准单位可能已不在候选里，仍需原样回显）。
List<String> withCurrentBasisUnit(List<String> options, String current) {
  final unit = normalizeBasisUnit(current);
  if (options.contains(unit)) return List<String>.of(options);
  return [unit, ...options];
}

int? _asInt(Object? value) => switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };

double? _asDouble(Object? value) => switch (value) {
      num v => v.toDouble(),
      String v => double.tryParse(v.trim()),
      _ => null,
    };

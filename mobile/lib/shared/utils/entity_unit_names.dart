import 'dart:developer';

import '../../core/api/api_client.dart';
import 'nutrition_basis.dart';

/// 实体自定义单位 / 全局单位的可注入请求缝（测试用）。
///
/// 传入形如 `/entities/product/42/units` 的路径，返回**已解码**的响应体
/// （`List`，或 `{items: [...]}` 包裹）。缺省实现走 [ApiClient]。
typedef EntityUnitsRequest = Future<Object?> Function(String path);

/// 价格记录单位下拉用的「实体自定义单位名」。
///
/// 与后端 `UnitConversionService.get_entity_override` 的优先级链一致：
///   商品自身覆盖 > 商品关联原料的覆盖 > 全局单位
/// 所以选了商品（或带着商品进编辑页）时，下拉除了全局单位，还要带上该商品
/// 及其关联原料的自定义单位（如「桶」「箱」），否则自定义单位记的价格记录
/// 没法再选同一个单位。返回顺序即展示顺序（商品自己的在前），已去重。
///
/// 行解析与 web 端 `frontend/src/utils/entityUnits.ts` 同口径：
/// 名字取 `unit_name ?? name`，并跳过显式停用（`is_active == false`）的行。
Future<List<String>> loadEntityUnitNames({
  required String entityType,
  required int entityId,
  int? ingredientId,
  ApiClient? client,
  EntityUnitsRequest? request,
  bool includeLinkUnits = false,
}) async {
  final fetch = request ?? _apiGet(client);
  final names = <String>[];

  Future<void> collect(String type, int id) async {
    final path = '/entities/$type/$id/units';
    final Object? data;
    try {
      data = await fetch(path);
    } catch (error, stackTrace) {
      // 只吞「请求失败」这一种，且留痕：原来 catch (_) 静默吞掉所有异常，
      // 线上表现为「下拉里少了自定义单位」却完全无从排查。
      log(
        'loadEntityUnitNames: GET $path 失败',
        name: 'entity_unit_names',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    for (final row in _rowsOf(data)) {
      if (_isInactive(row)) continue;
      final name = _unitNameOf(row);
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
  }

  Future<void> collectLinkUnits(String type, int id) async {
    final path = '/entities/$type/$id/quantity-links?include_prices=false';
    final Object? data;
    try {
      data = await fetch(path);
    } catch (error, stackTrace) {
      log(
        'loadEntityUnitNames: GET $path 失败（跳过关联单位）',
        name: 'entity_unit_names',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    for (final row in _rowsOf(data)) {
      if (row is! Map) continue;
      final current = row['current'];
      if (current is! Map) continue;
      final name = current['unit']?.toString().trim() ?? '';
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
    }
  }

  await collect(entityType, entityId);
  if (includeLinkUnits) {
    await collectLinkUnits(entityType, entityId);
  }

  if (entityType == 'product') {
    final linkedIngredientId =
        ingredientId ?? await _fetchIngredientId(fetch, entityId);
    if (linkedIngredientId != null) {
      await collect('ingredient', linkedIngredientId);
    }
  }

  return names;
}

/// 实体「默认单位」名（`entity_unit_overrides.is_default`）；没有默认单位时 null。
///
/// 维护价格选中商品时用它把单位下拉切到该商品的默认单位。优先级与单位解析链
/// 一致：**商品自身覆盖 > 商品关联原料的覆盖**；每层只取第一条 is_default 的启用行。
/// 读取失败返回 null（调用方保持原单位，绝不因网络抖动改用户的选择）。
Future<String?> loadEntityDefaultUnitName({
  required String entityType,
  required int entityId,
  int? ingredientId,
  ApiClient? client,
  EntityUnitsRequest? request,
}) async {
  final fetch = request ?? _apiGet(client);

  Future<String?> defaultOf(String type, int id) async {
    final path = '/entities/$type/$id/units';
    final Object? data;
    try {
      data = await fetch(path);
    } catch (error, stackTrace) {
      log(
        'loadEntityDefaultUnitName: GET $path 失败',
        name: 'entity_unit_names',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
    for (final row in _rowsOf(data)) {
      if (_isInactive(row)) continue;
      if (row is! Map || row['is_default'] != true) continue;
      final name = _unitNameOf(row);
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  final owned = await defaultOf(entityType, entityId);
  if (owned != null) return owned;
  if (entityType != 'product') return null;

  final linkedIngredientId =
      ingredientId ?? await _fetchIngredientId(fetch, entityId);
  if (linkedIngredientId == null) return null;
  return defaultOf('ingredient', linkedIngredientId);
}

/// 全局单位缩写（价格下拉的「基准列表」，与 web `loadGlobalUnitOptions` 同源）。
///
/// 移动端此前把全局基准硬编码成十来个常量，单位管理里新增或早已存在的全局单位
/// （斤/把/条/mL/桶/块…）在价格下拉里选不到（web 从 `/units/` 现拉）。
/// 失败返回空列表，由调用方回退硬编码常量，绝不抛异常、不弹用户可见错误。
Future<List<String>> loadGlobalUnitNames({
  ApiClient? client,
  EntityUnitsRequest? request,
}) async {
  final fetch = request ?? _apiGet(client);
  const path = '/units/?limit=500';
  final Object? data;
  try {
    data = await fetch(path);
  } catch (error, stackTrace) {
    log(
      'loadGlobalUnitNames: GET $path 失败',
      name: 'entity_unit_names',
      error: error,
      stackTrace: stackTrace,
    );
    return const [];
  }
  final names = <String>[];
  for (final row in _rowsOf(data)) {
    if (row is! Map) continue;
    final name = _firstNonEmptyName(row, const ['abbreviation', 'name']);
    if (name.isNotEmpty && !names.contains(name)) names.add(name);
  }
  return names;
}

EntityUnitsRequest _apiGet(ApiClient? client) {
  final dio = (client ?? ApiClient.instance).dio;
  return (path) async => (await dio.get(path)).data;
}

/// 商品未带关联原料 id 时回查商品实体（用于原料单位回退）。
Future<int?> _fetchIngredientId(EntityUnitsRequest fetch, int productId) async {
  final path = '/products/entity/$productId';
  final Object? data;
  try {
    data = await fetch(path);
  } catch (error, stackTrace) {
    log(
      'loadEntityUnitNames: GET $path 失败（跳过原料单位回退）',
      name: 'entity_unit_names',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
  if (data is! Map) return null;
  final value = data['ingredient_id'];
  final int? parsed = switch (value) {
    int v => v,
    num v => v.toInt(),
    String v => int.tryParse(v.trim()),
    _ => null,
  };
  return (parsed != null && parsed > 0) ? parsed : null;
}

/// 响应体 → 行列表（`List` 或 `{items: [...]}`，其余一律当空）。
List<Object?> _rowsOf(Object? data) {
  if (data is List) return data;
  if (data is Map) {
    final items = data['items'];
    if (items is List) return items;
    final nested = data['data'];
    if (nested is List) return nested;
  }
  return const [];
}

/// 行 → 单位名（`unit_name` 优先，其次 `name`；非 Map 行安全忽略）。
/// 首选项为空串/空白时继续看下一个键（比 web 的 `??` 更宽容，语义一致）。
String _unitNameOf(Object? row) {
  if (row is! Map) return '';
  return _firstNonEmptyName(row, const ['unit_name', 'name']);
}

String _firstNonEmptyName(Map row, List<String> keys) {
  for (final key in keys) {
    final name = row[key]?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
  }
  return '';
}

/// 行是否显式停用（`false` / `0` / `"false"` 都算；缺字段视为启用）。
bool _isInactive(Object? row) {
  if (row is! Map) return false;
  return switch (row['is_active']) {
    bool value => !value,
    num value => value == 0,
    String value => switch (value.trim().toLowerCase()) {
        'false' || '0' => true,
        _ => false,
      },
    _ => false,
  };
}

/// 合并「实体自定义单位」与全局单位列表（自定义单位在前，按名称去重），
/// 并保证 [current] 一定在结果里（否则 DropdownButton 会因值不在 items 中断言失败）。
List<String> mergePriceUnitOptions(
  List<String> customUnits,
  List<String> globalUnits, {
  String? current,
}) {
  final result = <String>[];
  for (final unit in [...customUnits, ...globalUnits]) {
    final name = unit.trim();
    if (name.isEmpty || result.contains(name)) continue;
    result.add(name);
  }
  final currentName = current?.trim();
  if (currentName != null && currentName.isNotEmpty && !result.contains(currentName)) {
    result.insert(0, currentName);
  }
  return result;
}

/// 营养基准（「每 X 单位」）的单位候选。
///
/// 候选 = 本实体（商品则含关联原料）**可折算**的自定义单位 + 全局质量/体积单位。
/// 实体尚未存在（新增商品/原料的草稿态，entityId<=0）时只给全局单位；
/// 商品若带了已选关联原料 id，则用该原料的可折算单位当候选。
///
/// 与 web 端 `entityUnits.loadNutritionBasisUnitOptions` 同口径；失败时回退
/// g/mL 常量，绝不抛异常、不弹用户可见错误。
Future<List<String>> loadNutritionBasisUnitNames({
  required String entityType,
  required int entityId,
  int? ingredientId,
  ApiClient? client,
  EntityUnitsRequest? request,
}) async {
  final fetch = request ?? _apiGet(client);

  Future<List<Map>> rowsOf(String path) async {
    final Object? data;
    try {
      data = await fetch(path);
    } catch (error, stackTrace) {
      log(
        'loadNutritionBasisUnitNames: GET $path 失败',
        name: 'entity_unit_names',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
    return [
      for (final row in _rowsOf(data))
        if (row is Map && !_isInactive(row)) Map<String, Object?>.from(row),
    ];
  }

  final globalRows = <Map>[
    for (final row in await rowsOf('/units/?limit=500'))
      if (row['unit_type'] == 'mass' || row['unit_type'] == 'volume') row,
  ];
  final globalNames = <String>[
    for (final row in globalRows)
      if (_firstNonEmptyName(row, const ['abbreviation', 'name']).isNotEmpty)
        _firstNonEmptyName(row, const ['abbreviation', 'name']),
  ];

  final ownRows = entityId > 0 ? await rowsOf('/entities/$entityType/$entityId/units') : <Map>[];
  var inheritedRows = <Map>[];
  if (entityType == 'product') {
    final linkedId = entityId > 0
        ? (ingredientId ?? await _fetchIngredientId(fetch, entityId))
        : ingredientId;
    if (linkedId != null && linkedId > 0) {
      inheritedRows = await rowsOf('/entities/ingredient/$linkedId/units');
    }
  }

  final seenIds = <int>{};
  final seenNames = <String>{};
  final customRows = <Map>[];
  for (final row in [...ownRows, ...inheritedRows]) {
    final id = row['id'];
    final idValue = id is num ? id.toInt() : int.tryParse('$id');
    if (idValue != null) {
      if (seenIds.contains(idValue)) continue;
      seenIds.add(idValue);
    }
    final name = _firstNonEmptyName(row, const ['unit_name', 'name']);
    if (name.isNotEmpty) {
      if (seenNames.contains(name)) continue;
      seenNames.add(name);
    }
    customRows.add(row);
  }

  final customNames = resolvableBasisUnitNames(customRows, globalRows);
  final options = mergeBasisUnitOptions(globalNames, customNames);
  if (options.isEmpty) return const ['g', 'mL'];
  for (final fallback in const ['g', 'mL']) {
    if (!options.contains(fallback)) options.add(fallback);
  }
  return options;
}

import '../../core/api/api_client.dart';

/// 价格记录单位下拉用的「实体自定义单位名」。
///
/// 与后端 `UnitConversionService.get_entity_override` 的优先级链一致：
///   商品自身覆盖 > 商品关联原料的覆盖 > 全局单位
/// 所以选了商品（或带着商品进编辑页）时，下拉除了全局单位，还要带上该商品
/// 及其关联原料的自定义单位（如「桶」「箱」），否则自定义单位记的价格记录
/// 没法再选同一个单位。返回顺序即展示顺序（商品自己的在前），已去重。
Future<List<String>> loadEntityUnitNames({
  required String entityType,
  required int entityId,
  int? ingredientId,
  ApiClient? client,
}) async {
  final dio = (client ?? ApiClient.instance).dio;
  final names = <String>[];

  Future<void> collect(String type, int id) async {
    try {
      final response = await dio.get('/entities/$type/$id/units');
      final data = response.data;
      final rows = data is List
          ? data
          : (data is Map ? (data['items'] as List? ?? const []) : const []);
      for (final row in rows) {
        final name =
            (row is Map ? row['unit_name'] : null)?.toString().trim() ?? '';
        if (name.isNotEmpty && !names.contains(name)) names.add(name);
      }
    } catch (_) {
      // 自定义单位加载失败不影响全局单位列表
    }
  }

  await collect(entityType, entityId);

  if (entityType == 'product') {
    final linkedIngredientId =
        ingredientId ?? await _fetchIngredientId(dio, entityId);
    if (linkedIngredientId != null) {
      await collect('ingredient', linkedIngredientId);
    }
  }

  return names;
}

/// 商品未带关联原料 id 时回查商品实体（用于原料单位回退）。
Future<int?> _fetchIngredientId(dynamic dio, int productId) async {
  try {
    final response = await dio.get('/products/entity/$productId');
    final data = response.data;
    if (data is Map) {
      final value = data['ingredient_id'];
      if (value is int && value > 0) return value;
      if (value is num && value > 0) return value.toInt();
    }
  } catch (_) {
    // 回查失败就不做原料回退
  }
  return null;
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

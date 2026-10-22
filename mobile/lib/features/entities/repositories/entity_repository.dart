import '../../../core/api/api_client.dart';
import '../../nutrition/models/usda_models.dart';
import '../../../shared/models/entity_unit.dart';
import '../../../shared/models/entity_quantity_link.dart';

/// 「字段未提供」哨兵：与显式 null（清空）区分。
const Object _keep = Object();

class EntityWriteResult<T> {
  final T? value;
  final bool pending;
  final String message;

  const EntityWriteResult({
    required this.value,
    required this.pending,
    this.message = '',
  });

  bool get applied => !pending;
}

/// 实体（原料/商品）自定义单位与密度管理。
class EntityRepository {
  final ApiClient _client;
  EntityRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  Future<List<EntityUnit>> listUnits(String entityType, int entityId) async {
    final response =
        await _client.dio.get('/entities/$entityType/$entityId/units');
    final data = response.data;
    final list = (data is List) ? data : (data['items'] as List?) ?? const [];
    return list
        .map((e) => EntityUnit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 创建自定义单位。
  ///
  /// [weightUnitId]（全局质量/体积单位）与 [weightUnitOverrideId]（本实体另一个
  /// 自定义单位）互斥，都为空表示按克；[conversionFactor] 为空表示 1。
  Future<EntityWriteResult<EntityUnit>> createUnit(
    String entityType,
    int entityId, {
    required String unitName,
    double? conversionFactor,
    double? weightPerUnit,
    int? weightUnitId,
    int? weightUnitOverrideId,
    bool isDefault = false,
    bool isAdmin = true,
  }) async {
    assert(
      weightUnitId == null || weightUnitOverrideId == null,
      'weightUnitId 与 weightUnitOverrideId 互斥',
    );
    final response = await _client.dio.post(
      '/entities/$entityType/$entityId/units',
      data: {
        'unit_name': unitName,
        if (conversionFactor != null) 'conversion_factor': conversionFactor,
        if (weightPerUnit != null) 'weight_per_unit': weightPerUnit,
        if (weightUnitId != null) 'weight_unit_id': weightUnitId,
        if (weightUnitOverrideId != null)
          'weight_unit_override_id': weightUnitOverrideId,
        'is_default': isDefault,
        'source': 'manual',
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final value = EntityUnit.fromJson(data);
    final review = MutationReviewResult.fromJson(data);
    return EntityWriteResult(
      value: value,
      pending: !isAdmin && value.id == 0 || review.pending,
      message: review.message,
    );
  }

  /// 更新自定义单位。
  ///
  /// 单位引用字段用 `_keep` 哨兵区分「不改动」（缺省）与「清空」（显式传 null）：
  /// 后端 `exclude_unset` 语义下不发送的字段保持原值，显式 null 才会清空。
  Future<EntityWriteResult<EntityUnit>> updateUnit(
    String entityType,
    int entityId,
    int unitId, {
    String? unitName,
    double? conversionFactor,
    double? weightPerUnit,
    Object? weightUnitId = _keep,
    Object? weightUnitOverrideId = _keep,
    bool? isDefault,
    bool isAdmin = true,
  }) async {
    final payload = <String, dynamic>{};
    if (unitName != null) payload['unit_name'] = unitName;
    if (conversionFactor != null) {
      payload['conversion_factor'] = conversionFactor;
    }
    if (weightPerUnit != null) payload['weight_per_unit'] = weightPerUnit;
    if (!identical(weightUnitId, _keep)) {
      payload['weight_unit_id'] = weightUnitId;
    }
    if (!identical(weightUnitOverrideId, _keep)) {
      payload['weight_unit_override_id'] = weightUnitOverrideId;
    }
    if (isDefault != null) payload['is_default'] = isDefault;
    final response = await _client.dio.put(
      '/entities/$entityType/$entityId/units/$unitId',
      data: payload,
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final review = MutationReviewResult.fromJson(data);
    return EntityWriteResult(
      value: EntityUnit.fromJson(data),
      pending: !isAdmin || review.pending,
      message: review.message,
    );
  }

  Future<EntityWriteResult<void>> deleteUnit(
    String entityType,
    int entityId,
    int unitId,
  ) async {
    final response = await _client.dio
        .delete('/entities/$entityType/$entityId/units/$unitId');
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    final review = MutationReviewResult.fromJson(data);
    return EntityWriteResult(
      value: null,
      pending: review.pending,
      message: review.message,
    );
  }

  Future<List<UnmappedUnit>> listUnmappedUnits(
    String entityType,
    int entityId,
  ) async {
    final response = await _client.dio
        .get('/entities/$entityType/$entityId/units/unmapped-units');
    final data = response.data;
    final list = (data is List) ? data : const [];
    return list
        .map((e) => UnmappedUnit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EntityDensity>> listDensities(
    String entityType,
    int entityId,
  ) async {
    final response =
        await _client.dio.get('/entities/$entityType/$entityId/density');
    final data = response.data;
    final list = (data is List) ? data : (data['items'] as List?) ?? const [];
    return list
        .map((e) => EntityDensity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 全局单位表（原始 Map），用于解析 weight_unit_id 的类型语义（质量/体积）。
  ///
  /// limit 取 500：单位下拉要列出**全部启用单位**，与 web（商品/原料详情、
  /// 新增对话框、价格页）同口径 —— 各端 limit 不一致会出现「web 13 条、
  /// 移动端 54 条」这种同一份数据的显示数量差异。
  Future<List<Map<String, dynamic>>> listGlobalUnits() async {
    final response =
        await _client.dio.get('/units/', queryParameters: {'limit': 500});
    final data = response.data;
    final list = (data is List) ? data : (data['items'] as List?) ?? const [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<EntityWriteResult<EntityDensity>> upsertDensity(
    String entityType,
    int entityId, {
    required double density,
    String? condition,
    bool isAdmin = true,
  }) async {
    final response = await _client.dio.post(
      '/entities/$entityType/$entityId/density',
      data: {
        'density': density,
        if (condition != null && condition.isNotEmpty) 'condition': condition,
        'source': 'manual',
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final value = EntityDensity.fromJson(data);
    final review = MutationReviewResult.fromJson(data);
    return EntityWriteResult(
      value: value,
      pending: !isAdmin && value.id == 0 || review.pending,
      message: review.message,
    );
  }

  Future<EntityWriteResult<void>> deleteDensity(
    String entityType,
    int entityId,
    int densityId,
  ) async {
    final response = await _client.dio
        .delete('/entities/$entityType/$entityId/density/$densityId');
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    final review = MutationReviewResult.fromJson(data);
    return EntityWriteResult(
      value: null,
      pending: review.pending,
      message: review.message,
    );
  }

  // ------------------------------------------------------------------ //
  //  商品/原料数量关联
  // ------------------------------------------------------------------ //

  Future<List<EntityQuantityLink>> listQuantityLinks(
    String entityType,
    int entityId, {
    bool includePrices = true,
  }) async {
    final response = await _client.dio.get(
      '/entities/$entityType/$entityId/quantity-links',
      queryParameters: {'include_prices': includePrices},
    );
    final data = response.data;
    final list = data is Map ? (data['items'] as List?) ?? const [] : const [];
    return list
        .whereType<Map>()
        .map((e) => EntityQuantityLink.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchQuantityLinkTargets(
    String targetType,
    String query,
  ) async {
    final response = await _client.dio.get(
      targetType == 'product' ? '/products/entity' : '/ingredients',
      queryParameters: targetType == 'product'
          ? {'search': query, 'limit': 20}
          : {'q': query, 'limit': 20},
    );
    final data = response.data;
    final list = data is Map ? (data['items'] as List?) ?? const [] : const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<EntityWriteResult<EntityQuantityLink>> createQuantityLink(
    String entityType,
    int entityId, {
    required String toType,
    required int toId,
    required double fromQuantity,
    required String fromUnit,
    required double toQuantity,
    required String toUnit,
    String? note,
    bool isAdmin = true,
  }) async {
    final response = await _client.dio.post(
      '/entities/$entityType/$entityId/quantity-links',
      data: {
        'to_type': toType,
        'to_id': toId,
        'from_quantity': fromQuantity,
        'from_unit': fromUnit,
        'to_quantity': toQuantity,
        'to_unit': toUnit,
        'note': note,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final value = EntityQuantityLink.fromJson(data);
    final review = MutationReviewResult.fromJson(data);
    return EntityWriteResult(
      value: value,
      pending: !isAdmin && value.id == 0 || review.pending,
      message: review.message,
    );
  }

  Future<EntityWriteResult<EntityQuantityLink>> updateQuantityLink(
    String entityType,
    int entityId,
    int linkId, {
    required double fromQuantity,
    required String fromUnit,
    required double toQuantity,
    required String toUnit,
    String? note,
  }) async {
    final response = await _client.dio.put(
      '/entities/$entityType/$entityId/quantity-links/$linkId',
      data: {
        'from_quantity': fromQuantity,
        'from_unit': fromUnit,
        'to_quantity': toQuantity,
        'to_unit': toUnit,
        'note': note,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final value = EntityQuantityLink.fromJson(data);
    final review = MutationReviewResult.fromJson(data);
    return EntityWriteResult(
      value: value,
      pending: review.pending,
      message: review.message,
    );
  }

  Future<EntityWriteResult<void>> deleteQuantityLink(
    String entityType,
    int entityId,
    int linkId,
  ) async {
    final response = await _client.dio
        .delete('/entities/$entityType/$entityId/quantity-links/$linkId');
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    final review = MutationReviewResult.fromJson(data);
    return EntityWriteResult(
      value: null,
      pending: review.pending,
      message: review.message,
    );
  }
}

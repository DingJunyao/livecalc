import '../../../core/api/api_client.dart';
import '../../nutrition/models/usda_models.dart';
import '../../../shared/models/entity_unit.dart';

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

  Future<EntityWriteResult<EntityUnit>> createUnit(
    String entityType,
    int entityId, {
    required String unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool isDefault = false,
    bool isAdmin = true,
  }) async {
    final response = await _client.dio.post(
      '/entities/$entityType/$entityId/units',
      data: {
        'unit_name': unitName,
        if (conversionFactor != null) 'conversion_factor': conversionFactor,
        if (weightPerUnit != null) 'weight_per_unit': weightPerUnit,
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

  Future<EntityWriteResult<EntityUnit>> updateUnit(
    String entityType,
    int entityId,
    int unitId, {
    String? unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool? isDefault,
    bool isAdmin = true,
  }) async {
    final payload = <String, dynamic>{};
    if (unitName != null) payload['unit_name'] = unitName;
    if (conversionFactor != null) {
      payload['conversion_factor'] = conversionFactor;
    }
    if (weightPerUnit != null) payload['weight_per_unit'] = weightPerUnit;
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
}

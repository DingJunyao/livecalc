// comparison_repository.dart — 跨地区物价对比数据源（与云端 /comparison/* 同契约）。
// 口径：卡片价 = 每标准单位综合价；趋势 = ¥/斤 前向携带加权（见后端 comparison.py docstring）。

import '../../../core/api/api_client.dart';

/// 对比项序列化：正数 = 地区 id；负数 = 自定义计算范围（-v → `s<v>`，
/// 后端展开为范围内多地区并集作为一棵合并子树参与对比）。
String serializeCompareRegionIds(List<int> ids) =>
    ids.map((v) => v < 0 ? 's${-v}' : '$v').join(',');

class RegionCandidate {
  final int regionId;
  final String name;
  final String displayName;
  final int level;
  final int recordCount;
  final int merchantCount;

  const RegionCandidate({
    required this.regionId,
    required this.name,
    required this.displayName,
    required this.level,
    required this.recordCount,
    required this.merchantCount,
  });

  factory RegionCandidate.fromJson(Map<String, dynamic> json) {
    return RegionCandidate(
      regionId: (json['region_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      displayName:
          (json['display_name'] as String?) ?? (json['name'] as String?) ?? '',
      level: (json['level'] as num?)?.toInt() ?? 0,
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
      merchantCount: (json['merchant_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class RegionSummary {
  final int regionId;
  final String name;
  final String displayName;
  final int recordCount;
  final int entityCount;
  final double? priceIndex;
  final List<double> trend;

  const RegionSummary({
    required this.regionId,
    required this.name,
    required this.displayName,
    required this.recordCount,
    required this.entityCount,
    required this.priceIndex,
    required this.trend,
  });

  factory RegionSummary.fromJson(Map<String, dynamic> json) {
    return RegionSummary(
      regionId: (json['region_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      displayName:
          (json['display_name'] as String?) ?? (json['name'] as String?) ?? '',
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
      entityCount: (json['entity_count'] as num?)?.toInt() ?? 0,
      priceIndex:
          json['price_index'] == null ? null : _toDouble(json['price_index']),
      trend: ((json['trend'] as List?) ?? const [])
          .map((e) => _toDouble(e))
          .toList(),
    );
  }
}

class ComparisonSummary {
  final String currency;
  final int baseRegionId;
  final int basketSize;
  final List<RegionSummary> regions;

  const ComparisonSummary({
    required this.currency,
    required this.baseRegionId,
    required this.basketSize,
    required this.regions,
  });

  factory ComparisonSummary.fromJson(Map<String, dynamic> json) {
    return ComparisonSummary(
      currency: (json['currency'] as String?) ?? 'CNY',
      baseRegionId: (json['base_region_id'] as num?)?.toInt() ?? 0,
      basketSize: (json['basket_size'] as num?)?.toInt() ?? 0,
      regions: ((json['regions'] as List?) ?? const [])
          .map((e) => RegionSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RegionMeta {
  final int regionId;
  final String name;
  final String displayName;
  final int level;

  const RegionMeta({
    required this.regionId,
    required this.name,
    required this.displayName,
    required this.level,
  });

  factory RegionMeta.fromJson(Map<String, dynamic> json) {
    return RegionMeta(
      regionId: (json['region_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      displayName:
          (json['display_name'] as String?) ?? (json['name'] as String?) ?? '',
      level: (json['level'] as num?)?.toInt() ?? 0,
    );
  }
}

class EntityRegionPrice {
  final double? price;
  final bool isStale;
  final int? daysSinceRecord;
  final int participantCount;
  final String? unit;
  final List<double> trend;

  const EntityRegionPrice({
    required this.price,
    required this.isStale,
    required this.daysSinceRecord,
    required this.participantCount,
    required this.unit,
    required this.trend,
  });

  factory EntityRegionPrice.fromJson(Map<String, dynamic> json) {
    return EntityRegionPrice(
      price: json['price'] == null ? null : _toDouble(json['price']),
      isStale: json['is_stale'] == true,
      daysSinceRecord: (json['days_since_record'] as num?)?.toInt(),
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String?,
      trend: ((json['trend'] as List?) ?? const [])
          .map((e) => _toDouble(e))
          .toList(),
    );
  }
}

class EntityPriceRow {
  final int entityId;
  final String name;
  final String? unit;

  /// 键为 region_id 字符串；该地区无数据时值为 null
  final Map<String, EntityRegionPrice?> regions;

  const EntityPriceRow({
    required this.entityId,
    required this.name,
    required this.unit,
    required this.regions,
  });

  factory EntityPriceRow.fromJson(Map<String, dynamic> json) {
    final raw = (json['regions'] as Map?) ?? const {};
    final regions = <String, EntityRegionPrice?>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      regions[entry.key.toString()] = v == null
          ? null
          : EntityRegionPrice.fromJson(v as Map<String, dynamic>);
    }
    return EntityPriceRow(
      entityId: (json['entity_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      unit: json['unit'] as String?,
      regions: regions,
    );
  }
}

class EntityPrices {
  final String currency;
  final String trendUnit;
  final List<RegionMeta> regions;
  final List<EntityPriceRow> entities;

  const EntityPrices({
    required this.currency,
    required this.trendUnit,
    required this.regions,
    required this.entities,
  });

  factory EntityPrices.fromJson(Map<String, dynamic> json) {
    return EntityPrices(
      currency: (json['currency'] as String?) ?? 'CNY',
      trendUnit: (json['trend_unit'] as String?) ?? '',
      regions: ((json['regions'] as List?) ?? const [])
          .map((e) => RegionMeta.fromJson(e as Map<String, dynamic>))
          .toList(),
      entities: ((json['entities'] as List?) ?? const [])
          .map((e) => EntityPriceRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 一个地区卡的数据（从 EntityPrices 实体行的地区格提取）。
class RegionCardData {
  final int regionId;
  final String name;
  final double price;
  final String? unit;
  final bool isStale;
  bool isLowest;
  final int? daysSinceRecord;
  final List<double> trend;

  RegionCardData({
    required this.regionId,
    required this.name,
    required this.price,
    required this.unit,
    required this.isStale,
    this.isLowest = false,
    required this.daysSinceRecord,
    required this.trend,
  });
}

/// 从单实体的 EntityPrices 响应提取地区卡。
/// 最低价标注：非陈旧里最低（≥2 条才标，与商家卡口径一致）。
List<RegionCardData> regionCardsFromEntityPrices(EntityPrices prices) {
  if (prices.entities.isEmpty) return const [];
  final row = prices.entities.first;
  final namesById = <int, String>{
    for (final r in prices.regions) r.regionId: r.displayName,
  };
  final cards = <RegionCardData>[];
  row.regions.forEach((ridStr, cell) {
    if (cell == null || cell.price == null) return;
    final rid = int.tryParse(ridStr);
    if (rid == null) return;
    cards.add(RegionCardData(
      regionId: rid,
      name: namesById[rid] ?? ridStr,
      price: cell.price!,
      unit: cell.unit,
      isStale: cell.isStale,
      daysSinceRecord: cell.daysSinceRecord,
      trend: cell.trend,
    ));
  });
  final fresh = cards.where((c) => !c.isStale).toList();
  if (fresh.length >= 2) {
    final min = fresh.map((c) => c.price).reduce((a, b) => a < b ? a : b);
    for (final c in fresh) {
      c.isLowest = c.price == min;
    }
  }
  return cards;
}

double _toDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

class ComparisonRepository {
  final ApiClient _client;
  ComparisonRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// 有价格记录的地区候选（按记录数降序）。
  Future<List<RegionCandidate>> getRegions() async {
    final response = await _client.dio.get('/comparison/regions');
    final data = response.data as Map<String, dynamic>;
    return ((data['regions'] as List?) ?? const [])
        .map((e) => RegionCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 各地区概览（物价指数 + 篮子趋势）；regionIds 第一个为基准地区。
  Future<ComparisonSummary> getSummary({
    required List<int> regionIds,
    int days = 30,
  }) async {
    final response =
        await _client.dio.get('/comparison/summary', queryParameters: {
      'region_ids': serializeCompareRegionIds(regionIds),
      'days': days,
    });
    return ComparisonSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// 实体×地区价格矩阵。
  Future<EntityPrices> getEntityPrices({
    required String entityType,
    required List<int> entityIds,
    required List<int> regionIds,
    int days = 30,
  }) async {
    final response =
        await _client.dio.get('/comparison/entity-prices', queryParameters: {
      'entity_type': entityType,
      'entity_ids': entityIds.join(','),
      'region_ids': serializeCompareRegionIds(regionIds),
      'days': days,
    });
    return EntityPrices.fromJson(response.data as Map<String, dynamic>);
  }

  /// 实体搜索（原料 / 商品）。原料端点用 q，商品端点用 search（与列表页同参）。
  Future<List<EntityOption>> searchEntities({
    required String entityType,
    String keyword = '',
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (keyword.isNotEmpty) {
      params[entityType == 'ingredient' ? 'q' : 'search'] = keyword;
    }
    final url =
        entityType == 'ingredient' ? '/ingredients' : '/products/entity';
    final response = await _client.dio.get(url, queryParameters: params);
    final data = response.data;
    final list =
        (data is Map ? (data['items'] as List?) : (data as List?)) ?? const [];
    return list
        .map((e) => EntityOption(
              id: ((e as Map)['id'] as num?)?.toInt() ?? 0,
              name: (e['name'] as String?) ?? '',
            ))
        .where((o) => o.id > 0)
        .toList();
  }

  /// 菜谱搜索（GET /recipes，服务端 search）。
  Future<List<EntityOption>> searchRecipes(
      {String keyword = '', int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (keyword.isNotEmpty) params['search'] = keyword;
    final response = await _client.dio.get('/recipes', queryParameters: params);
    final data = response.data;
    final list =
        (data is Map ? (data['items'] as List?) : (data as List?)) ?? const [];
    return list
        .map((e) => EntityOption(
              id: ((e as Map)['id'] as num?)?.toInt() ?? 0,
              name: (e['name'] as String?) ?? '',
            ))
        .where((o) => o.id > 0)
        .toList();
  }

  /// 试算下拉全量选项（端点无分页/搜索）。
  Future<List<EntityOption>> listPlans() async {
    final response = await _client.dio.get('/meal-plans');
    final data = response.data;
    final list =
        (data is Map ? (data['items'] as List?) : (data as List?)) ?? const [];
    return list
        .map((e) => EntityOption(
              id: ((e as Map)['id'] as num?)?.toInt() ?? 0,
              name: (e['name'] as String?) ?? '',
            ))
        .where((o) => o.id > 0)
        .toList();
  }

  // ==================== 二期：菜谱 / 试算成本对比 ====================

  /// 菜谱×地区成本矩阵（明细里 cost=null 的行即该地区缺价食材）。
  Future<Map<String, dynamic>> getRecipeCosts({
    required List<int> recipeIds,
    required List<int> regionIds,
  }) async {
    final response =
        await _client.dio.get('/comparison/recipe-costs', queryParameters: {
      'recipe_ids': recipeIds.join(','),
      'region_ids': serializeCompareRegionIds(regionIds),
    });
    return response.data as Map<String, dynamic>;
  }

  /// 已保存方案×地区合计对照（totals = evaluate 的 cost/营养五项）。
  Future<Map<String, dynamic>> getPlanCosts({
    required List<int> planIds,
    required List<int> regionIds,
  }) async {
    final response =
        await _client.dio.get('/comparison/plan-costs', queryParameters: {
      'plan_ids': planIds.join(','),
      'region_ids': serializeCompareRegionIds(regionIds),
    });
    return response.data as Map<String, dynamic>;
  }

  /// 同一组条目（草稿也可）在 N 个地区分别求值（合计卡口径切换）。
  Future<List<Map<String, dynamic>>> planEvaluateRegions({
    required List<Map<String, dynamic>> items,
    required List<int> regionIds,
    String kind = 'meal',
    String mealType = 'lunch',
  }) async {
    final response = await _client.dio.post(
      '/comparison/plan-evaluate-regions',
      data: {
        'kind': kind,
        'meal_type': mealType,
        'items': items,
        'region_ids': regionIds,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return ((data['regions'] as List?) ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// 商家物价热力图（mode=item 需 entity_type+entity_id；overall 全商家的篮子指数）。
  Future<Map<String, dynamic>> getHeatmap({
    required String mode,
    required List<int> regionIds,
    String entityType = 'ingredient',
    int? entityId,
  }) async {
    final response =
        await _client.dio.get('/comparison/heatmap', queryParameters: {
      'mode': mode,
      'region_ids': serializeCompareRegionIds(regionIds),
      if (mode == 'item') ...{
        'entity_type': entityType,
        'entity_id': entityId,
      },
    });
    return response.data as Map<String, dynamic>;
  }

  /// 用户的自定义计算范围（对比地区快捷选择）。
  Future<List<CalcScopeOption>> listCalcScopes() async {
    final response = await _client.dio.get('/calc-scopes');
    final data = response.data;
    final list = (data is List) ? data : ((data['items'] as List?) ?? const []);
    return list
        .map((e) => CalcScopeOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// 自定义计算范围选项（名称 + 多地区 id 组合）。
class CalcScopeOption {
  final int id;
  final String name;
  final List<int> regionIds;

  const CalcScopeOption({
    required this.id,
    required this.name,
    required this.regionIds,
  });

  factory CalcScopeOption.fromJson(Map<String, dynamic> json) {
    return CalcScopeOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      regionIds: ((json['region_ids'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

/// 实体搜索选项（原料/商品共用）。
class EntityOption {
  final int id;
  final String name;
  const EntityOption({required this.id, required this.name});
}

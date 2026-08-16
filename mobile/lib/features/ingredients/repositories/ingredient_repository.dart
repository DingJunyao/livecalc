import '../../../core/api/api_client.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/models/merchant_price.dart';
import '../../../shared/models/ingredient_recipe.dart';
import '../../../shared/models/hierarchy_relation.dart';
import '../models/ingredient.dart';
import '../models/ingredient_category.dart';

class IngredientPage {
  final List<Ingredient> items;
  final int total;
  const IngredientPage({required this.items, this.total = 0});
}

class IngredientRecipePage {
  final List<IngredientRecipeRef> items;
  final int total;
  const IngredientRecipePage({required this.items, this.total = 0});
}

class IngredientHierarchyData {
  final List<HierarchyRelation> parentRelations;
  final List<HierarchyRelation> childRelations;
  const IngredientHierarchyData({
    this.parentRelations = const [],
    this.childRelations = const [],
  });

  bool get isEmpty => parentRelations.isEmpty && childRelations.isEmpty;
}

class IngredientRepository {
  final ApiClient _client;
  IngredientRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// 分页搜索原料（对应后端 GET /ingredients）。
  /// [conditions] 支持 no_nutrition / no_price / single_price /
  /// single_merchant / no_recipe / no_product。
  Future<IngredientPage> search({
    String? search,
    List<int>? categoryIds,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
  }) async {
    final params = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'sort_by': sortBy,
    };
    if (search != null && search.isNotEmpty) params['q'] = search;
    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['category_ids'] = categoryIds.join(',');
    }
    for (final cond in conditions ?? const <String>[]) {
      params[cond] = 'true';
    }
    final response =
        await _client.dio.get('/ingredients', queryParameters: params);
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data['items'] as List?) ?? const []);
    final items = list
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (data is Map ? (data['total'] as num?)?.toInt() : null) ??
        items.length;
    return IngredientPage(items: items, total: total);
  }

  Future<List<IngredientCategory>> getCategories() async {
    final response = await _client.dio.get('/ingredients/categories');
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data['items'] as List?) ?? const []);
    return list
        .map((e) => IngredientCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Ingredient> createIngredient({
    required String name,
    int? categoryId,
    List<String> aliases = const [],
  }) async {
    final payload = <String, dynamic>{'name': name};
    if (categoryId != null) payload['category_id'] = categoryId;
    if (aliases.isNotEmpty) payload['aliases'] = aliases;
    final response = await _client.dio.post('/ingredients', data: payload);
    return Ingredient.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Ingredient> updateIngredient(
    int id, {
    String? name,
    int? categoryId,
    List<String>? aliases,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    payload['category_id'] = categoryId;
    if (aliases != null) payload['aliases'] = aliases;
    final response = await _client.dio.put('/ingredients/$id', data: payload);
    return Ingredient.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Ingredient> getIngredient(int id) async {
    final response = await _client.dio.get('/ingredients/$id');
    return Ingredient.fromJson(response.data as Map<String, dynamic>);
  }

  /// 最近一天平均价（GET /nutrition/ingredients/{id}/latest-price）。
  Future<LatestPriceInfo> getLatestPrice(int id) async {
    final response =
        await _client.dio.get('/nutrition/ingredients/$id/latest-price');
    return LatestPriceInfo.fromJson(response.data as Map<String, dynamic>);
  }

  /// 各商家最新价（GET /nutrition/ingredients/{id}/latest-price-by-merchant）。
  Future<List<MerchantPrice>> getLatestPricesByMerchant(int id) async {
    final response = await _client
        .dio
        .get('/nutrition/ingredients/$id/latest-price-by-merchant');
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data['prices'] as List?) ?? const []);
    return list
        .map((e) => MerchantPrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 迷你图（GET /sparklines/ingredients?ids=1,2,3）→ {id: [values]}。
  Future<Map<int, List<double>>> getSparklines(List<int> ids) async {
    if (ids.isEmpty) return const {};
    final response = await _client.dio.get(
      '/sparklines/ingredients',
      queryParameters: {'ids': ids.join(',')},
    );
    final data = response.data;
    if (data is! Map) return const {};
    return data.map((key, value) {
      final values = (value as List?)?.map((e) => (e as num).toDouble());
      return MapEntry(int.tryParse(key.toString()) ?? 0, values?.toList() ?? []);
    });
  }

  /// 包含该原料的菜谱（GET /nutrition/ingredients/{id}/recipes）。
  Future<IngredientRecipePage> getRelatedRecipes(
    int id, {
    int skip = 0,
    int limit = 10,
  }) async {
    final response = await _client.dio.get(
      '/nutrition/ingredients/$id/recipes',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data['items'] as List?) ?? const []);
    final items = list
        .map((e) => IngredientRecipeRef.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (data is Map ? (data['total'] as num?)?.toInt() : null) ??
        items.length;
    return IngredientRecipePage(items: items, total: total);
  }

  /// 层级关系（GET /ingredients/{id}/hierarchy）。
  Future<IngredientHierarchyData> getHierarchy(int id) async {
    final response =
        await _client.dio.get('/ingredients/$id/hierarchy', queryParameters: {
      'depth': 1,
    });
    final data = response.data as Map<String, dynamic>;
    return IngredientHierarchyData(
      parentRelations: ((data['parent_relations'] as List?) ?? const [])
          .map((e) =>
              HierarchyRelation.fromJson(e as Map<String, dynamic>))
          .toList(),
      childRelations: ((data['child_relations'] as List?) ?? const [])
          .map((e) =>
              HierarchyRelation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<HierarchyRelation> createHierarchyRelation({
    required int parentId,
    required int childId,
    required String relationType,
    int strength = 50,
  }) async {
    final response = await _client.dio.post(
      '/ingredients/hierarchy',
      data: {
        'parent_id': parentId,
        'child_id': childId,
        'relation_type': relationType,
        'strength': strength,
      },
    );
    return HierarchyRelation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<HierarchyRelation> updateHierarchyRelation(
    int relationId, {
    required int strength,
  }) async {
    final response = await _client.dio.put(
      '/ingredients/hierarchy/$relationId',
      data: {'strength': strength},
    );
    return HierarchyRelation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteHierarchyRelation(int relationId) async {
    await _client.dio.delete('/ingredients/hierarchy/$relationId');
  }
}

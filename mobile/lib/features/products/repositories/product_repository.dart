import 'package:dio/dio.dart' show DioException;

import '../../../core/api/api_client.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/models/merchant_price.dart';
import '../models/product.dart';
import '../../nutrition/models/usda_models.dart';
import '../models/barcode_lookup.dart';

class ProductPage {
  final List<Product> items;
  final int total;
  const ProductPage({required this.items, this.total = 0});
}

class ProductMutationResult {
  final Product? product;
  final MutationReviewResult review;

  const ProductMutationResult({
    this.product,
    required this.review,
  });

  bool get pending => review.pending;
  bool get applied => !pending;
  String get message => review.message;
}

/// 商品合并结果（POST /products/entity/{id}/merge-into/{target}）。
/// [targetId] 仅管理员直写时返回，表示合并后的目标商品。
class ProductMergeResult {
  final MutationReviewResult review;
  final int? targetId;

  const ProductMergeResult({required this.review, this.targetId});

  bool get pending => review.pending;
  bool get applied => !pending;
  String get message => review.message;
}

/// 商品拆分为原料结果（POST /products/entity/{id}/split-to-ingredient）。
/// [ingredientId] 仅管理员直写时返回，表示新原料 id。
class ProductSplitResult {
  final MutationReviewResult review;
  final int? ingredientId;

  const ProductSplitResult({required this.review, this.ingredientId});

  bool get pending => review.pending;
  bool get applied => !pending;
  String get message => review.message;
}

/// 商品对当前用户的生效价格权重（GET /products/{id}/my-weight）。
class MyWeightInfo {
  final int productId;
  final int effectiveWeight;
  final int globalWeight;
  final int? overrideWeight;
  final String source; // "override" | "global"

  const MyWeightInfo({
    required this.productId,
    required this.effectiveWeight,
    required this.globalWeight,
    this.overrideWeight,
    required this.source,
  });

  factory MyWeightInfo.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
    return MyWeightInfo(
      productId: asInt(json['product_id']) ?? 0,
      effectiveWeight: asInt(json['effective_weight']) ?? 0,
      globalWeight: asInt(json['global_weight']) ?? 0,
      overrideWeight: asInt(json['override_weight']),
      source: json['source']?.toString() ?? 'global',
    );
  }
}

class ProductRepository {
  final ApiClient _client;
  ProductRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// 分页搜索商品（对应后端 GET /products/entity）。
  /// [conditions] 支持 no_price / single_price / single_merchant。
  Future<ProductPage> search({
    String? search,
    int? ingredientId,
    List<int>? ingredientIds,
    List<int>? ingredientCategoryIds,
    List<String>? brands,
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
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (ingredientId != null) params['ingredient_id'] = ingredientId;
    if (ingredientIds != null && ingredientIds.isNotEmpty) {
      params['ingredient_ids'] = ingredientIds.join(',');
    }
    if (ingredientCategoryIds != null && ingredientCategoryIds.isNotEmpty) {
      params['ingredient_category_ids'] = ingredientCategoryIds.join(',');
    }
    if (brands != null && brands.isNotEmpty) {
      params['brands'] = brands.join(',');
    }
    for (final cond in conditions ?? const <String>[]) {
      params[cond] = 'true';
    }
    final response =
        await _client.dio.get('/products/entity', queryParameters: params);
    final data = response.data;
    final list = (data is List) ? data : ((data['items'] as List?) ?? const []);
    final items =
        list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    final total =
        (data is Map ? (data['total'] as num?)?.toInt() : null) ?? items.length;
    return ProductPage(items: items, total: total);
  }

  Future<Product> getProduct(int id) async {
    final response = await _client.dio.get('/products/entity/$id');
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BarcodeLookupResult> lookupBarcode(String barcode) async {
    final code = Uri.encodeComponent(barcode.trim());
    try {
      final response = await _client.dio.get('/products/entity/barcode/$code');
      return BarcodeLookupResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      if (error.response?.statusCode == 404 && data is Map<String, dynamic>) {
        return BarcodeLookupResult.fromJson(data);
      }
      rethrow;
    }
  }

  Future<Product> createProduct({
    required String name,
    required int ingredientId,
    String? brand,
    String? barcode,
    List<String> aliases = const [],
    List<String> tags = const [],
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'ingredient_id': ingredientId,
    };
    if (brand != null && brand.isNotEmpty) payload['brand'] = brand;
    if (barcode != null && barcode.isNotEmpty) payload['barcode'] = barcode;
    if (aliases.isNotEmpty) payload['aliases'] = aliases;
    if (tags.isNotEmpty) payload['tags'] = tags;
    final response = await _client.dio.post('/products/entity', data: payload);
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProductMutationResult> updateProduct(
    int id, {
    required bool isAdmin,
    String? name,
    int? ingredientId,
    String? brand,
    String? barcode,
    List<String>? aliases,
    List<String>? tags,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (ingredientId != null) payload['ingredient_id'] = ingredientId;
    if (brand != null) payload['brand'] = brand;
    if (barcode != null) payload['barcode'] = barcode;
    if (aliases != null) payload['aliases'] = aliases;
    if (tags != null) payload['tags'] = tags;
    final response =
        await _client.dio.put('/products/entity/$id', data: payload);
    final data = response.data as Map<String, dynamic>;
    return ProductMutationResult(
      product: Product.fromJson(data),
      review: isAdmin
          ? MutationReviewResult(
              applied: true,
              pending: false,
              message: '已保存',
              raw: data,
            )
          : MutationReviewResult(
              applied: false,
              pending: true,
              message: '已提交，待管理员审核',
              raw: data,
            ),
    );
  }

  Future<MutationReviewResult> deleteProduct(int id) async {
    final response = await _client.dio.delete('/products/entity/$id');
    final data = response.data;
    return MutationReviewResult.fromJson(
      data is Map<String, dynamic> ? data : const {},
    );
  }

  /// 同一原料下的其他商品（合并目标候选）。
  Future<List<Product>> listSiblingProducts(int productId, int ingredientId) async {
    final page = await search(ingredientIds: [ingredientId], limit: 50);
    return page.items.where((p) => p.id != productId).toList();
  }

  /// 合并商品（POST /products/entity/{id}/merge-into/{target}）。
  /// 同名冲突等约束由后端返回 400/409，调用方按需处理。
  Future<ProductMergeResult> mergeIntoProduct(
    int productId, {
    required int targetProductId,
  }) async {
    final response = await _client.dio
        .post('/products/entity/$productId/merge-into/$targetProductId');
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    return ProductMergeResult(
      review: MutationReviewResult.fromJson(data),
      targetId: data['target_id'] is int ? data['target_id'] as int : null,
    );
  }

  /// 拆分为原料（POST /products/entity/{id}/split-to-ingredient）。
  /// 同名冲突时后端返回 409，抛出 [DioException] 由调用方引导重命名。
  Future<ProductSplitResult> splitToIngredient(
    int productId, {
    String? newName,
  }) async {
    final response = await _client.dio.post(
      '/products/entity/$productId/split-to-ingredient',
      data: newName == null ? null : {'new_name': newName},
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    return ProductSplitResult(
      review: MutationReviewResult.fromJson(data),
      ingredientId:
          data['ingredient_id'] is int ? data['ingredient_id'] as int : null,
    );
  }

  /// 我的商品价格权重（个人偏好，不走审核）。
  Future<MyWeightInfo> getMyWeight(int productId) async {
    final response =
        await _client.dio.get('/products/$productId/my-weight');
    return MyWeightInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setMyWeight(int productId, int weight) async {
    await _client.dio
        .put('/products/$productId/my-weight', data: {'weight': weight});
  }

  Future<void> deleteMyWeight(int productId) async {
    await _client.dio.delete('/products/$productId/my-weight');
  }

  Future<LatestPriceInfo> getLatestPrice(int id, {int? regionId}) async {
    final response = await _client.dio.get(
      '/products/entity/$id/latest-price',
      queryParameters: {if (regionId != null) 'region_id': regionId},
    );
    return LatestPriceInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MerchantPrice>> getLatestPricesByMerchant(int id,
      {int? regionId}) async {
    final response = await _client.dio.get(
      '/products/entity/$id/latest-price-by-merchant',
      queryParameters: {if (regionId != null) 'region_id': regionId},
    );
    final data = response.data;
    final list =
        (data is List) ? data : ((data['prices'] as List?) ?? const []);
    return list
        .map((e) => MerchantPrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 商品自动完成搜索（GET /products/autocomplete）。
  /// 返回原始 Map 列表，含 name/match_type/id/ingredient_id/aliases/
  /// ingredient_aliases/ingredient_product_count 等字段（供粘贴导入匹配用）。
  Future<List<Map<String, dynamic>>> autocomplete(String q,
      {int limit = 20}) async {
    final response = await _client.dio.get(
      '/products/autocomplete',
      queryParameters: {'q': q, 'limit': limit},
    );
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data is Map ? data['items'] as List? : null) ?? const []);
    return list.map((e) => e as Map<String, dynamic>).toList(growable: false);
  }

  /// 迷你图（GET /sparklines/products?ids=1,2,3）→ {id: [values]}。
  Future<Map<int, List<double>>> getSparklines(List<int> ids) async {
    if (ids.isEmpty) return const {};
    final response = await _client.dio.get(
      '/sparklines/products',
      queryParameters: {'ids': ids.join(',')},
    );
    final data = response.data;
    if (data is! Map) return const {};
    return data.map((key, value) {
      final values = (value as List?)?.map((e) => (e as num).toDouble());
      return MapEntry(
          int.tryParse(key.toString()) ?? 0, values?.toList() ?? []);
    });
  }
}

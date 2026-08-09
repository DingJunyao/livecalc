import '../../../core/api/api_client.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/models/merchant_price.dart';
import '../models/product.dart';

class ProductPage {
  final List<Product> items;
  final int total;
  const ProductPage({required this.items, this.total = 0});
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
    final list = (data is List)
        ? data
        : ((data['items'] as List?) ?? const []);
    final items = list
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (data is Map ? (data['total'] as num?)?.toInt() : null) ??
        items.length;
    return ProductPage(items: items, total: total);
  }

  Future<Product> getProduct(int id) async {
    final response = await _client.dio.get('/products/entity/$id');
    return Product.fromJson(response.data as Map<String, dynamic>);
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

  Future<Product> updateProduct(
    int id, {
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
    final response = await _client.dio.put('/products/entity/$id', data: payload);
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteProduct(int id) async {
    await _client.dio.delete('/products/entity/$id');
  }

  Future<LatestPriceInfo> getLatestPrice(int id) async {
    final response =
        await _client.dio.get('/products/entity/$id/latest-price');
    return LatestPriceInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MerchantPrice>> getLatestPricesByMerchant(int id) async {
    final response = await _client
        .dio
        .get('/products/entity/$id/latest-price-by-merchant');
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data['prices'] as List?) ?? const []);
    return list
        .map((e) => MerchantPrice.fromJson(e as Map<String, dynamic>))
        .toList();
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
      return MapEntry(int.tryParse(key.toString()) ?? 0, values?.toList() ?? []);
    });
  }
}

import '../../../core/api/api_client.dart';
import '../models/merchant.dart';
import '../models/merchant_product_price.dart';

class MerchantPage {
  final List<Merchant> items;
  final int total;
  const MerchantPage({required this.items, this.total = 0});
}

class MerchantProductPricePage {
  final List<MerchantProductPrice> items;
  final int total;
  const MerchantProductPricePage({required this.items, this.total = 0});
}

class MerchantRepository {
  final ApiClient _client;
  MerchantRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// 分页搜索商家（GET /merchants）。
  Future<MerchantPage> search({
    String? search,
    bool includeClosed = false,
    bool noPrice = false,
    int skip = 0,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'include_closed': includeClosed,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (noPrice) params['no_price'] = 'true';
    final response =
        await _client.dio.get('/merchants', queryParameters: params);
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data['items'] as List?) ?? const []);
    final items = list
        .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (data is Map ? (data['total'] as num?)?.toInt() : null) ??
        items.length;
    return MerchantPage(items: items, total: total);
  }

  Future<Merchant> getMerchant(int id) async {
    final response = await _client.dio.get('/merchants/$id');
    return Merchant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Merchant> createMerchant({
    required String name,
    String? address,
    bool isOpen = true,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.dio.post(
      '/merchants',
      data: {
        'name': name,
        if (address != null && address.isNotEmpty) 'address': address,
        'is_open': isOpen,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    return Merchant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Merchant> updateMerchant(
    int id, {
    String? name,
    String? address,
    bool? isOpen,
    double? latitude,
    double? longitude,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (address != null) payload['address'] = address;
    if (isOpen != null) payload['is_open'] = isOpen;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    final response =
        await _client.dio.put('/merchants/$id', data: payload);
    return Merchant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteMerchant(int id) async {
    await _client.dio.delete('/merchants/$id');
  }

  /// 我的收藏（GET /merchants/favorites）。
  Future<List<Merchant>> getFavorites() async {
    final response = await _client.dio.get('/merchants/favorites');
    final data = response.data;
    final list = (data is List) ? data : ((data['items'] as List?) ?? const []);
    return list
        .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFavorite(int id) async {
    await _client.dio.post('/merchants/$id/favorite');
  }

  Future<void> removeFavorite(int id) async {
    await _client.dio.delete('/merchants/$id/favorite');
  }

  /// 商家各商品最新价格（GET /merchants/{id}/product-prices）。
  Future<MerchantProductPricePage> getProductPrices(
    int id, {
    int skip = 0,
    int limit = 20,
  }) async {
    final response = await _client.dio.get(
      '/merchants/$id/product-prices',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data['items'] as List?) ?? const []);
    final items = list
        .map((e) =>
            MerchantProductPrice.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (data is Map ? (data['total'] as num?)?.toInt() : null) ??
        items.length;
    return MerchantProductPricePage(items: items, total: total);
  }
}

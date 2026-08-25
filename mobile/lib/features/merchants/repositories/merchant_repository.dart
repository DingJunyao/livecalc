import '../../../core/api/api_client.dart';
import '../models/merchant.dart';
import '../models/merchant_coordinate.dart';
import '../models/merchant_product_price.dart';
import '../../nutrition/models/usda_models.dart';

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

class MerchantMutationResult {
  final Merchant? merchant;
  final MutationReviewResult review;

  const MerchantMutationResult({
    this.merchant,
    required this.review,
  });

  bool get pending => review.pending;
  bool get applied => !pending;
  String get message => review.message;
}

class MerchantRepository {
  final ApiClient _client;
  MerchantRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// 地图配置（GET /merchants/map-config），失败回退启用（对齐 web）。
  Future<Map<String, dynamic>> getMapConfig() async {
    final response = await _client.dio.get('/merchants/map-config');
    final data = response.data;
    return data is Map<String, dynamic> ? data : const {};
  }

  /// 分页搜索商家（GET /merchants）。
  Future<MerchantPage> search({
    String? search,
    bool includeClosed = false,
    bool noPrice = false,
    bool includeOtherRegions = false,
    int skip = 0,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'include_closed': includeClosed,
      'include_other_regions': includeOtherRegions,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (noPrice) params['no_price'] = 'true';
    final response =
        await _client.dio.get('/merchants', queryParameters: params);
    final data = response.data;
    final list = (data is List) ? data : ((data['items'] as List?) ?? const []);
    final items =
        list.map((e) => Merchant.fromJson(e as Map<String, dynamic>)).toList();
    final total =
        (data is Map ? (data['total'] as num?)?.toInt() : null) ?? items.length;
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
    int? regionId,
    String? defaultCurrency,
  }) async {
    final response = await _client.dio.post(
      '/merchants',
      data: {
        'name': name,
        if (address != null && address.isNotEmpty) 'address': address,
        'is_open': isOpen,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (regionId != null) 'region_id': regionId,
        if (defaultCurrency != null) 'default_currency': defaultCurrency,
      },
    );
    return Merchant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MerchantMutationResult> updateMerchant(
    int id, {
    required bool isAdmin,
    String? name,
    String? address,
    bool? isOpen,
    double? latitude,
    double? longitude,
    int? regionId,
    String? defaultCurrency,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (address != null) payload['address'] = address;
    if (isOpen != null) payload['is_open'] = isOpen;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (regionId != null) payload['region_id'] = regionId;
    if (defaultCurrency != null) payload['default_currency'] = defaultCurrency;
    final response = await _client.dio.put('/merchants/$id', data: payload);
    final data = response.data as Map<String, dynamic>;
    final review = MutationReviewResult.fromJson(data);
    return MerchantMutationResult(
      merchant: Merchant.fromJson(data),
      review: isAdmin
          ? MutationReviewResult(
              applied: true,
              pending: false,
              message: review.message.isEmpty ? '已保存' : review.message,
              raw: data,
            )
          : MutationReviewResult(
              applied: false,
              pending: true,
              message: review.message.isEmpty ? '已提交，待管理员审核' : review.message,
              raw: data,
            ),
    );
  }

  /// Geocode coordinates to a region id (POST /merchants/geocode).
  Future<int?> geocode({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.dio.post(
      '/merchants/geocode',
      data: {'latitude': latitude, 'longitude': longitude},
    );
    final data = response.data;
    if (data is Map) {
      final regionId = data['region_id'];
      if (regionId is num) return regionId.toInt();
      if (regionId is String) return int.tryParse(regionId);
    }
    return null;
  }

  Future<MutationReviewResult> deleteMerchant(int id) async {
    final response = await _client.dio.delete('/merchants/$id');
    final data = response.data;
    return MutationReviewResult.fromJson(
      data is Map<String, dynamic> ? data : const {},
    );
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

  /// 全部商家坐标（不分页，供地图 fit 范围用）。
  Future<List<MerchantCoordinate>> getAllCoordinates({
    String? search,
    bool includeClosed = false,
    bool includeOtherRegions = false,
  }) async {
    final response = await _client.dio.get(
      '/merchants/coordinates',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'include_closed': includeClosed,
        'include_other_regions': includeOtherRegions,
      },
    );
    final data = response.data;
    final list = (data is List) ? data : const [];
    return list
        .map((e) => MerchantCoordinate.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final list = (data is List) ? data : ((data['items'] as List?) ?? const []);
    final items = list
        .map((e) => MerchantProductPrice.fromJson(e as Map<String, dynamic>))
        .toList();
    final total =
        (data is Map ? (data['total'] as num?)?.toInt() : null) ?? items.length;
    return MerchantProductPricePage(items: items, total: total);
  }

  /// List regions (GET /regions). Returns region nodes, each containing at least id and name.
  Future<List<Map<String, dynamic>>> listRegions({int? parentId, int? level}) async {
    final params = <String, dynamic>{
      if (parentId != null) 'parent_id': parentId,
      if (level != null) 'level': level,
    };
    final response = await _client.dio.get('/regions', queryParameters: params);
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data is Map ? data['items'] as List? : null) ?? const []);
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Get one region with its ancestor chain (GET /regions/{id}).
  Future<Map<String, dynamic>> getRegion(int id) async {
    final response = await _client.dio.get('/regions/$id');
    final data = response.data;
    return (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }
}

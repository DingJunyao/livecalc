import '../../core/api/api_client.dart';

/// 收藏（原料 / 商品 / 菜谱）通用仓库；商家收藏沿用 MerchantRepository。
class FavoritesRepository {
  final ApiClient _client;
  FavoritesRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  /// 某类型的收藏 id 集合（GET /favorites/{type}）。
  Future<Set<int>> fetchIds(String type) async {
    final response = await _client.dio.get('/favorites/$type');
    final data = response.data;
    final list = data is List
        ? data
        : ((data as Map?)?['items'] as List? ?? const []);
    return list
        .map((e) => ((e as Map)['id'] as num).toInt())
        .toSet();
  }

  Future<void> add(String type, int id) async {
    await _client.dio.post('/favorites/$type/$id');
  }

  Future<void> remove(String type, int id) async {
    await _client.dio.delete('/favorites/$type/$id');
  }
}

import '../../../core/api/api_client.dart';
import '../models/usda_models.dart';

class UsdaRepository {
  final ApiClient _client;
  UsdaRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<List<UsdaFood>> search(String query, {int limit = 50}) async {
    final response = await _client.dio.get(
      '/usda/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    final data = response.data;
    final list = data is List ? data : (data['items'] as List? ?? const []);
    return [
      for (final item in list.cast<Map<String, dynamic>>())
        UsdaFood.fromJson(item),
    ];
  }

  Future<UsdaFood> getFood(int fdcId) async {
    final response = await _client.dio.get('/usda/$fdcId');
    return UsdaFood.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MutationReviewResult> match({
    required String entityType,
    required int entityId,
    required int fdcId,
  }) async {
    if (entityType != 'ingredient' && entityType != 'product') {
      throw ArgumentError.value(entityType, 'entityType');
    }
    final response = await _client.dio.post(
      '/usda/match/$entityType/$entityId',
      data: {'fdc_id': fdcId},
    );
    return MutationReviewResult.fromJson(
      response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : {'success': true},
    );
  }
}

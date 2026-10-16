import '../../../core/api/api_client.dart';

/// 试算方案（与云端 /meal-plans 同契约）。
class PlannerRepository {
  final ApiClient _client;
  PlannerRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<List<Map<String, dynamic>>> list() async {
    final response = await _client.dio.get('/meal-plans');
    final items = (response.data['items'] as List?) ?? const [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> get(int id) async {
    final response = await _client.dio.get('/meal-plans/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required String kind,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _client.dio.post('/meal-plans', data: {
      'name': name,
      'kind': kind,
      'note': note,
      'items': items,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
    int id, {
    String? name,
    String? kind,
    String? note,
    List<Map<String, dynamic>>? items,
  }) async {
    final response = await _client.dio.put('/meal-plans/$id', data: {
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (note != null) 'note': note,
      if (items != null) 'items': items,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(int id) async {
    await _client.dio.delete('/meal-plans/$id');
  }

  Future<Map<String, dynamic>> evaluate({
    required String kind,
    required String mealType,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _client.dio.post('/meal-plans/evaluate', data: {
      'kind': kind,
      'meal_type': mealType,
      'items': items,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> costTrend(int id, {int days = 90}) async {
    final response = await _client.dio
        .get('/meal-plans/$id/cost-trend', queryParameters: {'days': days});
    return ((response.data as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// 全局单位（试算条目选单位用；与 web `GET /units/?limit=500` 同源）
  Future<List<Map<String, dynamic>>> units() async {
    final response =
        await _client.dio.get('/units/', queryParameters: {'limit': 500});
    final data = response.data;
    final items = data is Map ? (data['items'] ?? const []) : data;
    return ((items as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// 试算方案 → 今日推荐
  Future<void> setPlan(int planId, {String? mealType}) async {
    await _client.dio.post('/meals/recommendations/set-plan', data: {
      'plan_id': planId,
      'meal_type': mealType,
    });
  }
}

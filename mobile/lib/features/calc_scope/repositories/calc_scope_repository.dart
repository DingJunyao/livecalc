import '../../../core/api/api_client.dart';
import '../models/calc_scope.dart';

/// 用户自定义计算范围（多地区组合）CRUD。
class CalcScopeRepository {
  final ApiClient _client;

  CalcScopeRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  Future<List<CalcScope>> listScopes() async {
    final response = await _client.dio.get('/calc-scopes');
    final data = response.data;
    final list = (data is List)
        ? data
        : ((data is Map ? data['items'] as List? : null) ?? const []);
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) CalcScope.fromJson(item),
    ];
  }

  Future<CalcScope> createScope(Map<String, dynamic> body) async {
    final response = await _client.dio.post('/calc-scopes', data: body);
    return CalcScope.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CalcScope> updateScope(int id, Map<String, dynamic> body) async {
    final response = await _client.dio.put('/calc-scopes/$id', data: body);
    return CalcScope.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteScope(int id) async {
    await _client.dio.delete('/calc-scopes/$id');
  }
}

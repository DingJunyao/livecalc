import '../../../core/api/api_client.dart';
import '../../../shared/models/nutrition.dart';

class NutritionRepository {
  final ApiClient _client;
  NutritionRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  /// 原料营养（GET /nutrition/ingredients/{id}/nutrition）。
  /// 404（无营养数据）时返回 null。
  Future<NutritionInfo?> getIngredientNutrition(int id) async {
    try {
      final response = await _client
          .dio
          .get('/nutrition/ingredients/$id/nutrition');
      return NutritionInfo.fromJson(response.data as Map<String, dynamic>);
    } on Exception catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  /// 商品营养（GET /nutrition/products/{id}/nutrition，含继承原料的数据）。
  Future<NutritionInfo?> getProductNutrition(int id) async {
    try {
      final response =
          await _client.dio.get('/nutrition/products/$id/nutrition');
      return NutritionInfo.fromJson(response.data as Map<String, dynamic>);
    } on Exception catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  Future<void> saveIngredientNutrition(
    int id,
    List<NutrientEntry> nutrients,
  ) async {
    await _client.dio.post(
      '/nutrition/ingredients/$id/nutrition',
      data: _payload(nutrients),
    );
  }

  Future<void> saveProductNutrition(
    int id,
    List<NutrientEntry> nutrients,
  ) async {
    await _client.dio.post(
      '/nutrition/products/$id/nutrition',
      data: _payload(nutrients),
    );
  }

  /// 清空商品自定义营养（回退到继承原料数据）。
  Future<void> clearProductNutrition(int id) async {
    await _client.dio.put('/products/entity/$id/nutrition', data: null);
  }

  Map<String, dynamic> _payload(List<NutrientEntry> nutrients) {
    return {
      'base_quantity': 100,
      'base_unit': 'g',
      'source': 'custom',
      'nutrients': [
        for (final n in nutrients)
          {
            'name': n.label,
            'value': n.value,
            'unit': n.unit,
            if (n.originalKey != null && n.originalKey!.isNotEmpty)
              'key': n.originalKey,
          },
      ],
    };
  }
}

/// Home repository: calls backend api to fetch today's meal recommendations.
library;

import '../../../core/api/api_client.dart';
import '../models/meal_recommendation.dart';

class HomeRepository {
  final ApiClient _client;

  HomeRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<DailyRecommendation> getTodayRecommendation() async {
    final response = await _client.dio.get('/meals/recommendations');
    return DailyRecommendation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DailyRecommendation> triggerGenerate({String? preference}) async {
    final response = await _client.dio.post(
      '/meals/recommendations/generate',
      data: preference != null && preference.isNotEmpty
          ? {'preference': preference}
          : null,
    );
    return DailyRecommendation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DailyRecommendation> refreshMeal(
    String mealType, {
    int? recipeId,
    String? preference,
  }) async {
    final response = await _client.dio.post(
      '/meals/recommendations/refresh',
      data: {
        'meal_type': mealType,
        'recipe_id': recipeId,
        'preference': preference,
      },
    );
    return DailyRecommendation.fromJson(response.data as Map<String, dynamic>);
  }
}

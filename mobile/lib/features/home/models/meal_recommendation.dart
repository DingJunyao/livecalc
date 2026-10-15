/// 套餐中的一道菜（多道菜推荐，与云端 RecommendedDish 同构）。
class RecommendedDish {
  final int recipeId;
  final String name;
  final String? category;
  final double? estimatedCost;
  final String? currency;
  final String? imageUrl;
  final double? calories;
  final String role; // staple / main / side / soup / drink
  final String? reason;

  const RecommendedDish({
    required this.recipeId,
    required this.name,
    this.category,
    this.estimatedCost,
    this.currency,
    this.imageUrl,
    this.calories,
    this.role = 'main',
    this.reason,
  });

  factory RecommendedDish.fromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition_per_serving'] as Map<String, dynamic>?;
    return RecommendedDish(
      recipeId: json['id'] as int,
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      estimatedCost: (json['cost_estimate'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      imageUrl: (json['image_urls'] as List<dynamic>?)?.firstOrNull?.toString(),
      calories: (nutrition?['calories'] as num?)?.toDouble(),
      role: json['role'] as String? ?? 'main',
      reason: json['reason'] as String?,
    );
  }
}

class MealRecommendation {
  final String mealType; // breakfast, lunch, dinner
  final int? recipeId;
  final String? recipeName;
  final double? estimatedCost;
  final String? imageUrl;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final bool isCurrentMeal;
  /// 多道菜套餐（新）；[recipeId]/[recipeName] 为 staple（无则首道）菜的兼容别名。
  final List<RecommendedDish> dishes;
  final String? source; // rule / system_ai / user_ai / plan
  final String? reason;
  final String? preference;

  const MealRecommendation({
    required this.mealType,
    this.recipeId,
    this.recipeName,
    this.estimatedCost,
    this.imageUrl,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.isCurrentMeal = false,
    this.dishes = const [],
    this.source,
    this.reason,
    this.preference,
  });

  bool get isAiSource => source == 'system_ai' || source == 'user_ai';

  factory MealRecommendation.fromJson(Map<String, dynamic> json) {
    final recipe = json['recipe'] as Map<String, dynamic>?;
    final nutrition = recipe?['nutrition_per_serving'] as Map<String, dynamic>?;
    return MealRecommendation(
      mealType: json['meal_type'] as String? ?? '',
      recipeId: recipe?['id'] as int?,
      recipeName: recipe?['name'] as String?,
      estimatedCost: (recipe?['cost_estimate'] as num?)?.toDouble(),
      imageUrl:
          (recipe?['image_urls'] as List<dynamic>?)?.firstOrNull?.toString(),
      calories: (nutrition?['calories'] as num?)?.toDouble(),
      proteinG: (nutrition?['protein_g'] as num?)?.toDouble(),
      carbsG: (nutrition?['carbs_g'] as num?)?.toDouble(),
      fatG: (nutrition?['fat_g'] as num?)?.toDouble(),
      isCurrentMeal: json['is_current_meal'] as bool? ?? false,
      dishes: (json['dishes'] as List<dynamic>?)
              ?.map((e) =>
                  RecommendedDish.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      source: json['source'] as String?,
      reason: json['reason'] as String?,
      preference: json['preference'] as String?,
    );
  }
}

class DailyRecommendation {
  final String date;
  final String status;
  final List<MealRecommendation> meals;
  final List<String> refreshingMeals;
  final Map<String, dynamic>? totals;

  const DailyRecommendation({
    required this.date,
    this.status = 'ready',
    this.meals = const [],
    this.refreshingMeals = const [],
    this.totals,
  });

  factory DailyRecommendation.fromJson(Map<String, dynamic> json) {
    return DailyRecommendation(
      date: json['date'] as String? ?? '',
      status: json['status'] as String? ?? 'ready',
      meals: (json['recommendations'] as List<dynamic>?)
              ?.map(
                  (e) => MealRecommendation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      refreshingMeals: (json['refreshing_meals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      totals: json['totals'] as Map<String, dynamic>?,
    );
  }
}

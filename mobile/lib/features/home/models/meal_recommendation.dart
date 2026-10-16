/// 套餐中的一道菜（多道菜推荐，与云端 RecommendedDish 同构）。
class RecommendedDish {
  final int recipeId;
  final String name;
  final String? category;
  final double? estimatedCost;
  final String? currency;
  final String? imageUrl;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
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
    this.proteinG,
    this.carbsG,
    this.fatG,
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
      proteinG: (nutrition?['protein_g'] as num?)?.toDouble(),
      carbsG: (nutrition?['carbs_g'] as num?)?.toDouble(),
      fatG: (nutrition?['fat_g'] as num?)?.toDouble(),
      role: json['role'] as String? ?? 'main',
      reason: json['reason'] as String?,
    );
  }
}

/// 一组营养合计（[energy] 为库存 kcal，其余为 g）。
class MealNutrients {
  final double energy;
  final double protein;
  final double carbohydrate;
  final double fat;

  const MealNutrients({
    this.energy = 0,
    this.protein = 0,
    this.carbohydrate = 0,
    this.fat = 0,
  });
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
  /// 试算方案来源餐（source='plan'）
  final int? planId;
  final String? planName;
  final String? planKind;
  final List<MealPlanItemBrief> planItems;
  final double? planCost;
  final double? planCalories;
  final double? planProteinG;
  final double? planCarbsG;
  final double? planFatG;

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
    this.planId,
    this.planName,
    this.planKind,
    this.planItems = const [],
    this.planCost,
    this.planCalories,
    this.planProteinG,
    this.planCarbsG,
    this.planFatG,
  });

  bool get isAiSource => source == 'system_ai' || source == 'user_ai';

  /// 多道菜合计营养（逐道 nutrition_per_serving 相加，与 web 餐卡同口径）。
  MealNutrients get dishNutrients {
    var energy = 0.0;
    var protein = 0.0;
    var carbohydrate = 0.0;
    var fat = 0.0;
    for (final dish in dishes) {
      energy += dish.calories ?? 0;
      protein += dish.proteinG ?? 0;
      carbohydrate += dish.carbsG ?? 0;
      fat += dish.fatG ?? 0;
    }
    return MealNutrients(
      energy: energy,
      protein: protein,
      carbohydrate: carbohydrate,
      fat: fat,
    );
  }

  /// 多道菜合计成本；一道成本都没有时返回 null（显示 --）。
  double? get dishCost {
    var sum = 0.0;
    var found = false;
    for (final dish in dishes) {
      final cost = dish.estimatedCost;
      if (cost == null) continue;
      found = true;
      sum += cost;
    }
    return found ? sum : null;
  }

  /// 方案来源餐的营养合计。
  MealNutrients get planNutrients => MealNutrients(
        energy: planCalories ?? 0,
        protein: planProteinG ?? 0,
        carbohydrate: planCarbsG ?? 0,
        fat: planFatG ?? 0,
      );

  factory MealRecommendation.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>?;
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
      planId: plan?['id'] as int?,
      planName: plan?['name'] as String?,
      planKind: plan?['kind'] as String?,
      planItems: (plan?['items'] as List<dynamic>?)
              ?.map((e) =>
                  MealPlanItemBrief.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      planCost: ((plan?['totals'] as Map<String, dynamic>?)?['cost'] as num?)
          ?.toDouble(),
      planCalories: ((plan?['totals'] as Map<String, dynamic>?)?['calories']
              as num?)
          ?.toDouble(),
      planProteinG: ((plan?['totals'] as Map<String, dynamic>?)?['protein_g']
              as num?)
          ?.toDouble(),
      planCarbsG: ((plan?['totals'] as Map<String, dynamic>?)?['carbs_g']
              as num?)
          ?.toDouble(),
      planFatG: ((plan?['totals'] as Map<String, dynamic>?)?['fat_g'] as num?)
          ?.toDouble(),
    );
  }
}

/// 方案来源餐的条目（名称 + 成本 + 可跳转的实体 id / 首图）
class MealPlanItemBrief {
  final String? itemType; // recipe / ingredient / product
  final String? name;
  final double? cost;
  final int? recipeId;
  final int? ingredientId;
  final int? productId;
  final String? imageUrl;

  const MealPlanItemBrief({
    this.itemType,
    this.name,
    this.cost,
    this.recipeId,
    this.ingredientId,
    this.productId,
    this.imageUrl,
  });

  factory MealPlanItemBrief.fromJson(Map<String, dynamic> json) {
    return MealPlanItemBrief(
      itemType: json['item_type'] as String?,
      name: json['name'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      recipeId: json['recipe_id'] as int?,
      ingredientId: json['ingredient_id'] as int?,
      productId: json['product_id'] as int?,
      imageUrl: (json['image_urls'] as List<dynamic>?)?.firstOrNull?.toString(),
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

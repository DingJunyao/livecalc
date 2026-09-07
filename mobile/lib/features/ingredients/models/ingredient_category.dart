import '../../../l10n/app_localizations.dart';

class IngredientCategory {
  final int id;
  final String name;
  final String displayName;
  final String? description;

  const IngredientCategory({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
  });

  factory IngredientCategory.fromJson(Map<String, dynamic> json) {
    return IngredientCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      displayName:
          json['display_name'] as String? ?? json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  String localizedDisplayName(AppLocalizations l10n) => switch (name) {
        'grains' => l10n.ingredientCategoryGrains,
        'vegetables' => l10n.ingredientCategoryVegetables,
        'fruits' => l10n.ingredientCategoryFruits,
        'meat' => l10n.ingredientCategoryMeat,
        'seafood' => l10n.ingredientCategorySeafood,
        'eggs' => l10n.ingredientCategoryEggs,
        'dairy' => l10n.ingredientCategoryDairy,
        'soy' => l10n.ingredientCategorySoy,
        'seasoning' => l10n.ingredientCategorySeasoning,
        'oil' => l10n.ingredientCategoryOil,
        'nuts' => l10n.ingredientCategoryNuts,
        'beverages' => l10n.ingredientCategoryBeverages,
        'others' => l10n.ingredientCategoryOthers,
        _ => displayName,
      };
}

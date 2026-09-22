export const RECIPE_CATEGORY_KEYS: Record<string, string> = {
  '荤菜': 'recipeCategories.meatDish',
  '素菜': 'recipeCategories.vegetableDish',
  '水产': 'recipeCategories.seafood',
  '主食': 'recipeCategories.staple',
  '汤与粥': 'recipeCategories.soupPorridge',
  '早餐': 'recipeCategories.breakfast',
  '甜品': 'recipeCategories.dessert',
  '调料': 'recipeCategories.seasoning',
  '半成品': 'recipeCategories.semiFinished',
  '小食': 'recipeCategories.snack',
}

export const RECIPE_CATEGORY_VALUES = Object.keys(RECIPE_CATEGORY_KEYS)

export const DEFAULT_RECIPE_CATEGORY = RECIPE_CATEGORY_VALUES[0]

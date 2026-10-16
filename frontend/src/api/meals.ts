// api/meals.ts
import { api } from './index'

export interface NutritionPerServing {
  calories: number
  protein_g: number
  carbs_g: number
  fat_g: number
}

export interface RecipeBrief {
  id: number
  name: string
  category?: string
  images?: string[]
  image_urls?: string[]  // 已解析的完整 URL（S3 直连 / local 路径）
  servings: number
  cost_estimate?: number
  currency?: string | null
  nutrition_per_serving?: NutritionPerServing | null
}

export type DishRole = 'staple' | 'main' | 'side' | 'soup' | 'drink'

export interface RecommendedDish extends RecipeBrief {
  role: DishRole
  reason?: string | null
}

export interface MealPlanBriefItem {
  item_type: 'recipe' | 'ingredient' | 'product' | string
  name?: string | null
  group?: string | null
  servings?: number | null
  quantity?: number | null
  unit?: string | null
  cost: number | null
}

/** 方案来源餐的方案视图（source='plan' 时后端返回） */
export interface MealPlanBrief {
  id: number
  name: string
  kind: 'meal' | 'day' | string
  note?: string | null
  items: MealPlanBriefItem[]
  totals: {
    cost: number
    currency: string | null
    calories: number
    protein_g: number
    carbs_g: number
    fat_g: number
  }
}

export interface MealRecommendation {
  meal_type: 'breakfast' | 'lunch' | 'dinner'
  recipe: RecipeBrief | null
  /** 多道菜套餐（新）；recipe 为 staple（无则首道）菜的兼容别名 */
  dishes?: RecommendedDish[]
  /** 试算方案来源餐：渲染方案视图 */
  plan?: MealPlanBrief | null
  source?: 'rule' | 'system_ai' | 'user_ai' | 'plan' | null
  reason?: string | null
  preference?: string | null
  is_current_meal: boolean
}

export interface DailyTotals {
  cost?: number
  currency?: string | null
  calories?: number
  protein_g?: number
  carbs_g?: number
  fat_g?: number
  refresh_counts?: Record<string, number>
}

export interface DailyRecommendationsResponse {
  status: 'ready' | 'not_generated' | 'generating'
  date: string
  recommendations: MealRecommendation[]
  totals?: DailyTotals
  /** 当前正在后台刷新的餐类 */
  refreshing_meals?: string[]
}

/** 获取今日三餐推荐（轻量，不触发计算） */
export async function getDailyRecommendations(): Promise<DailyRecommendationsResponse> {
  return api.get('/meals/recommendations') as any
}

/** 触发后台生成今日推荐（可带一句话偏好） */
export async function triggerRecommendationGeneration(preference?: string): Promise<DailyRecommendationsResponse> {
  return api.post(
    '/meals/recommendations/generate',
    preference ? { preference } : undefined
  ) as any
}

/** 刷新某一餐推荐：recipeId 为空 = 整餐重搭；给定 = 单道换 */
export async function refreshMealRecommendation(
  mealType: string,
  recipeId?: number,
  preference?: string
): Promise<DailyRecommendationsResponse> {
  return api.post('/meals/recommendations/refresh', {
    meal_type: mealType,
    recipe_id: recipeId ?? null,
    preference: preference ?? null,
  }) as any
}

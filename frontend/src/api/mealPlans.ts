// api/mealPlans.ts — 试算方案（与云端后端同契约）
import { api } from './index'
import type { NutritionPerServing } from './meals'

export type PlanKind = 'meal' | 'day'
export type PlanItemType = 'recipe' | 'ingredient' | 'product'
export type PlanGroup = 'breakfast' | 'lunch' | 'dinner' | 'other'

export interface PlanItem {
  id?: number
  group: PlanGroup
  item_type: PlanItemType
  recipe_id?: number | null
  ingredient_id?: number | null
  product_id?: number | null
  name?: string | null
  servings?: number | null
  quantity?: number | null
  unit_id?: number | null
  unit?: string | null
  sort_order: number
  note?: string | null
}

export interface MealPlan {
  id: number
  name: string
  kind: PlanKind
  note?: string | null
  items: PlanItem[]
  created_at?: string | null
  updated_at?: string | null
}

export interface PlanEvaluationItem {
  item_id?: number
  item_type: PlanItemType
  group?: PlanGroup
  name?: string
  servings?: number | null
  quantity?: number | null
  unit?: string | null
  cost: number | null
  currency: string | null
  nutrition: NutritionPerServing | null
}

export interface PlanNutrientValue {
  value: number
  unit: string
  key?: string
  nrp_pct?: number | null
  standard?: string
}

export interface PlanNutrition {
  per_serving_nutrition?: {
    core_nutrients?: Record<string, PlanNutrientValue>
    all_nutrients?: Record<string, PlanNutrientValue>
  }
  /** 各条目对每个营养素（英文 key）的贡献，供「营养来源」组件用 */
  ingredient_details?: {
    ingredient_id?: number
    ingredient_name?: string
    item_type?: PlanItemType
    nutrition_contribution?: Record<string, { value: number; unit?: string }>
  }[]
}

export interface PlanEvaluation {
  items: PlanEvaluationItem[]
  totals: {
    cost: number
    currency: string | null
    calories: number
    protein_g: number
    carbs_g: number
    fat_g: number
  }
  targets: Record<string, number>
  deltas: Record<string, number>
  /** 全部营养素（含 NRV%）与各条目贡献；空对象=该方案没有营养数据 */
  nutrition?: PlanNutrition
}

export interface PlanTrendPoint {
  date: string
  total_cost: number
  /** 当日成本区间（逐条目 min/max 求和），旧接口可能没有 */
  min_cost?: number
  max_cost?: number
  avg_cost?: number
  currency: string | null
}

export interface PlanItemInput {
  group: PlanGroup
  item_type: PlanItemType
  recipe_id?: number | null
  ingredient_id?: number | null
  product_id?: number | null
  servings?: number | null
  quantity?: number | null
  unit_id?: number | null
  sort_order?: number
  note?: string | null
}

export async function listPlans(): Promise<{ items: MealPlan[] }> {
  return api.get('/meal-plans') as any
}

export async function getPlan(id: number): Promise<MealPlan> {
  return api.get(`/meal-plans/${id}`) as any
}

export async function createPlan(body: {
  name: string
  kind: PlanKind
  note?: string | null
  items: PlanItemInput[]
}): Promise<MealPlan> {
  return api.post('/meal-plans', body) as any
}

export async function updatePlan(
  id: number,
  body: { name?: string; kind?: PlanKind; note?: string | null; items?: PlanItemInput[] }
): Promise<MealPlan> {
  return api.put(`/meal-plans/${id}`, body) as any
}

export async function deletePlan(id: number): Promise<void> {
  await api.delete(`/meal-plans/${id}`)
}

export async function evaluatePlan(body: {
  kind: PlanKind
  meal_type?: 'breakfast' | 'lunch' | 'dinner'
  items: PlanItemInput[]
}): Promise<PlanEvaluation> {
  return api.post('/meal-plans/evaluate', body) as any
}

export async function getPlanCostTrend(
  id: number,
  days = 90,
  offsetDays = 0
): Promise<PlanTrendPoint[]> {
  return api.get(`/meal-plans/${id}/cost-trend`, {
    params: { days, offset_days: offsetDays },
  }) as any
}

/** 试算方案 → 今日推荐（kind=meal 需 mealType；kind=day 一次设三餐） */
export async function setPlanAsRecommendation(
  planId: number,
  mealType?: 'breakfast' | 'lunch' | 'dinner'
): Promise<any> {
  return api.post('/meals/recommendations/set-plan', {
    plan_id: planId,
    meal_type: mealType ?? null,
  }) as any
}

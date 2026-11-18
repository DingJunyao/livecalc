// api/comparison.ts — 跨地区物价对比（与云端后端同契约）。
// 后端：backend/app/api/comparison.py（口径说明见该模块 docstring）。
// 卡片价 = 每标准单位综合价口径；趋势 = ¥/斤 归一（与列表迷你图同口径）。
import { api } from './index'

export interface RegionCandidate {
  region_id: number
  code?: string | null
  name: string
  name_en?: string | null
  display_name: string
  level: number
  path?: string | null
  record_count: number
  merchant_count: number
}

export interface RegionCandidatesResponse {
  regions: RegionCandidate[]
}

export interface RegionSummaryItem {
  region_id: number
  name: string
  display_name: string
  record_count: number
  entity_count: number
  price_index: number | null
  /** 篮子日均价（¥/斤，用户币种），前向填充到今天 */
  trend: number[]
}

export interface ComparisonSummary {
  currency: string
  base_region_id: number
  basket_size: number
  regions: RegionSummaryItem[]
}

export interface RegionMeta {
  region_id: number
  name: string
  display_name: string
  level: number
}

export interface EntityRegionPrice {
  price: number | null
  is_stale: boolean
  days_since_record: number | null
  participant_count: number
  unit: string | null
  trend: number[]
}

export interface EntityPriceRow {
  entity_id: number
  name: string
  unit: string | null
  /** 键为 region_id 字符串；该地区无数据时为 null */
  regions: Record<string, EntityRegionPrice | null>
}

export interface EntityPricesResponse {
  currency: string
  trend_unit: string
  regions: RegionMeta[]
  entities: EntityPriceRow[]
}

/** 有价格记录的地区候选（按记录数降序）。 */
export async function getComparisonRegions(): Promise<RegionCandidatesResponse> {
  return await api.get('/comparison/regions') as RegionCandidatesResponse
}

/** 各地区概览（物价指数 + 篮子趋势）；regionIds 第一个为基准地区。 */
export async function getComparisonSummary(regionIds: number[], days = 30): Promise<ComparisonSummary> {
  return await api.get('/comparison/summary', {
    params: { region_ids: regionIds.join(','), days },
  }) as ComparisonSummary
}

/** 实体×地区价格矩阵。entityType: 'ingredient' | 'product'。 */
export async function getComparisonEntityPrices(
  entityType: 'ingredient' | 'product',
  entityIds: number[],
  regionIds: number[],
  days = 30,
): Promise<EntityPricesResponse> {
  return await api.get('/comparison/entity-prices', {
    params: {
      entity_type: entityType,
      entity_ids: entityIds.join(','),
      region_ids: regionIds.join(','),
      days,
    },
  }) as EntityPricesResponse
}

// ==================== 二期：菜谱 / 试算成本对比 ====================

export interface RecipeBreakdownItem {
  ingredient_name: string | null
  ingredient_id: number | null
  quantity: number | null
  cost: number | null
  fallback_chain: string | null
  aggregation_chain: string | null
  price_recorded_at: string | null
}

export interface RecipeRegionCost {
  total_cost: number | null
  cost_per_serving: number | null
  currency: string | null
  missing_ingredients: string[]
  breakdown: RecipeBreakdownItem[]
}

export interface RecipeCostRow {
  recipe_id: number
  name: string
  /** 键为 region_id 字符串；该地区无数据时为 null */
  regions: Record<string, RecipeRegionCost | null>
}

export interface RecipeCostsResponse {
  currency: string
  regions: RegionMeta[]
  recipes: RecipeCostRow[]
}

export interface RecipeCostTrendPoint {
  date: string
  min_cost?: number
  max_cost?: number
  avg_cost: number
  has_record?: boolean
}

/** 菜谱×地区成本矩阵（明细里 cost=null 的行即该地区缺价食材）。 */
export async function getComparisonRecipeCosts(
  recipeIds: number[],
  regionIds: number[],
): Promise<RecipeCostsResponse> {
  return await api.get('/comparison/recipe-costs', {
    params: { recipe_ids: recipeIds.join(','), region_ids: regionIds.join(',') },
  }) as RecipeCostsResponse
}

/** 单菜谱的多地区成本趋势（键为 region_id 字符串）。 */
export async function getComparisonRecipeCostTrend(
  recipeId: number,
  regionIds: number[],
  days = 30,
): Promise<{ regions: Record<string, RecipeCostTrendPoint[]> }> {
  return await api.get('/comparison/recipe-cost-trend', {
    params: { recipe_id: recipeId, region_ids: regionIds.join(','), days },
  })
}

export interface PlanRegionTotals {
  region_id: number
  totals: {
    cost?: number
    currency?: string | null
    calories?: number
    protein_g?: number
    carbs_g?: number
    fat_g?: number
  }
}

/** 同一组试算条目在 N 个地区分别求值（试算详情合计卡口径切换）。 */
export async function postComparisonPlanEvaluateRegions(
  items: Array<Record<string, any>>,
  regionIds: number[],
  kind = 'meal',
  mealType = 'lunch',
): Promise<{ regions: PlanRegionTotals[] }> {
  return await api.post('/comparison/plan-evaluate-regions', {
    kind, meal_type: mealType, items, region_ids: regionIds,
  })
}

export interface PlanCostRow {
  plan_id: number
  name: string
  regions: Record<string, PlanRegionTotals['totals'] | null>
}

/** 已保存方案×地区合计对照（试算对比 tab）。 */
export async function getComparisonPlanCosts(
  planIds: number[],
  regionIds: number[],
): Promise<{ plans: PlanCostRow[]; regions: number[] }> {
  return await api.get('/comparison/plan-costs', {
    params: { plan_ids: planIds.join(','), region_ids: regionIds.join(',') },
  })
}

/** 单方案的多地区成本趋势（键为 region_id 字符串，点为 plan_cost_trend 结构）。 */
export async function getComparisonPlanCostTrend(
  planId: number,
  regionIds: number[],
  days = 30,
): Promise<{ regions: Record<string, RecipeCostTrendPoint[]> }> {
  return await api.get('/comparison/plan-cost-trend', {
    params: { plan_id: planId, region_ids: regionIds.join(','), days },
  })
}

// ==================== 三期：商家物价热力图 ====================

export interface HeatmapItem {
  merchant_id: number
  name: string
  latitude: number
  longitude: number
  price: number
  is_stale: boolean
  sample_count: number
  price_index?: number | null
}

export interface HeatmapBuckets {
  p25?: number | null
  p50?: number | null
  p75?: number | null
  p90?: number | null
}

export interface HeatmapResponse {
  mode: 'item' | 'overall'
  currency: string
  unit: string
  entity_type?: string | null
  entity_id?: number | null
  basket_size?: number | null
  buckets: HeatmapBuckets
  items: HeatmapItem[]
}

/** 商家物价热力图数据（mode=item 需 entity_type+entity_id）。 */
export async function getComparisonHeatmap(
  mode: 'item' | 'overall',
  regionIds: number[],
  opts: { entityType?: 'ingredient' | 'product'; entityId?: number } = {},
): Promise<HeatmapResponse> {
  return await api.get('/comparison/heatmap', {
    params: {
      mode,
      region_ids: regionIds.join(','),
      ...(mode === 'item' ? { entity_type: opts.entityType, entity_id: opts.entityId } : {}),
    },
  }) as HeatmapResponse
}

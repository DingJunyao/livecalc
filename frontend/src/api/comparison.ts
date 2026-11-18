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

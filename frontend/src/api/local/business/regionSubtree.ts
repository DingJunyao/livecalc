// 本地地区子树工具：根据所选地区返回其自身及全部下级地区 id。
// 语义与后端 price_region.py 的 region_subtree_ids 对齐。
import { getAll } from '../database'

/**
 * 返回 regionId 自身及全部下级地区 id。
 * - regionId == null 时返回 null（调用方保持全局聚合）。
 * - regionId 找不到时返回空数组（无任何商家落在该地区）。
 */
export async function regionSubtreeIds(regionId: number | null): Promise<number[] | null> {
  if (regionId == null) return null

  const all: any[] = await getAll('regions')
  const target = all.find((r: any) => Number(r.id) === Number(regionId) && r.is_active !== false)
  if (!target) return []

  const prefix = String(target.path || '').replace(/\/+$/, '')
  const result: number[] = []
  const seen = new Set<number>()

  const push = (id: any) => {
    const n = Number(id)
    if (Number.isFinite(n) && !seen.has(n)) {
      seen.add(n)
      result.push(n)
    }
  }

  push(target.id)

  // path 前缀匹配：自身 path 等于 prefix，或下级 path 以 prefix + '/' 开头。
  for (const r of all) {
    if (r.is_active === false) continue
    if (Number(r.id) === Number(target.id)) continue
    const path = String(r.path || '')
    if (!prefix) {
      // 目标自身没有 path（异常数据）：仅返回自身。
      continue
    }
    if (path === prefix || path.startsWith(prefix + '/')) {
      push(r.id)
    }
  }

  return result
}

export interface RegionFilterContext {
  regionId: number | null
  allowedRegionIds: number[] | null
  merchantRegions: Record<number, number | null>
}

/** 一次性构建地区过滤上下文：允许的 region id 集合 + 商家 region 映射。 */
export async function buildRegionFilter(regionId: number | null): Promise<RegionFilterContext> {
  const allowedRegionIds = await regionSubtreeIds(regionId)
  const merchants: any[] = await getAll('merchants')
  const merchantRegions: Record<number, number | null> = {}
  for (const m of merchants) {
    if (m.id != null) merchantRegions[m.id] = m.region_id ?? null
  }
  return { regionId, allowedRegionIds, merchantRegions }
}

/**
 * 按地区过滤价格记录（纯函数）。
 * 商家无 region、记录无 merchant_id 时排除。
 */
export function filterRecordsByRegion<T extends { merchant_id?: number | null }>(
  records: T[],
  regionId: number | null,
  allowedRegionIds: number[] | null,
  merchantRegions?: Record<number, number | null>,
): T[] {
  if (regionId == null) return records
  const allowed = new Set(allowedRegionIds ?? [])
  return records.filter((r) => {
    const mid = r.merchant_id
    if (mid == null) return false
    const rid = merchantRegions?.[mid]
    if (rid == null) return false
    return allowed.has(rid)
  })
}
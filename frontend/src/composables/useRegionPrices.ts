// 跨地区价格对比组合式函数（原料/商品详情页共用）。
// - 地区候选：会话级模块缓存（整个 App 只拉一次）
// - 实体各地区价格卡：/comparison/entity-prices（卡片价 = 每标准单位综合价口径）
// - 记录按地区分组序列：与「按商家」对比同构——同一批图表记录按
//   merchant_region_id 分组、同一 buildWeightedAsOfDailySeries 口径，保证
//   「综合 / 按商家 / 按地区」三种模式在同一张图上刻度一致。
import { api } from '@/api'
import { buildWeightedAsOfDailySeries, toLocalDayKey } from '@/utils/priceAsOf'

export interface RegionPriceCard {
  regionId: number
  name: string
  price: number | null
  unit: string | null
  isStale: boolean
  isLowest: boolean
  daysSince: number | null
  trend: number[]
}

export interface RegionMetaLite {
  region_id: number
  display_name: string
}

export interface RegionSeriesPoint {
  date: string
  min: number
  max: number
  avg: number
  count: number
  recorded: boolean
}

export interface RegionSeries {
  merchantId: number | null
  name: string
  data: RegionSeriesPoint[]
}

// 详情页默认对比的地区数（与商家对比 chips 默认前 3 家一致）
export const REGION_COMPARE_DEFAULT_COUNT = 3

// 会话级地区候选缓存
let candidatesCache: RegionMetaLite[] | null = null

/** 有价格记录的地区候选（记录数降序）。失败时返回空数组并缓存，避免反复请求。 */
export async function fetchPricedRegions(): Promise<RegionMetaLite[]> {
  if (candidatesCache) return candidatesCache
  try {
    const res: any = await api.get('/comparison/regions')
    candidatesCache = (res?.regions || []).map((r: any) => ({
      region_id: Number(r.region_id),
      display_name: r.display_name || r.name,
    }))
  } catch {
    candidatesCache = []
  }
  return candidatesCache
}

/** 拉取单实体的各地区价格卡（默认取候选前 N 个地区）。 */
export async function loadEntityRegionPrices(
  entityType: 'ingredient' | 'product',
  entityId: number,
  regionIds?: number[],
): Promise<{ regions: RegionMetaLite[]; cards: RegionPriceCard[] }> {
  const ids = regionIds?.length
    ? regionIds
    : (await fetchPricedRegions()).slice(0, REGION_COMPARE_DEFAULT_COUNT).map(r => r.region_id)
  if (!ids.length) return { regions: [], cards: [] }
  const res: any = await api.get('/comparison/entity-prices', {
    params: {
      entity_type: entityType,
      entity_ids: entityId,
      region_ids: ids.join(','),
      days: 30,
    },
  })
  const namesById = new Map<number, string>()
  for (const r of res?.regions || []) {
    namesById.set(Number(r.region_id), r.display_name || r.name)
  }
  const row = (res?.entities || [])[0]
  const cards: RegionPriceCard[] = []
  if (row) {
    for (const [ridStr, cell] of Object.entries<any>(row.regions || {})) {
      if (!cell || cell.price == null) continue
      cards.push({
        regionId: Number(ridStr),
        name: namesById.get(Number(ridStr)) || ridStr,
        price: Number(cell.price),
        unit: cell.unit || null,
        isStale: !!cell.is_stale,
        isLowest: false,
        daysSince: cell.days_since_record != null ? Number(cell.days_since_record) : null,
        trend: Array.isArray(cell.trend) ? cell.trend.map(Number).filter(v => isFinite(v)) : [],
      })
    }
  }
  // 最低价标注：非陈旧里最低（单条不标，与商家卡一致）
  const fresh = cards.filter(c => !c.isStale)
  if (fresh.length >= 2) {
    const min = Math.min(...fresh.map(c => c.price as number))
    for (const c of fresh) c.isLowest = c.price === min
  }
  return { regions: res?.regions || [], cards }
}

/** 记录的地区 id（后端记录序列化带 merchant_region_id）。 */
export function recordRegionId(record: { merchant_region_id?: number | null; merchant_id?: number | null }): number | null {
  const rid = record.merchant_region_id
  return rid != null ? Number(rid) : null
}

/** 记录按地区分组 → 多地区 as-of 序列（与 merchantComparisonSeries 同构同口径）。
 * 未分配地区的记录不进任何地区线（它们只参与「综合」）。 */
export function buildRegionSeriesFromRecords<T>(
  records: T[],
  opts: {
    /** 记录 → 图表点（与主序列同一归一口径）；返回 null 剔除 */
    toPoint: (record: T) => { date: string; value: number } | null
    /** 商品权重（与主序列一致） */
    weightOf: (pid: number | null) => number
    /** 窗口起点（本地日 YYYY-MM-DD），undefined = 全部 */
    startDay?: string
    /** 地区名（候选缓存） */
    namesById: Map<number, string>
    unknownLabel: string
  },
): RegionSeries[] {
  if (!records?.length) return []
  const byRegion = new Map<number, Array<{ date: string; value: number }>>()
  const recordDaysByRegion = new Map<number, Set<string>>()
  for (const record of records) {
    const rid = recordRegionId(record as any)
    if (rid == null) continue
    const p = opts.toPoint(record)
    if (!p) continue
    if (!byRegion.has(rid)) {
      byRegion.set(rid, [])
      recordDaysByRegion.set(rid, new Set())
    }
    byRegion.get(rid)!.push(p)
    const day = toLocalDayKey(p.date)
    if (day) recordDaysByRegion.get(rid)!.add(day)
  }
  const out: RegionSeries[] = []
  for (const [rid, points] of byRegion) {
    const series = buildWeightedAsOfDailySeries(points, opts.weightOf, {
      startDay: opts.startDay,
      backfillSparse: true,
      bandFromRecords: true,
    }).map((d: any) => ({
      date: d.date,
      min: d.min,
      max: d.max,
      avg: d.avg,
      count: d.count,
      recorded: recordDaysByRegion.get(rid)!.has(d.date),
    }))
    if (series.length === 0) continue
    out.push({
      merchantId: rid,
      name: opts.namesById.get(rid) || opts.unknownLabel,
      data: series,
    })
  }
  return out
}

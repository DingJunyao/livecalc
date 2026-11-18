// 跨地区物价对比 handler — 与云端 /comparison/* 同契约。
// 口径与后端 comparison.py 对齐：卡片价 = 每标准单位综合价（30 天参与上限、
// 全部超期放开）；趋势 = ¥/斤 前向携带加权（buildWeightedAsOfDailySeries，
// 与本地 sparklines 同源）。地区子树经 regionSubtree.ts。

import { getAll } from '../database'
import { normalizeRecordToJin } from '../business/priceNormalize'
import { buildWeightedAsOfDailySeries, toLocalDayKey } from '@/utils/priceAsOf'
import { regionSubtreeIds } from '../business/regionSubtree'
import { DEFAULT_USER_CURRENCY } from '../database'
import { localError } from '../../../utils/localErrors'
import { CHINESE_JIN_NAME } from '../../../data/localValues.ts'
import type { UnitInfo, EntityOverride, DensityInfo } from '../business/unitConverter'

const STALE_DAYS = 30
const BASKET_WINDOW_DAYS = 365
const MAX_REGIONS = 6
const MAX_ENTITIES = 50

function parseIds(raw: string | undefined, limit: number): number[] {
  const out: number[] = []
  for (const part of String(raw || '').split(',')) {
    const t = part.trim()
    if (!t) continue
    const v = parseInt(t, 10)
    if (!Number.isFinite(v) || v <= 0) throw localError('invalidIdList')
    if (!out.includes(v)) out.push(v)
  }
  if (!out.length) throw localError('idListRequired')
  if (out.length > limit) throw localError('idListTooLong', 400, { limit })
  return out
}

interface LocalContext {
  records: any[]
  merchants: any[]
  merchantRegion: Map<number, number | null>
  units: UnitInfo[]
  overrides: EntityOverride[]
  densities: DensityInfo[]
  weightOverrides: any[]
  products: any[]
  todayDay: string
}

/** 中位数（偶数个取中间两值均值，与后端 statistics.median 一致）。 */
function medianOf(arr: number[]): number | null {
  if (!arr.length) return null
  const s = [...arr].sort((a, b) => a - b)
  const m = Math.floor(s.length / 2)
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2
}

async function loadContext(): Promise<LocalContext> {
  const [records, merchants, units, overrides, densities, weightOverrides, products] = await Promise.all([
    getAll('product_records') as Promise<any[]>,
    getAll('merchants') as Promise<any[]>,
    getAll('units') as Promise<UnitInfo[]>,
    getAll('entity_unit_overrides') as Promise<EntityOverride[]>,
    getAll('entity_densities') as Promise<DensityInfo[]>,
    getAll('product_weight_overrides') as Promise<any[]>,
    getAll('products') as Promise<any[]>,
  ])
  const merchantRegion = new Map<number, number | null>()
  for (const m of merchants) {
    if (m?.id != null) merchantRegion.set(Number(m.id), m.region_id ?? null)
  }
  const now = new Date()
  now.setHours(0, 0, 0, 0)
  return {
    records: records.filter((r: any) => r.is_active !== false && r.price != null),
    merchants,
    merchantRegion,
    units,
    overrides,
    densities,
    weightOverrides,
    products,
    todayDay: toLocalDayKey(now) as string,
  }
}

/** 记录 → 地区子树内记录（未分配地区的商家在所有地区都计入，与后端一致）。 */
function recordsInRegion(ctx: LocalContext, allowed: number[] | null): any[] {
  if (allowed == null) return ctx.records
  const set = new Set(allowed)
  return ctx.records.filter((r) => {
    const mid = r.merchant_id
    if (mid == null) return false
    const rid = ctx.merchantRegion.get(Number(mid))
    // 后端 apply_region_filter：商家 region_id 为 NULL 时任何地区都计入
    if (rid == null) return true
    return set.has(rid)
  })
}

/** 记录的 ¥/斤 价（无法归一化的记录剔除）。 */
function toJinPoints(ctx: LocalContext, records: any[], entIdByPid: Map<number, number>): any[] {
  const points: any[] = []
  for (const r of records) {
    const entId = entIdByPid.get(Number(r.product_id)) ?? Number(r.product_id)
    const np = normalizeRecordToJin(r, ctx.units, ctx.overrides, ctx.densities, 'ingredient', entId)
    if (np.pricePerJin != null && isFinite(np.pricePerJin)) {
      points.push({ product_id: r.product_id, date: r.recorded_at, value: np.pricePerJin })
    }
  }
  return points
}

/** 权重表：用户覆盖 > price_weight > 50。 */
function weightMap(ctx: LocalContext, pids: number[]): Map<number, number> {
  const map = new Map<number, number>()
  const ov = new Map<number, number>()
  for (const w of ctx.weightOverrides) {
    if (w?.product_id != null) ov.set(Number(w.product_id), w.weight)
  }
  for (const pid of pids) {
    const p = ctx.products.find((x: any) => Number(x.id) === pid)
    map.set(pid, ov.get(pid) ?? p?.price_weight ?? 50)
  }
  return map
}

/** 实体卡片价：每商品「最近有记录日」每标准单位均价 → 30 天参与上限（全超期放开）→ 权重加权。 */
function cardPrice(
  ctx: LocalContext,
  records: any[],
  pids: number[],
  weights: Map<number, number>,
): { price: number | null; unit: string | null; isStale: boolean; daysSince: number | null; participants: number } {
  // {pid: {day: {sum,count}}}（每标准单位口径 = price*rate/standard_quantity，即 rawUnitPrice）
  const byPidDay = new Map<number, Map<string, { sum: number; count: number; unitId: number | null }>>()
  for (const r of records) {
    const pid = Number(r.product_id)
    if (!pids.includes(pid)) continue
    const rateRaw = Number(r.exchange_rate)
    const rate = Number.isFinite(rateRaw) && rateRaw > 0 ? rateRaw : 1
    const price = (Number(r.price) || 0) * rate
    const stdQty = Number(r.standard_quantity) || 0
    const unitPrice = stdQty > 0 ? price / stdQty : price
    const day = toLocalDayKey(r.recorded_at) as string
    if (!day) continue
    if (!byPidDay.has(pid)) byPidDay.set(pid, new Map())
    const dayMap = byPidDay.get(pid)!
    const agg = dayMap.get(day) || { sum: 0, count: 0, unitId: r.standard_unit_id ?? null }
    agg.sum += unitPrice
    agg.count += 1
    dayMap.set(day, agg)
  }
  const priced = [...byPidDay.keys()].filter((pid) => {
    const dayMap = byPidDay.get(pid)!
    return [...dayMap.values()].some((a) => a.count > 0)
  })
  if (!priced.length) return { price: null, unit: null, isStale: false, daysSince: null, participants: 0 }

  const dayMs = 24 * 60 * 60 * 1000
  const todayMs = Date.parse(ctx.todayDay)
  const fresh = priced.filter((pid) => {
    const days = [...byPidDay.get(pid)!.keys()].sort()
    const latestMs = Date.parse(days[days.length - 1])
    return (todayMs - latestMs) / dayMs <= STALE_DAYS
  })
  const pool = fresh.length ? fresh : priced
  let num = 0
  let den = 0
  let latestPid = pool[0]
  let latestMs = -1
  let latestUnitId: number | null = null
  for (const pid of pool) {
    const w = weights.get(pid) ?? 50
    if (w <= 0) continue
    const dayMap = byPidDay.get(pid)!
    const days = [...dayMap.keys()].sort()
    const last = dayMap.get(days[days.length - 1])!
    num += (last.sum / last.count) * w
    den += w
    const ms = Date.parse(days[days.length - 1])
    if (ms > latestMs) {
      latestMs = ms
      latestPid = pid
      latestUnitId = last.unitId
    }
  }
  const price = den > 0 ? Math.round((num / den) * 10000) / 10000 : null
  const unit = latestUnitId != null ? ctx.units.find((u) => Number(u.id) === Number(latestUnitId)) : undefined
  const daysSince = Math.round((todayMs - latestMs) / dayMs)
  return {
    price,
    unit: unit?.abbreviation || unit?.name || null,
    isStale: fresh.length === 0,
    daysSince,
    participants: pool.length,
  }
}

/** GET /comparison/regions — 有价格记录的地区候选（按记录数降序）。 */
export async function getComparisonRegions(_params: Record<string, string>, _query?: any): Promise<any> {
  const ctx = await loadContext()
  const allRegions: any[] = await getAll('regions')
  const counts = new Map<number, { records: number; merchants: Set<number> }>()
  for (const r of ctx.records) {
    const mid = r.merchant_id
    if (mid == null) continue
    const rid = ctx.merchantRegion.get(Number(mid))
    if (rid == null) continue
    const entry = counts.get(rid) || { records: 0, merchants: new Set<number>() }
    entry.records += 1
    entry.merchants.add(Number(mid))
    counts.set(rid, entry)
  }
  const regions = [...counts.entries()]
    .map(([rid, c]) => {
      const region = allRegions.find((r: any) => Number(r.id) === rid && r.is_active !== false)
      return {
        region_id: rid,
        code: region?.code ?? null,
        name: region?.name ?? String(rid),
        name_en: region?.name_en ?? null,
        display_name: region?.display_name || region?.name || String(rid),
        level: region?.level ?? 0,
        path: region?.path ?? null,
        record_count: c.records,
        merchant_count: c.merchants.size,
      }
    })
    .filter((r) => r.region_id != null)
    .sort((a, b) => b.record_count - a.record_count)
  return { regions }
}

/** GET /comparison/summary?region_ids=&days= — 各地区概览。 */
export async function getComparisonSummary(_params: Record<string, string>, query?: any): Promise<any> {
  const regionIds = parseIds(query?.region_ids, MAX_REGIONS)
  const days = Math.min(Math.max(parseInt(String(query?.days || '30'), 10) || 30, 7), 90)
  const ctx = await loadContext()
  const allRegions: any[] = await getAll('regions')

  const subtrees = new Map<number, number[] | null>()
  for (const rid of regionIds) subtrees.set(rid, await regionSubtreeIds(rid))

  // 篮子：基准地区近一年有记录的商品
  const dayMs = 24 * 60 * 60 * 1000
  const todayMs = Date.parse(ctx.todayDay)
  const cutoffMs = todayMs - BASKET_WINDOW_DAYS * dayMs
  const baseRecords = recordsInRegion(ctx, subtrees.get(regionIds[0])!)
  const basketPids = new Set<number>()
  for (const r of baseRecords) {
    const ms = Date.parse(toLocalDayKey(r.recorded_at) || '')
    if (Number.isFinite(ms) && ms >= cutoffMs) basketPids.add(Number(r.product_id))
  }
  const weights = weightMap(ctx, [...basketPids])

  // 篮子内商品 → 实体 id（计数单位折克用实体覆盖；篮子跨原料，用商品自身 id 兜底）
  const entIdByPid = new Map<number, number>()
  for (const p of ctx.products) {
    if (p?.id != null) entIdByPid.set(Number(p.id), p.ingredient_id ?? Number(p.id))
  }

  const items = regionIds.map((rid) => {
    const region = allRegions.find((r: any) => Number(r.id) === rid)
    const recs = recordsInRegion(ctx, subtrees.get(rid)!)
    const productIds = new Set(recs.map((r) => Number(r.product_id)))
    // 物价指数：篮子共同商品「最近有记录日每标准单位均价」的比率中位数 ×100
    const priceByPid = new Map<number, number>()
    for (const pid of basketPids) {
      const rec = recs.filter((r) => Number(r.product_id) === pid)
      if (!rec.length) continue
      const cp = cardPrice(ctx, rec, [pid], weights)
      if (cp.price != null) priceByPid.set(pid, cp.price)
    }
    return { rid, region, recs, productIds, priceByPid }
  })

  // 基准地区价表（第二遍，保证 ratios 用基准价）
  const baseData = items[0]
  const results = items.map((item) => {
    const ratios: number[] = []
    for (const [pid, price] of item.priceByPid) {
      const basePrice = baseData.priceByPid.get(pid)
      if (basePrice != null && basePrice > 0) ratios.push(price / basePrice)
    }
    const median = medianOf(ratios)
    const price_index = median != null ? Math.round(median * 1000) / 10 : null
    // 趋势：篮子商品 ¥/斤 前向携带加权
    const jinPoints = toJinPoints(ctx, item.recs.filter((r: any) => basketPids.has(Number(r.product_id))), entIdByPid)
    const start = new Date()
    start.setHours(0, 0, 0, 0)
    start.setDate(start.getDate() - (days - 1))
    const trend = buildWeightedAsOfDailySeries(
      jinPoints,
      (pid) => (pid == null ? 50 : weights.get(Number(pid)) ?? 50),
      { startDay: toLocalDayKey(start) as string, endDay: ctx.todayDay },
    ).map((d) => Math.round(d.avg * 100) / 100)
    return {
      region_id: item.rid,
      name: item.region?.name || String(item.rid),
      display_name: item.region?.display_name || item.region?.name || String(item.rid),
      record_count: item.recs.length,
      entity_count: item.productIds.size,
      price_index,
      trend,
    }
  })

  return { currency: DEFAULT_USER_CURRENCY, base_region_id: regionIds[0], basket_size: basketPids.size, regions: results }
}

/** GET /comparison/entity-prices?entity_type=&entity_ids=&region_ids=&days= — 矩阵。 */
export async function getComparisonEntityPrices(_params: Record<string, string>, query?: any): Promise<any> {
  const entityType = String(query?.entity_type || 'ingredient')
  if (entityType !== 'ingredient' && entityType !== 'product') throw localError('comparisonEntityTypeInvalid')
  const entityIds = parseIds(query?.entity_ids, MAX_ENTITIES)
  const regionIds = parseIds(query?.region_ids, MAX_REGIONS)
  const days = Math.min(Math.max(parseInt(String(query?.days || '30'), 10) || 30, 7), 90)
  const ctx = await loadContext()
  const allRegions: any[] = await getAll('regions')

  // 实体 → 商品集合；商品 → 实体（计数折克用）
  const entityPids = new Map<number, number[]>()
  const entIdByPid = new Map<number, number>()
  if (entityType === 'ingredient') {
    for (const eid of entityIds) entityPids.set(eid, [])
    for (const p of ctx.products) {
      if (p.is_active === false || p.ingredient_id == null) continue
      const eid = Number(p.ingredient_id)
      if (entityPids.has(eid)) {
        entityPids.get(eid)!.push(Number(p.id))
        entIdByPid.set(Number(p.id), eid)
      }
    }
  } else {
    for (const eid of entityIds) {
      entityPids.set(eid, [eid])
      entIdByPid.set(eid, eid)
    }
  }
  const allPids = [...new Set([...entityPids.values()].flat())]
  const weights = weightMap(ctx, allPids)

  const entities = entityIds.map((eid) => ({
    entity_id: eid,
    name: ctx.products.find((p: any) => Number(p.id) === eid)?.name
      ?? (entityType === 'product' ? String(eid) : ''),
    unit: null as string | null,
    regions: Object.fromEntries(regionIds.map((rid) => [String(rid), null])) as Record<string, any>,
  }))
  const nameById = new Map<number, string>()
  if (entityType === 'ingredient') {
    const ingredients: any[] = await getAll('ingredients')
    for (const ing of ingredients) {
      if (ing?.id != null) nameById.set(Number(ing.id), ing.name)
    }
  } else {
    for (const p of ctx.products) {
      if (p?.id != null) nameById.set(Number(p.id), p.name)
    }
  }

  const subtrees = new Map<number, number[] | null>()
  for (const rid of regionIds) subtrees.set(rid, await regionSubtreeIds(rid))

  for (let i = 0; i < regionIds.length; i++) {
    const rid = regionIds[i]
    const recs = recordsInRegion(ctx, subtrees.get(rid)!)
    for (const entity of entities) {
      const pids = entityPids.get(entity.entity_id) || []
      const entRecords = recs.filter((r) => pids.includes(Number(r.product_id)))
      const cp = cardPrice(ctx, entRecords, pids, weights)
      if (cp.price == null) continue
      // 趋势：该实体商品 ¥/斤 前向携带加权（与本地 sparklines 同口径）
      const jinPoints = toJinPoints(ctx, entRecords, entIdByPid).map((p: any) => ({
        ...p, product_id: entIdByPid.get(Number(p.product_id)) ?? p.product_id,
      }))
      const start = new Date()
      start.setHours(0, 0, 0, 0)
      start.setDate(start.getDate() - (days - 1))
      const trend = buildWeightedAsOfDailySeries(
        jinPoints,
        (pid) => (pid == null ? 50 : weights.get(Number(pid)) ?? 50),
        { startDay: toLocalDayKey(start) as string, endDay: ctx.todayDay },
      ).map((d) => Math.round(d.avg * 100) / 100)
      entity.regions[String(rid)] = {
        price: cp.price,
        is_stale: cp.isStale,
        days_since_record: cp.daysSince,
        participant_count: cp.participants,
        unit: cp.unit,
        trend,
      }
      if (entity.unit == null && cp.unit) entity.unit = cp.unit
    }
  }

  const finalEntities = entities.map((e) => ({ ...e, name: nameById.get(e.entity_id) || e.name || String(e.entity_id) }))
  return {
    currency: DEFAULT_USER_CURRENCY,
    trend_unit: CHINESE_JIN_NAME,
    regions: regionIds.map((rid) => {
      const region = allRegions.find((r: any) => Number(r.id) === rid)
      return {
        region_id: rid,
        name: region?.name || String(rid),
        display_name: region?.display_name || region?.name || String(rid),
        level: region?.level ?? 0,
      }
    }),
    entities: finalEntities,
  }
}

// ==================== 二期：菜谱 / 试算成本对比 ====================
// 菜谱成本复用 recipes.ts 的 getRecipeCost / getCostHistoryRange（已支持 region_id）；
// 试算求值在本地简单评估器上做地区过滤（原料/商品条目按商家地区子树取最新价，
// 营养与地区无关沿用 evaluateItem；菜谱项走 getRecipeCost 的地区口径）。

import { getRecipeCost, getCostHistoryRange } from './recipes'
import { evaluateItem } from './mealPlans'
import { getById } from '../database'

const MAX_RECIPES = 10
const MAX_PLANS = 10

async function regionNamesById(): Promise<Map<number, { name: string; display_name: string; level: number }>> {
  const all: any[] = await getAll('regions')
  const map = new Map<number, { name: string; display_name: string; level: number }>()
  for (const r of all) {
    if (r?.id != null && r.is_active !== false) {
      map.set(Number(r.id), {
        name: r.name || String(r.id),
        display_name: r.display_name || r.name || String(r.id),
        level: r.level ?? 0,
      })
    }
  }
  return map
}

/** GET /comparison/recipe-costs — 菜谱×地区成本矩阵（复用 getRecipeCost 地区口径）。 */
export async function getComparisonRecipeCosts(_params: Record<string, string>, query?: any): Promise<any> {
  const recipeIds = parseIds(query?.recipe_ids, MAX_RECIPES)
  const regionIds = parseIds(query?.region_ids, MAX_REGIONS)
  const names = await regionNamesById()

  const rows = []
  for (const rid of recipeIds) {
    const recipe = await getById('recipes', rid)
    rows.push({
      recipe_id: rid,
      name: recipe?.name || String(rid),
      regions: Object.fromEntries(regionIds.map(x => [String(x), null])),
    })
  }

  for (const regionId of regionIds) {
    for (const row of rows) {
      let cost: any = null
      try {
        cost = await getRecipeCost({ id: String(row.recipe_id) }, { region_id: String(regionId) })
      } catch {
        cost = null
      }
      if (!cost || cost.total_cost == null) continue
      const breakdown = (cost.cost_breakdown || []).map((b: any) => ({
        ingredient_name: b.ingredient_name ?? null,
        ingredient_id: b.ingredient_id ?? null,
        quantity: b.quantity ?? null,
        cost: b.cost ?? null,
        fallback_chain: b.fallback_chain ?? null,
        aggregation_chain: b.aggregation_chain ?? null,
        price_recorded_at: null,
      }))
      row.regions[String(regionId)] = {
        total_cost: cost.total_cost,
        cost_per_serving: cost.cost_per_serving ?? null,
        currency: cost.currency ?? DEFAULT_USER_CURRENCY,
        missing_ingredients: breakdown
          .filter((b: any) => b.cost == null && b.ingredient_name)
          .map((b: any) => b.ingredient_name),
        breakdown,
      }
    }
  }

  return {
    currency: DEFAULT_USER_CURRENCY,
    regions: regionIds.map(rid => ({
      region_id: rid,
      ...(names.get(rid) || { name: String(rid), display_name: String(rid), level: 0 }),
    })),
    recipes: rows,
  }
}

/** GET /comparison/recipe-cost-trend — 单菜谱多地区趋势（复用 getCostHistoryRange）。 */
export async function getComparisonRecipeCostTrend(_params: Record<string, string>, query?: any): Promise<any> {
  const recipeId = parseInt(String(query?.recipe_id || ''), 10)
  const regionIds = parseIds(query?.region_ids, MAX_REGIONS)
  const days = Math.min(Math.max(parseInt(String(query?.days || '30'), 10) || 30, 7), 90)
  const out: Record<string, any[]> = {}
  for (const regionId of regionIds) {
    let points: any[] = []
    try {
      points = (await getCostHistoryRange(
        { id: String(recipeId) },
        { region_id: String(regionId), days: String(days), offset_days: '0' },
      )) as any[]
    } catch {
      points = []
    }
    out[String(regionId)] = Array.isArray(points) ? points : []
  }
  return { regions: out }
}

/** 单条目的地区口径成本（原料/商品：地区子树内最新记录；菜谱：getRecipeCost）。 */
async function evaluateItemCostInRegion(
  item: any,
  regionId: number,
  allowed: number[] | null,
  ctx: LocalContext,
): Promise<{ cost: number | null; currency: string | null }> {
  if (item.item_type === 'recipe' && item.recipe_id != null) {
    try {
      const cost = await getRecipeCost({ id: String(item.recipe_id) }, { region_id: String(regionId) })
      return { cost: cost?.total_cost ?? null, currency: cost?.currency ?? null }
    } catch {
      return { cost: null, currency: null }
    }
  }
  const records = recordsInRegion(ctx, allowed)
  let productId: number | null = null
  if (item.item_type === 'product' && item.product_id != null) {
    productId = Number(item.product_id)
  } else if (item.item_type === 'ingredient' && item.ingredient_id != null) {
    productId = ctx.products.find(
      (p: any) => p.ingredient_id === item.ingredient_id && p.is_active !== false,
    )?.id ?? null
  }
  if (productId == null) return { cost: null, currency: null }
  const relevant = records.filter((r: any) => Number(r.product_id) === productId)
    .sort((a: any, b: any) => ((b.recorded_at || '') > (a.recorded_at || '') ? 1 : -1))
  const latest = relevant[0]
  if (latest?.price == null) return { cost: null, currency: null }
  const stdQty = Number(latest.standard_quantity) || 1
  const cost = Math.round((Number(latest.price) / stdQty) * Number(item.quantity ?? 0) * 100) / 100
  return { cost, currency: latest.currency || null }
}

async function evaluateTotalsInRegion(
  items: any[],
  regionId: number,
  allowed: number[] | null,
  ctx: LocalContext,
): Promise<Record<string, any>> {
  const totals = { cost: 0, currency: null as string | null, calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 }
  for (const item of items) {
    // 营养与地区无关，沿用 evaluateItem 的口径
    const { nutrition } = await evaluateItem(item)
    const costInfo = await evaluateItemCostInRegion(item, regionId, allowed, ctx)
    if (costInfo.cost != null) {
      totals.cost = Math.round((totals.cost + costInfo.cost) * 100) / 100
      totals.currency = costInfo.currency || totals.currency
    }
    if (nutrition) {
      totals.calories += nutrition.calories || 0
      totals.protein_g += nutrition.protein_g || 0
      totals.carbs_g += nutrition.carbs_g || 0
      totals.fat_g += nutrition.fat_g || 0
    }
  }
  for (const key of ['calories', 'protein_g', 'carbs_g', 'fat_g'] as const) {
    totals[key] = Math.round(totals[key] * 100) / 100
  }
  return totals
}

/** POST /comparison/plan-evaluate-regions — 同一组条目分地区求值（合计卡口径切换）。 */
export async function getComparisonPlanEvaluateRegions(_params: Record<string, string>, data?: any): Promise<any> {
  const regionIds = parseIds((data?.region_ids || []).map(String).join(','), MAX_REGIONS)
  const items = data?.items || []
  const ctx = await loadContext()
  const out = []
  for (const regionId of regionIds) {
    const allowed = await regionSubtreeIds(regionId)
    const totals = await evaluateTotalsInRegion(items, regionId, allowed, ctx)
    out.push({ region_id: regionId, totals })
  }
  return { regions: out }
}

/** GET /comparison/plan-costs — 已保存方案×地区合计对照。 */
export async function getComparisonPlanCosts(_params: Record<string, string>, query?: any): Promise<any> {
  const planIds = parseIds(query?.plan_ids, MAX_PLANS)
  const regionIds = parseIds(query?.region_ids, MAX_REGIONS)
  const ctx = await loadContext()
  const allPlans: any[] = await getAll('meal_plans')
  const out = []
  for (const pid of planIds) {
    const plan = allPlans.find((p: any) => Number(p.id) === pid)
    const row: any = {
      plan_id: pid,
      name: plan?.name || String(pid),
      regions: Object.fromEntries(regionIds.map(x => [String(x), null])),
    }
    if (plan) {
      for (const regionId of regionIds) {
        const allowed = await regionSubtreeIds(regionId)
        try {
          row.regions[String(regionId)] = await evaluateTotalsInRegion(plan.items || [], regionId, allowed, ctx)
        } catch {
          row.regions[String(regionId)] = null
        }
      }
    }
    out.push(row)
  }
  return { plans: out, regions: regionIds }
}

/** GET /comparison/plan-cost-trend — 单方案多地区趋势（与本地 mealPlans.costTrend 同口径 + 地区过滤）。 */
export async function getComparisonPlanCostTrend(_params: Record<string, string>, query?: any): Promise<any> {
  const planId = parseInt(String(query?.plan_id || ''), 10)
  const regionIds = parseIds(query?.region_ids, MAX_REGIONS)
  const days = Math.min(Math.max(parseInt(String(query?.days || '30'), 10) || 30, 7), 90)
  const ctx = await loadContext()
  const allPlans: any[] = await getAll('meal_plans')
  const plan = allPlans.find((p: any) => Number(p.id) === planId)

  const out: Record<string, any[]> = {}
  for (const regionId of regionIds) {
    if (!plan) {
      out[String(regionId)] = []
      continue
    }
    const allowed = await regionSubtreeIds(regionId)
    const records = recordsInRegion(ctx, allowed)
    const today = new Date()
    const points: any[] = []
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(today)
      d.setDate(d.getDate() - i)
      const dayStr = toLocalDayKey(d) as string
      let total = 0
      for (const item of plan.items || []) {
        if (item.item_type === 'recipe') {
          // 简化（与本地 mealPlans.costTrend 同口径）：菜谱项用当前成本
          try {
            const cost = await getRecipeCost({ id: String(item.recipe_id) }, { region_id: String(regionId) })
            total += cost?.total_cost ?? 0
          } catch { /* ignore */ }
          continue
        }
        let productId: number | null = null
        if (item.item_type === 'product' && item.product_id != null) {
          productId = Number(item.product_id)
        } else if (item.item_type === 'ingredient' && item.ingredient_id != null) {
          productId = ctx.products.find(
            (p: any) => p.ingredient_id === item.ingredient_id && p.is_active !== false,
          )?.id ?? null
        }
        if (productId == null) continue
        const dayRecords = records.filter(
          (r: any) => Number(r.product_id) === productId && r.is_active !== false
            && (r.recorded_at || '').split('T')[0] <= dayStr,
        ).sort((a: any, b: any) => ((b.recorded_at || '') > (a.recorded_at || '') ? 1 : -1))
        const latest = dayRecords[0]
        if (latest?.price != null) {
          const stdQty = Number(latest.standard_quantity) || 1
          total += (Number(latest.price) / stdQty) * Number(item.quantity ?? 0)
        }
      }
      const rounded = Math.round(total * 100) / 100
      points.push({
        date: dayStr, total_cost: rounded, min_cost: rounded,
        max_cost: rounded, avg_cost: rounded, currency: DEFAULT_USER_CURRENCY,
      })
    }
    out[String(regionId)] = points
  }
  return { regions: out }
}

/**
 * 逐日「as-of 加权综合价」。
 *
 * 与后端同一口径（综合最新价 / 原料 sparkline / 菜谱成本）：
 *   - 每个商品的价格 = 该商品「最近有记录日」的当日均价
 *   - 该价格一直有效到下一次记录（价格在两次记录之间视为不变）
 *   - 每日综合价 = 各商品当日有效价按权重（默认 50，0 = 排除）加权
 *   - 参与上限 staleDays：超过 N 天的价格不参与；但当日全部商品都过期时放开，
 *     按最近一次已知价计算（宁可显示旧价格，也不能没有价格）
 *
 * 用途：原料价格趋势图的 avg 线、原料迷你图。避免「某天只有单个商品有记录
 * → 该点退化成单品价」，也让久未记录的商品继续参与综合价。
 */

export interface AsOfPricePoint {
  product_id?: number | null
  date: string | number | Date
  value: number | null | undefined
}

export interface AsOfDayPoint {
  /** 本地日历日 YYYY-MM-DD（与日期展示口径一致） */
  date: string
  /** 各商品当日有效价的加权平均 */
  avg: number
  /** 参与加权的商品价区间 */
  min: number
  max: number
  /** 参与加权的商品数 */
  count: number
  /** 当日全部商品都超过参与上限（按最近一次已知价计算） */
  relaxed?: boolean
}

export interface AsOfOptions {
  /** 序列起始日（YYYY-MM-DD）；不传则从首个有值日起 */
  startDay?: string | null
  /** 序列结束日（YYYY-MM-DD）；默认今天 */
  endDay?: string | null
  /**
   * 参与上限（天）：商品最近一次价格超过 N 天不再参与当日综合价。
   * 与后端 INGREDIENT_PRICE_STALE_DAYS / 商家价 30 天陈旧口径一致；<=0 表示不限。
   * 当日全部商品都过期时自动放开，按最近一次已知价计算。
   */
  staleDays?: number | null
  /**
   * 区间（min/max）改按「记录」口径：当日有记录取当日全部记录价的 min/max，
   * 无记录日沿用最近一次记录日的区间（as-of 携带）。
   * 单商品视图里「按商品」区间会退化成均价线，需要打开此开关；
   * avg / count 语义不受影响。
   */
  bandFromRecords?: boolean
}

const DEFAULT_WEIGHT = 50
export const PRICE_STALE_DAYS = 30

/** 本地日 key（YYYY-MM-DD）：与日期展示口径一致，跨时区稳定。 */
export function toLocalDayKey(value: string | number | Date): string | null {
  const d = new Date(value)
  if (isNaN(d.getTime())) return null
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function dayToDate(day: string): Date {
  return new Date(`${day}T00:00:00`)
}

function addDays(day: string, delta: number): string {
  const d = dayToDate(day)
  d.setDate(d.getDate() + delta)
  return toLocalDayKey(d) as string
}

/**
 * 记录点集 → 逐日 as-of 加权序列。
 *
 * @param points 价格点（按商品 + 日期）；同商品同日多条先取当日均价
 * @param weightOf 生效权重查询（用户覆盖 > 全局 > 50）；返回 <=0 的商品被排除
 */
export function buildWeightedAsOfDailySeries(
  points: AsOfPricePoint[],
  weightOf: (productId: number | null) => number = () => DEFAULT_WEIGHT,
  opts: AsOfOptions = {},
): AsOfDayPoint[] {
  // 1) 按商品 + 本地日聚合当日均价
  const byProduct = new Map<string, Map<string, { sum: number; count: number }>>()
  for (const p of points) {
    if (!p || p.value == null || !isFinite(Number(p.value))) continue
    const day = toLocalDayKey(p.date)
    if (!day) continue
    const pid = p.product_id == null ? '' : String(p.product_id)
    if (!byProduct.has(pid)) byProduct.set(pid, new Map())
    const dayMap = byProduct.get(pid)!
    const agg = dayMap.get(day)
    if (agg) {
      agg.sum += Number(p.value)
      agg.count += 1
    } else {
      dayMap.set(day, { sum: Number(p.value), count: 1 })
    }
  }
  if (byProduct.size === 0) return []

  // 2) 每商品：日升序阶梯（日 → 当日均价）+ 游标
  type Step = {
    days: string[]
    values: number[]
    next: number
    current: number
    weight: number
    /** 超过该日的价格视为过期（不再参与） */
    expiresOn: string | null
  }
  const steps: Step[] = []
  let firstDay: string | null = null
  for (const [pid, dayMap] of byProduct) {
    const days = [...dayMap.keys()].sort()
    const values = days.map((d) => {
      const agg = dayMap.get(d)!
      return agg.sum / agg.count
    })
    const numericPid = pid === '' ? null : Number(pid)
    const weight = weightOf(numericPid)
    if (!(weight > 0)) continue
    const staleDays = opts.staleDays ?? PRICE_STALE_DAYS
    const expiresOn = staleDays != null && staleDays > 0 ? addDays(days[days.length - 1], staleDays) : null
    steps.push({ days, values, next: 0, current: -1, weight, expiresOn })
    if (firstDay === null || days[0] < firstDay) firstDay = days[0]
  }
  if (firstDay === null || steps.length === 0) return []

  // 记录口径区间：所有有效记录按本地日聚合（不看权重/超期），as-of 携带
  const bandDays: string[] = []
  const bandValues: Array<{ min: number; max: number }> = []
  if (opts.bandFromRecords) {
    const byDay = new Map<string, { min: number; max: number }>()
    for (const p of points) {
      if (!p || p.value == null || !isFinite(Number(p.value))) continue
      const day = toLocalDayKey(p.date)
      if (!day) continue
      const value = Number(p.value)
      const agg = byDay.get(day)
      if (agg) {
        agg.min = Math.min(agg.min, value)
        agg.max = Math.max(agg.max, value)
      } else {
        byDay.set(day, { min: value, max: value })
      }
    }
    for (const day of [...byDay.keys()].sort()) {
      bandDays.push(day)
      bandValues.push(byDay.get(day)!)
    }
  }

  // 3) 逐日推进：每个商品取「截至当日的最新价」
  const endDay = opts.endDay ?? (toLocalDayKey(new Date()) as string)
  let cur = opts.startDay && opts.startDay > firstDay ? opts.startDay : firstDay
  const out: AsOfDayPoint[] = []
  let bandNext = 0
  while (cur <= endDay) {
    // fresh：staleDays 内有价的商品；all：全部商品（当日全部过期时的放开兜底）
    let num = 0
    let den = 0
    let min = Number.POSITIVE_INFINITY
    let max = Number.NEGATIVE_INFINITY
    let count = 0
    let numAll = 0
    let denAll = 0
    let minAll = Number.POSITIVE_INFINITY
    let maxAll = Number.NEGATIVE_INFINITY
    let countAll = 0
    for (const step of steps) {
      while (step.next < step.days.length && step.days[step.next] <= cur) {
        step.current = step.next
        step.next += 1
      }
      if (step.current < 0) continue
      const value = step.values[step.current]
      numAll += value * step.weight
      denAll += step.weight
      countAll += 1
      if (value < minAll) minAll = value
      if (value > maxAll) maxAll = value
      if (step.expiresOn !== null && cur > step.expiresOn) continue
      num += value * step.weight
      den += step.weight
      count += 1
      if (value < min) min = value
      if (value > max) max = value
    }
    // 当日没有「新鲜」商品 → 放开上限，用全部商品的最近一次已知价
    const relaxed = den <= 0
    // 区间口径：默认按参与商品价区间（放开时用全部商品）；bandFromRecords 按记录区间 as-of 携带
    let bandMin = relaxed ? minAll : min
    let bandMax = relaxed ? maxAll : max
    if (opts.bandFromRecords) {
      while (bandNext < bandDays.length && bandDays[bandNext] <= cur) bandNext += 1
      if (bandNext > 0) {
        bandMin = bandValues[bandNext - 1].min
        bandMax = bandValues[bandNext - 1].max
      }
    }
    if (denAll > 0) {
      out.push({
        date: cur,
        avg: (relaxed ? numAll : num) / (relaxed ? denAll : den),
        min: bandMin,
        max: bandMax,
        count: relaxed ? countAll : count,
        relaxed,
      })
    }
    cur = addDays(cur, 1)
  }
  return out
}

/**
 * 图表价格记录的「回退全量」判断。
 *
 * 趋势图按 as-of 口径绘制（每商品最近一次价向前携带，全部超期时放开），
 * 所以「所选区间内没有新记录」并不等于「没有价格可画」：只要拿到区间之前
 * 最近一次记录作为携带起点，序列就能一直覆盖到区间末尾。
 * 而按区间取数（start_date）恰好把这些起点记录挡在区间之外，
 * 因此区间命中 0 条、且累积池还是空的时候，必须回退到「全量」请求，
 * 否则「近一个月没有更新」的实体（商品/原料）图表会空白。
 *
 * @param windowStart 本次请求的区间起点；undefined/null 表示「全部」，无需回退
 * @param windowHits 本次区间请求命中的记录条数
 * @param loadedCount 累积池中已有的记录条数
 */
export function shouldLoadFullPriceHistory(params: {
  windowStart?: Date | null
  windowHits: number
  loadedCount: number
}): boolean {
  return !!params.windowStart && params.windowHits === 0 && params.loadedCount === 0
}

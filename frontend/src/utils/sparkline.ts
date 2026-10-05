/**
 * 迷你图序列的按日历日前向填充。
 *
 * X 轴语义是时间：每天占一格，点间距才能反映真实天数间隔；
 * 无记录日沿用前值（价格在两次记录之间视为不变，与后端成本计算口径一致），
 * 久未更新时表现为长平尾。
 */

/** 本地日 key（YYYY-MM-DD）：与日期显示口径一致，跨时区稳定。 */
function toLocalDayKey(value: string | number | Date): string | null {
  const d = new Date(value)
  if (isNaN(d.getTime())) return null
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/**
 * (日期, 数值) 点集 → 按日聚合均值 → 从首个有值日到今天前向填充的数值序列。
 * 与后端 /sparklines 端点的填充口径一致。
 */
export function buildDailySparklineSeries(
  points: Array<{ date: string | number | Date; value: number | null | undefined }>,
): number[] {
  const byDay = new Map<string, { sum: number; count: number }>()
  for (const p of points) {
    if (p == null || p.value == null || !isFinite(Number(p.value))) continue
    const key = toLocalDayKey(p.date)
    if (!key) continue
    const agg = byDay.get(key)
    if (agg) {
      agg.sum += Number(p.value)
      agg.count += 1
    } else {
      byDay.set(key, { sum: Number(p.value), count: 1 })
    }
  }
  if (byDay.size === 0) return []

  const days = [...byDay.keys()].sort()
  const start = new Date(`${days[0]}T00:00:00`)
  const today = new Date()
  today.setHours(0, 0, 0, 0)

  const out: number[] = []
  let last: number | null = null
  for (let cur = new Date(start); cur <= today; cur.setDate(cur.getDate() + 1)) {
    const key = toLocalDayKey(cur)
    const agg = key ? byDay.get(key) : undefined
    if (agg) last = agg.sum / agg.count
    if (last !== null) out.push(last)
  }
  return out
}

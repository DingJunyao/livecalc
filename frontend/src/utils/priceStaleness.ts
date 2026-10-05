/**
 * 价格记录「陈旧」判断。
 * 阈值与后端 price_region.MERCHANT_PRICE_STALE_DAYS 保持一致（30 天）。
 */

export const PRICE_STALE_DAYS = 30

const STALE_MS = PRICE_STALE_DAYS * 24 * 60 * 60 * 1000

/** 记录时间距今超过 PRICE_STALE_DAYS 天时为 true；时间缺失或非法视为不陈旧。 */
export function isRecordedAtStale(
  recordedAt: string | number | Date | null | undefined,
  now: Date = new Date(),
): boolean {
  if (recordedAt === null || recordedAt === undefined || recordedAt === '') return false
  const t = new Date(recordedAt).getTime()
  if (isNaN(t)) return false
  return now.getTime() - t > STALE_MS
}

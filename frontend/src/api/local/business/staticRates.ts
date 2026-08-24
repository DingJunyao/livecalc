// 本地模式静态汇率表 — 以 EUR 为基准的近似固定汇率。
// 注意：仅用于本地演示/离线模式，数值为近似值（非实时行情），
// 注释注明为本地静态近似；云端模式请以 exchange_rate_snapshots 为准。
export const LOCAL_USER_CURRENCY = 'CNY'

/** 以 EUR=1 为基准的近似固定汇率（1 EUR = N 其他币种）。 */
export const STATIC_RATES_EUR: Record<string, number> = {
  EUR: 1,
  USD: 1.08,
  CNY: 7.8,
  GBP: 0.85,
  JPY: 160,
  HKD: 8.4,
  KRW: 1450,
  SGD: 1.45,
  AUD: 1.65,
  CAD: 1.45,
  TWD: 34,
  THB: 39,
  MYR: 5.0,
  VND: 26000,
  RUB: 95,
}

/**
 * 计算 1 单位记录币种折算成用户币种的汇率倍数（后端语义）。
 * 本地用户默认币种固定为 CNY：exchange_rate = rate[CNY] / rate[record_currency]。
 * 记录币种或用户币种不在静态表里时回退 1（不换算）。
 */
export function exchangeRateToUserCurrency(
  recordCurrency: string,
  userCurrency: string = LOCAL_USER_CURRENCY,
): number {
  const from = STATIC_RATES_EUR[recordCurrency]
  const to = STATIC_RATES_EUR[userCurrency]
  if (from == null || to == null || from <= 0) return 1
  return to / from
}

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
  // 与后端启动 seed（currency_seed.py）对齐补充的主流币种（2026-08-25 近似值）
  AED: 4.2875,
  BGN: 1.9558, // 保加利亚列弗锚定 EUR（1 EUR = 1.9558 BGN）
  BRL: 6.0152,
  CHF: 0.93639,
  CZK: 24.115,
  DKK: 7.4767,
  HUF: 362.73,
  IDR: 20662,
  ILS: 3.4931,
  INR: 111.7,
  ISK: 141.36,
  MXN: 19.7713,
  NOK: 10.8701,
  NZD: 1.9571,
  PHP: 72.03,
  PLN: 4.311,
  RON: 5.2543,
  SEK: 11.077,
  TRY: 56.124,
  ZAR: 18.6782,
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

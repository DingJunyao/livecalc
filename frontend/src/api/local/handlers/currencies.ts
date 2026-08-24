import type { Currency } from '@/types'

// 本地静态币种 — 与后端 seed（backend/scripts/sql/20260823_multi_currency_*.sql）对齐的 15 种。
const CURRENCIES: Currency[] = [
  { code: 'CNY', name: '人民币', symbol: '¥', decimals: 2 },
  { code: 'USD', name: '美元', symbol: '$', decimals: 2 },
  { code: 'EUR', name: '欧元', symbol: '€', decimals: 2 },
  { code: 'GBP', name: '英镑', symbol: '£', decimals: 2 },
  { code: 'JPY', name: '日元', symbol: '¥', decimals: 0 },
  { code: 'HKD', name: '港币', symbol: 'HK$', decimals: 2 },
  { code: 'KRW', name: '韩元', symbol: '₩', decimals: 0 },
  { code: 'SGD', name: '新加坡元', symbol: 'S$', decimals: 2 },
  { code: 'AUD', name: '澳大利亚元', symbol: 'A$', decimals: 2 },
  { code: 'CAD', name: '加拿大元', symbol: 'C$', decimals: 2 },
  { code: 'TWD', name: '新台币', symbol: 'NT$', decimals: 2 },
  { code: 'THB', name: '泰铢', symbol: '฿', decimals: 2 },
  { code: 'MYR', name: '马来西亚林吉特', symbol: 'RM', decimals: 2 },
  { code: 'VND', name: '越南盾', symbol: '₫', decimals: 0 },
  { code: 'RUB', name: '俄罗斯卢布', symbol: '₽', decimals: 2 },
]

export function localGetCurrencies(): Currency[] {
  return CURRENCIES
}

export function localRatesStatus() {
  return { latest: null, source: 'local-static' }
}

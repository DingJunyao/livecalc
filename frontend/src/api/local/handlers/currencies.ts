import type { Currency } from '@/types'

const CURRENCIES: Currency[] = [
  { code: 'CNY', name: '人民币', symbol: '¥', decimals: 2 },
  { code: 'USD', name: '美元', symbol: '$', decimals: 2 },
  { code: 'EUR', name: '欧元', symbol: '€', decimals: 2 },
  { code: 'JPY', name: '日元', symbol: '¥', decimals: 0 },
]

export function localGetCurrencies(): Currency[] {
  return CURRENCIES
}

export function localRatesStatus() {
  return { latest: null, source: 'local-static' }
}

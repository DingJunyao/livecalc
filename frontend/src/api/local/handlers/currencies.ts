import type { Currency } from '@/types'

// 本地静态币种 — 与后端启动 seed（backend/app/services/currency_seed.py）对齐的 35 种。
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
  { code: 'AED', name: '阿联酋迪拉姆', symbol: 'د.إ', decimals: 2 },
  { code: 'BGN', name: '保加利亚列弗', symbol: 'лв', decimals: 2 },
  { code: 'BRL', name: '巴西雷亚尔', symbol: 'R$', decimals: 2 },
  { code: 'CHF', name: '瑞士法郎', symbol: 'CHF', decimals: 2 },
  { code: 'CZK', name: '捷克克朗', symbol: 'Kč', decimals: 2 },
  { code: 'DKK', name: '丹麦克朗', symbol: 'kr', decimals: 2 },
  { code: 'HUF', name: '匈牙利福林', symbol: 'Ft', decimals: 0 },
  { code: 'IDR', name: '印度尼西亚盾', symbol: 'Rp', decimals: 2 },
  { code: 'ILS', name: '以色列新谢克尔', symbol: '₪', decimals: 2 },
  { code: 'INR', name: '印度卢比', symbol: '₹', decimals: 2 },
  { code: 'ISK', name: '冰岛克朗', symbol: 'kr', decimals: 0 },
  { code: 'MXN', name: '墨西哥比索', symbol: 'Mex$', decimals: 2 },
  { code: 'NOK', name: '挪威克朗', symbol: 'kr', decimals: 2 },
  { code: 'NZD', name: '新西兰元', symbol: 'NZ$', decimals: 2 },
  { code: 'PHP', name: '菲律宾比索', symbol: '₱', decimals: 2 },
  { code: 'PLN', name: '波兰兹罗提', symbol: 'zł', decimals: 2 },
  { code: 'RON', name: '罗马尼亚列伊', symbol: 'lei', decimals: 2 },
  { code: 'SEK', name: '瑞典克朗', symbol: 'kr', decimals: 2 },
  { code: 'TRY', name: '土耳其里拉', symbol: '₺', decimals: 2 },
  { code: 'ZAR', name: '南非兰特', symbol: 'R', decimals: 2 },
]

export function localGetCurrencies(): Currency[] {
  return CURRENCIES
}

export function localRatesStatus() {
  return { latest: null, source: 'local-static' }
}

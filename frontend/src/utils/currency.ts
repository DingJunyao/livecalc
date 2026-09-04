import type { Currency } from '@/types'
import { api } from '@/api'
import { formatMoney as formatMoneyWithLocale } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'
import { currencyDisplayName, currencyOptionLabel } from './currencyLabels'

let cache: { locale: string; items: Currency[] } | null = null

export { currencyDisplayName, currencyOptionLabel }

export async function loadCurrencies(force = false): Promise<Currency[]> {
  const locale = useLocaleStore().locale
  if (!force && cache?.locale === locale) return cache.items
  const res = await api.get('/currencies')
  const items = Array.isArray(res) ? res : ((res as any)?.items || [])
  cache = { locale, items }
  return items
}

export function symbolFromIntl(code: string): string {
  try {
    const parts = new Intl.NumberFormat(undefined, { style: 'currency', currency: code, currencyDisplay: 'narrowSymbol' }).formatToParts(0)
    const p = parts.find((x) => x.type === 'currency')
    return p?.value || code
  } catch {
    return code
  }
}

export async function currencySymbol(code: string): Promise<string> {
  const list = await loadCurrencies()
  const hit = list.find((c) => c.code === code)
  return hit?.symbol || symbolFromIntl(code)
}

// 防御：code 异常（如误传对象）时兜底 CNY，避免渲染出 "[object Object]"。
// 统一采用“金额 + ISO 币种代码”格式，避免因浏览器语言环境不同而出现
// ¥、Rp、IDR 的位置或符号不一致。
export function formatMoney(amount: number, code: string): string {
  const cur = typeof code === 'string' && code ? code : 'CNY'
  const locale = useLocaleStore().effectiveFormatLocale
  const formatted = formatMoneyWithLocale(amount, cur, locale)
  if (formatted !== '-' || cur === 'CNY') return formatted
  return formatMoneyWithLocale(amount, 'CNY', locale)
}

export function convertAmount(amount: number, exchangeRate: number): number {
  return amount * (exchangeRate || 1)
}

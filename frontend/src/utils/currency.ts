import type { Currency } from '@/types'
import { api } from '@/api'

let cache: Currency[] | null = null

export async function loadCurrencies(force = false): Promise<Currency[]> {
  if (!force && cache) return cache
  const res = await api.get('/currencies')
  cache = Array.isArray(res) ? res : ((res as any)?.items || [])
  return cache
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
export function formatMoney(amount: number, code: string): string {
  const cur = typeof code === 'string' && code ? code : 'CNY'
  try {
    return new Intl.NumberFormat(undefined, { style: 'currency', currency: cur }).format(amount)
  } catch {
    return `${amount.toFixed(2)} ${cur}`
  }
}

export function convertAmount(amount: number, exchangeRate: number): number {
  return amount * (exchangeRate || 1)
}
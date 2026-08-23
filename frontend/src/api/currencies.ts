import { api } from './client'
import type { Currency } from '@/types'

export function listCurrencies(): Promise<Currency[]> {
  return api.get('/currencies') as unknown as Promise<Currency[]>
}

export function ratesStatus(): Promise<{ latest: string | null; source: string | null }> {
  return api.get('/exchange-rates/status') as unknown as Promise<{
    latest: string | null
    source: string | null
  }>
}

export function refreshRates(): Promise<any> {
  return api.post('/admin/exchange-rates/refresh')
}

export function manualRate(payload: {
  rate_date: string
  base_currency: string
  rates: Record<string, number>
}): Promise<any> {
  return api.post('/admin/exchange-rates/manual', payload)
}

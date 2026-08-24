import { api } from './client'
import type { Currency } from '@/types'

export function listCurrencies(): Promise<Currency[]> {
  return api.get('/currencies') as unknown as Promise<Currency[]>
}

export function listAdminCurrencies(): Promise<Currency[]> {
  return api.get('/admin/currencies') as unknown as Promise<Currency[]>
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

export function createCurrency(payload: {
  code: string
  name: string
  symbol?: string | null
  decimals?: number
  is_active?: boolean
}): Promise<Currency> {
  return api.post('/admin/currencies', payload) as unknown as Promise<Currency>
}

export function updateCurrency(
  code: string,
  payload: { name?: string; symbol?: string | null; decimals?: number; is_active?: boolean }
): Promise<Currency> {
  return api.put(`/admin/currencies/${code}`, payload) as unknown as Promise<Currency>
}

export function deleteCurrency(code: string): Promise<any> {
  return api.delete(`/admin/currencies/${code}`)
}

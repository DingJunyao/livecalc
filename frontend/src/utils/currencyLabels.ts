import type { Currency } from '../types'

export function currencyDisplayName(currency: Pick<Currency, 'name' | 'display_name' | 'code'>): string {
  return currency.display_name || currency.name || currency.code
}

export function currencyOptionLabel(currency: Pick<Currency, 'name' | 'display_name' | 'code'>): string {
  const displayName = currencyDisplayName(currency)
  return displayName && displayName !== currency.code ? `${displayName} (${currency.code})` : currency.code
}

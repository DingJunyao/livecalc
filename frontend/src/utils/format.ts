export type FormatLocale =
  | 'zh-CN'
  | 'zh-TW'
  | 'en-US'
  | 'en-GB'
  | 'ja-JP'
  | 'de-DE'
  | 'id-ID'
  | 'ar-EG'

type DateInput = string | number | Date | null | undefined
type NumberInput = number | string | null | undefined

const FORMAT_LOCALES = new Set<FormatLocale>([
  'zh-CN',
  'zh-TW',
  'en-US',
  'en-GB',
  'ja-JP',
  'de-DE',
  'id-ID',
  'ar-EG',
])

const DEFAULT_DATE_OPTIONS: Intl.DateTimeFormatOptions = {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}

const DEFAULT_TIME_OPTIONS: Intl.DateTimeFormatOptions = {
  hour: '2-digit',
  minute: '2-digit',
}

const DEFAULT_DATE_TIME_OPTIONS: Intl.DateTimeFormatOptions = {
  ...DEFAULT_DATE_OPTIONS,
  ...DEFAULT_TIME_OPTIONS,
}

export function resolveFormatLocale(locale: string, formatLocale: string | null): FormatLocale {
  if (formatLocale && FORMAT_LOCALES.has(formatLocale as FormatLocale)) {
    return formatLocale as FormatLocale
  }

  const normalized = (locale || '').toLowerCase().replaceAll('_', '-')
  if (FORMAT_LOCALES.has(normalized as FormatLocale)) {
    return normalized as FormatLocale
  }

  if (normalized.startsWith('ar')) return 'ar-EG'
  if (normalized.startsWith('zh-hant') || normalized.startsWith('zh-tw') || normalized.startsWith('zh-hk') || normalized.startsWith('zh-mo')) return 'zh-TW'
  if (normalized.startsWith('zh')) return 'zh-CN'
  if (normalized.startsWith('en-gb')) return 'en-GB'
  if (normalized.startsWith('en')) return 'en-US'
  if (normalized.startsWith('ja')) return 'ja-JP'
  if (normalized.startsWith('de')) return 'de-DE'
  if (normalized.startsWith('id')) return 'id-ID'

  return 'zh-CN'
}

function toDate(value: DateInput): Date | null {
  if (value === null || value === undefined || value === '') return null

  let date: Date
  if (typeof value === 'string') {
    const trimmed = value.trim()
    if (!trimmed) return null
    // Date-only values are parsed as local midnight so the displayed date is stable across time zones.
    date = /^\d{4}-\d{2}-\d{2}$/.test(trimmed) ? new Date(`${trimmed}T00:00:00`) : new Date(trimmed)
  } else {
    date = new Date(value)
  }

  return isNaN(date.getTime()) ? null : date
}

function toNumber(value: NumberInput): number | null {
  if (value === null || value === undefined || value === '') return null
  if (typeof value === 'string' && value.trim() === '') return null
  const number = Number(value)
  return Number.isFinite(number) ? number : null
}

export function formatDate(value: DateInput, locale: string, options?: Intl.DateTimeFormatOptions): string {
  const date = toDate(value)
  if (!date) return '-'
  const resolvedLocale = resolveFormatLocale(locale, null)
  return new Intl.DateTimeFormat(resolvedLocale, options ?? DEFAULT_DATE_OPTIONS).format(date)
}

export function formatTime(value: DateInput, locale: string, options?: Intl.DateTimeFormatOptions): string {
  const date = toDate(value)
  if (!date) return '-'
  const resolvedLocale = resolveFormatLocale(locale, null)
  return new Intl.DateTimeFormat(resolvedLocale, options ?? DEFAULT_TIME_OPTIONS).format(date)
}

export function formatDateTime(value: DateInput, locale: string, options?: Intl.DateTimeFormatOptions): string {
  const date = toDate(value)
  if (!date) return '-'
  const resolvedLocale = resolveFormatLocale(locale, null)
  return new Intl.DateTimeFormat(resolvedLocale, options ?? DEFAULT_DATE_TIME_OPTIONS).format(date)
}

export function formatNumber(value: NumberInput, locale: string, options?: Intl.NumberFormatOptions): string {
  const number = toNumber(value)
  if (number === null) return '-'
  const resolvedLocale = resolveFormatLocale(locale, null)
  return new Intl.NumberFormat(resolvedLocale, options ?? {}).format(number)
}

export function formatPercent(value: NumberInput, locale: string, options?: Intl.NumberFormatOptions): string {
  const number = toNumber(value)
  if (number === null) return '-'
  const resolvedLocale = resolveFormatLocale(locale, null)
  return new Intl.NumberFormat(resolvedLocale, { style: 'percent', ...options }).format(number)
}

export function formatMoney(value: NumberInput, currency: string, locale: string): string {
  const number = toNumber(value)
  if (number === null) return '-'
  const code = typeof currency === 'string' ? currency.trim().toUpperCase() : ''
  if (!code) return '-'

  const resolvedLocale = resolveFormatLocale(locale, null)
  try {
    const parts = new Intl.NumberFormat(resolvedLocale, {
      style: 'currency',
      currency: code,
      currencyDisplay: 'code',
    }).formatToParts(number)
    const numberText = parts.filter((part) => part.type !== 'currency').map((part) => part.value).join('').trim()
    return `${numberText} ${code}`
  } catch {
    return '-'
  }
}

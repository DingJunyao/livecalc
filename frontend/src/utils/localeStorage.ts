export const LOCALE_STORAGE_KEY = 'livecalc.locale'
export const FORMAT_LOCALE_STORAGE_KEY = 'livecalc.formatLocale'

export const UI_LOCALES = ['zh-CN', 'en-US', 'ar'] as const
export const FORMAT_LOCALES = [
  null,
  'zh-CN',
  'zh-TW',
  'en-US',
  'en-GB',
  'ja-JP',
  'de-DE',
  'id-ID',
  'ar-EG',
] as const

export type UiLocale = (typeof UI_LOCALES)[number]
export type FormatLocale = (typeof FORMAT_LOCALES)[number]

const DEFAULT_UI_LOCALE: UiLocale = 'zh-CN'
const DEFAULT_FORMAT_LOCALES: Record<UiLocale, string> = {
  'zh-CN': 'zh-CN',
  'en-US': 'en-US',
  ar: 'ar-EG',
}

export function normalizeUiLocale(value: string | null | undefined): UiLocale {
  if (value === 'zh-CN' || value === 'en-US' || value === 'ar') {
    return value
  }
  return DEFAULT_UI_LOCALE
}

export function normalizeFormatLocale(value: string | null | undefined): FormatLocale {
  if (value === null || value === undefined) return null
  if (FORMAT_LOCALES.includes(value as FormatLocale)) {
    return value as FormatLocale
  }
  return null
}

function browserLocale(): string | null {
  if (typeof window === 'undefined' || !window.navigator) return null
  return window.navigator.languages?.[0] || window.navigator.language || null
}

function mapBrowserLocale(value: string | null): UiLocale | null {
  if (!value) return null
  const normalized = value.toLowerCase().replaceAll('_', '-')
  if (normalized.startsWith('zh-hans') || normalized.startsWith('zh-cn') || normalized.startsWith('zh-sg') || normalized.startsWith('zh')) {
    return 'zh-CN'
  }
  if (normalized.startsWith('en')) {
    return 'en-US'
  }
  if (normalized.startsWith('ar')) {
    return 'ar'
  }
  return null
}

export function readStoredLocale(): UiLocale {
  if (typeof window === 'undefined') return DEFAULT_UI_LOCALE
  const stored = window.localStorage.getItem(LOCALE_STORAGE_KEY)
  if (stored) return normalizeUiLocale(stored)
  return mapBrowserLocale(browserLocale()) ?? DEFAULT_UI_LOCALE
}

export function readStoredFormatLocale(): FormatLocale {
  if (typeof window === 'undefined') return null
  const stored = window.localStorage.getItem(FORMAT_LOCALE_STORAGE_KEY)
  if (stored === null) return null
  return normalizeFormatLocale(stored)
}

export function writeStoredLocale(locale: string): UiLocale {
  const normalized = normalizeUiLocale(locale)
  if (typeof window !== 'undefined') {
    window.localStorage.setItem(LOCALE_STORAGE_KEY, normalized)
  }
  return normalized
}

export function writeStoredFormatLocale(formatLocale: string | null): FormatLocale {
  const normalized = normalizeFormatLocale(formatLocale)
  if (typeof window !== 'undefined') {
    if (normalized === null) {
      window.localStorage.removeItem(FORMAT_LOCALE_STORAGE_KEY)
    } else {
      window.localStorage.setItem(FORMAT_LOCALE_STORAGE_KEY, normalized)
    }
  }
  return normalized
}

export function defaultFormatLocale(locale: UiLocale): string {
  return DEFAULT_FORMAT_LOCALES[locale]
}

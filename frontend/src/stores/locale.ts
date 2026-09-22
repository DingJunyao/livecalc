import { defineStore } from 'pinia'
import { computed, ref, watch } from 'vue'
import i18n from '@/plugins/i18n'
import vuetify from '@/plugins/vuetify'
import {
  defaultFormatLocale,
  readStoredFormatLocale,
  readStoredLocale,
  writeStoredFormatLocale,
  writeStoredLocale,
  type FormatLocale,
  type UiLocale,
} from '@/utils/localeStorage'

export interface UserLocalePatch {
  locale?: string | null
  format_locale?: string | null
}

export const useLocaleStore = defineStore('locale', () => {
  const locale = ref<UiLocale>(readStoredLocale())
  const formatLocale = ref<FormatLocale>(readStoredFormatLocale())

  const effectiveFormatLocale = computed<string>(() => {
    return formatLocale.value ?? defaultFormatLocale(locale.value)
  })

  const isRtl = computed(() => locale.value === 'ar')

  function applyLocale(nextLocale: UiLocale) {
    const nextIsRtl = nextLocale === 'ar'
    i18n.global.locale.value = nextLocale
    vuetify.locale.current.value = nextLocale
    vuetify.locale.rtl.value = {
      ...vuetify.locale.rtl.value,
      [nextLocale]: nextIsRtl,
    }
    if (typeof document !== 'undefined') {
      document.documentElement.lang = nextLocale
      document.documentElement.dir = nextIsRtl ? 'rtl' : 'ltr'
    }
  }

  function setLocale(nextLocale: string) {
    locale.value = writeStoredLocale(nextLocale)
  }

  function setFormatLocale(nextFormatLocale: string | null) {
    formatLocale.value = writeStoredFormatLocale(nextFormatLocale)
  }

  function syncFromUser(data: UserLocalePatch) {
    if (data.locale) {
      setLocale(data.locale)
    }
    if (data.format_locale) {
      setFormatLocale(data.format_locale)
    } else {
      setFormatLocale(null)
    }
  }

  watch(locale, (nextLocale) => {
    applyLocale(nextLocale)
  }, { immediate: true })

  return {
    locale,
    formatLocale,
    effectiveFormatLocale,
    isRtl,
    setLocale,
    setFormatLocale,
    syncFromUser,
  }
})

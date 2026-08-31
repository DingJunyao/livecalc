import { createI18n } from 'vue-i18n'
import ar from '../locales/ar.json'
import enUS from '../locales/en-US.json'
import zhCN from '../locales/zh-CN.json'

const i18n = createI18n({
  legacy: false,
  locale: 'zh-CN',
  fallbackLocale: 'zh-CN',
  messages: { 'zh-CN': zhCN, 'en-US': enUS, ar },
})

export default i18n

export function t(key: string, named?: Record<string, unknown>): string {
  return i18n.global.t(key, named ?? {})
}

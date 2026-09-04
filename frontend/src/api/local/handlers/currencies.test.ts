import assert from 'node:assert/strict'
import { test } from 'node:test'
import i18n from '../../../plugins/i18n.ts'
import { localGetCurrencies } from './currencies.ts'

test('local currencies expose display names for the UI locale', () => {
  i18n.global.locale.value = 'zh-CN'
  const zhCurrency = localGetCurrencies().find((currency) => currency.code === 'CNY')
  assert.equal((zhCurrency as any).display_name, '\u4eba\u6c11\u5e01')

  i18n.global.locale.value = 'en-US'
  const enCurrency = localGetCurrencies().find((currency) => currency.code === 'USD')
  assert.equal((enCurrency as any).display_name, 'US Dollar')

  i18n.global.locale.value = 'ar'
  const arCurrency = localGetCurrencies().find((currency) => currency.code === 'EUR')
  assert.equal((arCurrency as any).display_name, 'يورو')
})

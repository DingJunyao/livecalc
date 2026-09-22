import assert from 'node:assert/strict'
import { test } from 'node:test'
import { currencyDisplayName, currencyOptionLabel } from './currencyLabels.ts'

test('currency labels prefer localized display_name over raw name', () => {
  assert.equal(
    currencyDisplayName({ code: 'USD', name: '\u7f8e\u5143', display_name: 'US Dollar' }),
    'US Dollar',
  )
  assert.equal(
    currencyDisplayName({ code: 'CNY', name: '\u4eba\u6c11\u5e01', display_name: null }),
    '\u4eba\u6c11\u5e01',
  )
  assert.equal(currencyDisplayName({ code: 'EUR', name: 'EUR' }), 'EUR')
})

test('currency option labels include the ISO code when a name exists', () => {
  assert.equal(
    currencyOptionLabel({ code: 'USD', name: '\u7f8e\u5143', display_name: 'US Dollar' }),
    'US Dollar (USD)',
  )
  assert.equal(currencyOptionLabel({ code: 'CNY', name: 'CNY' }), 'CNY')
})

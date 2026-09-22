import assert from 'node:assert/strict'
import { test } from 'node:test'
import i18n from '../../../plugins/i18n.ts'
import { regionDisplayName } from './regions.ts'

test('region display names follow the UI locale', () => {
  const guangdong = {
    name: '\u5e7f\u4e1c\u7701',
    name_en: 'Guangdong',
    iso_country: 'CN',
    level: 1,
  }

  i18n.global.locale.value = 'zh-CN'
  assert.equal(regionDisplayName(guangdong), '\u5e7f\u4e1c\u7701')
  assert.equal(regionDisplayName({ name: 'China', name_en: 'China', iso_country: 'CN', level: 0 }), '\u4e2d\u56fd')

  i18n.global.locale.value = 'en-US'
  assert.equal(regionDisplayName(guangdong), 'Guangdong')
  assert.equal(regionDisplayName({ name: 'China', name_en: 'China', iso_country: 'CN', level: 0 }), 'China')

  i18n.global.locale.value = 'ar'
  assert.equal(regionDisplayName(guangdong), 'Guangdong')
  assert.equal(regionDisplayName({ name: 'China', name_en: 'China', iso_country: 'CN', level: 0 }), '\u0627\u0644\u0635\u064a\u0646')
})

import assert from 'node:assert/strict'
import { test } from 'node:test'
import i18n from '../plugins/i18n.ts'
import { CHINESE_GRAM_NAME, CHINESE_JIN_NAME, CHINESE_PIECE_NAME } from '../data/localValues.ts'
import {
  adminBackgroundMarker,
  canonicalMassUnitName,
  canonicalPriceUnitName,
  fallbackPriceUnitValues,
  localUserNickname,
  localizedMassUnitLabel,
  localizedPriceUnitLabel,
  localizedUnitLabel,
  newNameSuffix,
  pendingReviewMarker,
  proposalMarker,
  unknownIngredientName,
} from './localDisplay.ts'

test('display-only local values follow the active locale', () => {
  i18n.global.locale.value = 'en-US'
  assert.equal(localUserNickname(), 'Local user')
  assert.equal(unknownIngredientName(), 'Unknown ingredient')
  assert.equal(newNameSuffix(), ' (new)')

  i18n.global.locale.value = 'zh-CN'
  assert.equal(localUserNickname(), '\u672c\u5730\u7528\u6237')
  assert.equal(unknownIngredientName(), '\u672a\u77e5\u539f\u6599')
})

test('protocol markers stay fixed across locales', () => {
  const expectedAdmin = '[\u540e\u53f0]'
  const expectedPending = '\u5f85\u7ba1\u7406\u5458\u5ba1\u6838'
  const expectedProposal = '\u63d0\u8bae'

  i18n.global.locale.value = 'zh-CN'
  assert.equal(adminBackgroundMarker(), expectedAdmin)
  assert.equal(pendingReviewMarker(), expectedPending)
  assert.equal(proposalMarker(), expectedProposal)

  i18n.global.locale.value = 'en-US'
  assert.equal(adminBackgroundMarker(), expectedAdmin)
  assert.equal(pendingReviewMarker(), expectedPending)
  assert.equal(proposalMarker(), expectedProposal)
})

test('canonical unit helpers and localized labels stay separate', () => {
  assert.equal(canonicalMassUnitName(), CHINESE_JIN_NAME)
  assert.equal(canonicalPriceUnitName(), CHINESE_JIN_NAME)
  assert.deepEqual(fallbackPriceUnitValues().slice(0, 3), [
    CHINESE_JIN_NAME,
    CHINESE_PIECE_NAME,
    'kg',
  ])
  assert.deepEqual(fallbackPriceUnitValues().slice(3, 5), [
    CHINESE_GRAM_NAME,
    '\u5347',
  ])

  i18n.global.locale.value = 'en-US'
  assert.equal(localizedMassUnitLabel(), 'Jin (500 g)')
  assert.equal(localizedPriceUnitLabel(), 'Jin (500 g)')
  assert.equal(localizedUnitLabel(CHINESE_GRAM_NAME), 'Gram')

  i18n.global.locale.value = 'zh-CN'
  assert.equal(localizedMassUnitLabel(), '\u65a4')
  assert.equal(localizedPriceUnitLabel(), '\u65a4')
  assert.equal(localizedUnitLabel(CHINESE_GRAM_NAME), '\u514b')
})

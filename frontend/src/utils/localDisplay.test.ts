import assert from 'node:assert/strict'
import { test } from 'node:test'
import i18n from '../plugins/i18n.ts'
import {
  adminBackgroundMarker,
  fallbackPriceUnitValues,
  localUserNickname,
  newNameSuffix,
  pendingReviewMarker,
  proposalMarker,
  unknownIngredientName,
} from './localDisplay.ts'

test('local display values follow the active locale', () => {
  i18n.global.locale.value = 'en-US'
  assert.equal(localUserNickname(), 'Local user')
  assert.equal(unknownIngredientName(), 'Unknown ingredient')
  assert.equal(adminBackgroundMarker(), '[Admin]')
  assert.equal(pendingReviewMarker(), 'Pending admin review')
  assert.equal(proposalMarker(), 'Proposal')
  assert.equal(newNameSuffix(), ' (new)')
  assert.deepEqual(fallbackPriceUnitValues().slice(0, 3), ['Jin (500 g)', 'Piece', 'kg'])

  i18n.global.locale.value = 'zh-CN'
  assert.equal(localUserNickname(), '\u672c\u5730\u7528\u6237')
  assert.equal(unknownIngredientName(), '\u672a\u77e5\u539f\u6599')
  assert.deepEqual(fallbackPriceUnitValues().slice(0, 3), ['\u65a4', '\u4e2a', 'kg'])
})

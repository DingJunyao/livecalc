import assert from 'node:assert/strict'
import test from 'node:test'

import {
  buildLinkEquivalents,
  formatGramsSelfCheck,
  formatLinkSentence,
  mergeLinkUnits,
  type EntityQuantityLink,
} from './entityLinks.ts'

function link(overrides: Partial<EntityQuantityLink> = {}): EntityQuantityLink {
  return {
    id: 1,
    current: {
      type: 'product', id: 1, name: '五连包',
      quantity: 1, unit: '提', ingredient_id: 10,
    },
    other: {
      type: 'product', id: 2, name: '单包',
      quantity: 5, unit: '包', ingredient_id: 10,
    },
    other_per_current: 5,
    current_per_other: 0.2,
    grams_per_current_unit: 425,
    grams_per_other_unit: 85,
    price_factor_current_to_other: 1,
    resolvable: true,
    other_latest_price: 5,
    other_latest_price_unit: '包',
    equivalent_current_price: 25,
    ...overrides,
  }
}

test('formatLinkSentence prints the full equation', () => {
  assert.equal(
    formatLinkSentence(link()),
    '1 提 五连包 = 5 包 单包',
  )
  assert.equal(
    formatLinkSentence(link({
      current: { type: 'ingredient', id: 1, name: '鲜香菇', quantity: 3, unit: 'kg' },
      other: { type: 'ingredient', id: 2, name: '干香菇', quantity: 1, unit: 'kg' },
      other_per_current: 1 / 3,
    })),
    '3 kg 鲜香菇 = 1 kg 干香菇',
  )
})

test('formatGramsSelfCheck uses grams per current unit', () => {
  assert.equal(formatGramsSelfCheck(link()), '1 提 ≈ 425 g')
  assert.equal(formatGramsSelfCheck(link({ resolvable: false, grams_per_current_unit: null })), '')
})

test('buildLinkEquivalents converts a record price to the other side unit', () => {
  const rows = buildLinkEquivalents(link(), 25, 1, '提')
  assert.equal(rows.length, 1)
  assert.equal(rows[0].unit, '包')
  assert.equal(rows[0].productName, '单包')
  assert.equal(rows[0].unitPrice, 5)

  assert.deepEqual(buildLinkEquivalents(link(), 25, 1, '包'), [])
  assert.deepEqual(buildLinkEquivalents(link(), 25, 0, '提'), [])
})

test('mergeLinkUnits adds link units without duplicates', () => {
  const base = [{ title: 'g', value: 'g' }]
  const merged = mergeLinkUnits(base, [link()])
  assert.deepEqual(merged.map(item => item.value), ['g', '提', '包'])
})

import assert from 'node:assert/strict'
import test from 'node:test'

import {
  hasCompleteFactorFields,
  hasEmptyFactorFields,
  hierarchyPriceFactor,
} from './hierarchyFactor.ts'

test('hierarchyPriceFactor computes 1 kg dried = 3 kg fresh as 1/3', () => {
  // 干(父) 1 kg=1000g，鲜(子) 3 kg=3000g → factor = 1000/3000
  const factor = hierarchyPriceFactor(1, 1000, 3, 1000)
  assert.ok(Math.abs(factor - 1 / 3) < 1e-12)
})

test('hierarchyPriceFactor falls back to 1 on missing grams or invalid values', () => {
  assert.equal(hierarchyPriceFactor(1, null, 3, 1000), 1)
  assert.equal(hierarchyPriceFactor(1, 1000, 3, null), 1)
  assert.equal(hierarchyPriceFactor(null, 1000, 3, 1000), 1)
  assert.equal(hierarchyPriceFactor(0, 1000, 3, 1000), 1)
  assert.equal(hierarchyPriceFactor(-1, 1000, 3, 1000), 1)
})

test('factor field completeness helpers treat partial input as neither complete nor empty', () => {
  const partial = {
    factor_parent_quantity: 1,
    factor_parent_unit: 'kg',
    factor_child_quantity: 3,
    factor_child_unit: '',
  }
  assert.equal(hasCompleteFactorFields(partial), false)
  assert.equal(hasEmptyFactorFields(partial), false)
  assert.equal(hasCompleteFactorFields(null), false)
  assert.equal(hasEmptyFactorFields(null), true)
  assert.equal(
    hasCompleteFactorFields({
      factor_parent_quantity: 1,
      factor_parent_unit: 'kg',
      factor_child_quantity: 3,
      factor_child_unit: 'kg',
    }),
    true,
  )
})

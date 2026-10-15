import { test } from 'node:test'
import assert from 'node:assert/strict'

import {
  buildBasisUnitOptions,
  buildDefaultNutrientRows,
  formatBasisAmount,
  normalizeBasisAmount,
  normalizeBasisUnit,
  readNutritionBasis,
  resolvableBasisUnitNames,
  withCurrentBasisUnit,
} from './nutritionBasis.ts'

const DEFS = [
  { key: 'energy', label: '能量', units: ['kcal', 'kJ'], defaultUnit: 'kcal' },
  { key: 'protein', label: '蛋白质', units: ['g', 'mg'], defaultUnit: 'g' },
  { key: 'fat', label: '脂肪', units: ['g', 'mg'], defaultUnit: 'g' },
  { key: 'carbohydrate', label: '碳水化合物', units: ['g', 'mg'], defaultUnit: 'g' },
  { key: 'sodium', label: '钠', units: ['mg', 'g'], defaultUnit: 'mg' },
  { key: 'fiber', label: '膳食纤维', units: ['g'], defaultUnit: 'g' },
]

test('默认行是五项核心营养素，能量 kJ、钠 mg', () => {
  const rows = buildDefaultNutrientRows(DEFS)
  assert.deepEqual(rows.map(r => r.key), ['energy', 'protein', 'fat', 'carbohydrate', 'sodium'])
  assert.deepEqual(rows.map(r => r.unit), ['kJ', 'g', 'g', 'g', 'mg'])
  assert.ok(rows.every(r => r.value === null))
})

test('默认行跳过定义表里没有的营养素', () => {
  const rows = buildDefaultNutrientRows([DEFS[0]])
  assert.equal(rows.length, 1)
  assert.equal(rows[0].key, 'energy')
})

test('基准量/单位归一化', () => {
  assert.equal(normalizeBasisAmount(250), 250)
  assert.equal(normalizeBasisAmount(0), 100)
  assert.equal(normalizeBasisAmount(-5), 100)
  assert.equal(normalizeBasisAmount('abc'), 100)
  assert.equal(formatBasisAmount(100), '100')
  assert.equal(formatBasisAmount(2.5), '2.5')
  assert.equal(formatBasisAmount('3.140000'), '3.14')
  assert.equal(normalizeBasisUnit('  '), 'g')
  assert.equal(normalizeBasisUnit('mL'), 'mL')
})

test('可折算自定义单位：有单件重量才进候选', () => {
  const rows = [
    { id: 1, unit_name: '袋', weight_per_unit: 250 },
    { id: 2, unit_name: '把', weight_per_unit: null },
  ]
  assert.deepEqual(resolvableBasisUnitNames(rows, []), ['袋'])
})

test('可折算自定义单位：嵌套引用跟随被引用方', () => {
  const rows = [
    { id: 1, unit_name: '袋', weight_per_unit: 250 },
    { id: 2, unit_name: '箱', weight_per_unit: 12, weight_unit_override_id: 1 },
    { id: 3, unit_name: '悬空箱', weight_per_unit: 12, weight_unit_override_id: 99 },
  ]
  // 箱：引用「袋」可折算 → 可作基准；悬空箱：引用不存在，但本行另有 weight_per_unit，
  // 后端会退化到「12 g」的全局单位路径 —— 与后端一致地判为可折算
  assert.deepEqual(resolvableBasisUnitNames(rows, []), ['袋', '箱', '悬空箱'])
})

test('可折算自定义单位：引用的全局单位必须是质量/体积', () => {
  const rows = [
    { id: 1, unit_name: '袋', weight_per_unit: 250, weight_unit_id: 3 },
    { id: 2, unit_name: '颗', weight_per_unit: 5, weight_unit_id: 49 },
  ]
  const globals = [
    { id: 3, unit_type: 'mass' },
    { id: 49, unit_type: 'count' },
  ]
  assert.deepEqual(resolvableBasisUnitNames(rows, globals), ['袋'])
})

test('可折算自定义单位：同名只保留第一条（实体自身优先）', () => {
  const rows = [
    { id: 1, unit_name: '袋', weight_per_unit: 250 },
    { id: 2, unit_name: '袋', weight_per_unit: 300 },
  ]
  assert.deepEqual(resolvableBasisUnitNames(rows, []), ['袋'])
})

test('基准候选：自定义单位在前，同名全局项让位', () => {
  const options = buildBasisUnitOptions(
    [
      { title: '克 (g)', value: 'g' },
      { title: '毫升 (mL)', value: 'mL' },
      { title: '袋 (袋)', value: '袋' },
    ],
    ['袋'],
  )
  assert.deepEqual(options.map(o => o.value), ['袋', 'g', 'mL'])
})

test('基准候选：当前值不在候选里也要能回显', () => {
  const options = buildBasisUnitOptions([{ title: '克 (g)', value: 'g' }], [])
  const withCurrent = withCurrentBasisUnit(options, '已删除的单位')
  assert.equal(withCurrent[0].value, '已删除的单位')
  assert.equal(withCurrent.length, 2)
  // 已在候选里则不重复添加
  assert.deepEqual(withCurrentBasisUnit(options, 'g').map(o => o.value), ['g'])
})

test('从营养响应读基准：统一字段优先，其次自定义数据，最后 base_*', () => {
  assert.deepEqual(
    readNutritionBasis({ reference_amount: 250, reference_unit: 'mL' }),
    { amount: 250, unit: 'mL' },
  )
  assert.deepEqual(
    readNutritionBasis({ custom_nutrition_data: { reference_amount: 1, reference_unit: '袋' } }),
    { amount: 1, unit: '袋' },
  )
  assert.deepEqual(readNutritionBasis({ base_quantity: 30, base_unit: 'g' }), { amount: 30, unit: 'g' })
  // 缺省 / 脏数据都回落到 100 g
  assert.deepEqual(readNutritionBasis(null), { amount: 100, unit: 'g' })
  assert.deepEqual(
    readNutritionBasis({ reference_amount: 0, reference_unit: '' }),
    { amount: 100, unit: 'g' },
  )
})

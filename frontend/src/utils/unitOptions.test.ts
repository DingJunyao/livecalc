import assert from 'node:assert/strict'
import test from 'node:test'

import { pickDefaultUnitName, withoutShadowedGlobals } from './unitOptions.ts'

const GRAM = { id: 3, name: '克', abbreviation: 'g' }
const GRAIN = { id: 49, name: '颗', abbreviation: '颗' }
const CATTY = { id: 7, name: '斤', abbreviation: '斤' }

test('withoutShadowedGlobals 隐藏与实体自定义单位同名的全局单位', () => {
  // 全局单位表里有「颗」，包菜原料又自定义了「颗 = 500 克」→ 只保留实体那条
  const globals = [GRAM, GRAIN, CATTY]
  const entity = [{ unit_name: '颗', weight_per_unit: 500 }]
  assert.deepEqual(
    withoutShadowedGlobals(globals, entity).map(unit => unit.id),
    [3, 7],
  )
})

test('withoutShadowedGlobals 实体没有自定义单位时原样保留（且不共享数组）', () => {
  const globals = [GRAM, GRAIN]
  const result = withoutShadowedGlobals(globals, [])
  assert.deepEqual(result.map(unit => unit.id), [3, 49])
  assert.notEqual(result, globals)
})

test('withoutShadowedGlobals 名字两侧空白 / unit_name 优先', () => {
  const globals = [{ name: ' 颗 ' }, { name: '克' }]
  // 实体行的 unit_name 为空串时回退不到 name（行本身没有 name）→ 不算同名
  assert.deepEqual(
    withoutShadowedGlobals(globals, [{ unit_name: '颗' }, { unit_name: '' }]).map(
      unit => unit.name.trim(),
    ),
    ['克'],
  )
  assert.deepEqual(
    withoutShadowedGlobals(globals, [{ name: '颗' }]).map(unit => unit.name.trim()),
    ['克'],
  )
})

test('withoutShadowedGlobals 全局行缺名字时保留（不误删）', () => {
  assert.deepEqual(
    withoutShadowedGlobals([{ id: 1 }, { id: 2, name: '颗' }], [{ unit_name: '颗' }]).map(
      unit => unit.id,
    ),
    [1],
  )
})

test('pickDefaultUnitName 取第一条 is_default=true 的单位名', () => {
  assert.equal(
    pickDefaultUnitName([
      { unit_name: '盒', is_default: false },
      { unit_name: '箱', is_default: true },
      { unit_name: '袋', is_default: true },
    ]),
    '箱',
  )
  // name 兜底 + 两侧空白
  assert.equal(pickDefaultUnitName([{ name: ' 桶 ', is_default: true }]), '桶')
})

test('pickDefaultUnitName 没有默认单位 / 空数据时返回 null', () => {
  assert.equal(pickDefaultUnitName([{ unit_name: '盒', is_default: false }]), null)
  // 宽松真值不算默认（后端可能给 null / 缺字段）
  assert.equal(pickDefaultUnitName([{ unit_name: '盒' }, { unit_name: '箱', is_default: null }]), null)
  assert.equal(pickDefaultUnitName([]), null)
  assert.equal(pickDefaultUnitName(null), null)
  // 默认行名字为空时继续找下一条
  assert.equal(
    pickDefaultUnitName([{ unit_name: '  ', is_default: true }, { unit_name: '袋', is_default: true }]),
    '袋',
  )
})

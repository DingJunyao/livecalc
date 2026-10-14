import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  gramsPerGlobalUnit,
  millilitersPerGlobalUnit,
  overrideAmounts,
  type GlobalUnitLike,
  type OverrideRowLike,
} from './unitFactor.ts'

// 真实 si_factor（以 kg / L 为基准），与后端 main.py 的种子数据一致。
// 用 1 当夹具会掩盖 1000 倍的错误——「1 个 = 200 g 显示成 0.2 g」就是这样漏出去的。
const G: GlobalUnitLike = { id: 3, unit_type: 'mass', si_factor: 0.001 }
const KG: GlobalUnitLike = { id: 2, unit_type: 'mass', si_factor: 1 }
const JIN: GlobalUnitLike = { id: 7, unit_type: 'mass', si_factor: 0.5 }
const LIANG: GlobalUnitLike = { id: 8, unit_type: 'mass', si_factor: 0.05 }
const ML: GlobalUnitLike = { id: 5, unit_type: 'volume', si_factor: 0.001 }
const L: GlobalUnitLike = { id: 4, unit_type: 'volume', si_factor: 1 }
const GE: GlobalUnitLike = { id: 18, unit_type: 'count', si_factor: 1 }

const DENSITY = 1030 // 牛奶 kg/m³

function globals(...units: GlobalUnitLike[]): Map<number, GlobalUnitLike> {
  return new Map(units.map(u => [u.id as number, u]))
}

test('每个全局单位折算：质量按 kg 基准 ×1000，体积按 L 基准 ×1000', () => {
  assert.equal(gramsPerGlobalUnit(G, DENSITY), 1)
  assert.equal(gramsPerGlobalUnit(KG, DENSITY), 1000)
  assert.equal(gramsPerGlobalUnit(JIN, DENSITY), 500)
  assert.equal(gramsPerGlobalUnit(LIANG, DENSITY), 50)
  // 体积：si(L) × 密度(kg/m³)，数值上即 g/L
  assert.equal(gramsPerGlobalUnit(ML, DENSITY), 1.03)
  assert.equal(gramsPerGlobalUnit(L, DENSITY), 1030)
  // 计数单位不参与克换算
  assert.equal(gramsPerGlobalUnit(GE, DENSITY), null)
  assert.equal(gramsPerGlobalUnit(undefined, DENSITY), null)
})

test('每个全局体积单位折算毫升', () => {
  assert.equal(millilitersPerGlobalUnit(ML), 1)
  assert.equal(millilitersPerGlobalUnit(L), 1000)
  assert.equal(millilitersPerGlobalUnit(G), null)
  assert.equal(millilitersPerGlobalUnit(GE), null)
})

test('用户报告的场景：1 个 = 200 g 必须显示 200 g（不是 0.2 g）', () => {
  const row: OverrideRowLike = {
    id: 280,
    unit_name: '个',
    conversion_factor: 1,
    weight_per_unit: 200,
    weight_unit_id: 3,
    weight_unit_override_id: null,
  }
  const amounts = overrideAmounts(row, new Map(), globals(G, KG, JIN, ML, L), DENSITY)
  assert.ok(amounts)
  assert.equal(amounts.grams, 200)
  assert.equal(amounts.milliliters, null)
})

test('质量叶子按各自 si_factor 折算（kg / 斤 / 未设重量单位按克）', () => {
  const byId = new Map<number, OverrideRowLike>()
  const g = globals(G, KG, JIN, ML, L)

  assert.equal(
    overrideAmounts({ id: 1, weight_per_unit: 2, weight_unit_id: 2 }, byId, g, DENSITY)?.grams,
    2000,
  )
  assert.equal(
    overrideAmounts({ id: 2, weight_per_unit: 2, weight_unit_id: 7 }, byId, g, DENSITY)?.grams,
    1000,
  )
  // 未设重量单位：后端按克兜底
  assert.equal(
    overrideAmounts({ id: 3, weight_per_unit: 55 }, byId, g, DENSITY)?.grams,
    55,
  )
  // 无 weight_per_unit 也无引用：不可折算
  assert.equal(overrideAmounts({ id: 4, weight_unit_id: 3 }, byId, g, DENSITY), null)
})

test('体积叶子：mL 与 L 都折算成毫升与克', () => {
  const byId = new Map<number, OverrideRowLike>()
  const g = globals(G, KG, JIN, ML, L)

  const box = overrideAmounts({ id: 11, weight_per_unit: 220, weight_unit_id: 5 }, byId, g, DENSITY)
  assert.ok(box)
  assert.equal(box.milliliters, 220)
  assert.ok(Math.abs(box.grams - 226.6) < 1e-9)

  const bottle = overrideAmounts({ id: 12, weight_per_unit: 2, weight_unit_id: 4 }, byId, g, DENSITY)
  assert.ok(bottle)
  assert.equal(bottle.milliliters, 2000)
  assert.ok(Math.abs(bottle.grams - 2060) < 1e-9)

  // 未设置密度：按水密度 1000 估算（1 mL = 1 g）
  const water = overrideAmounts({ id: 13, weight_per_unit: 220, weight_unit_id: 5 }, byId, g, null)
  assert.ok(water)
  assert.equal(water.grams, 220)
})

test('嵌套引用：1 箱 = 12 盒，盒 = 220 mL → 2640 mL / 2719.2 g', () => {
  const box: OverrideRowLike = { id: 11, unit_name: '盒', weight_per_unit: 220, weight_unit_id: 5 }
  const carton: OverrideRowLike = {
    id: 12,
    unit_name: '箱',
    weight_per_unit: 12,
    weight_unit_override_id: 11,
  }
  const byId = new Map<number, OverrideRowLike>([[11, box], [12, carton]])
  const amounts = overrideAmounts(carton, byId, globals(G, ML, L), DENSITY)
  assert.ok(amounts)
  assert.equal(amounts.milliliters, 2640)
  assert.ok(Math.abs(amounts.grams - 2719.2) < 1e-9)
})

test('嵌套引用：缺省 weight_per_unit 按 1（后端口径）', () => {
  const box: OverrideRowLike = { id: 21, unit_name: '盒', weight_per_unit: 220, weight_unit_id: 5 }
  const one: OverrideRowLike = { id: 22, unit_name: '提', weight_unit_override_id: 21 }
  const byId = new Map<number, OverrideRowLike>([[21, box], [22, one]])
  const amounts = overrideAmounts(one, byId, globals(ML), DENSITY)
  assert.ok(amounts)
  assert.equal(amounts.milliliters, 220)
})

test('老数据的换算系数继续参与乘算（不改存储语义）', () => {
  const legacy: OverrideRowLike = {
    id: 31,
    unit_name: '袋',
    conversion_factor: 3,
    weight_per_unit: 500,
    weight_unit_id: 3,
  }
  const amounts = overrideAmounts(legacy, new Map(), globals(G), DENSITY)
  assert.ok(amounts)
  assert.equal(amounts.grams, 1500)
})

test('环引用 / 引用断裂 / 缺 si_factor 一律不可折算', () => {
  const a: OverrideRowLike = { id: 41, weight_per_unit: 2, weight_unit_override_id: 42 }
  const b: OverrideRowLike = { id: 42, weight_per_unit: 3, weight_unit_override_id: 41 }
  const cyclic = new Map<number, OverrideRowLike>([[41, a], [42, b]])
  assert.equal(overrideAmounts(a, cyclic, globals(G), DENSITY), null)

  const dangling: OverrideRowLike = { id: 43, weight_per_unit: 2, weight_unit_override_id: 999 }
  assert.equal(overrideAmounts(dangling, new Map(), globals(G), DENSITY), null)

  const noSi: OverrideRowLike = { id: 44, weight_per_unit: 2, weight_unit_id: 77 }
  assert.equal(
    overrideAmounts(noSi, new Map(), globals({ id: 77, unit_type: 'mass', si_factor: 0 }), DENSITY),
    null,
  )
})

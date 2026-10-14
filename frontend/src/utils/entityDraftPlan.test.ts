import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  draftChainReaches,
  draftUnitAmounts,
  nextDraftUnitId,
  planDraftUnitWrites,
  reconcileUnitsAfterIngredientChange,
  unresolvableUnitIds,
  type EntityDraftUnit,
} from './entityDraftPlan.ts'

// 夹具用真实量级的 si_factor（质量基准 kg：g=0.001；体积基准 L：mL=0.001），
// 写成 1 会让「1 个 = 200 g」这类系统性错误被掩盖。
const GLOBAL_G = { id: 1, unit_type: 'mass', si_factor: 0.001, name: 'g', abbreviation: 'g' }
const GLOBAL_KG = { id: 2, unit_type: 'mass', si_factor: 1, name: 'kg', abbreviation: 'kg' }
const GLOBAL_ML = { id: 3, unit_type: 'volume', si_factor: 0.001, name: 'mL', abbreviation: 'mL' }
const GLOBALS = [GLOBAL_G, GLOBAL_KG, GLOBAL_ML]

function draft(partial: Partial<EntityDraftUnit> & { id: number; unit_name: string }): EntityDraftUnit {
  return {
    weight_per_unit: null,
    is_default: false,
    weight_unit_id: null,
    weight_unit_override_id: null,
    ...partial,
  }
}

test('nextDraftUnitId 生成不与既有草稿冲突的负数 id', () => {
  assert.equal(nextDraftUnitId([]), -1)
  assert.equal(nextDraftUnitId([draft({ id: -1, unit_name: 'a' })]), -2)
  // 中间被删掉也不会复用已被占用的 id
  assert.equal(nextDraftUnitId([draft({ id: -1, unit_name: 'a' }), draft({ id: -3, unit_name: 'b' })]), -4)
})

test('planDraftUnitWrites 把被引用的单位排在引用者之前', () => {
  const box = draft({
    id: -1,
    unit_name: '盒',
    weight_per_unit: 200,
    weight_unit_id: GLOBAL_G.id,
  })
  const carton = draft({
    id: -2,
    unit_name: '箱',
    weight_per_unit: 12,
    weight_unit_override_id: box.id,
  })
  // 故意乱序：箱在前，仍需先创建盒
  const plan = planDraftUnitWrites([carton, box])
  assert.deepEqual(plan.batches.map(batch => batch.map(unit => unit.unit_name)), [['盒'], ['箱']])
  assert.deepEqual(plan.cycles, [])
})

test('planDraftUnitWrites 把互不依赖的单位放进同一批', () => {
  const the = draft({ id: -1, unit_name: '个', weight_per_unit: 200, weight_unit_id: GLOBAL_G.id })
  const bag = draft({ id: -2, unit_name: '袋', weight_per_unit: 500, weight_unit_id: GLOBAL_G.id })
  const plan = planDraftUnitWrites([the, bag])
  assert.deepEqual(plan.batches.map(batch => batch.length), [2])
})

test('planDraftUnitWrites 识别循环引用（不创建、不丢行）', () => {
  const a = draft({ id: -1, unit_name: 'A', weight_per_unit: 2, weight_unit_override_id: -2 })
  const b = draft({ id: -2, unit_name: 'B', weight_per_unit: 2, weight_unit_override_id: -1 })
  const plan = planDraftUnitWrites([a, b])
  assert.deepEqual(plan.batches, [])
  assert.deepEqual(plan.cycles.map(unit => unit.unit_name).sort(), ['A', 'B'])
})

test('draftChainReaches 沿引用链判断是否会成环', () => {
  const a = draft({ id: -1, unit_name: 'A', weight_per_unit: 2, weight_unit_override_id: -2 })
  const b = draft({ id: -2, unit_name: 'B', weight_per_unit: 3 })
  assert.equal(draftChainReaches([a, b], a.id, b.id), true)
  assert.equal(draftChainReaches([a, b], b.id, a.id), false)
  assert.equal(draftChainReaches([a, b], b.id, null), false)
})

test('draftUnitAmounts 折算嵌套与体积（真实 si_factor 口径）', () => {
  const the = draft({ id: -1, unit_name: '个', weight_per_unit: 200, weight_unit_id: GLOBAL_G.id })
  const box = draft({ id: -2, unit_name: '盒', weight_per_unit: 220, weight_unit_id: GLOBAL_ML.id })
  const carton = draft({ id: -3, unit_name: '箱', weight_per_unit: 12, weight_unit_override_id: box.id })

  // 1 个 = 200 g（g 的 si_factor 是 0.001，不能直接乘）
  assert.equal(draftUnitAmounts(the, [the, box, carton], [], GLOBALS, 1030)?.grams, 200)

  // 1 盒 = 220 mL，按密度 1030 kg/m³ → 226.6 g
  const boxAmounts = draftUnitAmounts(box, [the, box, carton], [], GLOBALS, 1030)
  assert.equal(Math.round(boxAmounts!.milliliters!), 220)
  assert.equal(Math.round(boxAmounts!.grams * 10) / 10, 226.6)

  // 1 箱 = 12 盒 → 2719.2 g
  const cartonAmounts = draftUnitAmounts(carton, [the, box, carton], [], GLOBALS, 1030)
  assert.equal(Math.round(cartonAmounts!.grams * 10) / 10, 2719.2)
})

test('draftUnitAmounts 引用关联原料的单位（正数 id）也能折算', () => {
  const inheritedBox = {
    id: 77,
    unit_name: '盒',
    weight_per_unit: 220,
    weight_unit_id: GLOBAL_ML.id,
    conversion_factor: 1,
  }
  const carton = draft({
    id: -1,
    unit_name: '箱',
    weight_per_unit: 12,
    // 正数 = 关联原料已存在的自定义单位
    weight_unit_override_id: 77,
  })
  const amounts = draftUnitAmounts(carton, [carton], [inheritedBox], GLOBALS, 1000)
  assert.equal(Math.round(amounts!.grams), 2640)
})

test('draftUnitAmounts 引用断裂时不臆估（返回 null）', () => {
  const broken = draft({ id: -1, unit_name: '箱', weight_per_unit: 12, weight_unit_override_id: -99 })
  assert.equal(draftUnitAmounts(broken, [broken], [], GLOBALS, 1000), null)
  // 没有量也没有引用 → 后端视为不可折算
  const empty = draft({ id: -2, unit_name: '袋' })
  assert.equal(draftUnitAmounts(empty, [empty], [], GLOBALS, 1000), null)
})

test('reconcileUnitsAfterIngredientChange 引用换成全局同名单位（不删行）', () => {
  // 用户场景：商品单位「箱」引用原料包菜的「颗」(31)；换原料后 31 不存在，
  // 但全局单位里本来就有「颗」(49) → 改指向，保留这条自定义单位
  const units = [
    { id: 900, unit_name: '箱', weight_per_unit: 12, weight_unit_override_id: 31 },
  ]
  const result = reconcileUnitsAfterIngredientChange({
    units,
    targetIngredientUnits: [],
    globalUnits: [{ id: 49, unit_name: '颗' }],
    missingRefNames: { 31: '颗' },
  })
  assert.deepEqual(result.removed, [])
  assert.deepEqual(result.retargeted, [
    { id: 900, unit_name: '箱', weight_unit_id: 49, weight_unit_override_id: null },
  ])
})

test('reconcileUnitsAfterIngredientChange 优先改指向新原料的同名单位', () => {
  const units = [{ id: 900, unit_name: '箱', weight_unit_override_id: 31 }]
  const result = reconcileUnitsAfterIngredientChange({
    units,
    targetIngredientUnits: [{ id: 88, unit_name: '颗' }],
    globalUnits: [{ id: 49, unit_name: '颗' }],
    missingRefNames: { 31: '颗' },
  })
  assert.deepEqual(result.retargeted, [
    { id: 900, unit_name: '箱', weight_unit_id: null, weight_unit_override_id: 88 },
  ])
  assert.deepEqual(result.removed, [])
})

test('reconcileUnitsAfterIngredientChange 没有同名单位才移除（含下游）', () => {
  const units = [
    { id: 900, unit_name: '箱', weight_unit_override_id: 31 },
    { id: 901, unit_name: '大箱', weight_unit_override_id: 900 },
    { id: 902, unit_name: '个', weight_unit_id: 18 }, // 指向全局单位，不受影响
  ]
  const result = reconcileUnitsAfterIngredientChange({
    units,
    targetIngredientUnits: [],
    globalUnits: [{ id: 18, unit_name: '个' }],
    missingRefNames: { 31: '哈' },
  })
  assert.deepEqual(result.retargeted, [])
  assert.deepEqual(result.removed.sort((a, b) => a - b), [900, 901])
})

test('reconcileUnitsAfterIngredientChange 拿不到旧单位名字时不猜（移除）', () => {
  const units = [{ id: 900, unit_name: '箱', weight_unit_override_id: 31 }]
  const result = reconcileUnitsAfterIngredientChange({
    units,
    targetIngredientUnits: [],
    globalUnits: [{ id: 49, unit_name: '颗' }],
    missingRefNames: {},
  })
  assert.deepEqual(result.retargeted, [])
  assert.deepEqual(result.removed, [900])
})

test('reconcileUnitsAfterIngredientChange 引用仍然有效时什么都不动', () => {
  const units = [
    { id: 900, unit_name: '箱', weight_unit_override_id: 88 },
    { id: 901, unit_name: '个', weight_unit_id: 18 },
  ]
  const result = reconcileUnitsAfterIngredientChange({
    units,
    targetIngredientUnits: [{ id: 88, unit_name: '颗' }],
    globalUnits: [{ id: 18, unit_name: '个' }],
    missingRefNames: {},
  })
  assert.deepEqual(result.retargeted, [])
  assert.deepEqual(result.removed, [])
})

test('unresolvableUnitIds 找出引用失效（含下游）的单位', () => {
  const own = [
    { id: 9, unit_name: '箱', weight_per_unit: 12, is_default: false, weight_unit_id: null, weight_unit_override_id: 77 },
    { id: 10, unit_name: '个', weight_per_unit: 200, is_default: false, weight_unit_id: 1, weight_unit_override_id: null },
  ]
  // 新原料只提供 78，没有 77 → 「箱」失效；指向全局单位的「个」不受影响
  assert.deepEqual([...unresolvableUnitIds(own, new Set([78]))], [9])
})

test('unresolvableUnitIds 引用在目标原料里存在则可解析', () => {
  const own = [
    { id: 9, unit_name: '箱', weight_per_unit: 12, is_default: false, weight_unit_id: null, weight_unit_override_id: 77 },
  ]
  assert.equal(unresolvableUnitIds(own, new Set([77])).size, 0)
})

test('unresolvableUnitIds 级联：依赖失效单位的下游同样失效', () => {
  const own = [
    { id: 9, unit_name: '盒', weight_per_unit: 200, is_default: false, weight_unit_id: null, weight_unit_override_id: 77 },
    { id: 10, unit_name: '箱', weight_per_unit: 12, is_default: false, weight_unit_id: null, weight_unit_override_id: 9 },
  ]
  assert.deepEqual([...unresolvableUnitIds(own, new Set([78]))].sort((a, b) => a - b), [9, 10])
})

test('unresolvableUnitIds 自引用与悬空引用都算失效', () => {
  const own = [
    { id: 9, unit_name: '自引用', weight_per_unit: null, is_default: false, weight_unit_id: null, weight_unit_override_id: 9 },
    { id: 10, unit_name: '悬空', weight_per_unit: null, is_default: false, weight_unit_id: null, weight_unit_override_id: 999 },
  ]
  assert.deepEqual([...unresolvableUnitIds(own, new Set())].sort((a, b) => a - b), [9, 10])
})

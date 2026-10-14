// 新增商品/原料对话框的「自定义单位」草稿：纯函数部分（无网络依赖，可直接被 node --test 跑）。
//
// 为什么需要草稿：新增时实体（商品或原料）还不存在（没有 id），而单位覆盖必须挂在实体 id 上
// （POST /entities/{type}/{id}/units）。所以先在本地用**负数 id** 表示草稿单位，
// 等实体创建成功后再按依赖顺序落库（见 entityDrafts.ts）。
//
// 引用两种「每单位量」：
//   - 负数的 weight_unit_override_id → 同一批草稿里的另一条（嵌套，1箱 = 12 盒）；
//   - 正数的 weight_unit_override_id → 关联原料已存在的自定义单位（后端允许
//     商品 → 其关联原料 的引用，落库时原样发送）。

// 用相对路径 + 显式 .ts 后缀（tsconfig allowImportingTsExtensions）而非 `@/` 别名：
// 本模块要能被 `node --test` 直接加载，Node 的 ESM 解析不认别名也不补后缀。
import { overrideAmounts, type UnitAmounts } from './unitFactor.ts'

/** 待保存的自定义单位草稿。 */
export interface EntityDraftUnit {
  /** 草稿内部 id（恒为负数）。 */
  id: number
  unit_name: string
  weight_per_unit: number | null
  is_default: boolean
  /** 每单位量指向的全局质量/体积单位；与 weight_unit_override_id 互斥。 */
  weight_unit_id: number | null
  weight_unit_override_id: number | null
}

/** 待保存的营养素草稿。 */
export interface EntityDraftNutrient {
  key: string
  name: string
  value: number | null
  unit: string
}

/** 落库计划：批内互不依赖，批与批之间按顺序创建即可满足嵌套引用。 */
export interface DraftUnitPlan {
  batches: EntityDraftUnit[][]
  /** 无法落库的草稿（引用成环）。 */
  cycles: EntityDraftUnit[]
}

/** 生成不与既有草稿冲突的负数 id。 */
export function nextDraftUnitId(units: EntityDraftUnit[]): number {
  let min = 0
  for (const unit of units) {
    if (unit.id < min) min = unit.id
  }
  return min - 1
}

/** 按依赖关系分批：一批内的单位只引用「更早批次」或正数（原料）引用。 */
export function planDraftUnitWrites(units: EntityDraftUnit[]): DraftUnitPlan {
  const batches: EntityDraftUnit[][] = []
  const done = new Set<number>()
  let remaining = [...(units || [])]
  let progressed = true

  while (remaining.length > 0 && progressed) {
    progressed = false
    const batch: EntityDraftUnit[] = []
    const postponed: EntityDraftUnit[] = []
    for (const unit of remaining) {
      const ref = unit.weight_unit_override_id
      if (ref != null && ref < 0 && !done.has(ref)) postponed.push(unit)
      else batch.push(unit)
    }
    if (batch.length > 0) {
      batches.push(batch)
      for (const unit of batch) done.add(unit.id)
      progressed = true
    }
    remaining = postponed
  }

  return { batches, cycles: remaining }
}

/**
 * 候选草稿沿 weight_unit_override_id 链能否走回 [targetId]。
 * 与后端环检测口径一致（visited + 深度上限 8），用于把会成环的候选从下拉里剔除。
 */
export function draftChainReaches(
  units: EntityDraftUnit[],
  candidateId: number,
  targetId: number | null,
): boolean {
  if (targetId == null) return false
  const byId = new Map(units.map(unit => [unit.id, unit]))
  let cursor: number | null = candidateId
  const visited = new Set<number>()
  for (let depth = 0; depth <= 8; depth += 1) {
    if (cursor == null || visited.has(cursor)) return false
    if (cursor === targetId) return true
    visited.add(cursor)
    const row = byId.get(cursor)
    if (!row || row.weight_unit_override_id == null) return false
    cursor = row.weight_unit_override_id
  }
  return false
}

/**
 * 找出引用链无法解析的单位 id。
 *
 * 「无法解析」指：`weight_unit_override_id` 指向的行既不在 [units] 里、
 * 也不在 [availableExternalIds]（如目标原料已有的自定义单位）里；或链上依赖的
 * 单位本身已失效；或自引用。返回值包含依赖失效单位的下游单位
 * （用于「换绑关联原料后清理悬空单位」）。
 */
export function unresolvableUnitIds(
  units: EntityDraftUnit[],
  availableExternalIds: Set<number>,
): Set<number> {
  const ownIds = new Set((units || []).map(unit => unit.id))
  const broken = new Set<number>()
  let changed = true
  while (changed) {
    changed = false
    for (const unit of units || []) {
      if (broken.has(unit.id)) continue
      const ref = unit.weight_unit_override_id
      if (ref == null) continue
      if (ref === unit.id) {
        broken.add(unit.id)
        changed = true
        continue
      }
      const resolvable = availableExternalIds.has(ref) || (ownIds.has(ref) && !broken.has(ref))
      if (!resolvable) {
        broken.add(unit.id)
        changed = true
      }
    }
  }
  return broken
}

/** 参与「换原料后调和」的单位行（只需要引用字段）。 */
export interface UnitRefRow {
  id: number
  unit_name: string
  weight_unit_id?: number | null
  weight_unit_override_id?: number | null
}

export interface UnitRefCandidate {
  id: number
  unit_name: string
}

export interface IngredientChangeReconcile {
  /** 引用改成指向「同名的其它单位」的行（新原料的覆盖优先，其次全局单位） */
  retargeted: {
    id: number
    unit_name: string
    weight_unit_id: number | null
    weight_unit_override_id: number | null
  }[]
  /** 找不到同名单位、只能移除的行 id（含引用链被带断的下游行） */
  removed: number[]
}

/**
 * 换绑关联原料后调和自定义单位。
 *
 * 商品的单位覆盖可以引用**关联原料**的自定义单位（`weight_unit_override_id`）。
 * 换成另一个原料后，原来的引用就指向了「新原料里不存在的 id」。此时不要直接删：
 * 那个单位往往只是**换了归属**（例如「颗」在全局单位表里本来就有），
 * 按名字依次找 ①新原料里的同名单位 ②全局单位里的同名单位，
 * 找到就**改指向**（保留这条自定义单位），只有真的没有同名单位才移除。
 *
 * 改指向之后仍解析不了的行（引用链断掉、自引用）才进入 [removed]，
 * 下游依赖被移除行的单位会一起移除（与 [unresolvableUnitIds] 同口径）。
 */
export function reconcileUnitsAfterIngredientChange(params: {
  units: UnitRefRow[]
  /** 新原料已有的自定义单位（按名字匹配，优先） */
  targetIngredientUnits: UnitRefCandidate[]
  /** 启用中的全局单位（按名字匹配，兜底） */
  globalUnits: UnitRefCandidate[]
  /** 失效引用 id → 单位名（来自旧原料的单位列表；查不到名字的行只能移除） */
  missingRefNames?: Record<number, string>
}): IngredientChangeReconcile {
  const units = params.units || []
  const ownIds = new Set(units.map(unit => unit.id))
  const targetByName = new Map<string, number>()
  for (const row of params.targetIngredientUnits || []) {
    const name = String(row?.unit_name ?? '').trim()
    if (name && !targetByName.has(name)) targetByName.set(name, row.id)
  }
  const targetIds = new Set((params.targetIngredientUnits || []).map(row => row.id))
  const globalByName = new Map<string, number>()
  for (const row of params.globalUnits || []) {
    const name = String(row?.unit_name ?? '').trim()
    if (name && !globalByName.has(name)) globalByName.set(name, row.id)
  }
  const missingRefNames = params.missingRefNames || {}

  // 先算出「改指向」后的引用，再用同一套判定挑出真正要移除的行
  const rewritten = new Map<number, Pick<UnitRefRow, 'weight_unit_id' | 'weight_unit_override_id'>>()
  const retargeted: IngredientChangeReconcile['retargeted'] = []
  for (const unit of units) {
    const ref = unit.weight_unit_override_id
    if (ref == null) continue
    if (ownIds.has(ref) || targetIds.has(ref)) continue
    const name = String(missingRefNames[ref] ?? '').trim()
    if (!name) continue
    const targetId = targetByName.get(name)
    if (targetId != null) {
      rewritten.set(unit.id, { weight_unit_id: null, weight_unit_override_id: targetId })
      retargeted.push({
        id: unit.id,
        unit_name: unit.unit_name,
        weight_unit_id: null,
        weight_unit_override_id: targetId,
      })
      continue
    }
    const globalId = globalByName.get(name)
    if (globalId != null) {
      rewritten.set(unit.id, { weight_unit_id: globalId, weight_unit_override_id: null })
      retargeted.push({
        id: unit.id,
        unit_name: unit.unit_name,
        weight_unit_id: globalId,
        weight_unit_override_id: null,
      })
    }
  }

  const effective: UnitRefRow[] = units.map(unit => {
    const next = rewritten.get(unit.id)
    return next ? { ...unit, ...next } : unit
  })
  const broken = unresolvableUnitIds(
    effective as EntityDraftUnit[],
    new Set([...targetIds].filter(id => !ownIds.has(id))),
  )
  return {
    retargeted: retargeted.filter(row => !broken.has(row.id)),
    removed: [...broken],
  }
}

/**
 * 计算「1 个该草稿单位」折多少克/毫升；无法折算时返回 null（不臆估）。
 * [inheritedUnits] 为关联原料已有的自定义单位行（正数 id），[globals] 为全局单位。
 */
export function draftUnitAmounts(
  unit: EntityDraftUnit,
  units: EntityDraftUnit[],
  inheritedUnits: any[],
  globals: any[],
  densityKgM3: number | null,
): UnitAmounts | null {
  const rows = new Map<number, any>()
  for (const row of inheritedUnits || []) {
    if (row?.id != null) rows.set(Number(row.id), row)
  }
  for (const row of units || []) rows.set(row.id, row)
  const globalMap = new Map<number, any>()
  for (const global of globals || []) {
    if (global?.id != null) globalMap.set(Number(global.id), global)
  }
  return overrideAmounts(unit, rows, globalMap, densityKgM3)
}

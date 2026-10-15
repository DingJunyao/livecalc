/**
 * 营养基准（「每 X 单位」）的纯函数：默认行、单位候选、可折算判定。
 *
 * 不含网络/框架依赖，可被 `node --test` 直接跑（取数的部分见 entityUnits.ts）。
 *
 * 基准单位既可以是全局质量/体积单位（g、mL、斤…），也可以是**本实体的自定义单位**
 * （如「1 袋 = 250 g」）——后者必须能折算成克，否则后端缩放会退化成「按克」口径。
 * 这里的 resolvableBasisUnitNames 与后端 UnitConversionService.resolve_override_amount
 * 的口径保持一致（跟随嵌套引用、最多 8 层、悬空引用只看本行 weight_per_unit）。
 */

export interface BasisUnitOption {
  title: string
  value: string
}

/** 营养基准默认值：每 100 g。 */
export const DEFAULT_NUTRITION_BASIS = { amount: 100, unit: 'g' }

/** 新建营养时的默认营养素：能量/蛋白质/脂肪/碳水化合物/钠（中国营养成分表五项）。 */
export const DEFAULT_NUTRIENT_KEYS = ['energy', 'protein', 'fat', 'carbohydrate', 'sodium'] as const

/**
 * 默认单位覆盖：能量给 kJ（营养成分表通行写法）、钠给 mg；
 * 其余用营养素定义里的 defaultUnit。用户仍可在行内下拉改。
 */
const DEFAULT_UNIT_OVERRIDES: Record<string, string> = {
  energy: 'kJ',
  sodium: 'mg',
}

export interface NutrientDefLike {
  key: string
  label: string
  units: string[]
  defaultUnit: string
}

export interface DefaultNutrientRow {
  key: string
  name: string
  value: number | null
  unit: string
  units: string[]
}

/**
 * 新建（无任何营养数据）时的默认行：五项核心营养素 + 能量 kJ / 钠 mg。
 * 定义表里找不到的键跳过（营养素定义由调用方按用户能量单位偏好构建）。
 */
export function buildDefaultNutrientRows(defs: NutrientDefLike[]): DefaultNutrientRow[] {
  const rows: DefaultNutrientRow[] = []
  for (const key of DEFAULT_NUTRIENT_KEYS) {
    const def = (defs || []).find(item => item?.key === key)
    if (!def) continue
    const preferred = DEFAULT_UNIT_OVERRIDES[key] ?? def.defaultUnit
    const unit = def.units?.includes(preferred) ? preferred : def.defaultUnit
    rows.push({
      key: def.key,
      name: def.label,
      value: null,
      unit,
      units: [...(def.units ?? [])],
    })
  }
  return rows
}

/** 基准量：正数直接取，其余回落到 100（展示/提交前都过一遍）。 */
export function normalizeBasisAmount(raw: unknown): number {
  const value = Number(raw)
  if (!isFinite(value) || value <= 0) return DEFAULT_NUTRITION_BASIS.amount
  return value
}

/** 基准量展示：去掉多余小数位（100 / 2.5 / 0.5），避免出现 100.00。 */
export function formatBasisAmount(raw: unknown): string {
  const value = normalizeBasisAmount(raw)
  return Number.isInteger(value) ? String(value) : String(Math.round(value * 1000) / 1000)
}

/** 基准单位展示：空值回落到 g。 */
export function normalizeBasisUnit(raw: unknown): string {
  const unit = String(raw ?? '').trim()
  return unit || DEFAULT_NUTRITION_BASIS.unit
}

export interface BasisUnitRowLike {
  id?: number | null
  unit_name?: string | null
  weight_per_unit?: number | null
  weight_unit_id?: number | null
  weight_unit_override_id?: number | null
}

export interface GlobalUnitRowLike {
  id?: number | null
  unit_type?: string | null
}

const MAX_OVERRIDE_CHAIN_DEPTH = 8

/**
 * 自定义单位行能否折算成质量/体积（决定它能不能当营养基准）。
 * 口径与后端 resolve_override_amount 一致：嵌套引用时必须**被引用方**可解析。
 */
function isResolvableRow(
  row: BasisUnitRowLike,
  byId: Map<number, BasisUnitRowLike>,
  unitTypeById: Map<number, string>,
  depth = 0,
  seen: Set<number> = new Set(),
): boolean {
  if (!row || depth > MAX_OVERRIDE_CHAIN_DEPTH) return false
  const id = row.id == null ? null : Number(row.id)
  if (id != null) {
    if (seen.has(id)) return false
    seen.add(id)
  }

  const refId = row.weight_unit_override_id
  if (refId != null) {
    const ref = byId.get(Number(refId))
    if (ref && Number(ref.id) !== id && isResolvableRow(ref, byId, unitTypeById, depth + 1, seen)) {
      // 嵌套行自身的 weight_per_unit 缺省按 1（后端口径），不阻塞
      return true
    }
    // 引用悬空/不可解析：只有本行另有 weight_per_unit 时后端才退化到全局单位路径
    return row.weight_per_unit != null
  }

  if (row.weight_per_unit == null) return false
  if (row.weight_unit_id != null) {
    const type = unitTypeById.get(Number(row.weight_unit_id))
    // 量纲必须是质量或体积；未知的全局单位（列表没拉到）不臆断，按可用处理
    if (type && type !== 'mass' && type !== 'volume') return false
  }
  return true
}

/**
 * 可作为营养基准的自定义单位名（已按后端口径过滤掉折算不出来的行）。
 * 行顺序即优先级顺序（实体自身 > 继承），同名只保留第一条。
 */
export function resolvableBasisUnitNames(
  rows: BasisUnitRowLike[] | null | undefined,
  globalUnits: GlobalUnitRowLike[] | null | undefined = [],
): string[] {
  const byId = new Map<number, BasisUnitRowLike>()
  const unitTypeById = new Map<number, string>()
  for (const row of rows || []) {
    if (row?.id == null) continue
    byId.set(Number(row.id), row)
  }
  for (const unit of globalUnits || []) {
    if (unit?.id == null) continue
    unitTypeById.set(Number(unit.id), String(unit.unit_type ?? ''))
  }

  const names: string[] = []
  const seen = new Set<string>()
  for (const row of rows || []) {
    const name = String(row?.unit_name ?? '').trim()
    if (!name || seen.has(name)) continue
    if (!isResolvableRow(row, byId, unitTypeById)) continue
    seen.add(name)
    names.push(name)
  }
  return names
}

/**
 * 营养基准的下拉候选：全局质量/体积单位在后、本实体可折算的自定义单位在前。
 * 同名的全局项让位给更具体的实体定义（与单位解析优先级链一致）。
 */
export function buildBasisUnitOptions(
  globalOptions: BasisUnitOption[],
  customNames: string[],
): BasisUnitOption[] {
  const customSet = new Set(customNames.map(name => name.trim()).filter(Boolean))
  const options: BasisUnitOption[] = []
  const seen = new Set<string>()

  const push = (option: BasisUnitOption) => {
    const value = String(option?.value ?? '').trim()
    if (!value || seen.has(value)) return
    seen.add(value)
    options.push({ title: option.title, value })
  }

  for (const name of customNames) push({ title: name, value: String(name).trim() })
  for (const option of globalOptions || []) {
    if (customSet.has(String(option?.value ?? '').trim())) continue
    push(option)
  }
  return options
}

/**
 * 从营养响应里读基准：reference_amount/reference_unit（原料与商品的统一字段）优先，
 * 其次商品自定义数据里的同名字段，再退到 base_quantity/base_unit，最后 100 g。
 */
export function readNutritionBasis(source: any): { amount: number; unit: string } {
  const root = source ?? {}
  const custom = root.custom_nutrition_data ?? {}
  const amount =
    root.reference_amount ??
    custom?.reference_amount ??
    root.base_quantity ??
    DEFAULT_NUTRITION_BASIS.amount
  const unit =
    root.reference_unit ??
    custom?.reference_unit ??
    root.base_unit ??
    DEFAULT_NUTRITION_BASIS.unit
  return { amount: normalizeBasisAmount(amount), unit: normalizeBasisUnit(unit) }
}

/** 把「当前值」补进候选（后端返回的基准单位可能已不在候选里，仍需原样回显）。 */
export function withCurrentBasisUnit(
  options: BasisUnitOption[],
  current: string,
): BasisUnitOption[] {
  const unit = normalizeBasisUnit(current)
  if (options.some(option => option.value === unit)) return [...options]
  return [{ title: unit, value: unit }, ...(options || [])]
}

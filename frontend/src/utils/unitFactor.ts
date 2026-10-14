// 单位折算（纯函数，无依赖，可由 node --test 直接跑）
//
// ## si_factor 的语义（以后端为准，别想当然）
//
// `units.si_factor` **不是**「每 1 个单位等于多少 g/mL」，而是「换算成 SI 基本单位」的因子：
//   - 质量：基准是 **kg** —— g = 0.001、斤 = 0.5、两 = 0.05、100g = 0.1、kg = 1
//     （后端 main.py 建表注释：「si_factor 以 kg 为基准，100g = 0.1kg」，
//       unit_conversion_service.py「SI 质量单位是 kg」）
//   - 体积：基准是 **L** —— mL = 0.001、L = 1
//     （unit_conversion_service.py「体积 si_factor 换算到 SI 基本单位 L（不是 m³）」）
//
// 因此要把「1 个自定义单位」折算成界面上显示的 g / mL，必须自己乘回基准：
//   - 质量：`si_factor × 1000`  → g（g:0.001→1、斤:0.5→500、kg:1→1000）
//   - 体积：`si_factor × 1000`  → mL（mL:0.001→1、L:1→1000）
//           `si_factor × 密度`   → g （体积(L)→m³(×0.001)→kg(×密度)→g(×1000)，0.001 与 1000 抵消）
//
// 踩过的坑：列表显示曾经直接乘 `si_factor`，于是「1 个 = 200 g」显示成「= 0.2 g」
// （200 × 0.001），体积路径同样差 1000 倍。单位测试必须用真实 si_factor（g=0.001、mL=0.001、
// kg=1、L=1、斤=0.5），用 1 当夹具会把这类错误全部掩盖。

/** 换算链深度上限（与后端 MAX_OVERRIDE_CHAIN_DEPTH 一致）。 */
export const MAX_UNIT_CHAIN_DEPTH = 8

/** 全局单位参与折算所需的最小字段。 */
export interface GlobalUnitLike {
  id?: number | null
  unit_type?: string | null
  si_factor?: number | string | null
}

/** 实体单位覆盖行参与折算所需的最小字段。 */
export interface OverrideRowLike {
  id?: number | null
  unit_name?: string | null
  weight_per_unit?: number | string | null
  conversion_factor?: number | string | null
  weight_unit_id?: number | null
  weight_unit_override_id?: number | null
}

/** 折算结果：克必给，毫升仅在体积语义下给出。 */
export interface UnitAmounts {
  grams: number
  milliliters: number | null
}

function toNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

function siFactorOf(unit: GlobalUnitLike | null | undefined): number | null {
  const si = toNumber(unit?.si_factor)
  if (si === null || si === 0) return null
  return si
}

/**
 * 每 1 个全局单位折多少克。
 * - 质量：si_factor(kg) × 1000
 * - 体积：si_factor(L) × 密度(kg/m³)（数值上等于 g/L）
 * - 计数/长度等不参与质量换算 → null（调用方回退到原样显示）
 */
export function gramsPerGlobalUnit(
  unit: GlobalUnitLike | null | undefined,
  densityKgM3: number | null | undefined,
): number | null {
  const si = siFactorOf(unit)
  if (si === null) return null
  if (unit?.unit_type === 'volume') {
    const density = toNumber(densityKgM3)
    const effective = density !== null && density > 0 ? density : 1000
    return si * effective
  }
  if (unit?.unit_type === 'mass') return si * 1000
  return null
}

/** 每 1 个全局体积单位折多少毫升；质量/计数单位返回 null。 */
export function millilitersPerGlobalUnit(
  unit: GlobalUnitLike | null | undefined,
): number | null {
  if (unit?.unit_type !== 'volume') return null
  const si = siFactorOf(unit)
  return si === null ? null : si * 1000
}

/**
 * 一条实体单位覆盖「1 个该单位」折算出的克 / 毫升。
 *
 * 与后端 `UnitConversionService.resolve_override_amount` 同口径：
 *   `1 单位 = conversion_factor(缺省 1) × weight_per_unit(缺省 1) × weight_unit`
 * - `weight_unit_override_id` 指向另一条覆盖时递归（visited 防环 + 深度上限）；
 * - 未设置重量单位 → 按克（后端 `get_unit_by_abbr('g')` 兜底）；
 * - 无法折算（引用断裂、weight_per_unit 缺失且无引用、全局单位缺 si_factor、
 *   计数/长度单位）→ 返回 null，调用方按「无法折算」处理，不臆估。
 */
export function overrideAmounts(
  row: OverrideRowLike | null | undefined,
  rowsById: Map<number, OverrideRowLike>,
  globalsById: Map<number, GlobalUnitLike>,
  densityKgM3: number | null | undefined,
  visited: Set<number> = new Set(),
  depth = 0,
): UnitAmounts | null {
  if (!row || depth > MAX_UNIT_CHAIN_DEPTH) return null
  const rowId = row.id ?? null
  if (rowId !== null) {
    if (visited.has(rowId)) return null
    visited.add(rowId)
  }
  const factor = toNumber(row.conversion_factor) ?? 1
  const refId = row.weight_unit_override_id ?? null
  if (refId !== null) {
    const ref = rowsById.get(refId)
    if (!ref) return null
    const sub = overrideAmounts(ref, rowsById, globalsById, densityKgM3, visited, depth + 1)
    if (!sub) return null
    // 后端嵌套语义：weight_per_unit 缺省按 1
    const amount = (toNumber(row.weight_per_unit) ?? 1) * factor
    return {
      grams: amount * sub.grams,
      milliliters: sub.milliliters === null ? null : amount * sub.milliliters,
    }
  }
  // 后端：无引用且无 weight_per_unit → 该行不可折算
  const amount = toNumber(row.weight_per_unit)
  if (amount === null) return null
  const total = amount * factor
  const unitId = row.weight_unit_id ?? null
  if (unitId === null) return { grams: total, milliliters: null }
  const unit = globalsById.get(unitId)
  if (!unit) return null
  const gramsPer = gramsPerGlobalUnit(unit, densityKgM3)
  if (gramsPer === null) return null
  const mlPer = millilitersPerGlobalUnit(unit)
  return {
    grams: total * gramsPer,
    milliliters: mlPer === null ? null : total * mlPer,
  }
}

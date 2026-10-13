// 单位换算模块 — 纯函数，不依赖 IndexedDB。
// 基于 SI 因子、实体单位覆盖、密度三层策略完成跨类型换算。

export interface UnitInfo {
  id: number
  name?: string
  unit_type: string     // 'mass' | 'volume' | 'count' | 'length' | 'time'
  si_factor: number | null
  abbreviation?: string
}

export interface EntityOverride {
  id?: number
  entity_type: string
  entity_id: number
  unit_name?: string | null
  base_unit_id: number | null
  conversion_factor: number | null
  weight_per_unit: number | null
  weight_unit_id: number | null
  weight_unit_name?: string | null
  /** 指向同一实体的另一条自定义单位覆盖（嵌套；解析为全局质量/体积单位） */
  weight_unit_override_id?: number | null
  /** 嵌套引用的单位名（云端导出冗余字段；id 会重排，名字优先解析） */
  weight_unit_override_name?: string | null
  is_active?: boolean | number | null
}

export interface DensityInfo {
  entity_type: string
  entity_id: number
  density: number       // kg/m³
}

export interface ConvertInput {
  value: number
  from_unit_id: number
  to_unit_id: number
  entity_type?: string   // 'ingredient' | 'product'
  entity_id?: number
  units: UnitInfo[]
  overrides?: EntityOverride[]
  densities?: DensityInfo[]
}

export interface ConvertResult {
  value: number
  to_unit_id: number
}

import { localError } from '../../../utils/localErrors'

/**
 * 在两个单位之间转换数值。纯函数。
 *
 * 策略：
 * 1. 同类型（mass→mass, volume→volume）：si_factor 比值（直接链式归约到 SI 基准）
 * 2. 跨类型（mass↔volume）：密度桥接（密度 kg/m³ → kg/L）
 * 3. 计数单位（count）：实体单位覆盖 weight_per_unit
 * 4. 最大递归 5 层防止循环
 *
 * 链式换算说明：
 * - 同类型单位转换已通过 SI 因子一步到位：value × (from_si / to_si)
 *   （相当于 from→SI→to 的二段链）
 * - 跨类型转换以密度为单一桥接点：mass↔density↔volume
 * - 更长链（如 count→mass→volume）需调用方分步，或通过实体覆盖的
 *   weight_per_unit 将 count 先转为 mass/volume 再经密度桥接。
 *   当前实现中 count→volume 分支已内置此二层链（line 109-117）。
 */
export function convert(input: ConvertInput): ConvertResult {
  const { value, from_unit_id, to_unit_id, entity_type, entity_id, units, overrides = [], densities = [] } = input

  if (from_unit_id === to_unit_id) {
    return { value, to_unit_id }
  }

  const fromUnit = units.find(u => u.id === from_unit_id)
  const toUnit = units.find(u => u.id === to_unit_id)

  if (!fromUnit || !toUnit) {
    throw localError('unitsNotFound', 400, { from_unit_id, to_unit_id })
  }

  // 同类型：直接 si_factor 换算
  if (fromUnit.unit_type === toUnit.unit_type && fromUnit.si_factor != null && toUnit.si_factor != null) {
    return { value: value * (fromUnit.si_factor / toUnit.si_factor), to_unit_id }
  }

  // 跨类型：密度桥接 (mass ↔ volume)
  if (isMassType(fromUnit.unit_type) && isVolumeType(toUnit.unit_type)) {
    // mass → volume: value / density (density in kg/m³ → kg/L)
    const density = findDensity(from_unit_id, to_unit_id, entity_type, entity_id, units, overrides, densities)
    if (density != null) {
      // density is kg/m³, we need kg/L: divide by 1000
      // value (in mass unit) * fromUnit.siFactor = kg
      // kg / density_kg_per_L = L
      // L / toUnit.siFactor = value in target unit
      const kg = value * fromUnit.si_factor!
      const liters = kg / density
      return { value: liters / toUnit.si_factor!, to_unit_id }
    }
  }

  if (isVolumeType(fromUnit.unit_type) && isMassType(toUnit.unit_type)) {
    // volume → mass: value * density
    const density = findDensity(from_unit_id, to_unit_id, entity_type, entity_id, units, overrides, densities)
    if (density != null) {
      // value (in volume unit) * fromUnit.siFactor = L
      // L * density_kg_per_L = kg
      // kg / toUnit.siFactor = value in target unit
      const liters = value * fromUnit.si_factor!
      const kg = liters * density
      return { value: kg / toUnit.si_factor!, to_unit_id }
    }
  }

  // 计数单位回退：查实体单位覆盖中的 weight_per_unit
  if (fromUnit.unit_type === 'count') {
    const override = findOverride(entity_type, entity_id, overrides, fromUnit.name)
    // weight_unit_override_id 为嵌套引用时，本行可以只给 weight_per_unit 的系数
    if (override && (override.weight_per_unit != null || override.weight_unit_override_id != null)) {
      const resolved = resolveOverrideAmount(override, units, overrides)
      if (resolved) {
        const weightUnit = resolved.unit
        if (weightUnit.si_factor != null && toUnit.si_factor != null) {
          // 体积语义覆盖（如 1瓶=500mL）且目标为体积：直接 si 换算，无需密度
          if (weightUnit.unit_type === 'volume' && isVolumeType(toUnit.unit_type)) {
            return { value: value * resolved.amount * weightUnit.si_factor / toUnit.si_factor!, to_unit_id }
          }
          const gramsPerUnit = resolveOverrideGramsPerUnit(
            override, units, densities, entity_type, entity_id, overrides,
          )
          if (gramsPerUnit != null && gramsPerUnit > 0) {
            if (isMassType(toUnit.unit_type)) {
              // count → mass: value × 每单位克数 → kg → 目标单位
              return { value: value * gramsPerUnit / 1000 / toUnit.si_factor, to_unit_id }
            }
            if (isVolumeType(toUnit.unit_type)) {
              // count → volume: 质量 via 覆盖，再经密度桥接
              const density = findDensity(weightUnit.id, to_unit_id, entity_type, entity_id, units, overrides, densities)
              if (density != null) {
                const liters = value * gramsPerUnit / 1000 / density
                return { value: liters / toUnit.si_factor, to_unit_id }
              }
            }
          }
        }
      }
    }
  }

  throw localError('unitTypesNotConvertible', 400, {
    from_type: fromUnit.unit_type,
    to_type: toUnit.unit_type,
  })
}

function isMassType(type: string): boolean {
  return type === 'mass'
}

function isVolumeType(type: string): boolean {
  return type === 'volume'
}

/**
 * 查找实体密度（kg/m³）。仅按实体精确匹配，无记录返回 null。
 */
function findEntityDensityKgM3(
  densities?: DensityInfo[], entityType?: string, entityId?: number,
): number | null {
  if (entityType && entityId && densities) {
    const d = densities.find(x => x.entity_type === entityType && x.entity_id === entityId && x.density > 0)
    if (d) return d.density
  }
  return null
}

/** 自定义单位链解析结果：1 个自定义单位 = amount × unit（全局质量/体积单位）。 */
export interface OverrideAmount {
  amount: number
  unit: UnitInfo
}

/** 嵌套自定义单位链最大深度（与后端 MAX_OVERRIDE_CHAIN_DEPTH 一致）。 */
export const MAX_OVERRIDE_CHAIN_DEPTH = 8

/**
 * 把一条实体单位覆盖解析为「1 个自定义单位对应多少 weight_unit」。
 *
 * 语义（与后端 UnitConversionService.resolve_override_amount 对齐）：
 *   1 个自定义单位 = conversion_factor(默认 1) × weight_per_unit × weight_unit
 * - weight_unit_override_id 指向同一实体的另一条自定义单位覆盖 → 递归解析，
 *   每层都乘该层的 conversion_factor ?? 1 与 weight_per_unit ?? 1；
 *   引用优先按 weight_unit_override_name 解析，再按 id；
 * - weight_unit_id 指向全局质量/体积单位 → 链的终点；
 * - 两者都为空 → 与后端一致按「克」兜底（record 里存在 weight_per_unit 有值
 *   但 weight_unit_id 为空的历史行，云端按 g 解释，本地必须同口径）。
 * - 循环引用/超过深度上限/引用悬空且本行无 weight_per_unit → null（不臆估）。
 *
 * 为兼容存量数据：未使用 weight_unit_override_id 的覆盖保持旧口径
 * （只乘 weight_per_unit，不乘 conversion_factor）。
 */
export function resolveOverrideAmount(
  override: EntityOverride | null | undefined,
  units: UnitInfo[],
  overrides?: EntityOverride[],
  _depth: number = 0,
  _seen: Set<number> = new Set(),
): OverrideAmount | null {
  if (!override || _depth > MAX_OVERRIDE_CHAIN_DEPTH) return null
  if (override.id != null) {
    if (_seen.has(override.id)) return null
    _seen.add(override.id)
  }

  const nestedId = override.weight_unit_override_id
  const nestedName = override.weight_unit_override_name
  const hasNested = (nestedId != null && nestedId !== ('' as any)) || !!nestedName
  const factor = override.conversion_factor ?? 1

  if (hasNested) {
    const ref = findNestedOverride(override, overrides)
    // 自引用也视作环
    if (ref && ref.id !== override.id) {
      const sub = resolveOverrideAmount(ref, units, overrides, _depth + 1, _seen)
      if (sub) {
        const weightPerUnit = override.weight_per_unit ?? 1
        const amount = factor * weightPerUnit * sub.amount
        if (!Number.isFinite(amount) || amount <= 0) return null
        return { amount, unit: sub.unit }
      }
    }
    // 引用悬空/不可解析：若本行另有 weight_per_unit 则退化为全局单位路径
    if (override.weight_per_unit == null) return null
  }

  if (override.weight_per_unit == null) return null

  // 与后端对齐：weight_unit_id 缺失时按克处理（unit_by_id(None) → g）
  const weightUnit = resolveWeightUnit(override, units) ?? findGlobalGramUnit(units)
  if (!weightUnit || weightUnit.si_factor == null) return null

  // conversion_factor 的乘入口径：
  // - 嵌套链上的每一跳都要乘（与后端一致，链内被引用的行即使自身不再嵌套也算一跳）；
  // - 纯旧数据（既无嵌套、也不是链的一环）保持既有口径不变（不乘 conversion_factor）。
  const applyFactor = hasNested || _depth > 0
  const amount = (applyFactor ? factor : 1) * Number(override.weight_per_unit)
  if (!Number.isFinite(amount) || amount <= 0) return null
  return { amount, unit: weightUnit }
}

/**
 * 找嵌套引用的另一条覆盖（须同一实体、active、非自身）。
 *
 * 优先按 `weight_unit_override_name` 解析：云端导出记录的 id 会被重排
 * （本地 id 自增 / 导入时 id 可能不与引用对齐），名字是权威信息；
 * 名字缺失时再按 id 回退（本地新建的嵌套引用通常只有 id）。
 */
function findNestedOverride(
  base: EntityOverride,
  overrides?: EntityOverride[],
): EntityOverride | null {
  if (!overrides) return null
  const candidates = overrides.filter(o => o !== base
    && o.id !== base.id
    && o.entity_type === base.entity_type
    && o.entity_id === base.entity_id
    && (o.is_active === undefined || o.is_active === true || o.is_active === 1))
  if (candidates.length === 0) return null

  const name = base.weight_unit_override_name
  if (name) {
    const byName = candidates.find(o => o.unit_name === name || (o as any).name === name)
    if (byName) return byName
  }

  const id = base.weight_unit_override_id
  if (id == null) return null
  return candidates.find(o => o.id === id) ?? null
}

/** 全局克单位（与后端 get_unit_by_abbr("g") 兜底一致）。 */
function findGlobalGramUnit(units: UnitInfo[]): UnitInfo | undefined {
  return units.find(u => u.abbreviation === 'g')
    ?? units.find(u => u.name === '克')
    ?? units.find(u => u.unit_type === 'mass' && u.si_factor === 0.001)
}

/**
 * 解析实体覆盖的"每单位量"（折算为克）。
 * - 体积语义覆盖（weight_unit 为 mL/L，如 1瓶=500mL）：经实体密度折算，
 *   无密度记录时按水密度 1 g/mL 兜底（与后端 get_density 链一致）。
 * - 质量语义覆盖：按 si_factor 折 g。
 * - weight_unit 优先按 name/abbreviation 解析（云端导出记录的 id 与本地
 *   seed 不对齐），再按 id 回退；支持 weight_unit_override_id 嵌套链。
 * 返回 null 表示无法折算。
 */
export function resolveOverrideGramsPerUnit(
  override: EntityOverride,
  units: UnitInfo[],
  densities?: DensityInfo[],
  entityType?: string,
  entityId?: number,
  overrides?: EntityOverride[],
): number | null {
  const resolved = resolveOverrideAmount(override, units, overrides)
  if (!resolved) return null
  const { amount, unit } = resolved
  if (!Number.isFinite(amount) || amount <= 0) return null
  const type = entityType ?? override.entity_type
  const id = entityId ?? override.entity_id
  if (unit.unit_type === 'volume') {
    // amount × si_factor = L；L × kg/m³ = kg；kg → g 恰好等于 L × kg/m³ × 1000 / 1000
    return amount * unit.si_factor! * (findEntityDensityKgM3(densities, type, id) ?? 1000)
  }
  if (unit.unit_type === 'mass') {
    return amount * unit.si_factor! * 1000
  }
  return null
}

/**
 * 查找密度（kg/m³）。
 * 优先级：
 * 1. 实体单位覆盖中的 weight_per_unit
 * 2. entity_densities 表
 * 3. 无密度时返回 null（不默认水密度，由调用方决定回退策略）
 */
function findDensity(
  fromUnitId: number, toUnitId: number,
  entityType?: string, entityId?: number,
  units?: UnitInfo[], overrides?: EntityOverride[], densities?: DensityInfo[],
): number | null {
  // 先查实体单位覆盖
  if (entityType && entityId && overrides) {
    const ov = overrides.find(o => o.entity_type === entityType && o.entity_id === entityId)
    if (ov?.weight_per_unit != null && ov?.weight_unit_id != null) {
      const wu = units?.find(u => u.id === ov.weight_unit_id)
      if (wu?.si_factor) {
        // weight_per_unit × si_factor → kg per unit
        // density = (weight_per_unit × si_factor_kg) / fromUnit_si_factor_L
        // UnitInfo only has id/unit_type/si_factor, we can't know which unit is kg or L
        // Better to just return null and let caller handle
        return null
      }
    }
  }

  // 查 entity_densities（存储为 kg/m³，即 g/L）
  if (entityType && entityId && densities) {
    const d = densities.find(d => d.entity_type === entityType && d.entity_id === entityId)
    if (d && d.density > 0) {
      // kg/m³ → kg/L: 1 m³ = 1000 L, so 1 kg/m³ = 0.001 kg/L
      return d.density / 1000
    }
  }

  return null
}

/**
 * 查找 entity_unit_overrides 中的匹配记录。
 */
/** Resolve the weight unit from an override, preferring name over ID.
 *  Cloud-exported records carry cloud unit IDs; local seed IDs differ,
 *  so weight_unit_name (always present, always correct) is authoritative. */
function resolveWeightUnit(override: EntityOverride, units: UnitInfo[]): UnitInfo | undefined {
  // 1) If weight_unit_name exists, match by name (handles ID mismatch)
  if (override.weight_unit_name) {
    const byName = units.find(u => u.name === override.weight_unit_name)
    if (byName) return byName
  }
  // 2) Fallback to ID lookup
  return units.find(u => u.id === override.weight_unit_id)
}
function findOverride(
  entityType?: string, entityId?: number,
  overrides?: EntityOverride[], unitName?: string,
): EntityOverride | null {
  if (!entityType || !entityId || !overrides) return null
  const candidates = overrides.filter(o => o.entity_type === entityType
    && o.entity_id === entityId
    && (o.is_active === undefined || o.is_active === true || o.is_active === 1))
  if (candidates.length === 0) return null
  if (unitName) {
    const byName = candidates.find(o => o.unit_name === unitName || (o as any).name === unitName)
    if (byName) return byName
  }
  return candidates[0] || null
}

// 实体自定义单位 → 下拉选项（共享实现）
//
// 与后端 UnitConversionService.get_entity_override 的优先级链保持一致：
//   商品自身覆盖 > 商品关联原料的覆盖 > 全局单位
// 因此商品的价格记录单位下拉不仅要有商品自己的自定义单位，还要合并
// 其关联原料（product.ingredient_id）的自定义单位；同名时商品优先。
//
// 另外：选项列表必须每次都从「全局单位」基准重建，不能向上一次结果追加，
// 否则切换商品后上一个商品的自定义单位会残留（清空商品时也不会消失）。
//
// 本地（离线）模式同样适用：/entities/... 与 /units/ 均已在
// api/local/proxy.ts 注册，统一走 @/api 客户端即可。

import { api } from '@/api'

export interface UnitOption {
  title: string
  value: string
}

/** 与后端实体类型对齐（本模块只关心 product / ingredient）。 */
export type EntityUnitEntityType = 'product' | 'ingredient' | string

function normalizeRows(res: any): any[] {
  if (Array.isArray(res)) return res
  if (Array.isArray(res?.items)) return res.items
  return []
}

/** 自定义单位行 → 下拉项（标题用 unit_name，保持信息量）。 */
function toEntityOptions(rows: any[]): UnitOption[] {
  const options: UnitOption[] = []
  for (const row of rows) {
    const name = row?.unit_name ?? row?.name
    if (name === null || name === undefined || name === '') continue
    options.push({ title: String(name), value: String(name) })
  }
  return options
}

/** 自定义单位下拉项的最小行结构（/entities/.../units 与视图内状态通用）。 */
export interface UnitRowLike {
  id?: number | null
  unit_name?: string | null
  weight_per_unit?: number | null
  weight_unit_id?: number | null
  weight_unit_override_id?: number | null
  conversion_factor?: number | null
  source?: string | null
}

/**
 * 合并「本实体自定义单位行」与「可继承的自定义单位行」（商品 → 关联原料）。
 *
 * 与 fetchEntityUnitOptions 同一口径：本实体的行在前，按 id 与名称双重去重，
 * 因此**同名时本实体的单位胜出**，不会出现两个「盒」；
 * 同时避免两个实体主键空间重叠时误把原料的行当成自己的行。
 */
export function dedupeUnitRows<T extends { id?: number | null; unit_name?: string | null }>(
  ownRows: T[],
  inheritedRows: T[],
): T[] {
  const result: T[] = []
  const seenIds = new Set<number>()
  const seenNames = new Set<string>()
  for (const row of ownRows) {
    const id = row?.id ?? null
    if (id != null) {
      if (seenIds.has(id)) continue
      seenIds.add(id)
    }
    const name = String(row?.unit_name ?? '').trim()
    if (name) {
      if (seenNames.has(name)) continue
      seenNames.add(name)
    }
    result.push(row)
  }
  for (const row of inheritedRows) {
    const id = row?.id ?? null
    if (id == null || seenIds.has(id)) continue
    const name = String(row?.unit_name ?? '').trim()
    if (name && seenNames.has(name)) continue
    seenIds.add(id)
    if (name) seenNames.add(name)
    result.push(row)
  }
  return result
}

/**
 * 单位下拉项标题：`名称（自定义单位）` / 商品的继承项 `名称（继承自原料）`。
 * 名字为空时退化为 `#id`（复现原有兜底，避免出现空标题项）。
 */
export function formatUnitOptionLabel(
  unitName: string | null | undefined,
  unitId: number | null | undefined,
  suffix: string,
): string {
  const name = String(unitName ?? '').trim()
  return name ? `${name}${suffix}` : `#${unitId ?? ''}`
}

/**
 * 单位对话框里「量」输入框的初始值。
 *
 * 旧数据的换算系数可能不是 1（语义：1 单位 = factor × weight_per_unit × 单位）。
 * 新界面已移除换算系数、保存时固定发 1，因此编辑旧行时必须先把 factor 折进量，
 * 否则保存会把总重量悄悄缩小 factor 倍。
 *
 * 只有「引用另一条自定义单位（嵌套）」且 factor ≠ 1 时才需要折算：此时
 * weight_per_unit 就是嵌套单位的个数，factor × 个数 语义完全等价。
 * 引用全局单位（g/mL）的行是 D 类旧数据（单位本身参与克/毫升换算），
 * 保持原样以免改变既有显示。
 */
export function normalizeWeightPerUnitForEdit(row: UnitRowLike): number | null {
  const raw = row?.weight_per_unit
  const value = raw == null ? null : Number(raw)
  if (row?.weight_unit_override_id == null) return value
  const factor = row.conversion_factor != null ? Number(row.conversion_factor) : 1
  if (!isFinite(factor) || factor === 1) return value
  if (value == null || !isFinite(value)) return value
  const normalized = value * factor
  return isFinite(normalized) ? normalized : value
}

/** 按 value 去重（保留先出现的项）。 */
export function dedupeUnitOptions(options: UnitOption[]): UnitOption[] {
  const seen = new Set<string>()
  const result: UnitOption[] = []
  for (const option of options) {
    if (!option || !option.value || seen.has(option.value)) continue
    seen.add(option.value)
    result.push(option)
  }
  return result
}

/**
 * 合并「全局单位」与本实体的自定义单位：自定义单位在前（更贴合实体），
 * 全局单位在后，按 value 去重。
 */
export function mergeUnitOptions(
  baseOptions: UnitOption[],
  entityOptions: UnitOption[],
): UnitOption[] {
  return dedupeUnitOptions([...entityOptions, ...baseOptions])
}

/** 拉取全局单位（标题「名称 (缩写)」）；失败或为空时回退到给定列表。 */
export async function loadGlobalUnitOptions(fallback: UnitOption[] = []): Promise<UnitOption[]> {
  try {
    // limit 放大到 500 且只取启用项：与移动端价格下拉同口径（同一份基准列表）
    const res = await api.get('/units/', { params: { limit: 500 } })
    const options = normalizeRows(res)
      .filter((u: any) => u?.is_active !== false)
      .map((u: any) => ({
        title: `${u.name} (${u.abbreviation})`,
        value: u.abbreviation,
      }))
    const deduped = dedupeUnitOptions(options)
    return deduped.length > 0 ? deduped : [...fallback]
  } catch {
    return [...fallback]
  }
}

/** 请求某实体的自定义单位；失败不影响全局单位（返回空数组）。 */
async function requestEntityUnits(
  entityType: EntityUnitEntityType,
  entityId: number,
): Promise<UnitOption[]> {
  try {
    const res = await api.get(`/entities/${entityType}/${entityId}/units`)
    return toEntityOptions(normalizeRows(res))
  } catch {
    // 自定义单位加载失败不影响全局单位
    return []
  }
}

/** 商品未直接带 ingredient_id 时，回查商品实体补上（用于原料回退）。 */
async function fetchLinkedIngredientId(productId: number): Promise<number | null> {
  try {
    const product = await api.get(`/products/entity/${productId}`)
    const ingredientId = product?.ingredient_id
    return typeof ingredientId === 'number' && ingredientId > 0 ? ingredientId : null
  } catch {
    return null
  }
}

/**
 * 加载实体自定义单位选项（商品 → 关联原料回退，商品覆盖优先）。
 *
 * @param entityType    'product' | 'ingredient'
 * @param entityId      实体 id；为空时返回空数组
 * @param ingredientId  商品关联原料 id；缺省时自动回查商品实体
 */
export async function fetchEntityUnitOptions(
  entityType: EntityUnitEntityType,
  entityId: number | null | undefined,
  ingredientId?: number | null,
): Promise<UnitOption[]> {
  if (!entityId) return []

  const ownOptions = await requestEntityUnits(entityType, entityId)

  let fallbackOptions: UnitOption[] = []
  if (entityType === 'product') {
    const linkedIngredientId = ingredientId
      ?? (await fetchLinkedIngredientId(entityId))
    if (linkedIngredientId) {
      fallbackOptions = await requestEntityUnits('ingredient', linkedIngredientId)
    }
  }

  // 商品自身覆盖优先：同名单位保留商品的那一条
  return dedupeUnitOptions([...ownOptions, ...fallbackOptions])
}

export interface LoadEntityUnitOptionsParams {
  /** 全局单位基准列表；缺省时现场拉取 /units/（带兜底）。 */
  baseOptions?: UnitOption[]
  /** 商品关联原料 id（可选，缺省时自动回查）。 */
  ingredientId?: number | null
}

/**
 * 重建实体单位下拉选项：始终以 baseOptions（全局单位）为基准，
 * 把实体自定义单位（含关联原料回退）排在最前。
 *
 * 每次调用都返回新数组，调用方直接整体替换即可，不会残留上一个实体的单位。
 */
export async function loadEntityUnitOptions(
  entityType: EntityUnitEntityType,
  entityId: number | null | undefined,
  params: LoadEntityUnitOptionsParams = {},
): Promise<UnitOption[]> {
  const baseOptions = params.baseOptions ?? (await loadGlobalUnitOptions())
  if (!entityId) return [...baseOptions]
  const entityOptions = await fetchEntityUnitOptions(entityType, entityId, params.ingredientId)
  return mergeUnitOptions(baseOptions, entityOptions)
}

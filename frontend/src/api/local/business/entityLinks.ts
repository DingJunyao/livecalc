// 本地模式：商品/原料数量关联的折克与价格因子（与云端 entity_link_service 同口径）。
import {
  resolveOverrideGramsPerUnit,
  type DensityInfo,
  type EntityOverride,
  type UnitInfo,
} from './unitConverter'

export interface LocalQuantityLink {
  id: number
  from_type: 'product' | 'ingredient'
  from_id: number
  from_quantity: number
  from_unit: string
  to_type: 'product' | 'ingredient'
  to_id: number
  to_quantity: number
  to_unit: string
  note?: string | null
  is_active?: boolean
}

export interface LocalLinkSide {
  type: 'product' | 'ingredient'
  id: number
  name?: string | null
  quantity: number
  unit: string
  ingredient_id?: number | null
}

export function normalizeLocalLink(
  link: LocalQuantityLink,
  entityType: string,
  entityId: number,
) {
  if (link.from_type === entityType && link.from_id === entityId) {
    return {
      current: { type: link.from_type, id: link.from_id, quantity: Number(link.from_quantity), unit: link.from_unit },
      other: { type: link.to_type, id: link.to_id, quantity: Number(link.to_quantity), unit: link.to_unit },
    }
  }
  if (link.to_type === entityType && link.to_id === entityId) {
    return {
      current: { type: link.to_type, id: link.to_id, quantity: Number(link.to_quantity), unit: link.to_unit },
      other: { type: link.from_type, id: link.from_id, quantity: Number(link.from_quantity), unit: link.from_unit },
    }
  }
  return null
}

export function resolveLocalUnitGrams(
  entityType: string,
  entityId: number,
  unitName: string,
  units: UnitInfo[],
  overrides: EntityOverride[],
  densities: DensityInfo[],
  links: LocalQuantityLink[],
  visited: Set<string> = new Set(),
): number | null {
  const unit = (unitName || '').trim()
  if (!unit) return null
  const key = `${entityType}:${entityId}:${unit}`
  if (visited.has(key)) return null
  visited.add(key)

  const override = overrides.find(
    (row: any) => row.entity_type === entityType
      && row.entity_id === entityId
      && row.unit_name === unit
      && row.is_active !== false,
  )
  if (override) {
    const grams = resolveOverrideGramsPerUnit(override, units, densities, entityType, entityId, overrides)
    if (grams != null && grams > 0) return grams
  }

  const global = units.find(u => u.name === unit || u.abbreviation === unit)
  if (global && global.unit_type === 'mass' && global.si_factor != null) {
    return global.si_factor * 1000
  }

  for (const link of links || []) {
    if (link.is_active === false) continue
    const norm = normalizeLocalLink(link, entityType, entityId)
    if (!norm || norm.current.unit !== unit) continue
    const otherGrams = resolveLocalUnitGrams(
      norm.other.type, norm.other.id, norm.other.unit,
      units, overrides, densities, links, visited,
    )
    if (otherGrams == null || otherGrams <= 0) continue
    const qc = norm.current.quantity
    const qo = norm.other.quantity
    if (!Number.isFinite(qc) || qc <= 0 || !Number.isFinite(qo) || qo <= 0) continue
    return (qo / qc) * otherGrams
  }
  return null
}

export function localLinkFactor(
  gramsCurrent: number | null,
  qtyCurrent: number,
  gramsOther: number | null,
  qtyOther: number,
): number | null {
  if (gramsCurrent == null || gramsOther == null) return null
  if (!(gramsCurrent > 0) || !(gramsOther > 0) || !(qtyCurrent > 0) || !(qtyOther > 0)) return null
  return (gramsCurrent * qtyCurrent) / (gramsOther * qtyOther)
}

export function serializeLocalLink(
  link: LocalQuantityLink,
  entityType: string,
  entityId: number,
  units: UnitInfo[],
  overrides: EntityOverride[],
  densities: DensityInfo[],
  links: LocalQuantityLink[],
  names: { product: Record<number, string>; ingredient: Record<number, string> },
): any {
  const norm = normalizeLocalLink(link, entityType, entityId)
  if (!norm) return null
  const currentName = norm.current.type === 'product'
    ? names.product[norm.current.id]
    : names.ingredient[norm.current.id]
  const otherName = norm.other.type === 'product'
    ? names.product[norm.other.id]
    : names.ingredient[norm.other.id]
  const gramsCurrent = resolveLocalUnitGrams(
    norm.current.type, norm.current.id, norm.current.unit,
    units, overrides, densities, links,
  )
  const gramsOther = resolveLocalUnitGrams(
    norm.other.type, norm.other.id, norm.other.unit,
    units, overrides, densities, links,
  )
  const factor = localLinkFactor(
    gramsCurrent, norm.current.quantity, gramsOther, norm.other.quantity,
  )
  const otherPerCurrent = norm.current.quantity > 0
    ? norm.other.quantity / norm.current.quantity
    : 0
  const currentPerOther = norm.other.quantity > 0
    ? norm.current.quantity / norm.other.quantity
    : 0
  return {
    id: link.id,
    current: {
      type: norm.current.type, id: norm.current.id, name: currentName,
      quantity: norm.current.quantity, unit: norm.current.unit,
    },
    other: {
      type: norm.other.type, id: norm.other.id, name: otherName,
      quantity: norm.other.quantity, unit: norm.other.unit,
    },
    other_per_current: otherPerCurrent,
    current_per_other: currentPerOther,
    grams_per_current_unit: gramsCurrent,
    grams_per_other_unit: gramsOther,
    price_factor_current_to_other: factor,
    resolvable: gramsCurrent != null && gramsOther != null,
    note: link.note ?? null,
    other_latest_price: null,
    other_latest_price_unit: null,
    equivalent_current_price: null,
    price_date: null,
    is_stale: false,
    pending: false,
  }
}

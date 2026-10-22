// 商品/原料数量关联：前端纯函数（与后端 entity_link_service 同口径）。
//
// 语义：q_current [u_current] current = q_other [u_other] other
// 1 current = other_per_current other
// 单件等价价：P_current = P_other × other_per_current

export type EntityLinkEntityType = 'product' | 'ingredient'

export interface EntityLinkSide {
  type: EntityLinkEntityType
  id: number
  name?: string | null
  quantity: number
  unit: string
  ingredient_id?: number | null
}

export interface EntityQuantityLink {
  id: number
  current: EntityLinkSide
  other: EntityLinkSide
  other_per_current: number
  current_per_other: number
  grams_per_current_unit?: number | null
  grams_per_other_unit?: number | null
  price_factor_current_to_other?: number | null
  resolvable: boolean
  note?: string | null
  other_latest_price?: number | null
  other_latest_price_unit?: string | null
  equivalent_current_price?: number | null
  price_date?: string | null
  is_stale?: boolean
  pending?: boolean
}

export interface LinkEquivalent {
  productName?: string | null
  unit: string
  unitPrice: number
}

export function formatLinkQty(value: unknown): string {
  const n = Number(value)
  if (!Number.isFinite(n)) return '?'
  if (Number.isInteger(n)) return String(n)
  return String(Number(n.toFixed(6)))
}

export function formatLinkSentence(link: EntityQuantityLink | null | undefined): string {
  if (!link) return ''
  return (
    `${formatLinkQty(link.current.quantity)} ${link.current.unit || '—'} ${link.current.name || '—'} = `
    + `${formatLinkQty(link.other.quantity)} ${link.other.unit || '—'} ${link.other.name || '—'}`
  )
}

export function formatGramsSelfCheck(link: EntityQuantityLink | null | undefined): string {
  if (!link || !link.resolvable || link.grams_per_current_unit == null) return ''
  const grams = Number(link.grams_per_current_unit)
  if (!Number.isFinite(grams) || grams <= 0) return ''
  return `1 ${link.current.unit || '—'} ≈ ${Number(grams.toFixed(2))} g`
}

/**
 * 输入一条价格（总价/数量/单位），折算成关联对方的单价。
 * 只有输入单位等于「当前侧单位」时才返回；否则返回空数组（不臆估）。
 */
export function buildLinkEquivalents(
  link: EntityQuantityLink | null | undefined,
  totalPrice: unknown,
  quantity: unknown,
  unitName: string,
): LinkEquivalent[] {
  if (!link) return []
  const price = Number(totalPrice)
  const qty = Number(quantity)
  if (!Number.isFinite(price) || price < 0) return []
  if (!Number.isFinite(qty) || qty <= 0) return []
  if ((unitName || '').trim() !== (link.current.unit || '').trim()) return []
  const perCurrent = price / qty
  const otherPerCurrent = Number(link.other_per_current)
  if (!Number.isFinite(otherPerCurrent) || otherPerCurrent <= 0) return []
  return [{
    productName: link.other.name,
    unit: link.other.unit,
    unitPrice: perCurrent / otherPerCurrent,
  }]
}

/** 把关联里出现的单位合并进下拉候选（去重，保留原顺序）。 */
export function mergeLinkUnits(
  base: Array<{ title: string; value: string }>,
  links: EntityQuantityLink[],
): Array<{ title: string; value: string }> {
  const result = [...base]
  const seen = new Set(result.map(item => item.value))
  for (const link of links || []) {
    for (const unit of [link.current?.unit, link.other?.unit]) {
      const value = String(unit || '').trim()
      if (!value || seen.has(value)) continue
      seen.add(value)
      result.push({ title: value, value })
    }
  }
  return result
}

/** 关联区提示文案由组件通过 i18n 提供；此处保留纯数据工具，不放用户可见中文。 */

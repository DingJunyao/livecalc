// 本地模式：商品/原料数量关联 CRUD。
import { addOne, getAll, getById, putOne } from '../database'
import { localError } from '../../../utils/localErrors'
import {
  serializeLocalLink,
  type LocalQuantityLink,
} from '../business/entityLinks'

async function loadContext() {
  const [links, units, overrides, densities, products, ingredients] = await Promise.all([
    getAll('entity_quantity_links'),
    getAll('units'),
    getAll('entity_unit_overrides'),
    getAll('entity_densities'),
    getAll('products'),
    getAll('ingredients'),
  ])
  return { links, units, overrides, densities, products, ingredients }
}

function nameMaps(products: any[], ingredients: any[]) {
  return {
    product: Object.fromEntries((products || []).map((p: any) => [p.id, p.name])),
    ingredient: Object.fromEntries((ingredients || []).map((i: any) => [i.id, i.name])),
  }
}

function normalizePayload(data: any) {
  return {
    from_quantity: Number(data?.from_quantity ?? 1),
    from_unit: String(data?.from_unit ?? '').trim(),
    to_quantity: Number(data?.to_quantity ?? 1),
    to_unit: String(data?.to_unit ?? '').trim(),
    note: data?.note ? String(data.note).trim() : null,
  }
}

function validate(payload: any) {
  if (!payload.from_unit || !payload.to_unit) {
    throw localError('quantityLinkUnitRequired', 400, {})
  }
  if (!(payload.from_quantity > 0) || !(payload.to_quantity > 0)) {
    throw localError('quantityLinkQuantityInvalid', 400, {})
  }
}

export async function listEntityLinks(params: Record<string, string>): Promise<any> {
  const entityType = params.entityType
  const entityId = parseInt(params.entityId)
  const { links, units, overrides, densities, products, ingredients } = await loadContext()
  const names = nameMaps(products, ingredients)
  const active = (links || []).filter((l: any) => l.is_active !== false)
  const items = active
    .filter((l: any) => (
      (l.from_type === entityType && l.from_id === entityId)
      || (l.to_type === entityType && l.to_id === entityId)
    ))
    .map((l: any) => serializeLocalLink(
      l as LocalQuantityLink, entityType, entityId,
      units as any, overrides as any, densities as any, active as any, names,
    ))
    .filter(Boolean)
  return { items }
}

export async function createEntityLink(params: Record<string, string>, data?: any): Promise<any> {
  const entityType = params.entityType
  const entityId = parseInt(params.entityId)
  const payload = normalizePayload(data)
  validate(payload)
  if (data?.to_type !== 'product' && data?.to_type !== 'ingredient') {
    throw localError('quantityLinkTargetRequired', 400, {})
  }
  const toId = Number(data?.to_id)
  if (!toId) throw localError('quantityLinkTargetRequired', 400, {})
  if (data.to_type === entityType && toId === entityId) {
    throw localError('quantityLinkSelf', 400, {})
  }

  const { links } = await loadContext()
  const duplicate = (links || []).find((l: any) => l.is_active !== false && (
    (l.from_type === entityType && l.from_id === entityId && l.to_type === data.to_type && l.to_id === toId)
    || (l.from_type === data.to_type && l.from_id === toId && l.to_type === entityType && l.to_id === entityId)
  ))
  if (duplicate) throw localError('quantityLinkDuplicate', 400, {})

  const id = await addOne('entity_quantity_links', {
    from_type: entityType,
    from_id: entityId,
    ...payload,
    to_type: data.to_type,
    to_id: toId,
    is_active: true,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  })
  const saved = await getById('entity_quantity_links', id as number)
  const context = await loadContext()
  return serializeLocalLink(
    saved as any, entityType, entityId,
    context.units as any, context.overrides as any, context.densities as any,
    context.links as any, nameMaps(context.products, context.ingredients),
  )
}

export async function updateEntityLink(params: Record<string, string>, data?: any): Promise<any> {
  const entityType = params.entityType
  const entityId = parseInt(params.entityId)
  const linkId = parseInt(params.linkId)
  const existing = await getById('entity_quantity_links', linkId)
  if (!existing) throw localError('quantityLinkNotFound', 404, { id: linkId })
  const payload = normalizePayload({ ...existing, ...data })
  validate(payload)
  await putOne('entity_quantity_links', {
    ...existing,
    ...payload,
    updated_at: new Date().toISOString(),
  })
  const context = await loadContext()
  const saved = await getById('entity_quantity_links', linkId)
  return serializeLocalLink(
    saved as any, entityType, entityId,
    context.units as any, context.overrides as any, context.densities as any,
    context.links as any, nameMaps(context.products, context.ingredients),
  )
}

export async function deleteEntityLink(params: Record<string, string>): Promise<any> {
  const linkId = parseInt(params.linkId)
  const existing = await getById('entity_quantity_links', linkId)
  if (!existing) throw localError('quantityLinkNotFound', 404, { id: linkId })
  await putOne('entity_quantity_links', {
    ...existing,
    is_active: false,
    updated_at: new Date().toISOString(),
  })
  return { message: 'deleted', pending: false }
}

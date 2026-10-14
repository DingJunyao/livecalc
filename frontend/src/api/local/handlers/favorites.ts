// Favorites handler — 原料/商品/菜谱收藏（本地模式，云端 URL 同构）。

import { getAll, addOne, deleteOne, getById, getByIndex } from '../database'
import { localError } from '../../../utils/localErrors'

const TYPES = ['ingredient', 'product', 'recipe']

async function loadRows(type: string): Promise<any[]> {
  const favs = await getAll('user_favorites')
  return favs
    .filter((f: any) => f.entity_type === type)
    .sort((a: any, b: any) => ((b.created_at || '') > (a.created_at || '') ? 1 : -1))
}

async function toItems(type: string): Promise<any[]> {
  const rows = await loadRows(type)
  const storeName =
    type === 'ingredient' ? 'ingredients' : type === 'product' ? 'products' : 'recipes'
  const items: any[] = []
  for (const row of rows) {
    const entity = await getById(storeName, row.entity_id)
    if (!entity || entity.is_active === false) continue
    if (type === 'ingredient') {
      items.push({ id: entity.id, name: entity.name, subtitle: null, image: null })
    } else if (type === 'product') {
      let subtitle = null
      if (entity.ingredient_id) {
        const ing = await getById('ingredients', entity.ingredient_id)
        subtitle = ing?.name || null
      }
      items.push({ id: entity.id, name: entity.name, subtitle, image: entity.image_url || null })
    } else {
      items.push({
        id: entity.id,
        name: entity.name,
        subtitle: entity.category || null,
        image: (entity.images || [])[0] || null,
      })
    }
  }
  return items
}

async function listMerchantFavorites(): Promise<any[]> {
  const [favorites, allMerchants] = await Promise.all([
    getAll('merchant_favorites'),
    getAll('merchants'),
  ])
  const merchantMap = new Map(allMerchants.map((m: any) => [m.id, m]))
  return favorites
    .map((f: any) => merchantMap.get(f.merchant_id))
    .filter((m: any) => m != null && m.is_active !== false)
}

export async function listAll(_params: Record<string, string>): Promise<any> {
  return {
    ingredients: await toItems('ingredient'),
    products: await toItems('product'),
    recipes: await toItems('recipe'),
    merchants: await listMerchantFavorites(),
  }
}

export async function listByType(params: Record<string, string>): Promise<any> {
  const type = params.type
  if (!TYPES.includes(type)) throw localError('favoriteUnsupportedType', 400, { type })
  return await toItems(type)
}

export async function addFavorite(params: Record<string, string>): Promise<any> {
  const type = params.type
  const entityId = parseInt(params.id)
  if (!TYPES.includes(type)) throw localError('favoriteUnsupportedType', 400, { type })
  const storeName =
    type === 'ingredient' ? 'ingredients' : type === 'product' ? 'products' : 'recipes'
  const entity = await getById(storeName, entityId)
  if (!entity || entity.is_active === false) {
    throw localError('favoriteEntityNotFound', 404, { id: entityId })
  }
  const entityKey = `${type}:${entityId}`
  const existing = await getByIndex('user_favorites', 'by_entity_key', entityKey)
  if (existing.length > 0) return { ok: true }
  await addOne('user_favorites', {
    entity_type: type,
    entity_id: entityId,
    entity_key: entityKey,
    created_at: new Date().toISOString(),
  })
  return { ok: true }
}

export async function removeFavorite(params: Record<string, string>): Promise<any> {
  const type = params.type
  const entityId = parseInt(params.id)
  const entityKey = `${type}:${entityId}`
  const existing = await getByIndex('user_favorites', 'by_entity_key', entityKey)
  for (const row of existing) {
    await deleteOne('user_favorites', row.id)
  }
  return { ok: true }
}

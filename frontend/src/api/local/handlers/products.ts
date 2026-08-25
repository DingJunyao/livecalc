// Products handler — product entities, price records, barcodes, weights.

import { getAll, getById, addOne, putOne, deleteOne, getByIndex, paginate, resolvePagination, DEFAULT_CURRENCY, DEFAULT_USER_CURRENCY } from '../database'
import { aggregatePrices } from '../business/priceNormalize'
import { exchangeRateToUserCurrency } from '../business/staticRates'
import type { UnitInfo, EntityOverride, DensityInfo } from '../business/unitConverter'
import {
  parseIdList,
  parseStringList,
  isTruthy,
  listIncludes,
  buildProductRecordStats,
} from './_filter'
import { getBarcodeConfig, resolveExternalBarcode } from './barcodeServices'
import { buildRegionFilter, filterRecordsByRegion } from '../business/regionSubtree'

// ============================================================
// 地区过滤辅助
// ============================================================

/** 从 query 解析可选 region_id；null/空值表示全局。 */
function parseRegionId(value: any): number | null {
  if (value == null || value === '') return null
  const n = Number(value)
  return Number.isFinite(n) ? n : null
}

/** 按所选地区及其下级过滤价格记录（regionId == null 时原样返回）。 */
async function applyRegionFilter<T extends { merchant_id?: number | null }>(
  records: T[],
  regionId: number | null,
): Promise<T[]> {
  if (regionId == null) return records
  const regionFilter = await buildRegionFilter(regionId)
  return filterRecordsByRegion(records, regionId, regionFilter.allowedRegionIds, regionFilter.merchantRegions)
}

// ============================================================
// Product Entity CRUD
// ============================================================

export async function listEntity(_params: Record<string, string>, query?: any): Promise<any> {
  const lower = (query?.search || query?.name || query?.q)?.toLowerCase()
  const ingredientIds = parseIdList(query?.ingredient_ids ?? query?.ingredient_id)
  const ingredientCategoryIds = parseIdList(query?.ingredient_category_ids)
  const brandList = parseStringList(query?.brands)
  const brandSet = brandList.length ? new Set(brandList) : null
  const noPrice = isTruthy(query?.no_price)
  const singlePrice = isTruthy(query?.single_price)
  const singleMerchant = isTruthy(query?.single_merchant)
  const sortBy = query?.sort_by

  const needStats = noPrice || singlePrice || singleMerchant || sortBy === 'price_records'
  const needIngredients = !!lower || ingredientCategoryIds.length > 0
  const stats = needStats ? await buildProductRecordStats() : null

  const ingredientById = new Map<number, any>()
  if (needIngredients) {
    const allIngredients = await getAll('ingredients')
    for (const ing of allIngredients) ingredientById.set(ing.id, ing)
  }

  // ingredient_ids filter (direct) and ingredient_category_ids (resolved)
  const directIngredientIds = ingredientIds.length ? new Set(ingredientIds) : null
  let categoryIngredientIds: Set<number> | null = null
  if (ingredientCategoryIds.length) {
    const catSet = new Set(ingredientCategoryIds)
    categoryIngredientIds = new Set(
      [...ingredientById.values()]
        .filter((i) => catSet.has(i.category_id))
        .map((i) => i.id),
    )
  }

  const allProducts = stats ? stats.products : await getAll('products')
  let filtered = allProducts.filter((p: any) => {
    if (p.is_active === false) return false
    if (lower) {
      const selfMatch = p.name?.toLowerCase().includes(lower) || listIncludes(p.aliases, lower)
      if (!selfMatch) {
        const ing = ingredientById.get(p.ingredient_id)
        const ingMatch =
          ing && (ing.name?.toLowerCase().includes(lower) || listIncludes(ing.aliases, lower))
        if (!ingMatch) return false
      }
    }
    if (directIngredientIds && !directIngredientIds.has(p.ingredient_id)) return false
    if (categoryIngredientIds && !categoryIngredientIds.has(p.ingredient_id)) return false
    if (brandSet && !(p.brand && brandSet.has(p.brand))) return false
    if (noPrice && (stats!.recordCountByProduct.get(p.id) ?? 0) > 0) return false
    if (singlePrice && (stats!.recordCountByProduct.get(p.id) ?? 0) !== 1) return false
    if (singleMerchant && (stats!.merchantCountByProduct.get(p.id) ?? 0) !== 1) return false
    return true
  })

  if (sortBy === 'price_records' && stats) {
    filtered.sort(
      (a, b) =>
        (stats.recordCountByProduct.get(b.id) ?? 0) -
          (stats.recordCountByProduct.get(a.id) ?? 0) || a.id - b.id,
    )
  } else if (sortBy === 'updated_at') {
    filtered.sort((a, b) => ((b.updated_at || '') > (a.updated_at || '') ? 1 : -1))
  } else {
    filtered.sort((a, b) => ((b.created_at || '') > (a.created_at || '') ? 1 : -1))
  }

  const { skip, limit: pageSize, page, page_size } = resolvePagination(query)
  return { items: filtered.slice(skip, skip + pageSize), total: filtered.length, page, page_size }
}

export async function getEntity(params: Record<string, string>, query?: any): Promise<any> {
  const id = parseInt(params.id)
  const regionId = parseRegionId(query?.region_id)
  const product = await getById('products', id)
  if (!product) throw { status: 404, message: `Product ${id} not found` }
  // Attach barcodes
  const barcodes = await getByIndex('product_barcodes', 'by_product_id', id)
  // Attach ingredient name
  let ingredientName = ''
  if (product.ingredient_id) {
    const ing = await getById('ingredients', product.ingredient_id)
    ingredientName = ing?.name || ''
  }
  // Attach latest price（复用自身的 getLatestPrice 计算逻辑）
  let latestPrice: number | null = null
  let latestPriceUnit: string | null = null
  try {
    let records = await getByIndex('product_records', 'by_product_id', id)
    records = await applyRegionFilter(records, regionId)
    if (records.length > 0) {
      // 按单位类型分组归一化，避免质量/计数混算（鸡蛋类问题的根因）
      const [units, overrides, densities] = await Promise.all([
        getAll('units') as Promise<UnitInfo[]>,
        getAll('entity_unit_overrides') as Promise<EntityOverride[]>,
        getAll('entity_densities') as Promise<DensityInfo[]>,
      ])
      // 覆盖表按 ingredient 维护，用 product.ingredient_id 查找；缺则回退到商品 id
      const entId = product.ingredient_id ?? id
      const agg = aggregatePrices(records, units, overrides, densities, 'ingredient', entId)
      if (agg.average_price != null) {
        latestPrice = agg.average_price
        latestPriceUnit = agg.unit
      }
    }
  } catch { /* latest price is optional */ }
  return {
    ...product,
    barcodes: barcodes || [],
    ingredient_name: ingredientName,
    latest_price: latestPrice,
    latest_price_unit: latestPriceUnit,
  }
}

export async function lookupBarcode(params: Record<string, string>): Promise<any> {
  const barcode = String(params.barcode || '').trim()
  if (!barcode || barcode.length > 50) {
    return {
      found: false,
      source: null,
      product: {},
      errors: ['Invalid barcode'],
      has_enabled_providers: false,
    }
  }

  const [config, products, ingredients] = await Promise.all([
    getBarcodeConfig(),
    getAll('products'),
    getAll('ingredients'),
  ])
  const activeIngredientIds = new Set(
    ingredients.filter((item: any) => item.is_active !== false).map((item: any) => item.id)
  )
  const isActive = (product: any) =>
    product.is_active !== false &&
    (!product.ingredient_id || activeIngredientIds.has(product.ingredient_id))

  let product = products.find((item: any) => isActive(item) && item.barcode === barcode)
  if (!product) {
    const barcodeRows = await getByIndex('product_barcodes', 'by_code', barcode)
    const productId = barcodeRows.find((row: any) => row.is_active !== false)?.product_id
    product = products.find((item: any) => item.id === productId && isActive(item))
  }
 if (!product) return resolveExternalBarcode(barcode, config)

 return {
   found: true,
   source: 'local',
   product: {
     id: product.id,
     barcode,
     name: product.name,
     brand: product.brand || null,
     spec: null,
     manufacturer: null,
     image_url: product.image_url || null,
   },
   errors: [],
  has_enabled_providers: false,
 }
}

export async function createEntity(_params: Record<string, string>, data?: any): Promise<any> {
  // IndexedDB structured cloning cannot store Vue's reactive form proxy.
  const payload = JSON.parse(JSON.stringify(data || {}))
  const id = await addOne('products', {
    ...payload,
    is_active: true,
    aliases: payload.aliases || [],
    tags: payload.tags || [],
    price_weight: payload.price_weight ?? 50,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  })
  return await getById('products', id as number)
}

export async function updateEntity(params: Record<string, string>, data?: any): Promise<any> {
  const id = parseInt(params.id)
  const existing = await getById('products', id)
  if (!existing) throw { status: 404, message: `Product ${id} not found` }
  await putOne('products', { ...existing, ...data, id, updated_at: new Date().toISOString() })
  return await getById('products', id)
}

export async function deleteEntity(params: Record<string, string>): Promise<any> {
  const id = parseInt(params.id)
  const existing = await getById('products', id)
  if (!existing) throw { status: 404, message: `Product ${id} not found` }
  await putOne('products', { ...existing, id, is_active: false, updated_at: new Date().toISOString() })
  return { ok: true }
}

// ============================================================
// Autocomplete
// ============================================================

export async function autocomplete(_params: Record<string, string>, query?: any): Promise<any> {
  const q = query?.q || query?.name || ''
  if (!q) return []

  const lower = q.toLowerCase()
  const result = await paginate('products', query, (p: any) => {
    if (p.is_active === false) return false
    if (!p.name?.toLowerCase().includes(lower) &&
        !(Array.isArray(p.aliases) && p.aliases.some((a: string) => a.toLowerCase().includes(lower)))) {
      return false
    }
    return true
  })
  return result.items
}

// ============================================================
// Price Records CRUD
// ============================================================

export async function listRecords(_params: Record<string, string>, query?: any): Promise<any> {
  const lower = (query?.search || query?.product_name || query?.q)?.toLowerCase()
  const merchantIds = parseIdList(query?.merchant_ids ?? query?.merchant_id)
  const merchantIdSet = merchantIds.length ? new Set(merchantIds) : null
  const recordTypes = parseStringList(query?.record_types ?? query?.record_type)
  const recordTypeSet = recordTypes.length ? new Set(recordTypes) : null
  const categoryIds = parseIdList(query?.ingredient_category_ids)
  const catSet = categoryIds.length ? new Set(categoryIds) : null
  const ingredientId = query?.ingredient_id
  const productId = query?.product_id
  const startDate = query?.start_date || query?.startDate
  const endDate = query?.end_date || query?.endDate
  const regionId = parseRegionId(query?.region_id)

  // Product names are always needed for display; ingredient lookups remain lazy.
  const needJoin = !!lower || !!catSet || !!ingredientId
  const products = await getAll('products')
  const merchants = await getAll('merchants')
  const ingredients = needJoin ? await getAll('ingredients') : null

  const productMap = new Map<number, any>()
  if (products) for (const p of products) productMap.set(p.id, p)
  const merchantMap = new Map<number, any>()
  for (const m of merchants) merchantMap.set(m.id, m)
  const ingredientMap = new Map<number, any>()
  if (ingredients) for (const i of ingredients) ingredientMap.set(i.id, i)

  // ingredient_id -> product ids (ingredient detail page)
  let ingredientProductIds: Set<number> | null = null
  if (ingredientId) {
    ingredientProductIds = new Set(
      (products || [])
        .filter((p: any) => p.ingredient_id === parseInt(ingredientId))
        .map((p: any) => p.id),
    )
  }
  // ingredient_category_ids -> product ids via product.ingredient.category_id
  let categoryProductIds: Set<number> | null = null
  if (catSet) {
    categoryProductIds = new Set(
      (products || [])
        .filter((p: any) => {
          const ing = ingredientMap.get(p.ingredient_id)
          return ing && catSet.has(ing.category_id)
        })
        .map((p: any) => p.id),
    )
  }

  const all = (await getAll('product_records')).filter((r: any) => {
    if (ingredientProductIds && !ingredientProductIds.has(r.product_id)) return false
    if (productId && r.product_id !== parseInt(productId)) return false
    if (merchantIdSet && !(r.merchant_id != null && merchantIdSet.has(r.merchant_id))) return false
    if (recordTypeSet && !recordTypeSet.has(r.record_type)) return false
    if (categoryProductIds && !categoryProductIds.has(r.product_id)) return false
    if (startDate && (r.recorded_at || '') < startDate) return false
    if (endDate && (r.recorded_at || '') > endDate) return false
    if (lower) {
      const prod = productMap.get(r.product_id)
      const nameMatch =
        r.product_name?.toLowerCase().includes(lower) ||
        (prod && (prod.name?.toLowerCase().includes(lower) || listIncludes(prod.aliases, lower)))
      if (!nameMatch) {
        const ing = ingredientMap.get(prod?.ingredient_id)
        const ingMatch =
          ing && (ing.name?.toLowerCase().includes(lower) || listIncludes(ing.aliases, lower))
        if (!ingMatch) return false
      }
    }
    return true
  })

  // Backfill missing fields (legacy import data) and attach product/merchant
  // names so the list (and its filters) behave like cloud mode.
  for (const r of all) {
    if (r.original_unit == null) r.original_unit = r.original_unit_name || ''
    if (r.unit_name == null) r.unit_name = r.standard_unit_name || ''
    if (r.original_quantity == null) r.original_quantity = r.quantity ?? 1
    if (typeof r.product_name !== 'string' || !r.product_name) {
      const prod = productMap.get(r.product_id)
      if (prod) r.product_name = prod.name
      else r.product_name = ''
    }
    if (r.merchant_name === undefined && r.merchant_id != null) {
      const m = merchantMap.get(r.merchant_id)
      if (m) r.merchant_name = m.name
    }
  }

  // 地区过滤：与后端 get_product_records 的 region_id 语义对齐
  const regionFiltered = regionId == null ? all : await applyRegionFilter(all, regionId)

  // Sort by recorded_at descending
  regionFiltered.sort((a: any, b: any) => ((b.recorded_at || '') > (a.recorded_at || '') ? 1 : -1))

  const { skip, limit: pageSize, page, page_size } = resolvePagination(query)
  return { items: regionFiltered.slice(skip, skip + pageSize), total: regionFiltered.length, page, page_size }
}

export async function createRecord(_params: Record<string, string>, data?: any): Promise<any> {
  const currency = data?.currency || DEFAULT_CURRENCY
  const id = await addOne('product_records', {
    ...data,
    currency,
    exchange_rate: exchangeRateToUserCurrency(currency),
    user_currency: DEFAULT_USER_CURRENCY,
    created_at: new Date().toISOString(),
    recorded_at: data?.recorded_at || new Date().toISOString(),
  })
  return await getById('product_records', id as number)
}

export async function updateRecord(params: Record<string, string>, data?: any): Promise<any> {
  const id = parseInt(params.id)
  const existing = await getById('product_records', id)
  if (!existing) throw { status: 404, message: `Price record ${id} not found` }
  const currency = data?.currency || existing?.currency || DEFAULT_CURRENCY
  await putOne('product_records', {
    ...existing,
    ...data,
    id,
    currency,
    exchange_rate: exchangeRateToUserCurrency(currency),
    user_currency: DEFAULT_USER_CURRENCY,
    updated_at: new Date().toISOString(),
  })
  return await getById('product_records', id)
}

export async function deleteRecord(params: Record<string, string>): Promise<any> {
  const id = parseInt(params.id)
  const existing = await getById('product_records', id)
  if (!existing) throw { status: 404, message: `Price record ${id} not found` }
  await deleteOne('product_records', id)
  return { ok: true }
}

// ============================================================
// Product Weights
// ============================================================

export async function getWeight(params: Record<string, string>): Promise<any> {
  const productId = parseInt(params.id)
  const overrides = await getByIndex('product_weight_overrides', 'by_product_id', productId)
  const product = await getById('products', productId)
  return {
    product_id: productId,
    global_weight: product?.price_weight ?? 50,
    my_weight: overrides.length > 0 ? overrides[0].weight : null,
    override_id: overrides.length > 0 ? overrides[0].id : null,
  }
}

export async function setWeight(params: Record<string, string>, data?: any): Promise<any> {
  const productId = parseInt(params.id)
  const weight = data?.weight ?? 50
  const existing = await getByIndex('product_weight_overrides', 'by_product_id', productId)

  if (existing.length > 0) {
    await putOne('product_weight_overrides', { ...existing[0], weight, updated_at: new Date().toISOString() })
    return await getById('product_weight_overrides', existing[0].id)
  }
  const id = await addOne('product_weight_overrides', {
    product_id: productId,
    weight,
    created_at: new Date().toISOString(),
  })
  return await getById('product_weight_overrides', id as number)
}

export async function deleteWeight(params: Record<string, string>): Promise<any> {
  const productId = parseInt(params.id)
  const existing = await getByIndex('product_weight_overrides', 'by_product_id', productId)
  for (const item of existing) {
    await deleteOne('product_weight_overrides', item.id)
  }
  return { ok: true }
}

// ============================================================
// Barcodes
// ============================================================

export async function listBarcodes(params: Record<string, string>): Promise<any> {
  const productId = parseInt(params.id)
  const barcodes = await getByIndex('product_barcodes', 'by_product_id', productId)
  return { items: barcodes, total: barcodes.length }
}

export async function addBarcode(params: Record<string, string>, data?: any): Promise<any> {
  const productId = parseInt(params.id)
  const id = await addOne('product_barcodes', {
    product_id: productId,
    code: data?.code,
    standard: data?.standard || 'ean13',
    created_at: new Date().toISOString(),
  })
  return await getById('product_barcodes', id as number)
}

// ============================================================
// Latest Price
// ============================================================

export async function getLatestPrice(params: Record<string, string>, query?: any): Promise<any> {
  const productId = parseInt(params.id)
  const regionId = parseRegionId(query?.region_id)
  let records = await getByIndex('product_records', 'by_product_id', productId)
  records = await applyRegionFilter(records, regionId)

  if (records.length === 0) {
    return { average_price: null, unit: null, records: 0 }
  }

  records.sort((a: any, b: any) => ((b.recorded_at || '') > (a.recorded_at || '') ? 1 : -1))

  // 按单位类型分组归一化：质量记录返回 ¥/斤，计数记录单独 ¥/个，不混算
  const product = await getById('products', productId)
  const [units, overrides, densities] = await Promise.all([
    getAll('units') as Promise<UnitInfo[]>,
    getAll('entity_unit_overrides') as Promise<EntityOverride[]>,
    getAll('entity_densities') as Promise<DensityInfo[]>,
  ])
  const entId = product?.ingredient_id ?? productId
  const agg = aggregatePrices(records, units, overrides, densities, 'ingredient', entId)

  return {
    average_price: agg.average_price,
    unit: agg.average_price != null ? agg.unit : null,
    min_price: agg.min_price,
    max_price: agg.max_price,
    records: agg.records,
    latest_record: records[0],
  }
}

export async function getLatestPriceByMerchant(params: Record<string, string>, query?: any): Promise<any> {
  // Return per-merchant pricing for a product
  const id = parseInt(params.id)
  if (!Number.isFinite(id)) return { prices: [], unit: null }
  const regionId = parseRegionId(query?.region_id)
  let records = await getByIndex('product_records', 'by_product_id', id)
  records = await applyRegionFilter(records, regionId)
  // 前端模板期望 { prices: [...], unit: "..." }
  return {
    prices: records.map((r: any) => ({
      unit_name: r.unit_name || r.original_unit_name || '',
      price: r.price ?? 0,
      quantity: r.original_quantity ?? 1,
      merchant_id: r.merchant_id,
      merchant_name: r.merchant_name || '',
      recorded_at: r.recorded_at,
    })),
    unit: records[0]?.unit_name || '斤',
  }
}

export async function getProductHistory(params: Record<string, string>): Promise<any> {
  return { items: [], total: 0 }
}

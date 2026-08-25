// Merchants handler — CRUD, favorites, coordinates, prices.

import { getAll, getById, addOne, putOne, deleteOne, getByIndex, resolvePagination } from '../database'


// 本地模式商家币种推导：手选 default_currency 优先，其次按地区国家映射，无则 null（前端回落 CNY）。
const REGION_CURRENCIES: Record<string, string> = {
  AF: 'AFN', AX: 'EUR', AL: 'ALL', DZ: 'DZD', AS: 'USD', AD: 'EUR', AO: 'AOA', AI: 'XCD',
  AQ: 'USD', AG: 'XCD', AR: 'ARS', AM: 'AMD', AW: 'AWG', AU: 'AUD', AT: 'EUR', AZ: 'AZN',
  BS: 'BSD', BH: 'BHD', BD: 'BDT', BB: 'BBD', BY: 'BYN', BE: 'EUR', BZ: 'BZD', BJ: 'XOF',
  BM: 'BMD', BT: 'BTN', BO: 'BOB', BQ: 'USD', BA: 'BAM', BW: 'BWP', BV: 'NOK', BR: 'BRL',
  IO: 'USD', BN: 'BND', BG: 'BGN', BF: 'XOF', BI: 'BIF', CV: 'CVE', KH: 'KHR', CM: 'XAF',
  CA: 'CAD', KY: 'KYD', CF: 'XAF', TD: 'XAF', CL: 'CLP', CN: 'CNY', CX: 'AUD', CC: 'AUD',
  CO: 'COP', KM: 'KMF', CG: 'XAF', CD: 'CDF', CK: 'NZD', CR: 'CRC', CI: 'XOF', HR: 'EUR',
  CU: 'CUP', CW: 'ANG', CY: 'EUR', CZ: 'CZK', DK: 'DKK', DJ: 'DJF', DM: 'XCD', DO: 'DOP',
  EC: 'USD', EG: 'EGP', SV: 'USD', GQ: 'XAF', ER: 'ERN', EE: 'EUR', SZ: 'SZL', ET: 'ETB',
  FK: 'FKP', FO: 'DKK', FJ: 'FJD', FI: 'EUR', FR: 'EUR', GF: 'EUR', PF: 'XPF', TF: 'EUR',
  GA: 'XAF', GM: 'GMD', GE: 'GEL', DE: 'EUR', GH: 'GHS', GI: 'GIP', GR: 'EUR', GL: 'DKK',
  GD: 'XCD', GP: 'EUR', GU: 'USD', GT: 'GTQ', GG: 'GBP', GN: 'GNF', GW: 'XOF', GY: 'GYD',
  HT: 'HTG', HM: 'AUD', VA: 'EUR', HN: 'HNL', HK: 'HKD', HU: 'HUF', IS: 'ISK', IN: 'INR',
  ID: 'IDR', IR: 'IRR', IQ: 'IQD', IE: 'EUR', IM: 'GBP', IL: 'ILS', IT: 'EUR', JM: 'JMD',
  JP: 'JPY', JE: 'GBP', JO: 'JOD', KZ: 'KZT', KE: 'KES', KI: 'AUD', KP: 'KPW', KR: 'KRW',
  KW: 'KWD', KG: 'KGS', LA: 'LAK', LV: 'EUR', LB: 'LBP', LS: 'LSL', LR: 'LRD', LY: 'LYD',
  LI: 'CHF', LT: 'EUR', LU: 'EUR', MO: 'MOP', MG: 'MGA', MW: 'MWK', MY: 'MYR', MV: 'MVR',
  ML: 'XOF', MT: 'EUR', MH: 'USD', MQ: 'EUR', MR: 'MRU', MU: 'MUR', YT: 'EUR', MX: 'MXN',
  FM: 'USD', MD: 'MDL', MC: 'EUR', MN: 'MNT', ME: 'EUR', MS: 'XCD', MA: 'MAD', MZ: 'MZN',
  MM: 'MMK', NA: 'NAD', NR: 'AUD', NP: 'NPR', NL: 'EUR', NC: 'XPF', NZ: 'NZD', NI: 'NIO',
  NE: 'XOF', NG: 'NGN', NU: 'NZD', NF: 'AUD', MK: 'MKD', MP: 'USD', NO: 'NOK', OM: 'OMR',
  PK: 'PKR', PW: 'USD', PS: 'ILS', PA: 'USD', PG: 'PGK', PY: 'PYG', PE: 'PEN', PH: 'PHP',
  PN: 'NZD', PL: 'PLN', PT: 'EUR', PR: 'USD', QA: 'QAR', RE: 'EUR', RO: 'RON', RU: 'RUB',
  RW: 'RWF', BL: 'EUR', SH: 'SHP', KN: 'XCD', LC: 'XCD', MF: 'EUR', PM: 'EUR', VC: 'XCD',
  WS: 'WST', SM: 'EUR', ST: 'STN', SA: 'SAR', SN: 'XOF', RS: 'RSD', SC: 'SCR', SL: 'SLE',
  SG: 'SGD', SX: 'ANG', SK: 'EUR', SI: 'EUR', SB: 'SBD', SO: 'SOS', ZA: 'ZAR', GS: 'GBP',
  SS: 'SSP', ES: 'EUR', LK: 'LKR', SD: 'SDG', SR: 'SRD', SJ: 'NOK', SE: 'SEK', CH: 'CHF',
  SY: 'SYP', TW: 'TWD', TJ: 'TJS', TZ: 'TZS', TH: 'THB', TL: 'USD', TG: 'XOF', TK: 'NZD',
  TO: 'TOP', TT: 'TTD', TN: 'TND', TR: 'TRY', TM: 'TMT', TC: 'USD', TV: 'AUD', UG: 'UGX',
  UA: 'UAH', AE: 'AED', GB: 'GBP', US: 'USD', UM: 'USD', UY: 'UYU', UZ: 'UZS', VU: 'VUV',
  VE: 'VES', VN: 'VND', VG: 'USD', VI: 'USD', WF: 'XPF', EH: 'MAD', YE: 'YER', ZM: 'ZMW',
  ZW: 'ZWG',
}


async function withEffectiveCurrency(m: any): Promise<any> {
  if (!m || m.effective_currency != null) return m
  let currency: string | null = m.default_currency || null
  if (!currency && m.region_id != null) {
    const all = await getAll('regions')
    const byId = new Map(all.map((r: any) => [Number(r.id), r]))
    let node = byId.get(Number(m.region_id))
    while (node) {
      if (node.iso_country && REGION_CURRENCIES[node.iso_country]) {
        currency = REGION_CURRENCIES[node.iso_country]
        break
      }
      node = node.parent_id != null ? byId.get(Number(node.parent_id)) : null
    }
  }
  return { ...m, effective_currency: currency }
}

export async function listMerchants(_params: Record<string, string>, query?: any): Promise<any> {
  const search = query?.search || query?.name
  const lower = search?.toLowerCase()
  const includeClosed = query?.include_closed === true || query?.include_closed === 'true'
  const noPrice = query?.no_price === true || query?.no_price === 'true'

  let merchantsWithRecords: Set<number> | null = null
  if (noPrice) {
    const records = await getAll('product_records')
    merchantsWithRecords = new Set(records.map((r: any) => r.merchant_id).filter((id: any) => id != null))
  }

  const all = await getAll('merchants')
  const filtered = all.filter((m: any) => {
    if (m.is_active === false) return false
    if (!includeClosed && m.is_open === false) return false
    if (lower && !(m.name?.toLowerCase().includes(lower) || m.address?.toLowerCase().includes(lower))) return false
    if (noPrice && merchantsWithRecords!.has(m.id)) return false
    return true
  })
  filtered.sort((a: any, b: any) => ((b.created_at || '') > (a.created_at || '') ? 1 : -1))
  const { skip, limit: pageSize, page, page_size } = resolvePagination(query)
  const items = await Promise.all(filtered.slice(skip, skip + pageSize).map(withEffectiveCurrency))
  return { items, total: filtered.length, page, page_size }
}

export async function getMerchant(params: Record<string, string>): Promise<any> {
  const id = parseInt(params.id)
  const merchant = await getById('merchants', id)
  if (!merchant) throw { status: 404, message: `Merchant ${id} not found` }
  return await withEffectiveCurrency(merchant)
}

export async function createMerchant(_params: Record<string, string>, data?: any): Promise<any> {
  const id = await addOne('merchants', {
    ...data,
    region_id: data?.region_id ?? null,
    default_currency: data?.default_currency ?? null,
    is_active: true,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  })
  return await withEffectiveCurrency(await getById('merchants', id as number))
}

export async function updateMerchant(params: Record<string, string>, data?: any): Promise<any> {
  const id = parseInt(params.id)
  const existing = await getById('merchants', id)
  if (!existing) throw { status: 404, message: `Merchant ${id} not found` }
  await putOne('merchants', {
    ...existing,
    ...data,
    id,
    region_id: data?.region_id !== undefined ? data.region_id : (existing?.region_id ?? null),
    default_currency: data?.default_currency !== undefined ? data.default_currency : (existing?.default_currency ?? null),
    updated_at: new Date().toISOString(),
  })
  return await withEffectiveCurrency(await getById('merchants', id))
}

export async function deleteMerchant(params: Record<string, string>): Promise<any> {
  const id = parseInt(params.id)
  const existing = await getById('merchants', id)
  if (!existing) throw { status: 404, message: `Merchant ${id} not found` }
  await putOne('merchants', { ...existing, id, is_active: false, updated_at: new Date().toISOString() })
  return { ok: true }
}

export async function listFavorites(_params: Record<string, string>): Promise<any> {
  const [favorites, allMerchants] = await Promise.all([
    getAll('merchant_favorites'),
    getAll('merchants'),
  ])
  const merchantMap = new Map(allMerchants.map((m: any) => [m.id, m]))
  const rows = favorites
    .map((f: any) => merchantMap.get(f.merchant_id))
    .filter((m: any) => m != null && m.is_active !== false)
  return await Promise.all(rows.map(withEffectiveCurrency))
}

export async function addFavorite(params: Record<string, string>): Promise<any> {
  const merchantId = parseInt(params.id)
  const existing = await getByIndex('merchant_favorites', 'by_merchant_id', merchantId)
  if (existing.length > 0) return existing[0]
  const id = await addOne('merchant_favorites', {
    merchant_id: merchantId,
    created_at: new Date().toISOString(),
  })
  return await getById('merchant_favorites', id as number)
}

export async function removeFavorite(params: Record<string, string>): Promise<any> {
  const merchantId = parseInt(params.id)
  const existing = await getByIndex('merchant_favorites', 'by_merchant_id', merchantId)
  for (const f of existing) {
    await deleteOne('merchant_favorites', f.id)
  }
  return { ok: true }
}

export async function getCoordinates(_params: Record<string, string>, query?: any): Promise<any> {
  const all = await getAll('merchants')
  const coords = all
    .filter((m: any) => {
      if (!m.latitude || !m.longitude || m.is_active === false) return false
      // 默认排除已关闭商家，与列表行为一致；include_closed=true 时显示
      const includeClosed = query?.include_closed === true || query?.include_closed === 'true'
      if (!includeClosed && m.is_open === false) return false
      return true
    })
    .map((m: any) => ({
      id: m.id,
      name: m.name,
      latitude: m.latitude,
      longitude: m.longitude,
    }))
  return coords
}

export async function getMerchantPrices(params: Record<string, string>, query?: any): Promise<any> {
  const merchantId = parseInt(params.id)
  const all = await getByIndex('product_records', 'by_merchant_id', merchantId)
  const { skip, limit: pageSize, page, page_size } = resolvePagination(query)
  return { items: all.slice(skip, skip + pageSize), total: all.length, page, page_size }
}

export async function getMerchantProductPrices(params: Record<string, string>, query?: any): Promise<any> {
  const merchantId = parseInt(params.id)
  const all = await getByIndex('product_records', 'by_merchant_id', merchantId)
  // Return the latest price for each product at this merchant
  const latestByProduct: Record<number, any> = {}
  for (const rec of all) {
    const existing = latestByProduct[rec.product_id]
    if (!existing || rec.recorded_at > existing.recorded_at) {
      latestByProduct[rec.product_id] = rec
    }
  }
  const records = Object.values(latestByProduct)
  if (records.length === 0) {
    const { page, page_size } = resolvePagination(query)
    return { items: [], total: 0, page, page_size }
  }

  // Join products -> ingredients -> ingredient_categories, and attach fill
  // order from learned fill-order records. Sort by fill-in order (most recent
  // session first) before paginating, mirroring the cloud backend.
  const [products, ingredients, categories] = await Promise.all([
    getAll('products'),
    getAll('ingredients'),
    getAll('ingredient_categories'),
  ])
  // user_merchant_product_orders was added in DB v3; if the upgrade hasn't
  // applied yet (HMR stale connection, or an old tab holding the v2 DB open),
  // getAll would throw and break the whole list. Degrade to empty instead.
  const orderRecords = await safeGetAll('user_merchant_product_orders')
  const productMap = new Map(products.map((p: any) => [p.id, p]))
  const ingredientMap = new Map(ingredients.map((i: any) => [i.id, i]))
  const categoryMap = new Map(categories.map((c: any) => [c.id, c]))
  const fillOrders = computeFillOrders(orderRecords, merchantId)

  const enriched = records.map((rec: any) => {
    const product = productMap.get(rec.product_id)
    const ingredient = product?.ingredient_id ? ingredientMap.get(product.ingredient_id) : undefined
    const category = ingredient?.category_id != null ? categoryMap.get(ingredient.category_id) : undefined
    const fill = fillOrders.get(rec.product_id)
    return {
      ...rec,
      product_name: product?.name ?? '',
      category_id: category?.id ?? ingredient?.category_id ?? null,
      category_display_name: category?.display_name ?? null,
      category_sort_order: category?.sort_order ?? null,
      fill_sort_order: fill?.sort_order ?? null,
      fill_session_date: fill?.session_date ?? null,
    }
  })

  enriched.sort((a: any, b: any) => {
    const aHas = a.fill_sort_order != null
    const bHas = b.fill_sort_order != null
    if (aHas !== bHas) return aHas ? -1 : 1
    if (aHas) {
      const dc = (b.fill_session_date || '').localeCompare(a.fill_session_date || '')
      if (dc !== 0) return dc
      return a.fill_sort_order - b.fill_sort_order
    }
    return String(a.product_name || '').localeCompare(String(b.product_name || ''))
  })

  const total = enriched.length
  const { skip, limit, page, page_size } = resolvePagination(query)
  const items = enriched.slice(skip, skip + limit)
  return { items, total, page, page_size }
}

/** Read a store that may not exist yet; return [] on failure (DB not upgraded). */
async function safeGetAll(storeName: string): Promise<any[]> {
  try {
    return await getAll(storeName as any)
  } catch {
    return []
  }
}

/**
 * Each product's most recent fill-order session: the row with the max
 * session_date, carrying its sort_order. Mirrors the cloud backend's
 * recent_orders CTE. Products with no order records are absent.
 */
function computeFillOrders(orderRecords: any[], merchantId: number): Map<number, { sort_order: number; session_date: string }> {
  const result = new Map<number, { sort_order: number; session_date: string }>()
  for (const rec of orderRecords) {
    if (rec.merchant_id !== merchantId) continue
    const cur = result.get(rec.product_id)
    if (!cur || (rec.session_date || '') > (cur.session_date || '')) {
      result.set(rec.product_id, { sort_order: rec.sort_order, session_date: rec.session_date })
    }
  }
  return result
}

export async function saveProductOrders(params: Record<string, string>, data?: any): Promise<any> {
  const merchantId = parseInt(params.id)
  const productIds: number[] = Array.isArray(data?.product_ids) ? data.product_ids : []
  const sessionDate: string = data?.session_date || new Date().toLocaleDateString('en-CA')

  // Load existing records for this (merchant, session_date) to upsert by product_id.
  // New batch appends after the current day's max sort_order so multiple saves
  // in the same session don't collide (mirrors cloud backend).
  const all = await getAll('user_merchant_product_orders')
  const existingByPid = new Map<number, any>()
  for (const rec of all) {
    if (rec.merchant_id === merchantId && rec.session_date === sessionDate) {
      existingByPid.set(rec.product_id, rec)
    }
  }

  let nextSort = Math.max(-1, ...[...existingByPid.values()].map((r: any) => r.sort_order ?? -1)) + 1
  const seen = new Map<number, any>()
  for (const pid of productIds) {
    const record = seen.get(pid) || existingByPid.get(pid)
    if (record) {
      // Duplicate or re-saved product moves to the latest fill position.
      record.sort_order = nextSort
      seen.set(pid, record)
    } else {
      const id = await addOne('user_merchant_product_orders', {
        merchant_id: merchantId,
        product_id: pid,
        session_date: sessionDate,
        sort_order: nextSort,
        created_at: new Date().toISOString(),
      })
      seen.set(pid, { id, merchant_id: merchantId, product_id: pid, session_date: sessionDate, sort_order: nextSort })
    }
    nextSort++
  }

  for (const rec of seen.values()) {
    if (rec.id != null && existingByPid.has(rec.product_id)) {
      await putOne('user_merchant_product_orders', { ...rec })
    }
  }

  return { message: 'ok' }
}

export async function geocodeMerchant(_params: Record<string, string>, _data?: any): Promise<any> {
  return { region_id: null }
}

export async function getMapConfig(): Promise<any> {
  return {
    map_enabled: true,
    default_map: 'amap',
  }
}

export async function listUserPlaces(): Promise<any> {
  // 与云端 List[UserPlaceResponse] 对齐：返回数组，默认地点优先。
  const all = await getAll('user_places')
  return all.sort(
    (a: any, b: any) =>
      Number(!!b.is_default) - Number(!!a.is_default) ||
      (a.sort_order ?? 0) - (b.sort_order ?? 0) ||
      (a.created_at || '').localeCompare(b.created_at || ''),
  )
}

export async function createUserPlace(_params: Record<string, string>, data?: any): Promise<any> {
  if (data?.is_default) {
    // 设为默认前清除其他默认，保证全局唯一
    const all = await getAll('user_places')
    for (const p of all) {
      if (p.is_default) await putOne('user_places', { ...p, is_default: false })
    }
  }
  const id = await addOne('user_places', {
    ...data,
    is_default: !!data?.is_default,
    sort_order: data?.sort_order ?? 0,
    created_at: new Date().toISOString(),
  })
  return getById('user_places', id as number)
}

export async function updateUserPlace(params: Record<string, string>, data?: any): Promise<any> {
  const id = parseInt(params.id)
  const existing = await getById('user_places', id)
  if (!existing) throw { status: 404, message: '常用地点不存在' }
  await putOne('user_places', { ...existing, ...data, id })
  return getById('user_places', id)
}

export async function deleteUserPlace(params: Record<string, string>): Promise<any> {
  const id = parseInt(params.id)
  await deleteOne('user_places', id)
  return { message: '常用地点已删除' }
}

export async function setDefaultUserPlace(params: Record<string, string>): Promise<any> {
  const id = parseInt(params.id)
  const target = await getById('user_places', id)
  if (!target) throw { status: 404, message: '常用地点不存在' }
  // 清除其他默认，保证全局唯一
  const all = await getAll('user_places')
  for (const p of all) {
    if (p.id !== id && p.is_default) await putOne('user_places', { ...p, is_default: false })
  }
  await putOne('user_places', { ...target, is_default: true })
  return getById('user_places', id)
}

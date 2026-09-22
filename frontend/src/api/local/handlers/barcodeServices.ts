// Local-mode barcode service configuration and browser-side provider lookup.

import { getDb } from '../database'
import { t as translate } from '../../../plugins/i18n.ts'

export interface BarcodeService {
  id: string
  type: 'openfoodfacts' | 'mxnzp' | 'yunji' | 'custom'
  enabled: boolean
  timeout_seconds: number
  name?: string | null
  doc_url?: string | null
  app_id?: string | null
  app_secret?: string | null
  app_code?: string | null
  url_template?: string | null
  headers: Record<string, string>
  mappings: Record<string, string>
}

export interface BarcodeConfig {
  cache_ttl_minutes: number
  services: BarcodeService[]
}

export interface BarcodeProduct {
  barcode: string
  name: string | null
  brand?: string | null
  spec?: string | null
  manufacturer?: string | null
  image_url?: string | null
}

export interface BarcodeLookupResult {
  found: boolean
  source: string | null
  product: BarcodeProduct | Record<string, never>
  errors: string[]
  has_enabled_providers: boolean
}

const DEFAULT_BARCODE_SERVICES: BarcodeService[] = [
  {
    id: 'openfoodfacts',
    type: 'openfoodfacts',
    enabled: false,
    timeout_seconds: 5,
    name: 'Open Food Facts',
    doc_url: 'https://world.openfoodfacts.org/',
    headers: {},
    mappings: {},
  },
  {
    id: 'mxnzp',
    type: 'mxnzp',
    enabled: false,
    timeout_seconds: 5,
    name: 'mxnzp',
    doc_url: 'https://www.mxnzp.com/doc/detail?id=6',
    headers: {},
    mappings: {},
  },
  {
    id: 'yunji',
    type: 'yunji',
    enabled: false,
    timeout_seconds: 5,
    name: 'Yunji (Alibaba Cloud API Marketplace)',
    doc_url: 'https://market.aliyun.com/detail/cmapi031448',
    headers: {},
    mappings: {},
  },
]

export async function getBarcodeConfig(): Promise<BarcodeConfig> {
  const db = await getDb()
  const row = await db.get('system_config', 'barcode_service_config')
  return normalizeBarcodeConfig(row?.value)
}

export function normalizeBarcodeConfig(raw: any): BarcodeConfig {
  return {
    cache_ttl_minutes: Number(raw?.cache_ttl_minutes) || 10080,
    services: (raw?.services || DEFAULT_BARCODE_SERVICES).map((service: any) => ({
      headers: {},
      mappings: {},
      ...service,
    })),
  }
}

export function mergeBarcodeConfig(saved: BarcodeConfig, incoming: any): BarcodeConfig {
  const savedServices = new Map(saved.services.map((service) => [service.id, service]))
  return {
    cache_ttl_minutes: Number(incoming?.cache_ttl_minutes) || saved.cache_ttl_minutes,
    services: (incoming?.services || []).map((service: any) => {
      const previous = savedServices.get(service.id)
      const merged: BarcodeService = { headers: {}, mappings: {}, ...service }
      if (previous) {
        for (const field of ['app_id', 'app_secret', 'app_code'] as const) {
          if (merged[field] == null || merged[field] === '***') {
            merged[field] = previous[field] || null
          }
        }
        merged.headers = Object.fromEntries(
          Object.entries(merged.headers).map(([name, value]) => [
            name,
            value === '***' ? previous.headers?.[name] ?? value : value,
          ])
        )
      }
      return merged
    }),
  }
}

export async function saveBarcodeConfig(config: BarcodeConfig): Promise<void> {
  const db = await getDb()
  await db.put('system_config', {
    key: 'barcode_service_config',
    value: JSON.parse(JSON.stringify(config)),
  })
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(url, { ...init, signal: controller.signal })
  } finally {
    clearTimeout(timer)
  }
}

const JSONPATH_IDENTIFIER = /[^.[\]()*,:]+/y

function jsonpath(data: any, path: string): any {
  if (typeof path !== 'string' || !path.startsWith('$')) return undefined

  let current = data
  let index = 1
  while (index < path.length) {
    if (path[index] === '.') {
      index += 1
      JSONPATH_IDENTIFIER.lastIndex = index
      const match = JSONPATH_IDENTIFIER.exec(path)
      if (!match) throw new Error(`Invalid JSONPath segment at ${index}`)
      const key = match[0]
      if (!key || key === '*' || key === '..' || /[()*,:[]/.test(key)) {
        throw new Error(`Unsupported JSONPath segment: ${key}`)
      }
      if (!current || typeof current !== 'object') return undefined
      current = current[key]
      index = match.index + key.length
      continue
    }

    if (path[index] === '[') {
      const end = path.indexOf(']', index + 1)
      if (end < 0) throw new Error(`Unclosed JSONPath bracket at ${index}`)
      const token = path.slice(index + 1, end)
      index = end + 1
      if (token.startsWith("'") || token.startsWith('"')) {
        const key = token.slice(1, -1)
        if (!key) throw new Error('Empty JSONPath key')
        if (!current || typeof current !== 'object') return undefined
        current = current[key]
      } else if (/^\d+$/.test(token)) {
        const position = Number(token)
        if (!Array.isArray(current) || position >= current.length) return undefined
        current = current[position]
      } else {
        throw new Error(`Unsupported JSONPath token: ${token}`)
      }
      continue
    }

    throw new Error(`Unsupported JSONPath at ${index}`)
  }
  return current
}

function cleanProduct(barcode: string, values: Record<string, any>): BarcodeProduct | null {
  const product: Record<string, string | null> = {
    barcode,
    name: values.name ?? null,
    brand: values.brand ?? null,
    spec: values.spec ?? null,
    manufacturer: values.manufacturer ?? null,
    image_url: values.image_url ?? null,
  }
  for (const key of Object.keys(product)) {
    const value = product[key]
    if (typeof value === 'string') product[key] = value.trim() || null
  }
  return product.name ? (product as BarcodeProduct) : null
}

function parseOpenFoodFacts(payload: any, barcode: string): BarcodeProduct | null {
  if (payload?.status !== 1) return null
  const product = payload.product || {}
  return cleanProduct(barcode, {
    name: product.product_name,
    brand: product.brands,
    spec: product.quantity,
    manufacturer: null,
    image_url: product.image_url,
  })
}

function parseMxnzp(payload: any, barcode: string): BarcodeProduct | null {
  if (payload?.code !== 1) return null
  const data = payload.data || {}
  return cleanProduct(barcode, {
    name: data.goodsName,
    brand: data.brand,
    spec: data.standard,
    manufacturer: data.supplier,
    image_url: data.image,
  })
}

function parseYunji(payload: any, barcode: string): BarcodeProduct | null {
  if (String(payload?.status) !== '200') return null
  const images = payload.Image || []
  return cleanProduct(barcode, {
    name: payload.ItemName,
    brand: payload.BrandName,
    spec: payload.ItemSpecification,
    manufacturer: payload.FirmName,
    image_url: images[0]?.Imageurl,
  })
}

function parseCustom(
  service: BarcodeService,
  payload: any,
  barcode: string,
): BarcodeProduct | null {
  return cleanProduct(barcode, {
    name: jsonpath(payload, service.mappings.name || '$.missing'),
    brand: jsonpath(payload, service.mappings.brand || '$.missing'),
    spec: jsonpath(payload, service.mappings.spec || '$.missing'),
    manufacturer: jsonpath(payload, service.mappings.manufacturer || '$.missing'),
    image_url: jsonpath(payload, service.mappings.image_url || '$.missing'),
  })
}

export async function lookupWithProvider(
  service: BarcodeService,
  barcode: string,
): Promise<BarcodeProduct | null> {
  let url: string
  const headers: Record<string, string> = { ...service.headers }

  if (service.type === 'openfoodfacts') {
    url = `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(barcode)}.json`
  } else if (service.type === 'mxnzp') {
    url = `https://www.mxnzp.com/api/barcode/goods/details?${new URLSearchParams({
      barcode,
      app_id: service.app_id || '',
      app_secret: service.app_secret || '',
    })}`
  } else if (service.type === 'yunji') {
    url = `https://barcode100.market.alicloudapi.com/getBarcode?${new URLSearchParams({ Code: barcode })}`
    headers.Authorization = `APPCODE ${service.app_code || ''}`
  } else {
    url = (service.url_template || '').replace('{barcode}', encodeURIComponent(barcode))
  }

  const response = await fetchWithTimeout(url, { headers }, service.timeout_seconds * 1000)
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  const payload = await response.json()

  if (service.type === 'openfoodfacts') return parseOpenFoodFacts(payload, barcode)
  if (service.type === 'mxnzp') return parseMxnzp(payload, barcode)
  if (service.type === 'yunji') return parseYunji(payload, barcode)
  return parseCustom(service, payload, barcode)
}

function providerSource(service: BarcodeService): string {
  return service.type === 'custom' ? `custom:${service.id}` : service.type
}

function providerError(error: any): string {
  if (error?.name === 'AbortError') return translate('localMessages.requestTimeout')
  if (error instanceof TypeError) return translate('localMessages.browserConnectionFailure')
  return error?.message || translate('localMessages.lookupFailed')
}

export async function resolveExternalBarcode(
  barcode: string,
  config: BarcodeConfig,
): Promise<BarcodeLookupResult> {
  const services = config.services.filter((service) => service.enabled)
  const errors: string[] = []

  for (const service of services) {
    const label = service.name || service.id
    try {
      const product = await lookupWithProvider(service, barcode)
      if (product) {
        return {
          found: true,
          source: providerSource(service),
          product,
          errors: [],
          has_enabled_providers: true,
        }
      }
      errors.push(`${label}: ${translate('localMessages.productNotFoundInService')}`)
    } catch (error: any) {
      errors.push(`${label}: ${providerError(error)}`)
    }
  }

  const summary = services.length > 1
    ? translate('localMessages.barcodeProductNotFoundInServices', { count: services.length })
    : translate('localMessages.barcodeProductNotFound')

  return {
    found: false,
    source: null,
    product: {},
    errors: [summary],
    has_enabled_providers: services.length > 0,
  }
}

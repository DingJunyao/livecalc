import { api } from '@/api'

export interface BarcodeLookupProduct {
  id?: number
  barcode?: string | null
  name?: string | null
  brand?: string | null
  spec?: string | null
  manufacturer?: string | null
  image_url?: string | null
}

export interface BarcodeLookupResult {
  found: boolean
  source: string | null
 product: BarcodeLookupProduct
 errors: string[]
  has_enabled_providers: boolean
}

export async function lookupBarcode(barcode: string): Promise<BarcodeLookupResult> {
  const code = barcode.trim()
  if (!code) {
    return { found: false, source: null, product: {}, errors: ['请输入条码'], has_enabled_providers: true }
  }

  try {
    const result = await api.get(`/products/entity/barcode/${encodeURIComponent(code)}`)
    if (result && typeof result.found === 'boolean') return result
  } catch (error: any) {
    if (error?.found === false) return error
    if (error?.response?.data?.found === false) return error.response.data
    return {
      found: false,
      source: null,
      product: {},
      errors: [error?.userMessage || '条码查询失败'],
      has_enabled_providers: false,
    }
  }
  return { found: false, source: null, product: {}, errors: ['条码查询响应无效'], has_enabled_providers: true }
}

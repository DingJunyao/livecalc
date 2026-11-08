// 价格记录表单的商品自动完成搜索（编辑价格记录对话框共用）。
//
// 与 PricesView 内联实现同口径：/products/autocomplete + 300ms 防抖 +
// 请求序号（在途请求不回填旧结果）。搜索文本与选中商品不一致时自动
// 取消选中，避免保存时携带旧 productId（对齐移动端新增页语义）。
import { ref, watch } from 'vue'
import api from '@/api'

export interface ProductSuggestion {
  id: number
  name: string
  display_name?: string
  ingredient_name?: string | null
  matched_alias?: string | null
  [key: string]: any
}

export function normalizeProductSearch(value: any): string {
  if (typeof value === 'string') return value
  if (value && typeof value === 'object' && typeof value.name === 'string') return value.name
  return ''
}

export function usePriceProductAutocomplete() {
  const productSearch = ref('')
  const productSuggestions = ref<ProductSuggestion[]>([])
  const productLoading = ref(false)
  const selectedProduct = ref<ProductSuggestion | null>(null)
  let searchTimeout: ReturnType<typeof setTimeout> | null = null
  let sequence = 0

  const onProductSearchUpdate = (value: any) => {
    productSearch.value = normalizeProductSearch(value)
  }

  const searchProducts = async () => {
    const requestSequence = ++sequence
    const q = productSearch.value.trim()
    if (!q) {
      productSuggestions.value = []
      return
    }
    productLoading.value = true
    try {
      const response = await api.get('/products/autocomplete', {
        params: { q, limit: 20 }
      })
      if (requestSequence !== sequence) return
      productSuggestions.value = response || []
    } catch (e: any) {
      if (requestSequence !== sequence) return
      console.error('Failed to search products', e)
      productSuggestions.value = []
    } finally {
      if (requestSequence === sequence) productLoading.value = false
    }
  }

  watch(productSearch, (value) => {
    if (searchTimeout) clearTimeout(searchTimeout)
    searchTimeout = setTimeout(() => {
      const query = normalizeProductSearch(value)
      if (query) {
        searchProducts()
      } else {
        sequence++
        productLoading.value = false
        productSuggestions.value = []
      }
    }, 300)
    // 文本被手动改动后不再信任选中项（程序化回显时二者一致，不受影响）
    const selected = selectedProduct.value
    if (selected && normalizeProductSearch(value) !== selected.name) {
      selectedProduct.value = null
    }
  })

  /** 程序化选中（打开对话框预填用），并同步搜索文本回显。 */
  const selectProduct = (p: ProductSuggestion | null) => {
    selectedProduct.value = p
    productSearch.value = p?.name ?? ''
  }

  const resetProduct = () => {
    if (searchTimeout) clearTimeout(searchTimeout)
    sequence++
    productSearch.value = ''
    productSuggestions.value = []
    productLoading.value = false
    selectedProduct.value = null
  }

  return {
    productSearch,
    productSuggestions,
    productLoading,
    selectedProduct,
    onProductSearchUpdate,
    selectProduct,
    resetProduct
  }
}

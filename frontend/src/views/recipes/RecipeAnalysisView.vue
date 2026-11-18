<template>
  <v-app-bar elevation="0" color="background" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">
      <div class="d-flex align-center ga-2">
        <span class="text-truncate">{{ recipe?.name || t('recipes.analysis') }}</span>
        <v-chip size="x-small" variant="tonal" color="primary">{{ t('recipes.analysisChip') }}</v-chip>
      </div>
    </v-app-bar-title>
    <template #append>
      <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="loadAllData" />
    </template>
  </v-app-bar>

  <v-container fluid class="pa-0">
    <div v-if="!recipe && loading" class="text-center py-16">
      <v-progress-circular indeterminate color="primary" size="64" />
      <div class="text-body-1 mt-4">{{ t('recipes.loading') }}</div>
    </div>

    <v-alert v-else-if="error" type="error" class="ma-4">
      {{ error }}
      <template #append>
        <v-btn variant="text" @click="retry">{{ t('recipes.retry') }}</v-btn>
      </template>
    </v-alert>

    <template v-else-if="recipe">
      <div class="px-4 pt-4">
      </div>
      <!-- 模块 ① + ② -->
      <v-row no-gutters>
        <v-col cols="12" md="6">
          <CostProportionChart
            :cost-breakdown="costData?.cost_breakdown"
            :total-cost="costData?.total_cost"
            :loading="loadingCostData"
          />
        </v-col>
        <v-col cols="12" md="6">
          <CostTrendAnalysis
            :recipe-id="recipe.id"
            :cost-history="costHistoryRecords"
            :ingredients="recipe.ingredients"
            :cost-breakdown="costData?.cost_breakdown"
            :loading="loadingCostHistory"
            @filter-change="onCostTrendFilterChange"
          />
        </v-col>
      </v-row>

      <!-- 模块 ③ -->
      <NutritionSourceGrid
        :nutrition-data="nutritionData"
        :loading="loadingNutritionData"
      />

      <!-- 模块 ⑤ + ④（维度切换：商家 / 地区；有 ≥2 个有数据地区时才出现切换） -->
      <div class="ma-4">
        <div v-if="hasRegionComparison" class="d-flex justify-end mb-2">
          <v-btn-toggle v-model="compareDimension" mandatory density="compact" variant="outlined" divided>
            <v-btn value="merchant" size="small">{{ t('charts.byMerchant') }}</v-btn>
            <v-btn value="region" size="small">{{ t('charts.byRegion') }}</v-btn>
          </v-btn-toggle>
        </div>
        <MerchantCostCards
          :merchant-costs="compareDimension === 'region' ? regionCostsShaped : merchantCosts"
          :loading="compareDimension === 'region' ? loadingRegionCosts : loadingMerchantCosts"
          :title="compareDimension === 'region' ? t('compare.recipeMatrixTitle') : undefined"
        />
        <MerchantPriceMatrix
          :recipe-ingredients="recipe.ingredients"
          :merchant-prices="compareDimension === 'region' ? regionPricesShaped : merchantPriceData"
          :loading="compareDimension === 'region' ? loadingRegionCosts : loadingMerchantPrices"
          :title="compareDimension === 'region' ? t('compare.recipeMatrixTitle') : undefined"
        />
      </div>
    </template>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { api, LONG_REQUEST_TIMEOUT } from '@/api'
import CostProportionChart from '@/components/recipes/CostProportionChart.vue'
import CostTrendAnalysis from '@/components/recipes/CostTrendAnalysis.vue'
import NutritionSourceGrid from '@/components/recipes/NutritionSourceGrid.vue'
import MerchantCostCards from '@/components/recipes/MerchantCostCards.vue'
import MerchantPriceMatrix from '@/components/recipes/MerchantPriceMatrix.vue'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'
import { unitDisplayName } from '@/utils/catalogLabels'
import { QUANTITY_TYPE_KEYS, VAGUE_QUANTITY_GRAM_MAP } from '@/data/localValues'

const route = useRoute()
const router = useRouter()
const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const { t } = useI18n()
const localeStore = useLocaleStore()

function quantityTypeLabel(quantityType: string): string {
  return t(QUANTITY_TYPE_KEYS[quantityType] || 'quantityTypes.numeric')
}
const recipeIdRaw = Number(route.params.id)
const recipeId = Number.isFinite(recipeIdRaw) ? recipeIdRaw : 0

const recipe = ref<any>(null)
const costData = ref<any>(null)
const nutritionData = ref<any>(null)
const costHistoryRecords = ref<any[]>([])
const merchantCosts = ref<any>(null)
const merchantPriceData = ref<any[]>([])

const loading = ref(true)
const error = ref<string | null>(null)
const loadingCostData = ref(false)
const loadingNutritionData = ref(false)
const loadingCostHistory = ref(false)
const loadingMerchantCosts = ref(false)
const loadingMerchantPrices = ref(false)

function goBack() {
  router.push(`/recipes/${recipeId}`)
}

async function retry() {
  costData.value = null
  nutritionData.value = null
  costHistoryRecords.value = []
  merchantCosts.value = null
  merchantPriceData.value = []
  await loadAllData()
}

async function loadAllData() {
  if (!recipeId) {
    error.value = t('recipes.invalidId')
    loading.value = false
    return
  }

  loading.value = true
  error.value = null

  try {
    const [recipeRes, costRes, nutritionRes] = await Promise.all([
      api.get(`/recipes/${recipeId}`),
      api.get(`/recipes/${recipeId}/cost`, { params: { region_id: null } }).catch(() => null),
      api.get(`/recipes/${recipeId}/nutrition`).catch(() => null),
    ])

    recipe.value = recipeRes
    costData.value = costRes
    nutritionData.value = nutritionRes
    loading.value = false

    // 并行加载成本和商家数据
    loadCostHistory('month')
    loadMerchantCosts()
    loadMerchantPrices()

  } catch (e: any) {
    error.value = e?.userMessage || t('recipes.loadFailed')
    loading.value = false
  }
}

async function loadCostHistory(filter: string) {
  loadingCostHistory.value = true
  try {
    const daysMap: Record<string, number> = { week: 7, month: 30, quarter: 90, year: 365, all: 3650 }
    const days = daysMap[filter] || 90
    const res = await api.get(`/recipes/${recipeId}/cost-history-range`, {
      params: { days, offset_days: 0, region_id: null },
      timeout: LONG_REQUEST_TIMEOUT,
    })
    costHistoryRecords.value = Array.isArray(res) ? res : []
  } catch { /* 忽略 */ }
  finally {
    loadingCostHistory.value = false
  }
}

async function loadMerchantCosts() {
  loadingMerchantCosts.value = true
  try {
    const res = await api.get(`/recipes/${recipeId}/merchant-costs`, {
      params: { region_id: null },
      timeout: LONG_REQUEST_TIMEOUT,
    })
    merchantCosts.value = res
  } catch { /* 忽略 */ }
  finally {
    loadingMerchantCosts.value = false
  }
}

// 模糊量 → 默认克数（与后端 VAGUE_QUANTITY_GRAM_MAP 对齐）
const VAGUE_QUANTITY_GRAM = VAGUE_QUANTITY_GRAM_MAP

// 从 quantity / quantity_range / original_quantity 中提取有效数量
function getEffectiveQuantity(ingredient: any): { qty: number | null; qtyDisplay: string; qtyUnit: string } {
  let qty: number | null = null
  let qtyDisplay = ''
  let qtyUnit = ingredient.unit || ''

  if (ingredient.quantity) {
    qty = parseFloat(ingredient.quantity)
    qtyDisplay = formatQuantity(ingredient.quantity, qtyUnit)
  } else if (ingredient.quantity_range) {
    let qr = ingredient.quantity_range
    if (typeof qr === 'string') {
      try { qr = JSON.parse(qr) } catch { /* ignore */ }
    }
    if (qr && typeof qr === 'object') {
      const min = parseFloat(qr.min) || 0
      const max = parseFloat(qr.max) || 0
      qty = (min + max) / 2
      qtyDisplay = `${formatNumber(qr.min, localeStore.effectiveFormatLocale)}-${formatNumber(qr.max, localeStore.effectiveFormatLocale)}${qtyUnit ? ` ${unitDisplayName({ name: qtyUnit, abbreviation: qtyUnit })}` : ''}`
    }
  }

  // 模糊量回退（original_quantity 中的「适量/少许」→ 克）
  if (qty == null && ingredient.original_quantity) {
    let orig = ingredient.original_quantity
    if (typeof orig !== 'string') {
      try { orig = JSON.stringify(orig) } catch { orig = '' }
    }
    for (const [keyword, gramQty] of Object.entries(VAGUE_QUANTITY_GRAM)) {
      if (orig.includes(keyword)) {
        qty = gramQty
        qtyDisplay = `${quantityTypeLabel(keyword)} (${formatNumber(gramQty, localeStore.effectiveFormatLocale)} g)`
        qtyUnit = 'g'
        break
      }
    }
  }

  return { qty, qtyDisplay, qtyUnit }
}

function formatQuantity(quantity: number | string, unit: string) {
  const formatted = formatNumber(quantity, localeStore.effectiveFormatLocale)
  return unit ? `${formatted} ${unitDisplayName({ name: unit, abbreviation: unit })}` : formatted
}

function fetchMerchantPrice(ingredient: any): Promise<any> {
  const { qty, qtyDisplay, qtyUnit } = getEffectiveQuantity(ingredient)
  const params: Record<string, any> = { region_id: null }
  if (qty != null && !isNaN(qty) && qty > 0) {
    params.quantity = qty
    params.quantity_unit = qtyUnit
  }
  return api.get(`/nutrition/ingredients/${ingredient.ingredient_id}/latest-price-by-merchant`, {
    params,
  })
    .then((res: any) => ({
      recipeIngredientId: ingredient.id,
      ingredientId: ingredient.ingredient_id,
      ingredientName: ingredient.name,
      prices: res?.prices || [],
      unit: res?.unit || null,
      qtyDisplay,
      fallbackChain: res?.fallback_chain || null,
    }))
    .catch(() => null)
}

// ==================== 跨地区对比（维度切换：商家 / 地区） ====================
// 复用 MerchantCostCards / MerchantPriceMatrix：把 comparison/recipe-costs 的
// 地区数据整形为两个组件的商家数据形状（merchant_id=region_id、merchant_name=地区名），
// 表头随维度切换（title prop），组件不重写。
import { getComparisonRecipeCosts, type RecipeCostsResponse } from '@/api/comparison'
import { fetchPricedRegions } from '@/composables/useRegionPrices'

const compareDimension = ref<'merchant' | 'region'>('merchant')
const regionCandidates = ref<Array<{ region_id: number; display_name: string }>>([])
const regionCostsData = ref<RecipeCostsResponse | null>(null)
const loadingRegionCosts = ref(false)

const hasRegionComparison = computed(() => regionCandidates.value.length >= 2)

async function loadRegionCompare() {
  if (regionCandidates.value.length === 0) {
    try {
      regionCandidates.value = await fetchPricedRegions()
    } catch {
      regionCandidates.value = []
    }
  }
  if (regionCandidates.value.length < 2 || !recipeId) return
  loadingRegionCosts.value = true
  try {
    regionCostsData.value = await getComparisonRecipeCosts(
      [recipeId],
      regionCandidates.value.slice(0, 6).map(r => r.region_id),
    )
  } catch {
    regionCostsData.value = null
  } finally {
    loadingRegionCosts.value = false
  }
}

// 首次切到「地区」时才拉取（懒加载，与详情页一致）
watch(compareDimension, (dim) => {
  if (dim === 'region' && regionCostsData.value == null && !loadingRegionCosts.value) {
    void loadRegionCompare()
  }
})

const nameByIdFromRegions = computed(() => {
  const map = new Map<number, string>()
  for (const meta of regionCostsData.value?.regions || []) {
    map.set(meta.region_id, meta.display_name || meta.name)
  }
  return map
})

/** 地区数据 → MerchantCostCards 形状（推荐=非缺失里总成本最低；单地区不标）。 */
const regionCostsShaped = computed(() => {
  const row = regionCostsData.value?.recipes?.[0]
  if (!row) return null
  const merchants: any[] = []
  for (const [ridStr, cell] of Object.entries(row.regions)) {
    if (!cell || cell.total_cost == null) continue
    const breakdown = cell.breakdown || []
    merchants.push({
      merchant_id: Number(ridStr),
      merchant_name: nameByIdFromRegions.value.get(Number(ridStr)) || ridStr,
      total_cost: cell.total_cost,
      external_cost: 0,
      covered_cost: cell.total_cost,
      covered_count: breakdown.filter(b => b.cost != null).length,
      total_ingredients: breakdown.length,
      missing_ingredients: cell.missing_ingredients || [],
      fallback_chains: breakdown.map(b => b.fallback_chain).filter(Boolean),
      is_recommended: false,
    })
  }
  const fresh = merchants.filter(m => m.missing_ingredients.length === 0)
  if (fresh.length >= 2) {
    const min = Math.min(...fresh.map(m => m.total_cost))
    for (const m of fresh) m.is_recommended = m.total_cost === min
  }
  return { merchants, currency: regionCostsData.value?.currency }
})

/** 地区数据 → MerchantPriceMatrix 形状（行=食材，prices=[{merchant_id=地区, cost}]；
 * is_lowest 按行内非缺失最低计算）。 */
const regionPricesShaped = computed(() => {
  const row = regionCostsData.value?.recipes?.[0]
  const ingredients = recipe.value?.ingredients || []
  if (!row) return []
  const regionIdsList = Object.keys(row.regions)
  return ingredients.map((ing: any) => {
    const cells = regionIdsList
      .map(rid => ({ rid, cell: row.regions[rid] }))
      .filter(x => x.cell)
    const prices = cells.map(({ rid, cell }) => {
      const b = (cell!.breakdown || []).find(x => x.ingredient_id === ing.ingredient_id)
      return {
        merchant_id: Number(rid),
        merchant_name: nameByIdFromRegions.value.get(Number(rid)) || rid,
        price: b?.cost ?? null,
        total_cost: b?.cost ?? null,
        is_lowest: false,
      }
    })
    const valid = prices.filter(p => p.price != null)
    if (valid.length >= 2) {
      const min = Math.min(...valid.map(p => p.price as number))
      for (const p of valid) p.is_lowest = p.price === min
    }
    return {
      recipeIngredientId: ing.id,
      ingredientId: ing.ingredient_id,
      ingredientName: ing.name,
      prices,
      unit: null,
      qtyDisplay: getEffectiveQuantity(ing).qtyDisplay,
      fallbackChain: null,
    }
  })
})

// 并发控制：同时最多 3 个比价请求，全局超时 50 秒
async function loadMerchantPrices() {
  const ingredients = recipe.value?.ingredients
  if (!ingredients?.length) {
    loadingMerchantPrices.value = false
    return
  }

  loadingMerchantPrices.value = true
  const startTime = Date.now()
  const GLOBAL_TIMEOUT = 35000
  const CONCURRENCY = 3

  try {
    const validIngredients = ingredients.filter((i: any) => i.ingredient_id)
    const results: any[] = []

    for (let i = 0; i < validIngredients.length; i += CONCURRENCY) {
      // 全局超时检查，超时后至少保留已有结果
      if (Date.now() - startTime > GLOBAL_TIMEOUT) {
        console.warn('[analysis] Merchant comparison timed out; showing partial results')
        break
      }

      const batch = validIngredients.slice(i, i + CONCURRENCY)
      const batchResults = await Promise.allSettled(batch.map(fetchMerchantPrice))
      results.push(...batchResults.map(r => r.status === 'fulfilled' ? r.value : null))
    }
    merchantPriceData.value = results.filter(Boolean)
  } catch {
    /* 忽略 */
  } finally {
    loadingMerchantPrices.value = false
  }
}

function onCostTrendFilterChange(filter: string) {
  loadCostHistory(filter)
}


onMounted(loadAllData)
</script>

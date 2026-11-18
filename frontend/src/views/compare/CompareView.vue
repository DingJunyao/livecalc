<template>
  <v-container fluid class="pa-4 pb-8">
    <v-tabs v-model="tab" density="comfortable" color="primary">
      <v-tab value="overview">{{ t('compare.tabOverview') }}</v-tab>
      <v-tab value="prices">{{ t('compare.tabPrices') }}</v-tab>
      <v-tab value="recipes">{{ t('compare.tabRecipes') }}</v-tab>
      <v-tab value="heatmap">{{ t('compare.tabHeatmap') }}</v-tab>
    </v-tabs>
    <v-divider />

    <v-tabs-window v-model="tab" class="mt-4">
      <!-- ============ 概览 ============ -->
      <v-tabs-window-item value="overview">
        <v-card variant="outlined" class="mb-4">
          <v-card-text>
            <div class="text-caption text-medium-emphasis mb-2">{{ t('compare.regionSelector') }}</div>
            <RegionMultiSelect v-model="regionIds" />
            <div class="text-caption text-medium-emphasis mt-2">
              {{ t('compare.baseRegionNote', { base: baseRegionName }) }}
            </div>
          </v-card-text>
        </v-card>

        <v-alert v-if="regionIds.length < 2" type="info" variant="tonal" density="compact">
          {{ t('compare.needTwoRegions') }}
        </v-alert>

        <template v-else>
          <!-- 地区摘要卡（最低物价指数高亮） -->
          <v-row dense>
            <v-col v-for="r in summary?.regions || []" :key="r.region_id" cols="12" sm="6" md="4" lg="3">
              <v-card
                variant="outlined"
                class="region-summary-card"
                :class="{ 'region-summary-lowest': isLowestIndex(r) }"
              >
                <SparklineBackground :data="r.trend" color="tertiary" />
                <div class="pa-3" style="position: relative; z-index: 1">
                  <div class="d-flex align-center">
                    <span class="text-subtitle-1 font-weight-medium text-truncate">{{ r.display_name }}</span>
                    <v-spacer />
                    <v-chip v-if="isLowestIndex(r)" size="x-small" color="success" variant="flat" label>
                      {{ t('compare.lowestIndex') }}
                    </v-chip>
                  </div>
                  <div class="d-flex align-baseline mt-1">
                    <span class="text-h5 font-weight-bold">{{ indexDisplay(r.price_index) }}</span>
                    <span class="text-caption text-medium-emphasis ms-1">{{ t('compare.priceIndexUnit') }}</span>
                  </div>
                  <div class="text-caption text-medium-emphasis mt-1">
                    {{ t('compare.recordCount', { count: r.record_count }) }}
                    · {{ t('compare.entityCount', { count: r.entity_count }) }}
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>
          <div v-if="summaryLoading" class="text-center py-4">
            <v-progress-circular indeterminate size="22" />
          </div>

          <v-row v-if="summary" class="mt-2">
            <!-- 物价指数对比 -->
            <v-col cols="12" md="6">
              <v-card variant="outlined" class="fill-height">
                <v-card-text>
                  <div class="text-subtitle-2 text-medium-emphasis mb-2">
                    {{ t('compare.priceIndexTitle', { base: baseRegionName }) }}
                  </div>
                  <SimpleBarChart
                    :items="indexBarItems"
                    :format-value="indexDisplay"
                    :base-label="baseRegionName"
                  />
                  <div class="text-caption text-medium-emphasis mt-1">
                    {{ t('compare.basketNote', { count: summary.basket_size }) }}
                  </div>
                </v-card-text>
              </v-card>
            </v-col>
            <!-- 篮子均价趋势 -->
            <v-col cols="12" md="6">
              <PriceTrendChart
                :title="t('compare.basketTrendTitle')"
                icon="mdi-chart-line"
                icon-color="tertiary"
                :unit="t('compare.trendUnitJin')"
                :empty-text="t('compare.noBasketData')"
                :data="baseRegionTrendData"
                :comparison-series="regionTrendSeries"
                :compare-label="t('charts.byRegion')"
                :loading="summaryLoading"
              />
            </v-col>
          </v-row>
        </template>
      </v-tabs-window-item>

      <!-- ============ 原料·商品 ============ -->
      <v-tabs-window-item value="prices">
        <v-card variant="outlined" class="mb-4">
          <v-card-text>
            <div class="d-flex align-center flex-wrap ga-3">
              <v-btn-toggle v-model="entityType" mandatory density="compact" variant="outlined" divided>
                <v-btn value="ingredient">{{ t('compare.entityTypeIngredient') }}</v-btn>
                <v-btn value="product">{{ t('compare.entityTypeProduct') }}</v-btn>
              </v-btn-toggle>
              <v-autocomplete
                v-model="entityIds"
                :items="entityOptions"
                :loading="entitySearching"
                v-model:search="entitySearch"
                :custom-filter="() => true"
                multiple
                chips
                closable-chips
                density="compact"
                variant="outlined"
                hide-details
                :label="t('compare.selectEntities')"
                :placeholder="t('compare.searchEntityPlaceholder')"
                item-title="name"
                item-value="id"
                :no-data-text="t('compare.noEntityMatch')"
              />
              <span v-if="regionIds.length < 2" class="text-caption text-warning">
                {{ t('compare.needTwoRegions') }}
              </span>
            </div>
          </v-card-text>
        </v-card>

        <RegionPriceMatrix
          :title="t('compare.matrixTitle')"
          :unit-note="t('compare.matrixUnitNote')"
          :columns="matrixColumns"
          :rows="matrixRows"
          :loading="matrixLoading"
          :empty-text="t('compare.noMatrixData')"
        />
      </v-tabs-window-item>

      <!-- ============ 菜谱·试算 ============ -->
      <v-tabs-window-item value="recipes">
        <!-- 菜谱成本 -->
        <v-card variant="outlined" class="mb-4">
          <v-card-text>
            <div class="d-flex align-center flex-wrap ga-3">
              <span class="text-subtitle-2 text-medium-emphasis">{{ t('compare.recipesSection') }}</span>
              <v-autocomplete
                v-model="recipeIds"
                :items="recipeOptions"
                :loading="recipeSearching"
                v-model:search="recipeSearch"
                :custom-filter="() => true"
                multiple
                chips
                closable-chips
                density="compact"
                variant="outlined"
                hide-details
                :label="t('compare.selectRecipes')"
                :placeholder="t('compare.searchEntityPlaceholder')"
                item-title="name"
                item-value="id"
                :no-data-text="t('compare.noEntityMatch')"
                style="max-width: 420px"
              />
              <span v-if="regionIds.length < 2" class="text-caption text-warning">
                {{ t('compare.needTwoRegions') }}
              </span>
            </div>
          </v-card-text>
        </v-card>

        <RegionPriceMatrix
          :title="t('compare.recipeMatrixTitle')"
          :unit-note="t('compare.recipeMatrixUnitNote')"
          :columns="matrixColumns"
          :rows="recipeMatrixRows"
          :loading="recipeMatrixLoading"
          :empty-text="t('compare.noMatrixData')"
          clickable-rows
          @row-click="(id: number | string) => (trendRecipeId = Number(id))"
        />

        <PriceTrendChart
          v-if="trendRecipeId != null"
          :key="trendRecipeId"
          :title="t('compare.recipeTrendTitle', { name: trendRecipeName })"
          icon="mdi-chart-line"
          icon-color="tertiary"
          :unit="t('compare.trendUnitJin')"
          :empty-text="t('compare.noBasketData')"
          :data="recipeTrendBaseData"
          :comparison-series="recipeTrendSeries"
          :compare-label="t('charts.byRegion')"
          :loading="recipeTrendLoading"
          class="mt-4"
        />

        <v-divider class="my-4" />

        <!-- 试算合计 -->
        <v-card variant="outlined" class="mb-4">
          <v-card-text>
            <div class="d-flex align-center flex-wrap ga-3">
              <span class="text-subtitle-2 text-medium-emphasis">{{ t('compare.plansSection') }}</span>
              <v-autocomplete
                v-model="planIds"
                :items="planOptions"
                :loading="planSearching"
                multiple
                chips
                closable-chips
                density="compact"
                variant="outlined"
                hide-details
                :label="t('compare.selectPlans')"
                item-title="name"
                item-value="id"
                :no-data-text="t('compare.noEntityMatch')"
                style="max-width: 420px"
              />
            </div>
          </v-card-text>
        </v-card>

        <RegionPriceMatrix
          :title="t('compare.planMatrixTitle')"
          :unit-note="t('compare.planMatrixUnitNote')"
          :columns="matrixColumns"
          :rows="planMatrixRows"
          :loading="planMatrixLoading"
          :empty-text="t('compare.noMatrixData')"
          clickable-rows
          @row-click="(id: number | string) => (nutrientPlanId = Number(id))"
        />

        <!-- 单方案各地区营养对照 -->
        <v-card v-if="nutrientPlanRow" variant="outlined" class="mt-4">
          <v-card-text>
            <div class="text-subtitle-2 text-medium-emphasis mb-2">
              {{ t('compare.planNutrientTitle', { name: nutrientPlanRow.name }) }}
            </div>
            <v-table density="compact">
              <thead>
                <tr>
                  <th class="text-left">{{ t('compare.matrixEntityCol') }}</th>
                  <th v-for="c in matrixColumns" :key="String(c.id)" class="text-end">{{ c.label }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="metric in planNutrientMetrics" :key="metric.key">
                  <td>{{ metric.label }}</td>
                  <td
                    v-for="c in matrixColumns"
                    :key="String(c.id)"
                    class="text-end"
                    :class="{ 'text-success font-weight-bold': isPlanNutrientBest(nutrientPlanRow, c.id, metric.key) }"
                  >
                    {{ formatPlanMetric(nutrientPlanRow.regions[String(c.id)], metric) }}
                  </td>
                </tr>
              </tbody>
            </v-table>
          </v-card-text>
        </v-card>
      </v-tabs-window-item>

      <!-- ============ 热力图 ============ -->
      <v-tabs-window-item value="heatmap">
        <v-card variant="outlined" class="mb-4">
          <v-card-text>
            <div class="d-flex align-center flex-wrap ga-3">
              <v-btn-toggle v-model="heatmapMode" mandatory density="compact" variant="outlined" divided>
                <v-btn value="item">{{ t('compare.heatmapModeItem') }}</v-btn>
                <v-btn value="overall">{{ t('compare.heatmapModeOverall') }}</v-btn>
              </v-btn-toggle>
              <template v-if="heatmapMode === 'item'">
                <v-btn-toggle v-model="heatmapEntityType" mandatory density="compact" variant="outlined" divided>
                  <v-btn value="ingredient">{{ t('compare.entityTypeIngredient') }}</v-btn>
                  <v-btn value="product">{{ t('compare.entityTypeProduct') }}</v-btn>
                </v-btn-toggle>
                <v-autocomplete
                  v-model="heatmapEntityId"
                  :items="heatmapEntityOptions"
                  :loading="heatmapEntitySearching"
                  v-model:search="heatmapEntitySearch"
                  :custom-filter="() => true"
                  density="compact"
                  variant="outlined"
                  hide-details
                  clearable
                  :label="t('compare.heatmapPickEntity')"
                  :placeholder="t('compare.searchEntityPlaceholder')"
                  item-title="name"
                  item-value="id"
                  :no-data-text="t('compare.noEntityMatch')"
                  style="max-width: 320px"
                />
              </template>
              <span v-else class="text-caption text-medium-emphasis">
                {{ t('compare.heatmapOverallNote') }}
              </span>
              <span v-if="regionIds.length < 1" class="text-caption text-warning">
                {{ t('compare.needTwoRegions') }}
              </span>
            </div>
          </v-card-text>
        </v-card>

        <div v-if="heatmapLoading" class="text-center py-8">
          <v-progress-circular indeterminate size="24" />
        </div>
        <HeatMapCanvas
          v-else-if="regionIds.length >= 1"
          :items="heatmapItems"
          :buckets="heatmapBuckets"
          :mode="heatmapMode"
          :empty-text="t('compare.heatmapEmpty')"
          class="mb-2"
        />
        <div v-if="heatmapData?.basket_size" class="text-caption text-medium-emphasis">
          {{ t('compare.basketNote', { count: heatmapData.basket_size }) }}
        </div>
      </v-tabs-window-item>
    </v-tabs-window>
  </v-container>
</template>

<script setup lang="ts">
// 物价对比页：概览（物价指数 + 篮子趋势）+ 原料·商品比价矩阵。
// 地区选择复用自定义计算范围的 RegionMultiSelect；tab/地区同步到 URL query。
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { formatMoney } from '@/utils/currency'
import RegionMultiSelect from '@/components/common/RegionMultiSelect.vue'
import RegionPriceMatrix from '@/components/compare/RegionPriceMatrix.vue'
import HeatMapCanvas from '@/components/compare/HeatMapCanvas.vue'
import SimpleBarChart from '@/components/charts/SimpleBarChart.vue'
import SparklineBackground from '@/components/charts/SparklineBackground.vue'
import PriceTrendChart from '@/components/charts/PriceTrendChart.vue'
import {
  getComparisonRegions,
  getComparisonSummary,
  getComparisonEntityPrices,
  getComparisonRecipeCosts,
  getComparisonRecipeCostTrend,
  getComparisonPlanCosts,
  getComparisonHeatmap,
  type ComparisonSummary,
  type EntityPricesResponse,
  type HeatmapResponse,
  type RecipeCostsResponse,
  type RecipeCostTrendPoint,
  type PlanCostRow,
  type RegionCandidate,
  type RegionSummaryItem,
} from '@/api/comparison'
import { api } from '@/api'

const { t } = useI18n()
const { currency: userCurrency } = useUserCurrency()
const route = useRoute()
const router = useRouter()

const MAX_REGIONS = 6

// 图表对比序列（结构兼容 PriceTrendChart 的 MerchantSeries：
// merchantId 泛化为序列标识，地区对比传地区 id）
interface TrendSeries {
  merchantId: number | string | null
  name: string
  data: Array<{ date: string; min: number; max: number; avg: number; count: number; recorded: boolean }>
}

// 矩阵行/列（结构兼容 RegionPriceMatrix 的 RegionMatrixRow/Column）
interface MatrixColumn { id: number | string; label: string }
interface MatrixRow {
  id: number | string
  label: string
  unit?: string | null
  cells: Record<string, { price: number | null; isStale?: boolean } | null>
}

// ---- URL 同步 ----
const tab = ref<'overview' | 'prices' | 'recipes' | 'heatmap'>(
  ['prices', 'recipes', 'heatmap'].includes(route.query.tab as string)
    ? (route.query.tab as 'prices' | 'recipes' | 'heatmap')
    : 'overview',
)
const regionIds = ref<number[]>([])

const queryRegionIds = computed<number[]>(() => {
  const raw = route.query.regions
  if (typeof raw !== 'string' || !raw) return []
  return raw.split(',').map(s => parseInt(s, 10)).filter(n => Number.isFinite(n) && n > 0).slice(0, MAX_REGIONS)
})

watch(queryRegionIds, (ids) => {
  regionIds.value = ids.length ? [...ids] : []
}, { immediate: true })

watch([tab, regionIds], () => {
  const q: Record<string, string> = {}
  if (tab.value !== 'overview') q.tab = tab.value
  if (regionIds.value.length) q.regions = regionIds.value.join(',')
  router.replace({ query: q })
})

// ---- 候选地区（默认带入记录数前 3） ----
const candidates = ref<RegionCandidate[]>([])
onMounted(async () => {
  try {
    const res = await getComparisonRegions()
    candidates.value = res.regions || []
    if (!regionIds.value.length && candidates.value.length) {
      regionIds.value = candidates.value.slice(0, 3).map(r => r.region_id)
    }
  } catch { /* 候选加载失败时保持手动选择 */ }
  // 试算下拉的全量选项（端点无分页/搜索，一次拉全 + 客户端过滤）
  void loadPlanOptions()
})

const baseRegionName = computed(() => {
  const id = regionIds.value[0]
  const item = summary.value?.regions.find(r => r.region_id === id)
    || candidates.value.find(c => c.region_id === id)
  return item?.display_name || '—'
})

// ---- 概览 ----
const summary = ref<ComparisonSummary | null>(null)
const summaryLoading = ref(false)
let summarySeq = 0

watch(regionIds, async (ids) => {
  summary.value = null
  if (!ids || ids.length < 1) return
  const seq = ++summarySeq
  summaryLoading.value = true
  try {
    const res = await getComparisonSummary(ids, 30)
    if (seq === summarySeq) summary.value = res
  } catch { /* 静默：卡片留空 */ }
  finally {
    if (seq === summarySeq) summaryLoading.value = false
  }
}, { immediate: true, deep: true })

function isLowestIndex(r: RegionSummaryItem): boolean {
  const values = (summary.value?.regions || [])
    .map(x => x.price_index)
    .filter((x): x is number => x != null)
  if (values.length < 2 || r.price_index == null) return false
  return r.price_index <= Math.min(...values)
}

function indexDisplay(v: number | null): string {
  if (v == null || !Number.isFinite(v)) return '—'
  return String(Math.round(v * 10) / 10)
}

const indexBarItems = computed<Array<{ label: string; value: number | null }>>(() =>
  (summary.value?.regions || []).map(r => ({ label: r.display_name, value: r.price_index })),
)

// 数字序列 → 图表数据点（序列结束于今天，按日历日回推日期）
function numbersToDataPoints(values: number[]): Array<{ date: string; min: number; max: number; avg: number; count: number; recorded: boolean }> {
  if (!values.length) return []
  const out: Array<{ date: string; min: number; max: number; avg: number; count: number; recorded: boolean }> = []
  const start = new Date()
  start.setHours(0, 0, 0, 0)
  start.setDate(start.getDate() - (values.length - 1))
  for (let i = 0; i < values.length; i++) {
    const d = new Date(start)
    d.setDate(start.getDate() + i)
    const v = values[i]
    out.push({ date: d.toISOString().slice(0, 10), min: v, max: v, avg: v, count: 1, recorded: false })
  }
  return out
}

const baseRegionTrendData = computed(() => {
  const base = summary.value?.regions.find(r => r.region_id === summary.value?.base_region_id)
  return numbersToDataPoints(base?.trend || [])
})

const regionTrendSeries = computed<TrendSeries[]>(() =>
  (summary.value?.regions || []).map(r => ({
    merchantId: r.region_id,
    name: r.display_name,
    data: numbersToDataPoints(r.trend),
  })).filter(s => s.data.length > 0),
)

// ---- 原料·商品矩阵 ----
const entityType = ref<'ingredient' | 'product'>('ingredient')
const entityIds = ref<number[]>([])
const entityOptions = ref<Array<{ id: number; name: string }>>([])
const entitySearching = ref(false)
const entitySearch = ref('')
let entitySearchSeq = 0
let entitySearchTimer: ReturnType<typeof setTimeout> | null = null

function fetchEntityOptions(keyword: string) {
  const seq = ++entitySearchSeq
  entitySearching.value = true
  const url = entityType.value === 'ingredient' ? '/ingredients' : '/products/entity'
  const params: Record<string, any> = { limit: 20 }
  if (keyword) params.q = keyword
  api.get(url, { params }).then((res: any) => {
    if (seq !== entitySearchSeq) return
    entityOptions.value = (res.items || []).map((x: any) => ({ id: x.id, name: x.name }))
  }).catch(() => {
    if (seq === entitySearchSeq) entityOptions.value = []
  }).finally(() => {
    if (seq === entitySearchSeq) entitySearching.value = false
  })
}

// 搜索词变化（300ms 防抖，与项目其他搜索下拉一致）
watch(entitySearch, (kw) => {
  if (entitySearchTimer) clearTimeout(entitySearchTimer)
  const keyword = (kw || '').trim()
  entitySearchTimer = setTimeout(() => fetchEntityOptions(keyword), 300)
})

watch(entityType, () => {
  entityIds.value = []
  entityOptions.value = []
  entitySearch.value = ''
  fetchEntityOptions('')
})

onMounted(() => { fetchEntityOptions('') })

// 矩阵取数：地区或实体变化时重新拉取
const matrixData = ref<EntityPricesResponse | null>(null)
const matrixLoading = ref(false)
let matrixSeq = 0

watch([entityType, entityIds, regionIds], async () => {
  matrixData.value = null
  const ids = regionIds.value || []
  const eids = entityIds.value || []
  if (ids.length < 1 || eids.length < 1) return
  const seq = ++matrixSeq
  matrixLoading.value = true
  try {
    const res = await getComparisonEntityPrices(entityType.value, eids, ids, 30)
    if (seq === matrixSeq) matrixData.value = res
  } catch { /* 静默 */ }
  finally {
    if (seq === matrixSeq) matrixLoading.value = false
  }
}, { immediate: true, deep: true })

const matrixColumns = computed<MatrixColumn[]>(() => {
  if (matrixData.value?.regions?.length) {
    return matrixData.value.regions.map(r => ({ id: r.region_id, label: r.display_name }))
  }
  return (summary.value?.regions || []).map(r => ({ id: r.region_id, label: r.display_name }))
})

const matrixRows = computed<MatrixRow[]>(() => {
  const data = matrixData.value
  if (!data) return []
  return data.entities.map(e => ({
    id: e.entity_id,
    label: e.name,
    unit: e.unit,
    cells: Object.fromEntries(
      Object.entries(e.regions).map(([rid, cell]) => [
        rid,
        cell ? { price: cell.price, isStale: cell.is_stale } : null,
      ]),
    ),
  }))
})

// ==================== 菜谱·试算 tab ====================

// ---- 菜谱 ----
const recipeIds = ref<number[]>([])
const recipeOptions = ref<Array<{ id: number; name: string }>>([])
const recipeSearching = ref(false)
const recipeSearch = ref('')
let recipeSearchSeq = 0
let recipeSearchTimer: ReturnType<typeof setTimeout> | null = null

function fetchRecipeOptions(keyword: string) {
  const seq = ++recipeSearchSeq
  recipeSearching.value = true
  const params: Record<string, any> = { limit: 20 }
  if (keyword) params.search = keyword
  api.get('/recipes', { params }).then((res: any) => {
    if (seq !== recipeSearchSeq) return
    recipeOptions.value = (res.items || []).map((x: any) => ({ id: x.id, name: x.name }))
  }).catch(() => {
    if (seq === recipeSearchSeq) recipeOptions.value = []
  }).finally(() => {
    if (seq === recipeSearchSeq) recipeSearching.value = false
  })
}

watch(recipeSearch, (kw) => {
  if (recipeSearchTimer) clearTimeout(recipeSearchTimer)
  recipeSearchTimer = setTimeout(() => fetchRecipeOptions((kw || '').trim()), 300)
})

const recipeMatrixData = ref<RecipeCostsResponse | null>(null)
const recipeMatrixLoading = ref(false)
let recipeMatrixSeq = 0

watch([recipeIds, regionIds], async () => {
  recipeMatrixData.value = null
  trendRecipeId.value = null
  const rids = regionIds.value
  const ridsRec = recipeIds.value
  if (!rids.length || !ridsRec.length) return
  const seq = ++recipeMatrixSeq
  recipeMatrixLoading.value = true
  try {
    const res = await getComparisonRecipeCosts(ridsRec, rids)
    if (seq === recipeMatrixSeq) recipeMatrixData.value = res
  } catch { /* 静默 */ }
  finally {
    if (seq === recipeMatrixSeq) recipeMatrixLoading.value = false
  }
}, { immediate: true, deep: true })

const recipeMatrixRows = computed<MatrixRow[]>(() => {
  const data = recipeMatrixData.value
  if (!data) return []
  return data.recipes.map(r => ({
    id: r.recipe_id,
    label: r.name,
    unit: null,
    cells: Object.fromEntries(
      Object.entries(r.regions).map(([rid, cell]) => [
        rid,
        cell ? { price: cell.cost_per_serving ?? cell.total_cost, isStale: false } : null,
      ]),
    ),
  }))
})

// 单菜谱多地区趋势（点矩阵行进入）
const trendRecipeId = ref<number | null>(null)
const recipeTrend = ref<Record<string, RecipeCostTrendPoint[]> | null>(null)
const recipeTrendLoading = ref(false)
let recipeTrendSeq = 0

const trendRecipeName = computed(() =>
  recipeMatrixData.value?.recipes.find(r => r.recipe_id === trendRecipeId.value)?.name || '',
)

watch([trendRecipeId, regionIds], async () => {
  recipeTrend.value = null
  const rid = trendRecipeId.value
  const rids = regionIds.value
  if (rid == null || !rids.length) return
  const seq = ++recipeTrendSeq
  recipeTrendLoading.value = true
  try {
    const res = await getComparisonRecipeCostTrend(rid, rids, 30)
    if (seq === recipeTrendSeq) recipeTrend.value = res.regions
  } catch { /* 静默 */ }
  finally {
    if (seq === recipeTrendSeq) recipeTrendLoading.value = false
  }
}, { immediate: true })

function trendPointsToData(points: RecipeCostTrendPoint[]): TrendSeries['data'] {
  return points.map(p => ({
    date: p.date,
    min: p.min_cost ?? p.avg_cost,
    max: p.max_cost ?? p.avg_cost,
    avg: p.avg_cost,
    count: 1,
    recorded: p.has_record !== false,
  }))
}

const recipeTrendBaseData = computed(() => {
  const base = recipeMatrixData.value?.regions.find(r => r.region_id === regionIds.value[0])
  const key = base ? String(base.region_id) : Object.keys(recipeTrend.value || {})[0]
  return trendPointsToData((recipeTrend.value || {})[key] || [])
})

const recipeTrendSeries = computed<TrendSeries[]>(() =>
  Object.entries(recipeTrend.value || {}).map(([rid, points]) => ({
    merchantId: rid,
    name: matrixColumns.value.find(c => String(c.id) === rid)?.label || rid,
    data: trendPointsToData(points),
  })).filter(s => s.data.length > 0),
)

// ---- 试算 ----
const planIds = ref<number[]>([])
const planOptions = ref<Array<{ id: number; name: string }>>([])
const planSearching = ref(false)

async function loadPlanOptions() {
  planSearching.value = true
  try {
    const res: any = await api.get('/meal-plans')
    planOptions.value = (res.items || []).map((x: any) => ({ id: x.id, name: x.name }))
  } catch {
    planOptions.value = []
  } finally {
    planSearching.value = false
  }
}

const planMatrixData = ref<{ plans: PlanCostRow[] } | null>(null)
const planMatrixLoading = ref(false)
let planMatrixSeq = 0

watch([planIds, regionIds], async () => {
  planMatrixData.value = null
  nutrientPlanId.value = null
  const pids = planIds.value
  const rids = regionIds.value
  if (!rids.length || !pids.length) return
  const seq = ++planMatrixSeq
  planMatrixLoading.value = true
  try {
    const res = await getComparisonPlanCosts(pids, rids)
    if (seq === planMatrixSeq) planMatrixData.value = res
  } catch { /* 静默 */ }
  finally {
    if (seq === planMatrixSeq) planMatrixLoading.value = false
  }
}, { immediate: true, deep: true })

const planMatrixRows = computed<MatrixRow[]>(() => {
  const data = planMatrixData.value
  if (!data) return []
  return data.plans.map(p => ({
    id: p.plan_id,
    label: p.name,
    unit: null,
    cells: Object.fromEntries(
      Object.entries(p.regions).map(([rid, totals]) => [
        rid,
        totals ? { price: totals.cost ?? null, isStale: false } : null,
      ]),
    ),
  }))
})

// 单方案各地区营养对照（点矩阵行进入；营养与地区无关但成本随地区）
const nutrientPlanId = ref<number | null>(null)
const nutrientPlanRow = computed(() =>
  planMatrixData.value?.plans.find(p => p.plan_id === nutrientPlanId.value) || null,
)

const planNutrientMetrics = computed(() => [
  { key: 'cost', label: t('compare.metricCost'), best: 'min' as const },
  { key: 'calories', label: t('compare.metricCalories'), best: null },
  { key: 'protein_g', label: t('compare.metricProtein'), best: null },
  { key: 'carbs_g', label: t('compare.metricCarbs'), best: null },
  { key: 'fat_g', label: t('compare.metricFat'), best: null },
])

function isPlanNutrientBest(
  row: PlanCostRow,
  colId: number | string,
  key: string,
): boolean {
  if (key !== 'cost') return false
  const values = matrixColumns.value
    .map(c => row.regions[String(c.id)]?.cost)
    .filter((v): v is number => v != null)
  if (values.length < 2) return false
  const mine = row.regions[String(colId)]?.cost
  if (mine == null) return false
  return mine <= Math.min(...values)
}

function formatPlanMetric(
  totals: PlanCostRow['regions'][string] | null,
  metric: { key: string },
): string {
  const v = (totals as any)?.[metric.key]
  if (v == null || !Number.isFinite(Number(v))) return '—'
  if (metric.key === 'cost') return formatMoney(Number(v), userCurrency.value)
  return String(Math.round(Number(v) * 10) / 10)
}

// ==================== 热力图 tab ====================
const heatmapMode = ref<'item' | 'overall'>('item')
const heatmapEntityType = ref<'ingredient' | 'product'>('ingredient')
const heatmapEntityId = ref<number | null>(null)
const heatmapEntityOptions = ref<Array<{ id: number; name: string }>>([])
const heatmapEntitySearching = ref(false)
const heatmapEntitySearch = ref('')
const heatmapData = ref<HeatmapResponse | null>(null)
const heatmapLoading = ref(false)
let heatmapEntitySearchSeq = 0
let heatmapEntitySearchTimer: ReturnType<typeof setTimeout> | null = null
let heatmapSeq = 0

// 单品模式的实体搜索：与原料·商品 tab 共用搜索实现，但独立状态（两 tab 可各自保留选择）
watch(heatmapEntitySearch, (kw) => {
  if (heatmapEntitySearchTimer) clearTimeout(heatmapEntitySearchTimer)
  const keyword = (kw || '').trim()
  heatmapEntitySearchTimer = setTimeout(() => {
    const seq = ++heatmapEntitySearchSeq
    heatmapEntitySearching.value = true
    const url = heatmapEntityType.value === 'ingredient' ? '/ingredients' : '/products/entity'
    const params: Record<string, any> = { limit: 20 }
    if (keyword) params.q = keyword
    api.get(url, { params }).then((res: any) => {
      if (seq !== heatmapEntitySearchSeq) return
      heatmapEntityOptions.value = (res.items || []).map((x: any) => ({ id: x.id, name: x.name }))
    }).catch(() => {
      if (seq === heatmapEntitySearchSeq) heatmapEntityOptions.value = []
    }).finally(() => {
      if (seq === heatmapEntitySearchSeq) heatmapEntitySearching.value = false
    })
  }, 300)
})

watch(heatmapEntityType, () => {
  heatmapEntityId.value = null
  heatmapEntityOptions.value = []
  heatmapEntitySearch.value = ''
  void fetchHeatmapEntityOptions('')
})

function fetchHeatmapEntityOptions(keyword: string) {
  const seq = ++heatmapEntitySearchSeq
  heatmapEntitySearching.value = true
  const url = heatmapEntityType.value === 'ingredient' ? '/ingredients' : '/products/entity'
  const params: Record<string, any> = { limit: 20 }
  if (keyword) params.q = keyword
  api.get(url, { params }).then((res: any) => {
    if (seq !== heatmapEntitySearchSeq) return
    heatmapEntityOptions.value = (res.items || []).map((x: any) => ({ id: x.id, name: x.name }))
  }).catch(() => {
    if (seq === heatmapEntitySearchSeq) heatmapEntityOptions.value = []
  }).finally(() => {
    if (seq === heatmapEntitySearchSeq) heatmapEntitySearching.value = false
  })
}

onMounted(() => { void fetchHeatmapEntityOptions('') })

// 取数：模式/地区/实体变化时重新拉（item 模式必须选了实体）
watch([heatmapMode, heatmapEntityType, heatmapEntityId, regionIds], async () => {
  heatmapData.value = null
  const rids = regionIds.value
  if (!rids.length) return
  if (heatmapMode.value === 'item' && heatmapEntityId.value == null) return
  const seq = ++heatmapSeq
  heatmapLoading.value = true
  try {
    const res = await getComparisonHeatmap(heatmapMode.value, rids, {
      entityType: heatmapEntityType.value,
      entityId: heatmapEntityId.value ?? undefined,
    })
    if (seq === heatmapSeq) heatmapData.value = res
  } catch { /* 静默 */ }
  finally {
    if (seq === heatmapSeq) heatmapLoading.value = false
  }
}, { immediate: true })

const heatmapItems = computed(() => heatmapData.value?.items || [])
const heatmapBuckets = computed(() => heatmapData.value?.buckets || null)
</script>

<style scoped>
.region-summary-card {
  overflow: hidden;
}
.region-summary-lowest {
  border-color: rgb(var(--v-theme-success));
}
</style>

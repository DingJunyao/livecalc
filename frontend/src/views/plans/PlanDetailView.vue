<template>
  <!-- 顶部导航栏 - 与其他页面统一（二级页面：返回箭头 + 标题为方案名） -->
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">
      {{ editor.name || (planId ? t('plans.title') : t('plans.newPlan')) }}
    </v-app-bar-title>
    <template #append>
      <CalcContextMenu />
      <template v-if="editor.id">
        <v-btn
          icon="mdi-clipboard-check-outline"
          variant="text"
          :loading="settingToday"
          :title="t('plans.setToday')"
          @click="onSetToday"
        />
        <v-btn
          icon="mdi-delete-outline"
          variant="text"
          color="error"
          @click="onDelete"
        />
      </template>
    </template>
  </v-app-bar>

  <v-container fluid class="pa-4">
    <div v-if="loading" class="py-8 text-center">
      <v-progress-circular indeterminate color="primary" />
    </div>

    <template v-else>
      <v-row dense class="mb-2">
        <v-col cols="12" sm="5">
          <v-text-field
            v-model="editor.name"
            :label="t('plans.planName')"
            variant="outlined"
            density="compact"
            hide-details
          />
        </v-col>
        <v-col cols="6" sm="3">
          <v-select
            v-model="editor.kind"
            :items="[
              { title: t('plans.kindMeal'), value: 'meal' },
              { title: t('plans.kindDay'), value: 'day' },
            ]"
            :label="t('plans.planKind')"
            variant="outlined"
            density="compact"
            hide-details
          />
        </v-col>
        <v-col cols="6" sm="4" class="d-flex align-center ga-2">
          <v-btn color="primary" :loading="saving" :disabled="!editor.name" @click="onSave">
            {{ t('common.save') }}
          </v-btn>
          <v-btn variant="text" @click="goBack">{{ t('common.cancel') }}</v-btn>
        </v-col>
      </v-row>

      <!-- 添加条目：三类搜索 -->
      <v-row dense>
        <v-col cols="12" md="4">
          <v-autocomplete
            v-model="recipePick"
            :items="recipeOptions"
            :loading="recipeSearchLoading"
            :label="t('plans.addRecipe')"
            variant="outlined"
            density="compact"
            hide-details
            clearable
            v-model:search="recipeSearch"
            :custom-filter="() => true"
          />
        </v-col>
        <v-col cols="12" md="4">
          <v-autocomplete
            v-model="ingredientPick"
            :items="ingredientOptions"
            :loading="ingredientSearchLoading"
            :label="t('plans.addIngredient')"
            variant="outlined"
            density="compact"
            hide-details
            clearable
            v-model:search="ingredientSearch"
            :custom-filter="() => true"
          />
        </v-col>
        <v-col cols="12" md="4">
          <v-autocomplete
            v-model="productPick"
            :items="productOptions"
            :loading="productSearchLoading"
            :label="t('plans.addProduct')"
            variant="outlined"
            density="compact"
            hide-details
            clearable
            v-model:search="productSearch"
            :custom-filter="() => true"
          />
        </v-col>
      </v-row>

      <!-- 条目：宽屏多列（样式对齐原料详情的扁平卡片）；点卡片进对应详情 -->
      <v-row dense class="mb-2">
        <v-col v-for="(item, idx) in editor.items" :key="idx" cols="12" sm="6" md="4" lg="3">
          <v-card
            elevation="0"
            class="h-100 d-flex flex-column plan-item-card"
            :class="{ 'plan-item-card--link': !!itemLink(item) }"
            @click="openItem(item)"
          >
            <v-card-title class="d-flex align-center ga-2 py-2">
              <v-chip size="x-small" :color="typeColor(item.item_type)" variant="tonal">
                {{ typeLabel(item.item_type) }}
              </v-chip>
              <span class="text-body-2 font-weight-medium text-truncate">{{ item.name || '…' }}</span>
              <v-spacer />
              <v-icon v-if="itemLink(item)" size="small" color="medium-emphasis">mdi-chevron-right</v-icon>
            </v-card-title>
            <v-divider />
            <v-card-text class="d-flex flex-wrap align-center py-2 text-caption text-medium-emphasis" style="gap: 6px 10px" @click.stop>
              <v-select
                v-if="editor.kind === 'day'"
                v-model="item.group"
                :items="groupItems"
                density="compact"
                hide-details
                variant="plain"
                style="max-width: 96px"
              />
              <template v-if="item.item_type === 'recipe'">
                {{ t('plans.servings') }}
                <v-number-input
                  v-model="item.servings"
                  :min="0.5"
                  :step="0.5"
                  control-variant="hidden"
                  density="compact"
                  hide-details
                  inline
                  style="width: 96px"
                />
              </template>
              <template v-else>
                {{ t('plans.quantity') }}
                <v-number-input
                  v-model="item.quantity"
                  :min="0"
                  :step="10"
                  control-variant="hidden"
                  density="compact"
                  hide-details
                  inline
                  style="width: 110px"
                />
                <v-select
                  v-model="item.unit_id"
                  :items="unitOptions"
                  :placeholder="defaultUnitHint(idx)"
                  density="compact"
                  hide-details
                  variant="plain"
                  clearable
                  style="width: 150px"
                />
              </template>
            </v-card-text>
            <v-spacer />
            <v-card-actions class="pt-0">
              <span class="text-caption text-medium-emphasis">{{ perItemCost(idx) }}</span>
              <v-spacer />
              <v-btn icon="mdi-close" size="small" variant="text" @click.stop="editor.items.splice(idx, 1)" />
            </v-card-actions>
          </v-card>
        </v-col>
        <v-col v-if="editor.items.length === 0" cols="12">
          <div class="text-body-2 text-medium-emphasis py-2">{{ t('plans.noItems') }}</div>
        </v-col>
      </v-row>

      <!-- 合计 vs 目标 -->
      <v-card v-if="evaluation" elevation="0" class="mb-4 pa-3">
        <div class="text-subtitle-2 mb-2">{{ t('plans.totals') }}</div>
        <v-row dense>
          <v-col v-for="row in totalsRows" :key="row.key" cols="6" sm="3">
            <div class="text-caption text-medium-emphasis">{{ row.label }}</div>
            <div class="text-body-1 font-weight-bold" :class="row.over ? 'text-error' : 'text-success'">
              {{ row.value }}
            </div>
            <div class="text-caption text-disabled">
              {{ t('plans.target') }} {{ row.target }}
            </div>
          </v-col>
        </v-row>
      </v-card>

      <!-- 方案里没有可算营养的条目（例如商品没维护营养）时给明确提示 -->
      <v-alert
        v-if="evaluation && !evaluation.nutrition?.per_serving_nutrition"
        type="info"
        variant="tonal"
        density="compact"
        class="mb-4"
      >
        {{ t('recipes.noNutritionData') }}
      </v-alert>

      <!-- 宽屏：成本构成 | 成本走势（含价格区间） 左右分列 -->
      <v-row no-gutters>
        <v-col cols="12" md="6">
          <CostProportionChart
            v-if="evaluation && costBreakdown.length"
            :cost-breakdown="costBreakdown"
            :total-cost="evaluation.totals.cost"
          />
        </v-col>
        <v-col cols="12" md="6">
          <!-- 成本走势：与「食材成本占比」同一套卡片样式（复用菜谱详情的图表，自带价格区间） -->
          <CostTrendAnalysis
            v-if="editor.id"
            :recipe-id="editor.id"
            :cost-history="trendPoints"
            :loading="trendLoading"
            @filter-change="onTrendFilterChange"
          />
        </v-col>
      </v-row>

      <!-- 营养成分（全部营养素 + NRV%）| 营养来源（贡献环形图）：宽屏 1:3 分栏，窄屏纵向堆叠 -->
      <v-row no-gutters>
        <v-col cols="12" md="3">
        <!-- 营养成分（全部营养素 + NRV%） -->
        <v-card v-if="nutrientRows.length" elevation="0" class="ma-4">
          <v-card-title class="d-flex align-center pb-2">
            <v-icon start color="success">mdi-food-apple-outline</v-icon>
            {{ t('plans.nutrition') }}
          </v-card-title>
          <v-divider />
          <v-card-text class="pa-0">
            <div class="d-flex py-2 border-bottom">
              <div class="text-caption text-medium-emphasis ps-4 flex-grow-1">{{ t('recipes.nutrient') }}</div>
              <div class="text-caption text-medium-emphasis text-end pe-4" style="min-width: 100px">{{ t('recipes.amount') }}</div>
              <div class="text-caption text-medium-emphasis text-end pe-4" style="min-width: 64px">{{ t('recipes.nrvPercent') }}</div>
            </div>
            <div
              v-for="(row, i) in nutrientRows"
              :key="row.key"
              class="d-flex py-2"
              :class="{ 'border-bottom': i !== nutrientRows.length - 1 }"
            >
              <div class="text-body-2 ps-4 flex-grow-1">{{ row.label }}</div>
              <div class="text-body-2 text-end pe-4" style="min-width: 100px">{{ row.amount }}</div>
              <div class="text-body-2 text-end pe-4" style="min-width: 64px">{{ row.nrv != null ? `${row.nrv}%` : '-' }}</div>
            </div>
            <div class="mt-3 mb-3 text-caption text-medium-emphasis ps-4">
              {{ t('recipes.nrvExplanation') }}
            </div>
          </v-card-text>
        </v-card>

        </v-col>
        <v-col cols="12" md="9">
          <NutritionSourceGrid
            v-if="evaluation?.nutrition?.per_serving_nutrition"
            :nutrition-data="evaluation.nutrition"
          />
        </v-col>
      </v-row>

    </template>
  </v-container>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import { useDisplay } from 'vuetify'
import CalcContextMenu from '@/components/layout/CalcContextMenu.vue'
import CostProportionChart from '@/components/recipes/CostProportionChart.vue'
import CostTrendAnalysis from '@/components/recipes/CostTrendAnalysis.vue'
import NutritionSourceGrid from '@/components/recipes/NutritionSourceGrid.vue'
import { api } from '@/api'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useConfirmDialog } from '@/composables/useConfirmDialog'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { useUserUnits } from '@/composables/useUserUnits'
import { useLocaleStore } from '@/stores/locale'
import { formatMoney } from '@/utils/currency'
import { formatNumber } from '@/utils/format'
import {
  getPlan, createPlan, updatePlan, deletePlan,
  evaluatePlan, getPlanCostTrend, setPlanAsRecommendation,
  type PlanKind, type PlanItemInput, type PlanEvaluation, type PlanItemType,
} from '@/api/mealPlans'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const { mdAndUp } = useDisplay()
const isDesktop = computed(() => mdAndUp.value)
const { toggleSidebar } = useMobileDrawerControl()
const { ask } = useConfirmDialog()
const { notify } = useGlobalSnackbar()
const { currency: userCurrency } = useUserCurrency()
const { energyUnit, toDisplayCalorie } = useUserUnits()
const localeStore = useLocaleStore()

/** /plans/new → null（新增）；/plans/:id → 数字 id */
const planId = computed<number | null>(() => {
  const raw = route.params.id
  const value = Number(Array.isArray(raw) ? raw[0] : raw)
  return Number.isFinite(value) && value > 0 ? value : null
})

const loading = ref(false)
const saving = ref(false)
const settingToday = ref(false)
const evaluation = ref<PlanEvaluation | null>(null)
/** 成本走势数据（交给 CostTrendAnalysis 渲染：平均线 + 价格区间带） */
const trendPoints = ref<any[]>([])
const trendLoading = ref(false)
/** 单位下拉（方案条目的数量单位，value 用 unit_id —— 与后端 meal_plan_items.unit_id 对齐） */
const unitOptions = ref<{ title: string; value: number }[]>([])
/** /units/ 原始行：用于「单位名 / 缩写 → unit_id」解析（默认单位要显式落库，不能只留空） */
const unitRows = ref<any[]>([])

function unitIdByName(name: string | null | undefined): number | null {
  if (!name) return null
  const hit = unitRows.value.find((u: any) => u.name === name || u.abbreviation === name)
  return hit?.id != null ? Number(hit.id) : null
}

/**
 * 未选单位的原料/商品条目：把后端**实际生效**的单位显式写进 unit_id。
 * 后端口径：原料无单位 → 克；商品无单位 → 该商品价格记录的标准单位（见 evaluate 的 items[].unit）。
 * 显式存下来，界面下拉就会选中它，保存/求值也走同一个 unit_id。
 */
function backfillDefaultUnits() {
  const effective = evaluation.value?.items || []
  editor.value.items.forEach((item, idx) => {
    if (item.item_type === 'recipe' || item.unit_id != null) return
    const id = unitIdByName(effective[idx]?.unit || 'g')
    if (id != null) item.unit_id = id
  })
}

const editor = ref<{
  id: number | null
  name: string
  kind: PlanKind
  items: (PlanItemInput & { name?: string | null })[]
}>({ id: null, name: '', kind: 'meal', items: [] })

const groupItems = computed(() => [
  { title: t('meals.breakfast'), value: 'breakfast' },
  { title: t('meals.lunch'), value: 'lunch' },
  { title: t('meals.dinner'), value: 'dinner' },
  { title: t('plans.groupOther'), value: 'other' },
])

// ---- 搜索（三类） ----
const recipePick = ref<number | null>(null)
const ingredientPick = ref<number | null>(null)
const productPick = ref<number | null>(null)
const recipeOptions = ref<{ title: string; value: number }[]>([])
const ingredientOptions = ref<{ title: string; value: number }[]>([])
const productOptions = ref<{ title: string; value: number }[]>([])
const recipeSearch = ref('')
const ingredientSearch = ref('')
const productSearch = ref('')
const recipeSearchLoading = ref(false)
const ingredientSearchLoading = ref(false)
const productSearchLoading = ref(false)

let searchTimer: ReturnType<typeof setTimeout> | null = null
function debounceSearch(kind: 'recipe' | 'ingredient' | 'product', kw: string) {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => doSearch(kind, kw), 300)
}

async function doSearch(kind: 'recipe' | 'ingredient' | 'product', kw: string) {
  if (!kw || kw.length < 1) return
  try {
    if (kind === 'recipe') {
      recipeSearchLoading.value = true
      const res: any = await api.get('/recipes', { params: { search: kw, limit: 20 } })
      recipeOptions.value = (res.items || []).map((r: any) => ({ title: r.name, value: r.id }))
    } else if (kind === 'ingredient') {
      ingredientSearchLoading.value = true
      const res: any = await api.get('/ingredients', { params: { q: kw, limit: 20 } })
      ingredientOptions.value = (res.items || []).map((r: any) => ({ title: r.name, value: r.id }))
    } else {
      productSearchLoading.value = true
      const res: any = await api.get('/products/entity', { params: { search: kw, limit: 20 } })
      productOptions.value = (res.items || []).map((r: any) => ({ title: r.name, value: r.id }))
    }
  } catch { /* 搜索失败静默 */ } finally {
    if (kind === 'recipe') recipeSearchLoading.value = false
    else if (kind === 'ingredient') ingredientSearchLoading.value = false
    else productSearchLoading.value = false
  }
}

watch(recipeSearch, (v) => debounceSearch('recipe', v))
watch(ingredientSearch, (v) => debounceSearch('ingredient', v))
watch(productSearch, (v) => debounceSearch('product', v))

function onPick(type: PlanItemType, id: number | null, options: { title: string; value: number }[]) {
  if (id == null) return
  addItem(type, id, options.find(o => o.value === id)?.title ?? '')
}

watch(recipePick, (id) => { onPick('recipe', id, recipeOptions.value); recipePick.value = null })
watch(ingredientPick, (id) => { onPick('ingredient', id, ingredientOptions.value); ingredientPick.value = null })
watch(productPick, (id) => { onPick('product', id, productOptions.value); productPick.value = null })

function addItem(type: PlanItemType, id: number, name: string) {
  editor.value.items.push({
    group: editor.value.kind === 'day' ? 'other' : 'dinner',
    item_type: type,
    recipe_id: type === 'recipe' ? id ?? null : null,
    ingredient_id: type === 'ingredient' ? id ?? null : null,
    product_id: type === 'product' ? id ?? null : null,
    servings: type === 'recipe' ? 1 : null,
    quantity: type === 'recipe' ? null : 100,
    unit_id: null,
    sort_order: editor.value.items.length,
    name,
  })
  void evaluateDraft()
}

// ---- 条目类型标签与颜色 ----
function typeLabel(type: PlanItemType) {
  if (type === 'recipe') return t('plans.typeRecipe')
  if (type === 'ingredient') return t('plans.typeIngredient')
  return t('plans.typeProduct')
}

function typeColor(type: PlanItemType) {
  if (type === 'recipe') return 'primary'
  if (type === 'ingredient') return 'success'
  return 'tertiary'
}

// ---- 求值 ----
// 一顿（meal）方案的目标按条目分组对应的餐次比例算（group=other 时退回午餐）；
// 一日（day）方案后端按整天算，meal_type 不参与。
const evalMealType = computed<'breakfast' | 'lunch' | 'dinner'>(() => {
  const g = editor.value.items[0]?.group
  return g === 'breakfast' || g === 'dinner' ? g : 'lunch'
})

// 注意 kind 也要进依赖：切换「一顿 / 一日」会同时改变合计口径与目标比例
watch(() => JSON.stringify({
  kind: editor.value.kind,
  items: editor.value.items.map(i => ({
    g: i.group, t: i.item_type, r: i.recipe_id, i2: i.ingredient_id, p: i.product_id,
    s: i.servings, q: i.quantity,
  })),
}), () => void evaluateDraft())

async function evaluateDraft() {
  if (editor.value.items.length === 0) {
    evaluation.value = null
    return
  }
  try {
    evaluation.value = await evaluatePlan({
      kind: editor.value.kind,
      meal_type: evalMealType.value,
      items: editor.value.items.map((i, idx) => ({
        group: i.group as any, item_type: i.item_type,
        recipe_id: i.recipe_id, ingredient_id: i.ingredient_id, product_id: i.product_id,
        servings: i.servings, quantity: i.quantity, unit_id: i.unit_id, sort_order: idx,
      })),
    })
  } catch { /* 求值失败静默，保留上次结果 */ }
  // 拿到「实际生效单位」后立刻显式落库（首次加载 / 刚加入条目）
  backfillDefaultUnits()
}

/** 条目 → 对应实体详情页 */
function itemLink(item: PlanItemInput) {
  if (item.item_type === 'recipe' && item.recipe_id) return `/recipes/${item.recipe_id}`
  if (item.item_type === 'ingredient' && item.ingredient_id) return `/data/ingredients/${item.ingredient_id}`
  if (item.item_type === 'product' && item.product_id) return `/data/products/${item.product_id}`
  return null
}

function openItem(item: PlanItemInput) {
  const link = itemLink(item)
  if (link) void router.push(link)
}

/** 未选单位时后端实际用的单位：原料回退「克」，商品用价格记录的标准单位（来自 evaluate 的 items[].unit） */
function defaultUnitHint(idx: number) {
  const unit = evaluation.value?.items?.[idx]?.unit
  return unit ? `${t('plans.defaultUnit')}（${unit}）` : t('plans.defaultUnit')
}

function perItemCost(idx: number) {
  const info = evaluation.value?.items?.[idx]
  if (!info || info.cost == null) return '--'
  return formatMoney(info.cost, info.currency || userCurrency.value)
}

/** 营养素表顺序（英文 key，与菜谱详情 / 营养来源组件一致） */
const NUTRIENT_ORDER = [
  'energy', 'protein', 'fat', 'carbohydrate', 'sodium', 'fiber', 'calcium', 'iron',
  'potassium', 'vitamin_a_rae', 'vitamin_b1', 'vitamin_b2', 'vitamin_b12', 'vitamin_c',
  'vitamin_d', 'vitamin_e', 'vitamin_k',
]

/** 全部营养素（含量 + NRV%），来自 evaluate 的 nutrition.per_serving_nutrition.core_nutrients */
const nutrientRows = computed(() => {
  const core = evaluation.value?.nutrition?.per_serving_nutrition?.core_nutrients || {}
  return Object.entries(core)
    .filter(([, v]) => v && v.value != null && Number(v.value) !== 0)
    .map(([label, v]) => ({
      key: v.key || label,
      label,
      amount: `${formatNumber(v.value, localeStore.effectiveFormatLocale, { maximumFractionDigits: 2 })}${v.unit ? ` ${v.unit}` : ''}`,
      nrv: v.nrp_pct != null ? Math.round(v.nrp_pct) : null,
    }))
    .sort((a, b) => {
      const ia = NUTRIENT_ORDER.indexOf(a.key)
      const ib = NUTRIENT_ORDER.indexOf(b.key)
      return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib)
    })
})

/** 各条目成本 →「食材成本占比」组件（{ingredient_id, ingredient_name, cost}） */
const costBreakdown = computed(() => (evaluation.value?.items || [])
  .map((info, idx) => ({
    ingredient_id: info.item_id ?? idx + 1,
    ingredient_name: info.name || '',
    cost: info.cost,
  }))
  .filter((b): b is { ingredient_id: number; ingredient_name: string; cost: number } =>
    b.cost != null && b.cost > 0))

const totalsRows = computed(() => {
  const ev = evaluation.value
  if (!ev) return []
  const n = ev.totals
  const tg = ev.targets
  return [
    { key: 'cost', label: t('plans.totalCost'),
      value: formatMoney(n.cost, n.currency || userCurrency.value),
      target: tg.cost != null ? formatMoney(tg.cost, n.currency || userCurrency.value) : '--',
      over: tg.cost != null && n.cost > tg.cost },
    { key: 'calories', label: t('plans.calories'),
      value: `${formatNumber(toDisplayCalorie(n.calories), localeStore.effectiveFormatLocale)} ${energyUnit.value}`,
      target: `${formatNumber(toDisplayCalorie(tg.calories), localeStore.effectiveFormatLocale)} ${energyUnit.value}`,
      over: n.calories > tg.calories },
    { key: 'protein', label: t('plans.protein'),
      value: `${formatNumber(n.protein_g, localeStore.effectiveFormatLocale, { maximumFractionDigits: 1 })} ${t('nutrientUnits.g')}`,
      target: `${formatNumber(tg.protein_g, localeStore.effectiveFormatLocale, { maximumFractionDigits: 1 })} ${t('nutrientUnits.g')}`,
      over: n.protein_g > tg.protein_g },
    { key: 'fat', label: t('plans.fat'),
      value: `${formatNumber(n.fat_g, localeStore.effectiveFormatLocale, { maximumFractionDigits: 1 })} ${t('nutrientUnits.g')}`,
      target: `${formatNumber(tg.fat_g, localeStore.effectiveFormatLocale, { maximumFractionDigits: 1 })} ${t('nutrientUnits.g')}`,
      over: n.fat_g > tg.fat_g },
  ]
})

// ---- 加载 / 保存 / 删除 ----
function resetEditor() {
  editor.value = { id: null, name: '', kind: 'meal', items: [] }
  evaluation.value = null
  trendChart?.dispose()
  trendChart = null
}

async function loadPlan() {
  const id = planId.value
  if (!id) {
    resetEditor()
    // 今日推荐「拿去试算」带来的草稿
    const draft = sessionStorage.getItem('planDraft')
    if (draft) {
      sessionStorage.removeItem('planDraft')
      try {
        const parsed = JSON.parse(draft)
        editor.value = {
          id: null, name: parsed.name || '', kind: parsed.kind || 'meal',
          items: parsed.items || [],
        }
      } catch { /* 草稿解析失败忽略 */ }
    }
    void evaluateDraft()
    return
  }
  loading.value = true
  try {
    const plan = await getPlan(id)
    editor.value = {
      id: plan.id, name: plan.name, kind: plan.kind,
      items: plan.items.map(i => ({
        group: i.group, item_type: i.item_type,
        recipe_id: i.recipe_id, ingredient_id: i.ingredient_id, product_id: i.product_id,
        servings: i.servings, quantity: i.quantity, unit_id: i.unit_id,
        sort_order: i.sort_order, note: i.note, name: i.name,
      })),
    }
  } catch (e: any) {
    notify(e.userMessage || t('plans.loadFailed'), 'error')
    void router.replace('/plans')
    return
  } finally {
    loading.value = false
  }
  // loading 落下后 v-if 才渲染出内容（含图表容器），此时再求值 / 画图
  await nextTick()
  void evaluateDraft()
  void loadTrend()
}

function goBack() {
  void router.push('/plans')
}

async function onSave() {
  saving.value = true
  try {
    const body = {
      name: editor.value.name,
      kind: editor.value.kind,
      items: editor.value.items.map((i, idx) => ({
        group: i.group as any, item_type: i.item_type,
        recipe_id: i.recipe_id, ingredient_id: i.ingredient_id, product_id: i.product_id,
        servings: i.servings, quantity: i.quantity, unit_id: i.unit_id,
        sort_order: idx, note: i.note ?? null,
      })),
    }
    if (editor.value.id) {
      await updatePlan(editor.value.id, body)
      notify(t('plans.saved'), 'success')
      await nextTick()
      void loadTrend()
    } else {
      const created = await createPlan(body)
      notify(t('plans.saved'), 'success')
      // 新建成功后换成详情地址：刷新 / 分享都落在同一个方案上
      await router.replace(`/plans/${created.id}`)
    }
  } catch (e: any) {
    notify(e.userMessage || t('plans.saveFailed'), 'error')
  } finally {
    saving.value = false
  }
}

async function onDelete() {
  const name = editor.value.name || ''
  const ok = await ask({
    text: t('plans.deleteConfirm', { name }),
    color: 'error',
  })
  if (!ok || !editor.value.id) return
  try {
    await deletePlan(editor.value.id)
    notify(t('plans.deleted'), 'info')
    await router.push('/plans')
  } catch (e: any) {
    notify(e.userMessage || t('plans.deleteFailed'), 'error')
  }
}

async function onSetToday() {
  if (!editor.value.id) return
  settingToday.value = true
  try {
    await setPlanAsRecommendation(editor.value.id)
    notify(t('plans.setTodayDone', { name: editor.value.name }), 'success')
  } catch (e: any) {
    notify(e.userMessage || t('plans.setTodayFailed'), 'error')
  } finally {
    settingToday.value = false
  }
}

// ---- 成本走势 ----
const TREND_FILTER_DAYS: Record<string, number> = {
  week: 7, month: 30, quarter: 90, year: 365, all: 3650,
}

async function loadTrend(days = 90) {
  if (!editor.value.id) {
    trendPoints.value = []
    return
  }
  trendLoading.value = true
  try {
    trendPoints.value = await getPlanCostTrend(editor.value.id, days)
  } catch {
    trendPoints.value = []
  } finally {
    trendLoading.value = false
  }
}

function onTrendFilterChange(filter: string) {
  void loadTrend(TREND_FILTER_DAYS[filter] ?? 90)
}

// 方案 id 变化（载入 / 新建保存后 replace）→ 重新拉趋势
watch(() => editor.value.id, () => void loadTrend())

/** 单位下拉：全局启用单位（value 用 unit_id）+ 实体自定义单位（若带 id） */
async function loadUnitOptions() {
  if (unitOptions.value.length) return
  try {
    const res: any = await api.get('/units/', { params: { limit: 500 } })
    const rows = (Array.isArray(res) ? res : (res?.items || []))
      .filter((u: any) => u?.is_active !== false && u?.id != null)
    unitRows.value = rows
    unitOptions.value = rows.map((u: any) => ({ title: `${u.name} (${u.abbreviation})`, value: Number(u.id) }))
    backfillDefaultUnits()
  } catch {
    // 拉不到就保持默认单位（原料按克 / 商品按记录单位）
  }
}

onMounted(() => {
  void loadPlan()
  void loadUnitOptions()
})

// 同一路由内换方案（列表点进另一个方案 / 新建后 replace 成 :id）也要重新载入
watch(() => route.fullPath, () => {
  if (route.name === 'plan-detail' || route.name === 'plan-new') void loadPlan()
})

onUnmounted(() => {
  // 无本地图表实例需要释放（趋势由 CostTrendAnalysis 自管）
})
</script>

<style scoped>
.plan-item-card {
  background: rgb(var(--v-theme-surface));
}

.plan-item-card--link {
  cursor: pointer;
}
</style>

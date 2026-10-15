<template>
  <!-- 顶部导航栏 - 与其他页面统一 -->
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-app-bar-title class="text-h6">{{ t('plans.title') }}</v-app-bar-title>
    <template #append>
      <CalcContextMenu />
      <v-btn
        icon="mdi-plus"
        variant="text"
        :title="t('plans.newPlan')"
        @click="startNew"
      />
    </template>
  </v-app-bar>

  <v-container fluid class="pa-4">
    <v-row v-if="!editing">
      <!-- 方案列表 -->
      <v-col cols="12">
        <v-alert v-if="error" type="error" class="mb-4" density="compact">
          {{ error }}
        </v-alert>

        <div v-if="loading" class="py-8 text-center">
          <v-progress-circular indeterminate color="primary" />
        </div>

        <template v-else>
          <v-row>
            <v-col v-for="plan in plans" :key="plan.id" cols="12" sm="6" md="4">
              <v-card elevation="1" rounded="lg">
                <v-card-item>
                  <v-card-title class="text-body-1 d-flex align-center ga-2">
                    {{ plan.name }}
                    <v-chip size="x-small" :color="plan.kind === 'day' ? 'tertiary' : 'primary'" variant="tonal">
                      {{ plan.kind === 'day' ? t('plans.kindDay') : t('plans.kindMeal') }}
                    </v-chip>
                  </v-card-title>
                  <v-card-subtitle>
                    {{ t('plans.itemCount', { count: plan.items.length }) }}
                  </v-card-subtitle>
                </v-card-item>
                <v-card-actions>
                  <v-btn size="small" variant="text" color="primary" @click="openEditor(plan.id)">
                    {{ t('plans.edit') }}
                  </v-btn>
                  <v-btn
                    size="small"
                    variant="text"
                    :color="plan.kind === 'day' ? 'tertiary' : 'primary'"
                    :loading="settingPlan === plan.id"
                    @click="onSetToday(plan)"
                  >
                    {{ t('plans.setToday') }}
                  </v-btn>
                  <v-spacer />
                  <v-btn
                    icon="mdi-delete-outline"
                    size="small"
                    variant="text"
                    color="error"
                    @click="onDelete(plan)"
                  />
                </v-card-actions>
              </v-card>
            </v-col>
            <v-col v-if="plans.length === 0" cols="12">
              <div class="text-center py-16 text-medium-emphasis">
                <v-icon size="64" color="medium-emphasis">mdi-clipboard-text-outline</v-icon>
                <div class="text-h6 mt-4">{{ t('plans.empty') }}</div>
                <v-btn class="mt-3" variant="tonal" color="primary" @click="startNew">
                  {{ t('plans.newPlan') }}
                </v-btn>
              </div>
            </v-col>
          </v-row>
        </template>
      </v-col>
    </v-row>

    <!-- 编辑器 -->
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
          <v-btn variant="text" @click="closeEditor">{{ t('common.cancel') }}</v-btn>
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
            :search="recipeSearch"
            @update:search="v => searchRecipes(v)"
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
            :search="ingredientSearch"
            @update:search="v => searchIngredients(v)"
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
            :search="productSearch"
            @update:search="v => searchProducts(v)"
          />
        </v-col>
      </v-row>

      <!-- 条目表 -->
      <v-list density="compact" class="mb-2 pa-0" lines="two">
        <v-list-item v-for="(item, idx) in editor.items" :key="idx">
          <template #prepend>
            <v-chip size="x-small" :color="typeColor(item.item_type)" variant="tonal">
              {{ typeLabel(item.item_type) }}
            </v-chip>
            <v-select
              v-if="editor.kind === 'day'"
              v-model="item.group"
              :items="groupItems"
              density="compact"
              hide-details
              variant="plain"
              style="max-width: 90px"
            />
          </template>
          <v-list-item-title>{{ item.name || '…' }}</v-list-item-title>
          <v-list-item-subtitle>
            <template v-if="item.item_type === 'recipe'">
              {{ t('plans.servings') }}
              <v-number-input
                v-model="item.servings"
                :min="0.5"
                :step="0.5"
                control-variant="stack"
                density="compact"
                hide-details
                inline
                style="max-width: 130px"
                class="ms-1"
              />
            </template>
            <template v-else>
              {{ t('plans.quantity') }}
              <v-number-input
                v-model="item.quantity"
                :min="0"
                :step="10"
                control-variant="stack"
                density="compact"
                hide-details
                inline
                style="max-width: 130px"
                class="ms-1"
              />
            </template>
          </v-list-item-subtitle>
          <template #append>
            <span v-if="evaluation?.items?.[idx]" class="text-caption text-medium-emphasis me-2">
              {{ evaluation.items[idx].cost != null ? formatMoney(evaluation.items[idx].cost, evaluation.items[idx].currency || userCurrency) : '--' }}
            </span>
            <v-btn icon="mdi-close" size="small" variant="text" @click="editor.items.splice(idx, 1)" />
          </template>
        </v-list-item>
        <v-list-item v-if="editor.items.length === 0">
          <v-list-item-title class="text-medium-emphasis text-body-2">
            {{ t('plans.noItems') }}
          </v-list-item-title>
        </v-list-item>
      </v-list>

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

      <!-- 成本趋势（已保存方案） -->
      <v-card v-if="editor.id" elevation="0" class="mb-4 pa-3">
        <div class="d-flex align-center mb-2">
          <div class="text-subtitle-2">{{ t('plans.costTrend') }}</div>
          <v-spacer />
          <v-btn-toggle v-model="trendDays" density="compact" variant="tonal">
            <v-btn :value="30">30{{ t('plans.days') }}</v-btn>
            <v-btn :value="90">90{{ t('plans.days') }}</v-btn>
            <v-btn :value="365">365{{ t('plans.days') }}</v-btn>
          </v-btn-toggle>
        </div>
        <div ref="trendCanvas" style="height: 260px" />
      </v-card>
    </template>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" timeout="3000">
      {{ snackbar.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref, watch, nextTick } from 'vue'
import { useI18n } from 'vue-i18n'
import { useDisplay } from 'vuetify'
import * as echarts from 'echarts'
import CalcContextMenu from '@/components/layout/CalcContextMenu.vue'
import { api } from '@/api'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { useUserUnits } from '@/composables/useUserUnits'
import { formatMoney } from '@/utils/currency'
import { formatNumber } from '@/utils/format'
import {
  listPlans, getPlan, createPlan, updatePlan, deletePlan,
  evaluatePlan, getPlanCostTrend, setPlanAsRecommendation,
  type MealPlan, type PlanKind, type PlanItemInput, type PlanEvaluation,
  type PlanItemType,
} from '@/api/mealPlans'

const { t } = useI18n()
const { mdAndUp } = useDisplay()
const isDesktop = computed(() => mdAndUp.value)
const { toggleSidebar } = useMobileDrawerControl()
const { notify } = useGlobalSnackbar()
const { currency: userCurrency } = useUserCurrency()
const { energyUnit, toDisplayCalorie } = useUserUnits()

const plans = ref<MealPlan[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const editing = ref(false)
const saving = ref(false)
const settingPlan = ref<number | null>(null)
const evaluation = ref<PlanEvaluation | null>(null)
const trendDays = ref(90)
const trendCanvas = ref<HTMLElement | null>(null)
let trendChart: echarts.ECharts | null = null

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

const snackbar = reactive({ show: false, message: '', color: 'info' })

function notifyMsg(message: string, color = 'info') {
  snackbar.message = message
  snackbar.color = color
  snackbar.show = true
}

// ---- 搜索（三类） ----
const recipePick = ref<{ title: string; value: number } | null>(null)
const ingredientPick = ref<{ title: string; value: number } | null>(null)
const productPick = ref<{ title: string; value: number } | null>(null)
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

watch(recipePick, (pick) => {
  if (pick) addItem('recipe', pick.value, pick.title)
  recipePick.value = null
})
watch(ingredientPick, (pick) => {
  if (pick) addItem('ingredient', pick.value, pick.title)
  ingredientPick.value = null
})
watch(productPick, (pick) => {
  if (pick) addItem('product', pick.value, pick.title)
  productPick.value = null
})

function addItem(type: PlanItemType, id: number, name: string) {
  editor.value.items.push({
    group: editor.value.kind === 'day' ? 'other' : 'dinner',
    item_type: type,
    recipe_id: type === 'recipe' ? id : null,
    ingredient_id: type === 'ingredient' ? id : null,
    product_id: type === 'product' ? id : null,
    servings: type === 'recipe' ? 1 : null,
    quantity: type === 'recipe' ? null : 100,
    unit_id: null,
    sort_order: editor.value.items.length,
    name,
  })
  void evaluateDraft()
}

// ---- 求值 ----
watch(() => JSON.stringify(editor.value.items.map(i => ({
  g: i.group, t: i.item_type, r: i.recipe_id, i2: i.ingredient_id, p: i.product_id,
  s: i.servings, q: i.quantity,
}))), () => void evaluateDraft())

async function evaluateDraft() {
  if (editor.value.items.length === 0) {
    evaluation.value = null
    return
  }
  try {
    evaluation.value = await evaluatePlan({
      kind: editor.value.kind,
      meal_type: 'lunch',
      items: editor.value.items.map((i, idx) => ({
        group: i.group as any, item_type: i.item_type,
        recipe_id: i.recipe_id, ingredient_id: i.ingredient_id, product_id: i.product_id,
        servings: i.servings, quantity: i.quantity, unit_id: i.unit_id, sort_order: idx,
      })),
    })
  } catch { /* 求值失败静默，保留上次结果 */ }
}

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
      value: `${formatNumber(toDisplayCalorie(n.calories))} ${energyUnit.value}`,
      target: `${formatNumber(toDisplayCalorie(tg.calories))} ${energyUnit.value}`,
      over: n.calories > tg.calories },
    { key: 'protein', label: t('plans.protein'),
      value: `${formatNumber(n.protein_g, { maximumFractionDigits: 1 })} g`,
      target: `${formatNumber(tg.protein_g, { maximumFractionDigits: 1 })} g`,
      over: n.protein_g > tg.protein_g },
    { key: 'fat', label: t('plans.fat'),
      value: `${formatNumber(n.fat_g, { maximumFractionDigits: 1 })} g`,
      target: `${formatNumber(tg.fat_g, { maximumFractionDigits: 1 })} g`,
      over: n.fat_g > tg.fat_g },
  ]
})

// ---- 列表与编辑 ----
async function loadPlans() {
  loading.value = true
  error.value = null
  try {
    plans.value = (await listPlans()).items || []
  } catch (e: any) {
    error.value = e.userMessage || t('plans.loadFailed')
  } finally {
    loading.value = false
  }
}

function startNew() {
  editor.value = { id: null, name: '', kind: 'meal', items: [] }
  evaluation.value = null
  editing.value = true
  draftConsumed.value = false
}

async function openEditor(id: number) {
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
    editing.value = true
    await nextTick()
    void evaluateDraft()
    void renderTrend()
  } catch (e: any) {
    notifyMsg(e.userMessage || t('plans.loadFailed'), 'error')
  }
}

function closeEditor() {
  editing.value = false
  editor.value = { id: null, name: '', kind: 'meal', items: [] }
  evaluation.value = null
  trendChart?.dispose()
  trendChart = null
  void loadPlans()
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
    } else {
      const created = await createPlan(body)
      editor.value.id = created.id
    }
    notifyMsg(t('plans.saved'), 'success')
    await nextTick()
    void renderTrend()
  } catch (e: any) {
    notifyMsg(e.userMessage || t('plans.saveFailed'), 'error')
  } finally {
    saving.value = false
  }
}

async function onDelete(plan: MealPlan) {
  try {
    await deletePlan(plan.id)
    plans.value = plans.value.filter(p => p.id !== plan.id)
    notifyMsg(t('plans.deleted'), 'info')
  } catch (e: any) {
    notifyMsg(e.userMessage || t('plans.deleteFailed'), 'error')
  }
}

async function onSetToday(plan: MealPlan) {
  settingPlan.value = plan.id
  try {
    await setPlanAsRecommendation(plan.id)
    notifyMsg(t('plans.setTodayDone', { name: plan.name }), 'success')
  } catch (e: any) {
    notifyMsg(e.userMessage || t('plans.setTodayFailed'), 'error')
  } finally {
    settingPlan.value = null
  }
}

// ---- 趋势图（echarts，与 CostTrendAnalysis 同库） ----
async function renderTrend() {
  if (!editor.value.id || !trendCanvas.value) return
  try {
    const points = await getPlanCostTrend(editor.value.id, trendDays.value)
    trendChart = trendChart || echarts.init(trendCanvas.value)
    trendChart.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 48, right: 16, top: 24, bottom: 28 },
      xAxis: { type: 'category', data: points.map(p => p.date) },
      yAxis: { type: 'value', scale: true },
      series: [{
        name: t('plans.totalCost'),
        type: 'line',
        data: points.map(p => p.total_cost),
        smooth: true,
        showSymbol: false,
        lineStyle: { width: 2 },
        areaStyle: { opacity: 0.08 },
      }],
    })
  } catch { /* 趋势失败静默 */ }
}

watch(trendDays, () => void renderTrend())
watch(() => editor.value.id, () => void renderTrend())

function onResize() {
  trendChart?.resize()
}

onMounted(async () => {
  await loadPlans()
  // 推荐「拿去试算」草稿：从今日推荐导入
  const draft = sessionStorage.getItem('planDraft')
  if (draft) {
    sessionStorage.removeItem('planDraft')
    try {
      const parsed = JSON.parse(draft)
      startNew()
      editor.value.name = parsed.name || ''
      editor.value.items = parsed.items || []
      void evaluateDraft()
    } catch { /* 草稿解析失败忽略 */ }
  }
  window.addEventListener('resize', onResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', onResize)
  trendChart?.dispose()
})

const draftConsumed = ref(false)
</script>

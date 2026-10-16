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
        @click="router.push('/plans/new')"
      />
    </template>
  </v-app-bar>

  <v-container fluid class="pa-4">
    <v-alert v-if="error" type="error" class="mb-4" density="compact">
      {{ error }}
    </v-alert>

    <div v-if="loading" class="py-8 text-center">
      <v-progress-circular indeterminate color="primary" />
    </div>

    <v-row v-else>
      <v-col v-for="plan in plans" :key="plan.id" cols="12" sm="6" md="4">
        <v-card
          elevation="1"
          rounded="lg"
          hover
          class="h-100 plan-card"
          @click="openPlan(plan.id)"
        >
          <SparklineBackground
            v-if="hasTrend(plan.id)"
            :data="trendOf(plan.id)"
            color="tertiary"
          />
          <v-card-item style="position: relative; z-index: 1">
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

          <v-card-text style="position: relative; z-index: 1">
            <template v-if="statsOf(plan.id)">
              <div class="text-subtitle-1 font-weight-bold text-tertiary mb-1">
                {{ formatMoney(statsOf(plan.id)!.cost, statsOf(plan.id)!.currency || userCurrency) }}
              </div>
              <div class="d-flex flex-wrap text-caption text-medium-emphasis" style="gap: 4px 14px">
                <span>{{ t('plans.calories') }} {{ caloriesText(plan.id) }}{{ nrvText(plan.id, 'energy') }}</span>
                <span>{{ t('plans.protein') }} {{ gramsText(plan.id, 'protein_g') }}{{ nrvText(plan.id, 'protein') }}</span>
                <span>{{ t('plans.fat') }} {{ gramsText(plan.id, 'fat_g') }}{{ nrvText(plan.id, 'fat') }}</span>
              </div>
            </template>
            <div v-else class="text-caption text-disabled">…</div>
          </v-card-text>

          <v-divider />
          <v-card-actions style="position: relative; z-index: 1">
            <v-btn size="small" variant="text" color="primary" @click.stop="openPlan(plan.id)">
              {{ t('plans.edit') }}
            </v-btn>
            <v-btn
              size="small"
              variant="text"
              :color="plan.kind === 'day' ? 'tertiary' : 'primary'"
              :loading="settingPlan === plan.id"
              @click.stop="onSetToday(plan)"
            >
              {{ t('plans.setToday') }}
            </v-btn>
            <v-spacer />
            <v-btn
              icon="mdi-delete-outline"
              size="small"
              variant="text"
              color="error"
              @click.stop="onDelete(plan)"
            />
          </v-card-actions>
        </v-card>
      </v-col>

      <v-col v-if="plans.length === 0" cols="12">
        <div class="text-center py-16 text-medium-emphasis">
          <v-icon size="64" color="medium-emphasis">mdi-clipboard-text-outline</v-icon>
          <div class="text-h6 mt-4">{{ t('plans.empty') }}</div>
          <v-btn class="mt-3" variant="tonal" color="primary" @click="router.push('/plans/new')">
            {{ t('plans.newPlan') }}
          </v-btn>
        </div>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useDisplay } from 'vuetify'
import CalcContextMenu from '@/components/layout/CalcContextMenu.vue'
import SparklineBackground from '@/components/charts/SparklineBackground.vue'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useConfirmDialog } from '@/composables/useConfirmDialog'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { useUserUnits } from '@/composables/useUserUnits'
import { useLocaleStore } from '@/stores/locale'
import { formatMoney } from '@/utils/currency'
import { formatNumber } from '@/utils/format'
import {
  listPlans, deletePlan, evaluatePlan, getPlanCostTrend, setPlanAsRecommendation,
  type MealPlan, type PlanEvaluation, type PlanItemInput, type PlanNutrition,
} from '@/api/mealPlans'

const { t } = useI18n()
const router = useRouter()
const { mdAndUp } = useDisplay()
const isDesktop = computed(() => mdAndUp.value)
const { toggleSidebar } = useMobileDrawerControl()
const { ask } = useConfirmDialog()
const { notify } = useGlobalSnackbar()
const { currency: userCurrency } = useUserCurrency()
const { energyUnit, toDisplayCalorie } = useUserUnits()
const localeStore = useLocaleStore()

const plans = ref<MealPlan[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const settingPlan = ref<number | null>(null)
/** plan.id → 合计（成本 / 热量 / 蛋白质 / 脂肪）与近 30 天成本迷你图 */
const planStats = ref<Record<number, PlanEvaluation['totals']>>({})
const planNutrients = ref<Record<number, PlanNutrition>>({})
const planTrends = ref<Record<number, number[]>>({})

function statsOf(id: number) {
  return planStats.value[id]
}

function trendOf(id: number) {
  return planTrends.value[id] || []
}

function hasTrend(id: number) {
  const data = trendOf(id)
  return data.length >= 2 && data.some(v => v > 0)
}

function caloriesText(id: number) {
  return `${formatNumber(toDisplayCalorie(statsOf(id)?.calories), localeStore.effectiveFormatLocale)} ${energyUnit.value}`
}

function gramsText(id: number, key: 'protein_g' | 'fat_g') {
  return `${formatNumber(statsOf(id)?.[key], localeStore.effectiveFormatLocale, { maximumFractionDigits: 1 })} ${t('nutrientUnits.g')}`
}

/** NRV%（营养素参考值百分比，后端按核心营养素表算好；按英文 key 取，避免模板里写中文常量） */
function nrvPct(id: number, key: string): number | null {
  const entry = planNutrients.value[id]?.per_serving_nutrition?.all_nutrients?.[key]
  return entry?.nrp_pct != null ? Math.round(entry.nrp_pct) : null
}

function nrvText(id: number, key: string) {
  const pct = nrvPct(id, key)
  return pct != null ? ` · NRV ${pct}%` : ''
}

function planItemsInput(plan: MealPlan): PlanItemInput[] {
  return plan.items.map((i, idx) => ({
    group: i.group, item_type: i.item_type,
    recipe_id: i.recipe_id ?? null, ingredient_id: i.ingredient_id ?? null,
    product_id: i.product_id ?? null,
    servings: i.servings ?? null, quantity: i.quantity ?? null, unit_id: i.unit_id ?? null,
    sort_order: idx,
  }))
}

/** 与详情页同口径：meal 方案按条目分组推餐次（other 退回午餐） */
function planMealType(plan: MealPlan): 'breakfast' | 'lunch' | 'dinner' {
  const g = plan.items[0]?.group
  return g === 'breakfast' || g === 'dinner' ? g : 'lunch'
}

/** 列表卡片上的合计与迷你图：逐条拉取（数量少），单条失败不影响其它卡片 */
async function loadPlanInsights() {
  await Promise.all(plans.value.map(async (plan) => {
    const items = planItemsInput(plan)
    if (items.length) {
      try {
        const ev = await evaluatePlan({
          kind: plan.kind, meal_type: planMealType(plan), items,
        })
        planStats.value = { ...planStats.value, [plan.id]: ev.totals }
        planNutrients.value = { ...planNutrients.value, [plan.id]: ev.nutrition || {} }
      } catch { /* 单条求值失败静默 */ }
    }
    try {
      const points = await getPlanCostTrend(plan.id, 30)
      planTrends.value = { ...planTrends.value, [plan.id]: points.map(p => p.total_cost ?? 0) }
    } catch { /* 单条趋势失败静默 */ }
  }))
}

async function loadPlans() {
  loading.value = true
  error.value = null
  try {
    plans.value = (await listPlans()).items || []
    planStats.value = {}
    planNutrients.value = {}
    planTrends.value = {}
    void loadPlanInsights()
  } catch (e: any) {
    error.value = e.userMessage || t('plans.loadFailed')
  } finally {
    loading.value = false
  }
}

function openPlan(id: number) {
  void router.push(`/plans/${id}`)
}

async function onDelete(plan: MealPlan) {
  const ok = await ask({
    text: t('plans.deleteConfirm', { name: plan.name }),
    color: 'error',
  })
  if (!ok) return
  try {
    await deletePlan(plan.id)
    plans.value = plans.value.filter(p => p.id !== plan.id)
    const stats = { ...planStats.value }
    const nutrients = { ...planNutrients.value }
    const trends = { ...planTrends.value }
    delete stats[plan.id]
    delete nutrients[plan.id]
    delete trends[plan.id]
    planStats.value = stats
    planNutrients.value = nutrients
    planTrends.value = trends
    notify(t('plans.deleted'), 'info')
  } catch (e: any) {
    notify(e.userMessage || t('plans.deleteFailed'), 'error')
  }
}

async function onSetToday(plan: MealPlan) {
  settingPlan.value = plan.id
  try {
    await setPlanAsRecommendation(plan.id)
    notify(t('plans.setTodayDone', { name: plan.name }), 'success')
  } catch (e: any) {
    notify(e.userMessage || t('plans.setTodayFailed'), 'error')
  } finally {
    settingPlan.value = null
  }
}

onMounted(() => {
  void loadPlans()
})
</script>

<style scoped>
.plan-card {
  cursor: pointer;
}
</style>

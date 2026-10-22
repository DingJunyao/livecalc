<template>
  <v-card
    class="meal-card"
    :class="{
      'meal-card--current': recommendation.is_current_meal,
      'meal-card--empty': !hasFood,
    }"
    :elevation="recommendation.is_current_meal ? 3 : 1"
    rounded="lg"
  >
    <!-- 加载遮罩 -->
    <v-overlay
      :model-value="isRefreshing"
      contained
      class="align-center justify-center"
      persistent
    >
      <v-progress-circular indeterminate color="primary" size="32" />
    </v-overlay>

    <!-- 空状态 -->
    <v-card-text v-if="!hasFood" class="empty-state pa-6 text-center">
      <v-icon size="48" color="grey-lighten-1" class="mb-2">mdi-book-plus-outline</v-icon>
      <p class="text-body-2 text-medium-emphasis mb-3">
        {{ t('meals.maintainRecipes') }}
      </p>
      <v-btn
        size="small"
        variant="outlined"
        color="primary"
        @click.stop="goToRecipes"
      >
        {{ t('meals.goAddRecipe') }}
      </v-btn>
    </v-card-text>

    <!-- 方案来源餐（source='plan'）：首图行 + 方案名 + 条目明细 + 合计 -->
    <template v-else-if="planView">
      <div v-if="planImages.length" class="meal-card__image-row">
        <img
          v-for="(img, i) in planImages"
          :key="i"
          :src="img"
          class="meal-card__dish-image"
          alt=""
          loading="lazy"
          referrerpolicy="no-referrer"
        />
      </div>
      <v-card-title class="d-flex align-center pb-1">
        <v-icon start size="18" color="tertiary">mdi-clipboard-text-outline</v-icon>
        <a
          class="text-body-1 font-weight-medium text-truncate meal-card__plan-title"
          :href="`/plans/${planView.id}`"
          :title="t('plans.title')"
          @click.prevent="goToPlan(planView.id)"
        >{{ planView.name }}</a>
        <v-chip size="x-small" color="tertiary" variant="tonal" class="ms-2">
          {{ planView.kind === 'day' ? t('plans.kindDay') : t('plans.kindMeal') }}
        </v-chip>
      </v-card-title>
      <div class="px-4 pt-1">
        <a
          v-for="(item, i) in planView.items"
          :key="i"
          class="d-flex align-center py-0.5 text-decoration-none meal-card__plan-item"
          :class="{ 'meal-card__plan-item--link': !!planItemLink(item) }"
          :href="planItemLink(item) || undefined"
          @click.prevent="onPlanItemClick(item)"
        >
          <span class="text-body-2 text-truncate flex-grow-1">{{ item.name || '…' }}</span>
          <span class="text-body-2 text-no-wrap ms-2">
            {{ item.cost != null ? formatMoney(item.cost, planView.totals?.currency || userCurrency) : '--' }}
          </span>
        </a>
      </div>
      <v-divider class="mx-4 my-2" />
      <div class="px-4 pb-2 d-flex flex-column">
        <div class="d-flex justify-space-between text-body-2 font-weight-bold">
          <span>{{ t('plans.totalCost') }}</span>
          <span>{{ formatMoney(planView.totals?.cost ?? 0, planView.totals?.currency || userCurrency) }}</span>
        </div>
        <NutrientSummaryGrid class="mt-2" :items="planNutrientItems" />
      </div>
    </template>

    <!-- 多道菜套餐（新） -->
    <template v-else-if="dishes.length > 0">
      <!-- 首图行：有几张就并排几张，等宽填满不留空白（不重复写菜名，菜名由下方清单给出） -->
      <div v-if="dishImageList.length" class="meal-card__image-row">
        <img
          v-for="(img, i) in dishImageList"
          :key="i"
          :src="img"
          class="meal-card__dish-image"
          alt=""
          loading="lazy"
          referrerpolicy="no-referrer"
        />
        <v-chip
          v-if="isAiSource"
          size="x-small"
          color="light-blue-accent-1"
          variant="flat"
          class="meal-card__overlay-chip"
          prepend-icon="mdi-creation"
        >{{ t('meals.aiGenerated') }}</v-chip>
      </div>

      <!-- 无首图：同样不重复写菜名，仅保留 AI 标识 -->
      <div v-else-if="isAiSource" class="meal-card__ai-chip-row">
        <v-chip
          size="x-small"
          color="light-blue"
          variant="tonal"
          prepend-icon="mdi-creation"
        >{{ t('meals.aiGenerated') }}</v-chip>
      </div>

      <!-- 菜品清单：与「分组/方案」条目同一行结构（唯一差别是行尾「换这道」） -->
      <div class="px-4 pt-1">
        <div
          v-for="dish in dishes"
          :key="dish.id"
          class="d-flex align-center py-0.5 meal-card__row meal-card__row--link"
          @click="goToRecipe(dish.id)"
        >
          <span class="text-body-2 text-truncate flex-grow-1">{{ dish.name }}</span>
          <span class="text-body-2 text-no-wrap ms-2">{{ dishCost(dish) }}</span>
          <v-btn
            icon="mdi-swap-horizontal"
            size="x-small"
            variant="text"
            :loading="isRefreshing"
            :disabled="isRefreshing"
            :title="t('meals.changeDish')"
            class="ms-1"
            @click.stop="onChangeDish(dish)"
          />
        </div>
      </div>

      <!-- 合计（与分组块同格式：分割线 + 成本 + 逐项营养） -->
      <v-divider class="mx-4 my-2" />
      <div class="px-4 pb-2 d-flex flex-column">
        <div class="d-flex justify-space-between text-body-2 font-weight-bold">
          <span>{{ t('plans.totalCost') }}</span>
          <span>{{ mealCostText }}</span>
        </div>
        <NutrientSummaryGrid class="mt-2" :items="dishNutrientItems" />
      </div>

      <!-- 理由 / 偏好脚注 -->
      <v-card-text class="py-2" v-if="recommendation.reason || recommendation.preference">
        <div v-if="recommendation.reason" class="text-caption text-medium-emphasis">
          <v-icon size="x-small" class="me-1">mdi-lightbulb-on-outline</v-icon>
          {{ recommendation.reason }}
        </div>
        <div v-if="recommendation.preference" class="text-caption text-disabled mt-1">
          <v-icon size="x-small" class="me-1">mdi-tag-outline</v-icon>
          {{ t('meals.preferenceChip') }}{{ recommendation.preference }}
        </div>
      </v-card-text>

      <v-card-actions class="pt-0">
        <v-btn
          size="small"
          variant="text"
          @click.stop="onTakeToPlanner"
          :title="t('plans.takeToPlanner')"
        >
          <v-icon start size="18">mdi-clipboard-text-outline</v-icon>
          {{ t('plans.takeToPlanner') }}
        </v-btn>
        <v-spacer />
        <v-btn
          size="small"
          variant="text"
          :loading="isRefreshing"
          :disabled="isRefreshing"
          @click.stop="onRefreshMeal"
        >
          <v-icon start size="18">mdi-refresh</v-icon>
          {{ t('meals.changeMeal') }}
        </v-btn>
      </v-card-actions>
    </template>

    <!-- 单道菜兼容（本地模式旧数据） -->
    <template v-else>
      <v-img
        v-if="recipeImage"
        :src="recipeImage"
        height="140"
        cover
        class="align-end"
      >
        <v-toolbar
          color="rgba(0,0,0,0.4)"
          density="compact"
          class="meal-card__overlay-toolbar"
        >
          <v-toolbar-title class="text-white text-body-1">
            {{ recommendation.recipe!.name }}
          </v-toolbar-title>
        </v-toolbar>
      </v-img>

      <v-card-item v-if="!recipeImage">
        <v-card-title class="text-body-1">{{ recommendation.recipe!.name }}</v-card-title>
        <v-card-subtitle v-if="recommendation.recipe!.category">
          {{ recipeCategoryLabel(recommendation.recipe!.category) }}
        </v-card-subtitle>
      </v-card-item>

      <v-card-text class="pb-2">
        <div class="d-flex align-center ga-1 flex-wrap">
          <v-icon size="small">mdi-cash</v-icon>
          <span class="font-weight-medium">{{ costText }}</span>
        </div>
        <NutrientSummaryGrid class="mt-2" :items="dishNutrientItems" />
        <div
          v-if="!recommendation.recipe!.nutrition_per_serving"
          class="text-caption text-disabled mt-1"
        >
          {{ t('meals.noNutritionData') }}
        </div>
      </v-card-text>

      <v-card-actions class="pt-0">
        <v-spacer />
        <v-btn
          size="small"
          variant="text"
          :loading="isRefreshing"
          @click.stop="onRefreshMeal"
          :disabled="isRefreshing"
        >
          <v-icon start size="18">mdi-refresh</v-icon>
          {{ t('meals.changeOne') }}
        </v-btn>
      </v-card-actions>
    </template>
  </v-card>
</template>

<script setup lang="ts">
import { computed, ref, watch, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import type { MealPlanBriefItem, MealRecommendation, RecommendedDish } from '@/api/meals'
import { useUserUnits } from '@/composables/useUserUnits'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { formatMoney } from '@/utils/currency'
import { formatNumber } from '@/utils/format'
import { resolveImageUrl, loadLocalImageBlob } from '@/utils/image'
import { useI18n } from 'vue-i18n'
import { useLocaleStore } from '@/stores/locale'
import { RECIPE_CATEGORY_KEYS } from '@/data/recipeCategories'
import { nrvPct } from '@/utils/nrv'
import NutrientSummaryGrid from './NutrientSummaryGrid.vue'

const router = useRouter()
const { energyUnit, toDisplayCalorie } = useUserUnits()
const { currency: userCurrency } = useUserCurrency()
const localeStore = useLocaleStore()
const { t } = useI18n()

function recipeCategoryLabel(category?: string): string {
  const key = category ? RECIPE_CATEGORY_KEYS[category] : null
  return key && category ? t(key) : (category || '')
}

const props = defineProps<{
  recommendation: MealRecommendation
  isRefreshing: boolean
}>()

const emit = defineEmits<{
  refresh: [mealType: string, recipeId?: number]
  takeToPlanner: [mealType: string]
}>()

const dishes = computed<RecommendedDish[]>(() => props.recommendation.dishes || [])
const planView = computed(() => props.recommendation.plan || null)
const hasFood = computed(
  () => dishes.value.length > 0 || !!props.recommendation.recipe || !!planView.value,
)
const isAiSource = computed(
  () => props.recommendation.source === 'system_ai' || props.recommendation.source === 'user_ai'
)

// ---- 逐条目首图：本地 blob 优先，其次 image_urls（云） ----
const localDishImageUrls = ref<Record<number, string>>({})
let dishObjectUrls: string[] = []

async function refreshLocalDishImages() {
  for (const url of dishObjectUrls) URL.revokeObjectURL(url)
  dishObjectUrls = []
  localDishImageUrls.value = {}
  for (const dish of dishes.value) {
    if (!dish.id || !dish.images?.length) continue
    const url = await loadLocalImageBlob('recipes', dish.id, dish.images[0])
    if (!url) continue
    dishObjectUrls.push(url)
    localDishImageUrls.value = { ...localDishImageUrls.value, [dish.id]: url }
  }
}

watch(dishes, () => { void refreshLocalDishImages() }, { immediate: true })

const dishImageList = computed(() => {
  const list: string[] = []
  for (const dish of dishes.value) {
    const local = localDishImageUrls.value[dish.id]
    if (local) {
      list.push(local)
      continue
    }
    const url = resolveImageUrl(dish.image_urls?.[0]) || resolveImageUrl(dish.images?.[0])
    if (url) list.push(url)
  }
  return list
})

/** 方案来源餐的首图：该餐各菜谱条目的首图（有图才显示，等宽并排） */
const planImages = computed(() =>
  (planView.value?.items || [])
    .map(item => item.image_urls?.[0])
    .filter((url): url is string => !!url),
)

const mealNutrients = computed(() => {
  const rows: any[] = dishes.value.length > 0
    ? dishes.value.map(d => d.nutrition_per_serving)
    : [props.recommendation.recipe?.nutrition_per_serving]
  const totals = { energy: 0, protein: 0, carbohydrate: 0, fat: 0 }
  for (const row of rows) {
    if (!row) continue
    totals.energy += Number(row.calories ?? row.energy ?? 0)
    totals.protein += Number(row.protein_g ?? row.protein ?? 0)
    totals.carbohydrate += Number(row.carbs_g ?? row.carbohydrate ?? 0)
    totals.fat += Number(row.fat_g ?? row.fat ?? 0)
  }
  return totals
})

type NutrientTotals = { energy: number; protein: number; carbohydrate: number; fat: number }

function nrvText(key: 'energy' | 'protein' | 'carbohydrate' | 'fat', value: number): string | undefined {
  const pct = nrvPct(key, value)
  return pct != null ? `NRV ${pct}%` : undefined
}

/** 四项营养素宫格条目（宽屏一行 4 列，窄屏 2×2），NRV 单独一行，与汇总条同格式 */
function buildNutrientItems(n: NutrientTotals) {
  const num = (v: number) =>
    formatNumber(v, localeStore.effectiveFormatLocale, { maximumFractionDigits: 1 })
  const g = t('nutrientUnits.g')
  return [
    {
      icon: 'mdi-fire',
      label: t('plans.calories'),
      value: `${formatNumber(toDisplayCalorie(n.energy))} ${energyUnit.value}`,
      nrv: nrvText('energy', n.energy),
    },
    {
      icon: 'mdi-food-drumstick-outline',
      label: t('plans.protein'),
      value: `${num(n.protein)} ${g}`,
      nrv: nrvText('protein', n.protein),
    },
    {
      icon: 'mdi-oil',
      label: t('plans.fat'),
      value: `${num(n.fat)} ${g}`,
      nrv: nrvText('fat', n.fat),
    },
    {
      icon: 'mdi-grain',
      label: t('nutrients.carbohydrate'),
      value: `${num(n.carbohydrate)} ${g}`,
      nrv: nrvText('carbohydrate', n.carbohydrate),
    },
  ]
}

const dishNutrientItems = computed(() => buildNutrientItems(mealNutrients.value))

const planNutrientItems = computed(() => {
  const totals = planView.value?.totals
  return buildNutrientItems({
    energy: Number(totals?.calories ?? 0),
    protein: Number(totals?.protein_g ?? 0),
    carbohydrate: Number(totals?.carbs_g ?? 0),
    fat: Number(totals?.fat_g ?? 0),
  })
})

function roleLabel(role: string): string {
  const map: Record<string, string> = {
    staple: t('meals.roleStaple'),
    main: t('meals.roleMain'),
    side: t('meals.roleSide'),
    soup: t('meals.roleSoup'),
    drink: t('meals.roleDrink'),
  }
  return map[role] || role
}

function roleColor(role: string): string {
  return role === 'staple' ? 'primary' : 'default'
}

function dishCost(dish: RecommendedDish): string {
  return dish.cost_estimate != null
    ? formatMoney(Number(dish.cost_estimate), dish.currency || userCurrency.value)
    : '--'
}

function dishCalorie(dish: RecommendedDish): string {
  const cal = dish.nutrition_per_serving?.calories
  return cal != null
    ? `${formatNumber(toDisplayCalorie(cal), localeStore.effectiveFormatLocale)} ${energyUnit.value}`
    : '--'
}

// ---- 封面图（staple 或首道有图者；本地 blob 优先） ----
const localImageUrl = ref<string | null>(null)
let currentObjectUrl: string | null = null

async function refreshLocalImage() {
  if (currentObjectUrl) {
    URL.revokeObjectURL(currentObjectUrl)
    currentObjectUrl = null
  }
  localImageUrl.value = null

  const source = coverRecipe.value
  if (!source?.id || !source.images?.length) return

  const url = await loadLocalImageBlob('recipes', source.id, source.images[0])
  if (url) {
    currentObjectUrl = url
    localImageUrl.value = url
  }
}

const coverRecipe = computed(() => {
  if (dishes.value.length > 0) {
    return (
      dishes.value.find(d => d.role === 'staple' && (d.image_urls?.length || d.images?.length)) ||
      dishes.value.find(d => d.image_urls?.length || d.images?.length) ||
      null
    )
  }
  return props.recommendation.recipe
})

watch(coverRecipe, refreshLocalImage, { immediate: true })

onUnmounted(() => {
  if (currentObjectUrl) URL.revokeObjectURL(currentObjectUrl)
})

const coverImage = computed(() => {
  if (localImageUrl.value) return localImageUrl.value
  const src = coverRecipe.value
  if (src?.image_urls?.[0]) return src.image_urls[0]
  const images = src?.images
  if (images && images.length > 0) {
    return resolveImageUrl(images[0]) || null
  }
  return null
})

// ---- 单道兼容模式的展示计算 ----
const recipeImage = computed(() => {
  const recipe = props.recommendation.recipe
  if (localImageUrl.value) return localImageUrl.value
  if (recipe?.image_urls?.[0]) return recipe.image_urls[0]
  const images = recipe?.images
  if (images && images.length > 0) {
    return resolveImageUrl(images[0]) || null
  }
  return null
})

const costText = computed(() => {
  const cost = props.recommendation.recipe?.cost_estimate
  return cost != null ? formatMoney(Number(cost), props.recommendation.recipe?.currency || userCurrency.value) : '--'
})

const calorieText = computed(() => {
  const cal = props.recommendation.recipe?.nutrition_per_serving?.calories
  return cal != null
    ? `${formatNumber(toDisplayCalorie(cal), localeStore.effectiveFormatLocale)} ${energyUnit.value}`
    : '--'
})

const proteinText = computed(() => {
  const pro = props.recommendation.recipe?.nutrition_per_serving?.protein_g
  return pro != null
    ? `${formatNumber(pro, localeStore.effectiveFormatLocale)} ${t('nutrientUnits.g')}`
    : '--'
})

/** AI 块的成本合计（各道菜 cost_estimate 相加） */
const mealCostText = computed(() => {
  if (dishes.value.length > 0) {
    const sum = dishes.value.reduce((acc, d) => acc + Number(d.cost_estimate ?? 0), 0)
    const currency = dishes.value.find(d => d.currency)?.currency || userCurrency.value
    return formatMoney(sum, currency)
  }
  return costText.value
})

/** 方案条目 → 对应实体详情 */
function planItemLink(item: MealPlanBriefItem) {
  if (item.item_type === 'recipe' && item.recipe_id) return `/recipes/${item.recipe_id}`
  if (item.item_type === 'ingredient' && item.ingredient_id) return `/data/ingredients/${item.ingredient_id}`
  if (item.item_type === 'product' && item.product_id) return `/data/products/${item.product_id}`
  return null
}

function onPlanItemClick(item: MealPlanBriefItem) {
  const link = planItemLink(item)
  if (link) void router.push(link)
}

function goToPlan(planId: number) {
  void router.push(`/plans/${planId}`)
}

function goToRecipe(recipeId: number) {
  router.push(`/recipes/${recipeId}`)
}

function goToRecipes() {
  router.push('/recipes')
}

function onRefreshMeal() {
  emit('refresh', props.recommendation.meal_type, undefined)
}

function onTakeToPlanner() {
  emit('takeToPlanner', props.recommendation.meal_type)
}

function onChangeDish(dish: RecommendedDish) {
  emit('refresh', props.recommendation.meal_type, dish.id)
}
</script>

<style scoped>
.meal-card__plan-item,
.meal-card__plan-title {
  color: inherit;
  text-decoration: none;
}

.meal-card__plan-item--link,
.meal-card__plan-title,
.meal-card__row--link {
  cursor: pointer;
}

.meal-card__row--link:hover {
  background: rgba(var(--v-theme-on-surface), 0.04);
}

/* 两侧行高一致：AI 块行尾的「换这道」按钮把行撑到 36px，分组行补同样的 min-height */
.meal-card__row,
.meal-card__plan-item {
  min-height: 36px;
}

/* 首图行：单行等宽并排、限高裁切（图片可被遮盖） */
.meal-card__image-row {
  position: relative;
  display: flex;
  width: 100%;
  height: 120px;
  overflow: hidden;
}

.meal-card__dish-image {
  flex: 1 1 0;
  min-width: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.meal-card {
  transition: transform 0.2s, box-shadow 0.2s;
}
.meal-card--current {
  border-inline-start: 4px solid rgb(var(--v-theme-primary));
  animation: pulse-glow 2s ease-in-out infinite;
}
.meal-card--empty {
  cursor: default;
}
.meal-card:hover:not(.meal-card--empty) {
  transform: translateY(-2px);
}
.meal-card__overlay-toolbar {
  background: linear-gradient(to top, rgba(0,0,0,0.6), transparent) !important;
  /* 必须脱离 flex 流：否则 toolbar 的 width:100% 会把图片的 flex-basis:0 压成 0 宽（图加载了却看不见） */
  position: absolute;
  inset-inline: 0;
  bottom: 0;
}
/* 有首图但不再写菜名：AI 标识直接浮在图上 */
.meal-card__overlay-chip {
  position: absolute;
  bottom: 8px;
  inset-inline-end: 8px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.35);
}
/* 无首图：AI 标识单占一行（右对齐），菜名交给下方清单 */
.meal-card__ai-chip-row {
  display: flex;
  justify-content: flex-end;
  padding: 12px 16px 0;
}
.meal-card__dish {
  min-height: 40px;
}
.empty-state {
  min-height: 160px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

@keyframes pulse-glow {
  0%, 100% { box-shadow: 0 0 0 0 rgba(var(--v-theme-primary), 0.3); }
  50% { box-shadow: 0 0 12px 2px rgba(var(--v-theme-primary), 0.15); }
}
</style>

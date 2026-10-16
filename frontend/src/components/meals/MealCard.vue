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

    <!-- 方案来源餐（source='plan'）：方案名 + 条目明细 + 合计 -->
    <template v-else-if="planView">
      <v-card-title class="d-flex align-center pb-1">
        <v-icon start size="18" color="tertiary">mdi-clipboard-text-outline</v-icon>
        <span class="text-body-1 font-weight-medium text-truncate">{{ planView.name }}</span>
        <v-chip size="x-small" color="tertiary" variant="tonal" class="ms-2">
          {{ planView.kind === 'day' ? t('plans.kindDay') : t('plans.kindMeal') }}
        </v-chip>
      </v-card-title>
      <v-card-text class="pt-0">
        <div
          v-for="(item, i) in planView.items"
          :key="i"
          class="d-flex justify-space-between text-body-2 py-0.5"
        >
          <span class="text-truncate me-2">{{ item.name || '…' }}</span>
          <span class="text-no-wrap">
            {{ item.cost != null ? formatMoney(item.cost, planView.totals?.currency || userCurrency) : '--' }}
          </span>
        </div>
        <v-divider class="my-2" />
        <div class="d-flex justify-space-between text-body-2 font-weight-bold">
          <span>{{ t('plans.totalCost') }}</span>
          <span>{{ formatMoney(planView.totals?.cost ?? 0, planView.totals?.currency || userCurrency) }}</span>
        </div>
        <div class="text-caption text-medium-emphasis mt-1">
          {{ t('plans.calories') }} {{ formatNumber(Math.round(planView.totals?.calories ?? 0)) }} kcal
          · {{ t('plans.protein') }} {{ formatNumber(planView.totals?.protein_g ?? 0, undefined, { maximumFractionDigits: 1 }) }} g
          · {{ t('plans.fat') }} {{ formatNumber(planView.totals?.fat_g ?? 0, undefined, { maximumFractionDigits: 1 }) }} g
        </div>
      </v-card-text>
    </template>

    <!-- 多道菜套餐（新） -->
    <template v-else-if="dishes.length > 0">
      <!-- 封面：主食（无则首道）的图 -->
      <v-img
        v-if="coverImage"
        :src="coverImage"
        height="120"
        cover
        class="align-end"
      >
        <v-toolbar
          color="rgba(0,0,0,0.4)"
          density="compact"
          class="meal-card__overlay-toolbar"
        >
          <v-toolbar-title class="text-white text-body-1">
            {{ dishNames }}
          </v-toolbar-title>
          <v-chip
            v-if="isAiSource"
            size="x-small"
            color="light-blue-accent-1"
            variant="flat"
            class="me-2"
            prepend-icon="mdi-creation"
          >{{ t('meals.aiGenerated') }}</v-chip>
        </v-toolbar>
      </v-img>

      <v-card-item v-if="!coverImage">
        <v-card-title class="text-body-1 d-flex align-center flex-wrap ga-2">
          {{ dishNames }}
          <v-chip
            v-if="isAiSource"
            size="x-small"
            color="light-blue"
            variant="tonal"
            prepend-icon="mdi-creation"
          >{{ t('meals.aiGenerated') }}</v-chip>
        </v-card-title>
      </v-card-item>

      <!-- 菜品清单 -->
      <v-list density="compact" class="py-0">
        <v-list-item
          v-for="dish in dishes"
          :key="dish.id"
          :title="dish.name"
          :subtitle="dishSubtitle(dish)"
          @click="goToRecipe(dish.id)"
          class="meal-card__dish"
        >
          <template #prepend>
            <v-chip size="x-small" :color="roleColor(dish.role)" variant="tonal" class="me-1">
              {{ roleLabel(dish.role) }}
            </v-chip>
          </template>
          <template #append>
            <span class="text-caption text-medium-emphasis me-1">
              {{ dishCost(dish) }} · {{ dishCalorie(dish) }}
            </span>
            <v-btn
              icon="mdi-swap-horizontal"
              size="x-small"
              variant="text"
              :loading="isRefreshing"
              :disabled="isRefreshing"
              :title="t('meals.changeDish')"
              @click.stop="onChangeDish(dish)"
            />
          </template>
        </v-list-item>
      </v-list>

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
        <div class="d-flex align-center ga-3 flex-wrap">
          <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
            <v-icon size="small">mdi-cash</v-icon>
            {{ costText }}
          </span>
          <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
            <v-icon size="small">mdi-fire</v-icon>
            {{ calorieText }}
          </span>
          <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
            <v-icon size="small">mdi-food-drumstick-outline</v-icon>
            {{ proteinText }}
          </span>
        </div>
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
import type { MealRecommendation, RecommendedDish } from '@/api/meals'
import { useUserUnits } from '@/composables/useUserUnits'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { formatMoney } from '@/utils/currency'
import { formatNumber } from '@/utils/format'
import { resolveImageUrl, loadLocalImageBlob } from '@/utils/image'
import { useI18n } from 'vue-i18n'
import { useLocaleStore } from '@/stores/locale'
import { RECIPE_CATEGORY_KEYS } from '@/data/recipeCategories'

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

const dishNames = computed(() => {
  const list = dishes.value
  if (list.length > 0) return list.map(d => d.name).join(' · ')
  return props.recommendation.recipe?.name || ''
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

function dishSubtitle(dish: RecommendedDish): string {
  return dish.category ? recipeCategoryLabel(dish.category) : ''
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

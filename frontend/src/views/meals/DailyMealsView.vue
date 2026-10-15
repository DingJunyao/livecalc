<template>
  <div class="daily-meals-view">
    <!-- 顶部栏 -->
    <v-app-bar flat density="comfortable" color="background">
      <v-app-bar-nav-icon
        @click="toggleSidebar(isDesktop)"
        icon="mdi-menu"
      />
      <v-app-bar-title>
        {{ t('meals.title') }}
        <span class="text-caption text-medium-emphasis ms-2">
          {{ formattedDate }}
        </span>
      </v-app-bar-title>

      <template #append>
        <CalcContextMenu />
        <v-btn
          icon="mdi-cog-outline"
          size="small"
          variant="text"
          @click="goToProfile"
          :title="t('meals.nutritionGoals')"
        />
      </template>
    </v-app-bar>

    <!-- 加载状态 -->
    <div v-if="store.loading" class="px-4 pt-4">
      <v-skeleton-loader type="card@3" />
    </div>

    <!-- 后台生成中 -->
    <v-container v-else-if="store.generating" class="text-center mt-12">
      <v-progress-circular
        indeterminate
        color="primary"
        size="64"
        width="4"
      />
      <p class="text-body-1 text-medium-emphasis mt-4">
        {{ t('meals.generatingTitle') }}
      </p>
      <p class="text-caption text-disabled mt-1">
        {{ t('meals.generatingSubtitle') }}
      </p>
    </v-container>

    <!-- 错误状态 -->
    <v-container v-else-if="store.error" class="text-center mt-8">
      <v-icon size="64" color="grey-lighten-1">mdi-alert-circle-outline</v-icon>
      <p class="text-body-1 text-medium-emphasis mt-3">{{ store.error }}</p>
      <v-btn variant="outlined" color="primary" @click="store.loadRecommendations()">
        {{ t('meals.retry') }}
      </v-btn>
    </v-container>

    <!-- 正常内容 -->
    <template v-else>
      <!-- 汇总条 -->
      <div class="px-4 pt-4">
        <DailySummaryBar :totals="store.totals" :loading="false" />
      </div>

      <!-- 一句话偏好 -->
      <div class="px-4 pt-3">
        <v-text-field
          v-model="store.preferenceInput"
          :label="t('meals.preferencePlaceholder')"
          prepend-inner-icon="mdi-comment-quote-outline"
          variant="outlined"
          density="compact"
          hide-details
          clearable
          :disabled="store.loading || store.generating"
          @keyup.enter="applyPreference"
        >
          <template #append-inner>
            <v-btn
              size="small"
              variant="tonal"
              color="primary"
              :loading="applyingPreference"
              :disabled="!store.preferenceInput || store.loading || store.generating"
              @click="applyPreference"
            >
              {{ t('meals.applyPreference') }}
            </v-btn>
          </template>
        </v-text-field>
      </div>

      <!-- 时间线 -->
      <MealTimeline
        :recommendations="store.recommendations"
        :refresh-loading="store.refreshLoading"
        @refresh="handleRefresh"
        @take-to-planner="handleTakeToPlanner"
      />
    </template>

    <!-- Snackbar -->
    <v-snackbar v-model="snackbar.show" :color="snackbar.color" timeout="3000">
      {{ snackbar.message }}
      <template #actions>
        <v-btn variant="text" @click="snackbar.show = false">{{ t('meals.close') }}</v-btn>
      </template>
    </v-snackbar>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import CalcContextMenu from '@/components/layout/CalcContextMenu.vue'
import { useRouter } from 'vue-router'
import { useDisplay } from 'vuetify'
import { useMealsStore } from '@/stores/meals'
import { useLocaleStore } from '@/stores/locale'
import { formatDate } from '@/utils/format'
import { useI18n } from 'vue-i18n'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import DailySummaryBar from '@/components/meals/DailySummaryBar.vue'
import MealTimeline from '@/components/meals/MealTimeline.vue'

const router = useRouter()
const store = useMealsStore()
const localeStore = useLocaleStore()
const { t } = useI18n()
const { mdAndUp } = useDisplay()
const isDesktop = computed(() => mdAndUp.value)
const { toggleSidebar } = useMobileDrawerControl()

const snackbar = reactive({
  show: false,
  message: '',
  color: 'info',
})

const applyingPreference = ref(false)

/** 应用偏好：按当前餐重搭（有推荐时整餐重搭一次让偏好生效；无推荐交给生成流程） */
async function applyPreference() {
  if (!store.preferenceInput || applyingPreference.value) return
  applyingPreference.value = true
  try {
    const current = store.recommendations.find(r => r.is_current_meal) ||
      store.recommendations.find(r => r.dishes?.length || r.recipe)
    if (current) {
      await store.refreshMeal(current.meal_type)
    } else {
      await store.loadRecommendations()
    }
    snackbar.color = 'success'
    snackbar.message = t('meals.preferenceApplied')
    snackbar.show = true
  } catch (e: any) {
    snackbar.color = 'error'
    snackbar.message = e.userMessage || t('meals.refreshFailed')
    snackbar.show = true
  } finally {
    applyingPreference.value = false
  }
}

const formattedDate = computed(() => {
  if (!store.date) return ''
  return formatDate(store.date, localeStore.effectiveFormatLocale, {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
})

function goToProfile() {
  router.push('/profile')
}

function handleTakeToPlanner(mealType: string) {
  const meal = store.recommendations.find(r => r.meal_type === mealType)
  if (!meal) return
  const dishes = meal.dishes?.length
    ? meal.dishes
    : (meal.recipe ? [{ id: meal.recipe.id, name: meal.recipe.name, role: 'staple' }] : [])
  const draft = {
    name: `${t('meals.' + mealType)} · ${new Date().toLocaleDateString()}`,
    items: dishes.map((d, idx) => ({
      group: mealType,
      item_type: 'recipe',
      recipe_id: d.id,
      servings: 1,
      sort_order: idx,
      name: d.name,
    })),
  }
  sessionStorage.setItem('planDraft', JSON.stringify(draft))
  router.push('/plans')
}

async function handleRefresh(mealType: string, recipeId?: number) {
  try {
    await store.refreshMeal(mealType, recipeId)
    snackbar.color = 'success'
    snackbar.message = t('meals.refreshed')
    snackbar.show = true
  } catch (e: any) {
    snackbar.color = e.response?.status === 429 ? 'warning' : 'error'
    snackbar.message = e.userMessage || t('meals.refreshFailed')
    snackbar.show = true
  }
}

onMounted(() => {
  store.loadRecommendations()
})

onUnmounted(() => {
  store.stopPolling()
})
</script>

<style scoped>
.daily-meals-view {
  max-width: 1200px;
  margin: 0 auto;
}

@media (max-width: 959px) {
  .daily-meals-view {
    max-width: 100%;
  }
}
</style>

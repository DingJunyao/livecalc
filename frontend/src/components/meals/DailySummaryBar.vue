<template>
  <div class="daily-summary-bar">
    <v-sheet
      class="summary-sheet px-4 py-3"
      :class="{ 'summary-sheet--mobile': !isDesktop }"
      rounded="lg"
      elevation="1"
    >
      <!-- 加载骨架 -->
      <v-skeleton-loader
        v-if="loading"
        type="text@3"
        class="bg-transparent"
      />

      <template v-else-if="totals">
        <!-- 成本 -->
        <div class="d-flex align-center justify-space-between flex-wrap">
          <div class="d-flex align-center ga-4 flex-wrap">
            <div class="summary-item">
              <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
                <v-icon size="small">mdi-cash</v-icon>
                {{ t('meals.estimatedToday') }}
              </span>
              <span class="text-h6 font-weight-bold ms-1">
                {{ totals.cost != null ? formatMoney(Number(totals.cost), totals.currency || userCurrency.value) : '--' }}
              </span>
            </div>

            <!-- 营养汇总 -->
            <div class="summary-item">
              <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
                <v-icon size="small">mdi-fire</v-icon>
                {{ t('meals.calories') }}
              </span>
              <span class="font-weight-medium ms-1">
                {{ totals.calories != null ? `${formatNumber(toDisplayCalorie(totals.calories), localeStore.effectiveFormatLocale)} ${energyUnitLabel}` : '--' }}
              </span>
            </div>

            <div class="d-flex ga-2 flex-wrap">
              <div class="summary-item">
                <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
                  <v-icon size="small">mdi-food-drumstick-outline</v-icon>
                  {{ t('meals.protein') }}
                </span>
                <span class="font-weight-medium ms-1">
                  {{ totals.protein_g != null ? `${formatNumber(totals.protein_g, localeStore.effectiveFormatLocale)} ${t('nutrientUnits.g')}` : '--' }}
                </span>
              </div>
              <div class="summary-item">
                <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
                  <v-icon size="small">mdi-grain</v-icon>
                  {{ t('meals.carbs') }}
                </span>
                <span class="font-weight-medium ms-1">
                  {{ totals.carbs_g != null ? `${formatNumber(totals.carbs_g, localeStore.effectiveFormatLocale)} ${t('nutrientUnits.g')}` : '--' }}
                </span>
              </div>
              <div class="summary-item">
                <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
                  <v-icon size="small">mdi-oil</v-icon>
                  {{ t('meals.fat') }}
                </span>
                <span class="font-weight-medium ms-1">
                  {{ totals.fat_g != null ? `${formatNumber(totals.fat_g, localeStore.effectiveFormatLocale)} ${t('nutrientUnits.g')}` : '--' }}
                </span>
              </div>
            </div>
          </div>

          <!-- 进度条 -->
          <div v-if="goalProgress" class="progress-area mt-2 mt-md-0" style="min-width: 180px">
            <div class="d-flex justify-space-between text-caption mb-1">
              <span>{{ goalProgress.label }}</span>
              <span>{{ formatNumber(goalProgress.pct, localeStore.effectiveFormatLocale) }}%</span>
            </div>
            <v-progress-linear
              :model-value="goalProgress.pct"
              :color="goalProgress.color"
              height="8"
              rounded
            />
          </div>
        </div>
      </template>

      <div v-else class="text-caption text-medium-emphasis text-center py-2">
        {{ t('meals.noData') }}
      </div>
    </v-sheet>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useDisplay } from 'vuetify'
import { useI18n } from 'vue-i18n'
import type { DailyTotals } from '@/api/meals'
import { formatMoney } from '@/utils/currency'
import { formatNumber } from '@/utils/format'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { useUserUnits } from '@/composables/useUserUnits'
import { useLocaleStore } from '@/stores/locale'

const { mdAndUp } = useDisplay()
const { energyUnit, toDisplayCalorie } = useUserUnits()
const { currency: userCurrency } = useUserCurrency()
const localeStore = useLocaleStore()
const { t } = useI18n()
const isDesktop = computed(() => mdAndUp.value)

const props = defineProps<{
  totals: DailyTotals | null
  loading: boolean
}>()

const goalProgress = computed(() => {
  if (!props.totals || props.totals.calories == null) return null

  const consumed = props.totals.calories
  const target = 2000  // 库存 kcal（默认目标；pct 按同单位比例算不受单位影响）
  const pct = Math.min(Math.round((consumed / target) * 100), 100)
  const color = pct > 100 ? 'error' : pct > 80 ? 'warning' : 'success'
  const amount = formatNumber(toDisplayCalorie(target), localeStore.effectiveFormatLocale)
  return { label: t('meals.calorieGoal', { amount, unit: energyUnitLabel.value }), pct, color }
})

const energyUnitLabel = computed(() => (
  energyUnit.value === 'kJ' ? t('nutrientUnits.kJ') : t('nutrientUnits.kcal')
))
</script>

<style scoped>
.summary-sheet {
  border: 1px solid rgba(var(--v-border-color), 0.12);
}
.summary-item {
  white-space: nowrap;
  display: inline-flex;
  align-items: center;
}
.progress-area {
  max-width: 240px;
}
</style>

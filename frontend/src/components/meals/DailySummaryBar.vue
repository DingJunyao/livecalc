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
        <!-- 成本：单独一行 -->
        <div class="d-flex align-center ga-1 flex-wrap">
          <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
            <v-icon size="small">mdi-cash</v-icon>
            {{ t('meals.estimatedToday') }}
          </span>
          <span class="text-h6 font-weight-bold ms-1">
            {{ totals.cost != null ? formatMoney(Number(totals.cost), totals.currency || userCurrency.value) : '--' }}
          </span>
        </div>

        <!-- 营养汇总：宽屏一行 4 列，窄屏 2×2 -->
        <NutrientSummaryGrid class="mt-2" :items="nutrientItems" />
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
import { nrvPct } from '@/utils/nrv'
import NutrientSummaryGrid from './NutrientSummaryGrid.vue'

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

/** NRV%（GB 28050 参考值：能量 2000 kcal、蛋白质 60 g、碳水化合物 300 g、脂肪 60 g） */
const nrv = computed(() => {
  const totals = props.totals
  return {
    energy: totals?.calories != null ? nrvPct('energy', totals.calories) : null,
    protein: totals?.protein_g != null ? nrvPct('protein', totals.protein_g) : null,
    carbohydrate: totals?.carbs_g != null ? nrvPct('carbohydrate', totals.carbs_g) : null,
    fat: totals?.fat_g != null ? nrvPct('fat', totals.fat_g) : null,
  }
})

function nrvText(pct: number | null) {
  return pct != null ? `NRV ${pct}%` : ''
}

const energyUnitLabel = computed(() => (
  energyUnit.value === 'kJ' ? t('nutrientUnits.kJ') : t('nutrientUnits.kcal')
))

const nutrientItems = computed(() => {
  const totals = props.totals
  if (!totals) return []
  return [
    {
      icon: 'mdi-fire',
      label: t('meals.calories'),
      value: totals.calories != null
        ? `${formatNumber(toDisplayCalorie(totals.calories), localeStore.effectiveFormatLocale)} ${energyUnitLabel.value}`
        : '--',
      nrv: nrvText(nrv.value.energy) || undefined,
    },
    {
      icon: 'mdi-food-drumstick-outline',
      label: t('meals.protein'),
      value: totals.protein_g != null
        ? `${formatNumber(totals.protein_g, localeStore.effectiveFormatLocale)} ${t('nutrientUnits.g')}`
        : '--',
      nrv: nrvText(nrv.value.protein) || undefined,
    },
    {
      icon: 'mdi-grain',
      label: t('meals.carbs'),
      value: totals.carbs_g != null
        ? `${formatNumber(totals.carbs_g, localeStore.effectiveFormatLocale)} ${t('nutrientUnits.g')}`
        : '--',
      nrv: nrvText(nrv.value.carbohydrate) || undefined,
    },
    {
      icon: 'mdi-oil',
      label: t('meals.fat'),
      value: totals.fat_g != null
        ? `${formatNumber(totals.fat_g, localeStore.effectiveFormatLocale)} ${t('nutrientUnits.g')}`
        : '--',
      nrv: nrvText(nrv.value.fat) || undefined,
    },
  ]
})
</script>

<style scoped>
.summary-sheet {
  border: 1px solid rgba(var(--v-border-color), 0.12);
}
</style>

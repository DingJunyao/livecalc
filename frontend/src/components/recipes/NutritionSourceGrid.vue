<template>
  <v-card elevation="0" class="ma-4">
    <v-card-title class="d-flex align-center pb-2">
      <v-icon start color="success">mdi-food-apple-outline</v-icon>
      {{ t('recipes.nutritionSources') }}
      <v-spacer />
      <v-btn-toggle v-model="showAll" mandatory density="compact">
        <v-btn :value="false" size="small">{{ t('recipes.nrvMetrics') }}</v-btn>
        <v-btn :value="true" size="small">{{ t('recipes.all') }}</v-btn>
      </v-btn-toggle>
    </v-card-title>
    <v-divider />
    <v-card-text>
      <div v-if="loading" class="text-center py-8">
        <v-progress-circular indeterminate size="32" />
      </div>
      <div v-else-if="!displayNutrients.length" class="text-center py-8 text-medium-emphasis">
        <v-icon size="48" color="medium-emphasis">mdi-food-apple-outline</v-icon>
        <div class="text-body-2 mt-2">{{ t('recipes.noNutritionData') }}</div>
      </div>
      <div v-else class="nutrition-grid">
        <div
          v-for="nutrient in displayNutrients"
          :key="nutrient.key"
          class="nutrition-donut-card"
        >
          <div class="text-body-2 font-weight-medium text-center mb-1">{{ nutrient.label }}</div>
          <div :ref="el => setChartRef(nutrient.key, el as HTMLElement)" class="mini-donut" dir="ltr" />
          <div class="text-caption text-center text-medium-emphasis mt-1">{{ nutrient.totalText }}</div>
          <div class="text-caption text-center text-disabled">{{ nutrient.topContributors }}</div>
        </div>
      </div>
    </v-card-text>
  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, nextTick, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import { nutrientKey, nutrientLabel, nutrientUnitLabel } from '@/utils/nutritionLabels'
import { getIngredientColor } from '@/utils/ingredientColors'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  nutritionData?: any | null
  loading?: boolean
}>()

const { t, locale } = useI18n()
const localeStore = useLocaleStore()

const showAll = ref(false)
const chartRefs = new Map<string, HTMLElement>()
const chartInstances = new Map<string, echarts.ECharts>()

function setChartRef(key: string, el: HTMLElement | null) {
  if (el) chartRefs.set(key, el)
}

const NRV_KEYS = new Set([
  'energy', 'protein', 'fat', 'carbohydrate', 'fiber',
  'calcium', 'iron', 'sodium', 'potassium',
  'vitamin_a_rae', 'vitamin_c', 'vitamin_b1', 'vitamin_b2',
  'vitamin_b12', 'vitamin_d', 'vitamin_e', 'vitamin_k',
])


interface NutrientDisplay {
  key: string
  label: string
  totalValue: number
  unit: string
  nrpPct: number | null
  totalText: string
  topContributors: string
  items: { name: string; value: number; color: string }[]
}

const displayNutrients = computed<NutrientDisplay[]>(() => {
  const nutrition = props.nutritionData
  if (!nutrition?.ingredient_details?.length) return []

  const perServing = nutrition.per_serving_nutrition
  if (!perServing) return []

  const allNutrients = perServing.all_nutrients || perServing.core_nutrients || {}
  // core_nutrients 的条目有 key 字段（英文名）和 nrp_pct 值，构建查找映射
  const nrpPctMap: Record<string, number> = {}
  if (perServing.core_nutrients) {
    for (const [, cnData] of Object.entries(perServing.core_nutrients)) {
      const entry = cnData as any
      if (entry.key && entry.nrp_pct != null) {
        nrpPctMap[entry.key] = Math.round(entry.nrp_pct)
      }
    }
  }
  const result: NutrientDisplay[] = []
  const usedStableKeys = new Set<string>()

  for (const [key, data] of Object.entries(allNutrients)) {
    const nData = data as any
    if (!nData || nData.value === undefined || nData.value === null) continue

    const isNrv = NRV_KEYS.has(key)
    if (!showAll.value && !isNrv) continue

    const stableKey = nutrientKey(key) || key
    const label = nutrientKey(key) ? nutrientLabel(key) : (nData.name_zh || key)
    // "全部"模式下同名营养素只显示第一个（优先保留有 NRV 的）
    if (showAll.value && usedStableKeys.has(stableKey)) continue
    usedStableKeys.add(stableKey)
    const totalValue = typeof nData.value === 'number' ? nData.value : parseFloat(nData.value) || 0
    const unit = nData.unit || ''
    // all_nutrients 的 nrp_pct 为 null，从 core_nutrients 的 key 映射中查找
    const nrpPct = nData.nrp_pct != null ? Math.round(nData.nrp_pct) : (nrpPctMap[key] ?? null)
    const totalText = `${formatNumber(totalValue, localeStore.effectiveFormatLocale)}${unit ? ` ${nutrientUnitLabel(unit)}` : ''}`

    const ingredientItems: { name: string; value: number; color: string }[] = []
    for (const detail of nutrition.ingredient_details) {
      const contributions = detail.nutrition_contribution || {}
      const contributionKey = Object.keys(contributions).find(
        candidate => candidate === key || nutrientKey(candidate) === stableKey,
      )
      const contrib = contributionKey ? contributions[contributionKey] : null
      if (contrib && contrib.value != null && Number(contrib.value) > 0) {
        ingredientItems.push({
          name: detail.ingredient_name || t('recipes.unknownIngredient'),
          value: Number(contrib.value) || 0,
          color: getIngredientColor(detail.ingredient_id),
        })
      }
    }

    if (!ingredientItems.length) continue

    ingredientItems.sort((a, b) => b.value - a.value)
    const totalIngredientValue = ingredientItems.reduce((s, i) => s + i.value, 0)
    const top2 = ingredientItems.slice(0, 2)
    const topContributors = top2
      .map(i => `${i.name} ${formatNumber(Math.round((i.value / totalIngredientValue) * 100), localeStore.effectiveFormatLocale)}%`)
      .join(' · ')

    result.push({
      key: stableKey,
      label,
      totalValue,
      unit,
      nrpPct,
      totalText,
      topContributors,
      items: ingredientItems,
    })
  }

  // 与菜谱详情页营养素成分排序保持一致
  const nutrientSortOrder = [
    'nutrients.energy', 'nutrients.protein', 'nutrients.fat', 'nutrients.carbohydrate', 'nutrients.sodium',
    'nutrients.fiber', 'nutrients.calcium', 'nutrients.iron', 'nutrients.potassium',
    'nutrients.vitaminA', 'nutrients.vitaminB1', 'nutrients.vitaminB2', 'nutrients.vitaminB12', 'nutrients.vitaminC',
    'nutrients.vitaminD', 'nutrients.vitaminE', 'nutrients.vitaminK'
  ]
  result.sort((a, b) => {
    const idxA = nutrientSortOrder.indexOf(a.key)
    const idxB = nutrientSortOrder.indexOf(b.key)
    if (idxA !== -1 && idxB !== -1) return idxA - idxB
    if (idxA !== -1) return -1
    if (idxB !== -1) return 1
    return (a.label || '').localeCompare(b.label || '')
  })

  return result
})

function renderDonuts() {
  for (const nutrient of displayNutrients.value) {
    const el = chartRefs.get(nutrient.key)
    if (!el) continue

    let instance = chartInstances.get(nutrient.key)
    if (!instance) {
      instance = echarts.init(el)
      chartInstances.set(nutrient.key, instance)
    }

    instance.setOption({
      rtl: false,
      tooltip: {
        trigger: 'item',
        extraCssText: 'direction:ltr;',
        formatter: (p: any) => {
          const pct = p.percent != null ? `${Math.round(p.percent)}%` : ''
          return `<b>${p.name}</b><br/>${nutrient.label}: ${formatNumber(p.value, localeStore.effectiveFormatLocale, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${nutrientUnitLabel(nutrient.unit)}${pct ? ' (' + pct + ')' : ''}`
        },
      },
      series: [{
        type: 'pie',
        radius: ['50%', '75%'],
        center: ['50%', '50%'],
        label: { show: false },
        emphasis: { scale: false },
        itemStyle: {
          borderRadius: 2,
          borderColor: '#fff',
          borderWidth: 1,
        },
        data: nutrient.items.map(i => ({
          name: i.name,
          value: i.value,
          itemStyle: { color: i.color },
        })),
      }],
      graphic: [{
        type: 'text',
        left: 'center',
        top: '48%',
        style: {
          text: nutrient.nrpPct != null ? `${nutrient.nrpPct}%` : '',
          textAlign: 'center' as const,
          fill: '#666',
          fontSize: 11,
          fontWeight: 'bold' as const,
        },
        z: 100,
      }],
    }, true)
  }
}

watch(showAll, () => nextTick(renderDonuts))
watch(() => [locale.value, localeStore.effectiveFormatLocale], () => {
  nextTick(renderDonuts)
})
watch(() => [props.nutritionData, props.loading], () => {
  nextTick(() => {
    if (!props.loading && displayNutrients.value.length) renderDonuts()
  })
}, { deep: true })

onMounted(() => {
  nextTick(() => {
    if (!props.loading && displayNutrients.value.length) renderDonuts()
  })
})

onMounted(() => window.addEventListener('resize', () => {
  chartInstances.forEach(c => c.resize())
}))
onUnmounted(() => {
  window.removeEventListener('resize', () => {
    chartInstances.forEach(c => c.resize())
  })
  chartInstances.forEach(c => c.dispose())
  chartInstances.clear()
})
</script>

<style scoped>
.nutrition-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 16px;
}
.nutrition-donut-card {
  border-radius: 8px;
  padding: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.mini-donut {
  width: 120px;
  height: 120px;
}
@media (max-width: 599px) {
  .nutrition-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  .mini-donut {
    width: 100px;
    height: 100px;
  }
}
</style>

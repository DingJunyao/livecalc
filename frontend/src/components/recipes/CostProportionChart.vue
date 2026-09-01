<template>
  <v-card elevation="0" class="ma-4">
    <v-card-title class="d-flex align-center pb-2">
      <v-icon start color="tertiary">mdi-chart-pie</v-icon>
      {{ t('recipes.ingredientCostShare') }}
    </v-card-title>
    <v-divider />
    <v-card-text>
      <div v-if="loading" class="text-center py-8">
        <v-progress-circular indeterminate size="32" />
      </div>
      <div v-else-if="!chartData.length" class="text-center py-8 text-medium-emphasis">
        <v-icon size="48" color="medium-emphasis">mdi-chart-pie</v-icon>
        <div class="text-body-2 mt-2">{{ t('recipes.noCostData') }}</div>
      </div>
      <div v-else ref="chartRef" class="cost-proportion-chart" style="width:100%;height:320px" />
    </v-card-text>
  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch, nextTick, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import { getIngredientColor } from '@/utils/ingredientColors'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { formatMoney } from '@/utils/currency'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  costBreakdown?: any[] | null
  totalCost?: number | string | null
  loading?: boolean
}>()

const chartRef = ref<HTMLElement | null>(null)
let chartInstance: echarts.ECharts | null = null

const { currency: userCurrency } = useUserCurrency()
const { t } = useI18n()

interface ChartItem {
  name: string
  value: number
  itemStyle: { color: string }
}

const chartData = computed<ChartItem[]>(() => {
  const breakdown = props.costBreakdown
  if (!breakdown?.length) return []

  const items: ChartItem[] = breakdown
    .map((b: any) => ({
      name: b.ingredient_name || t('recipes.unknownIngredient'),
      value: parseFloat(b.cost) || 0,
      itemStyle: { color: getIngredientColor(b.ingredient_id) },
    }))
    // 按成本降序排列，确保高成本食材始终在前
    .sort((a, b) => b.value - a.value)

  if (items.length > 6) {
    const top5 = items.slice(0, 5)
    const otherValue = items.slice(5).reduce((s, i) => s + i.value, 0)
    top5.push({
      name: t('recipes.other'),
      value: otherValue,
      itemStyle: { color: '#e0e0e0' },
    })
    return top5
  }
  return items
})

const totalCostDisplay = computed(() => {
  if (props.totalCost !== null && props.totalCost !== undefined) {
    return formatMoney(parseFloat(String(props.totalCost)), userCurrency.value)
  }
  const total = chartData.value.reduce((s, i) => s + i.value, 0)
  return formatMoney(total, userCurrency.value)
})

function renderChart() {
  if (!chartRef.value || !chartData.value.length) return

  if (!chartInstance) {
    chartInstance = echarts.init(chartRef.value)
  }

  chartInstance.setOption({
    rtl: false,
    tooltip: {
      trigger: 'item',
      extraCssText: 'direction:ltr;',
      formatter: (p: any) => `${p.name}: ${formatMoney(p.value, userCurrency.value)} (${p.percent}%)`,
    },
    series: [{
      type: 'pie',
      radius: ['40%', '70%'],
      center: ['50%', '50%'],
      avoidLabelOverlap: true,
      itemStyle: {
        borderRadius: 4,
        borderColor: '#fff',
        borderWidth: 2,
      },
      label: {
        show: true,
        formatter: (p: any) => `{b|${p.name}}\n{c|${formatMoney(p.value, userCurrency.value)}} {per|${p.percent}%}`,
        rich: {
          b: { fontSize: 12, lineHeight: 20 },
          c: { fontSize: 13, fontWeight: 'bold' as const },
          per: { fontSize: 11, color: '#999' },
        },
      },
      emphasis: {
        label: { show: true, fontSize: 14, fontWeight: 'bold' as const },
      },
      data: chartData.value,
    }],
    graphic: [{
      type: 'text',
      left: 'center',
      top: 'center',
      style: {
        text: totalCostDisplay.value,
        textAlign: 'center' as const,
        fill: '#333',
        fontSize: 20,
        fontWeight: 'bold' as const,
      },
      z: 100,
    }],
  }, true)
}

watch(() => [props.costBreakdown, props.loading], () => {
  nextTick(() => {
    if (!props.loading) renderChart()
  })
}, { deep: true })

onMounted(() => {
  nextTick(() => { if (!props.loading) renderChart() })
})

onMounted(() => window.addEventListener('resize', () => chartInstance?.resize()))
onUnmounted(() => {
  window.removeEventListener('resize', () => chartInstance?.resize())
  chartInstance?.dispose()
  chartInstance = null
})
</script>

<style scoped>
.cost-proportion-chart :deep(canvas) {
  outline: none;
}
</style>

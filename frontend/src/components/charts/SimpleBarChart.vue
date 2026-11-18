<template>
  <div ref="chartEl" class="simple-bar-chart" />
</template>

<script setup lang="ts">
// 简单横向柱状图（ECharts 按需注册）：用于物价指数等地区间对比。
// 与 PriceTrendChart 的 echarts/core 按需注册方式一致，避免引入全量包。
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import * as echarts from 'echarts/core'
import { BarChart } from 'echarts/charts'
import { GridComponent, TooltipComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([BarChart, GridComponent, TooltipComponent, CanvasRenderer])

export interface SimpleBarItem {
  label: string
  value: number | null
}

const props = withDefaults(defineProps<{
  items?: SimpleBarItem[]
  /** 数值格式化（如 price index 保留 1 位小数） */
  formatValue?: (v: number) => string
  /** 基准项 label（值恒为 100，用不同颜色） */
  baseLabel?: string
  height?: number
}>(), {
  items: () => [],
  formatValue: (v: number) => String(Math.round(v * 10) / 10),
  baseLabel: '',
  height: 260,
})

const chartEl = ref<HTMLDivElement | null>(null)
let chart: echarts.ECharts | null = null

function render() {
  if (!chartEl.value) return
  if (!chart) chart = echarts.init(chartEl.value)
  const items = [...props.items].filter(x => x.value != null).sort((a, b) => (b.value as number) - (a.value as number))
  if (!items.length) {
    chart.clear()
    return
  }
  const colors = items.map(x => (props.baseLabel && x.label === props.baseLabel ? '#42b883' : '#5c8ecb'))
  chart.setOption({
    grid: { left: 8, right: 48, top: 8, bottom: 8, containLabel: true },
    tooltip: {
      trigger: 'item',
      formatter: (p: any) => `${p.name}: ${props.formatValue(Number(p.value))}`,
    },
    xAxis: { type: 'value', splitLine: { show: false }, axisLabel: { show: false } },
    yAxis: {
      type: 'category',
      data: items.map(x => x.label),
      inverse: true,
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: {
        width: 110,
        overflow: 'truncate',
        formatter: (name: string) => name,
      },
    },
    series: [{
      type: 'bar',
      data: items.map((x, i) => ({ value: x.value, itemStyle: { color: colors[i], borderRadius: [0, 4, 4, 0] } })),
      label: {
        show: true,
        position: 'right',
        formatter: (p: any) => props.formatValue(Number(p.value)),
      },
      barMaxWidth: 22,
    }],
  }, true)
}

const resize = () => chart?.resize()

onMounted(() => {
  render()
  window.addEventListener('resize', resize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', resize)
  chart?.dispose()
  chart = null
})

watch(() => [props.items, props.baseLabel], () => render(), { deep: true })
</script>

<style scoped>
.simple-bar-chart {
  width: 100%;
  min-height: 160px;
}
</style>

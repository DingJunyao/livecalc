<template>
  <v-card elevation="0" class="price-trend-chart">
    <v-card-title class="d-flex align-center flex-wrap pb-2">
      <v-icon start :color="iconColor">{{ icon }}</v-icon>
      {{ chartTitle }}
      <v-spacer />
      <!-- 对比模式切换：仅在传入 ≥2 条商家序列时显示 -->
      <v-btn-toggle
        v-if="hasComparison"
        v-model="viewMode"
        mandatory
        density="compact"
        variant="outlined"
        divided
        class="filter-buttons me-2"
      >
        <v-btn value="avg" size="small">{{ t('charts.overall') }}</v-btn>
        <v-btn value="merchant" size="small">{{ t('charts.byMerchant') }}</v-btn>
      </v-btn-toggle>
      <!-- 折算序列开关（替代/回退/半成品/从属）：有折算数据时才出现，默认打开 -->
      <v-switch
        v-if="hasComputed"
        v-model="includeComputed"
        :label="t('charts.includeComputed')"
        density="compact"
        hide-details
        color="primary"
        class="computed-switch me-2"
      />
      <v-btn-toggle
        v-model="selectedFilter"
        mandatory
        density="compact"
        variant="outlined"
        divided
        class="filter-buttons"
      >
        <v-btn
          v-for="filter in filters"
          :key="filter.value"
          :value="filter.value"
          size="small"
        >
          {{ filter.label }}
        </v-btn>
      </v-btn-toggle>
    </v-card-title>
    <v-divider />

    <!-- 按商家模式：商家多选 chips（默认选前 3 家，避免线条过多） -->
    <div v-if="hasComparison && viewMode === 'merchant'" class="merchant-chips px-4 pt-2">
      <v-chip-group
        v-model="selectedMerchantIds"
        multiple
        column
        density="compact"
        selected-class="text-primary"
      >
        <v-chip
          v-for="s in comparisonSeries"
          :key="String(s.merchantId)"
          :value="s.merchantId"
          size="small"
          filter
          variant="outlined"
        >
          <template #prepend>
            <span
              class="merchant-dot"
              :style="{ backgroundColor: merchantColor(s.merchantId) }"
            />
          </template>
          {{ s.name }}
        </v-chip>
      </v-chip-group>
    </div>

    <div class="chart-area" style="position: relative; min-height: 300px">
      <!-- 加载中覆盖层（不销毁图表 DOM） -->
      <div
        v-if="loading"
        class="d-flex align-center justify-center"
        style="position: absolute; inset: 0; z-index: 1; background: rgba(var(--v-theme-surface), 0.8);"
      >
        <v-progress-circular indeterminate color="primary" size="48" />
      </div>

      <!-- 无数据（仅在非加载且无数据时显示） -->
      <div
        v-if="!loading && displayEmpty"
        class="text-center py-12"
      >
        <v-icon size="64" color="medium-emphasis">mdi-chart-line</v-icon>
        <div class="text-body-1 text-medium-emphasis mt-4">{{ emptyMessage }}</div>
      </div>

      <!-- 图表（一旦有数据就始终渲染，DOM 不被销毁） -->
      <template v-if="hasEverHadData || !displayEmpty">

        <div ref="chartRef" class="chart-container" dir="ltr"></div>
      </template>
    </div>
  </v-card>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, onBeforeUnmount, nextTick, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useLocaleStore } from '@/stores/locale'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { formatMoney } from '@/utils/currency'
import { formatDate } from '@/utils/format'
import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import { TitleComponent, TooltipComponent, GridComponent } from 'echarts/components'
import { UniversalTransition } from 'echarts/features'
import { CanvasRenderer } from 'echarts/renderers'
import type { EChartsOption } from 'echarts'

// 注册 ECharts 组件
echarts.use([
  LineChart,
  TitleComponent,
  TooltipComponent,
  GridComponent,
  UniversalTransition,
  CanvasRenderer
])

interface DataPoint {
  date: string
  min: number
  max: number
  avg: number
  count?: number
  /** 该日是否真实有价格记录；false = as-of 携带日（按商家模式不画点，只连线） */
  recorded?: boolean
  /** 折算来源：direct/fallback/name_match/recipe/contains_aggregation（computedSeries 用） */
  source?: string
  /** 折算链路说明，如「酱油 → 生抽」 */
  chain?: string | null
}

/** 按商家对比：一条商家序列（与主序列同口径的逐日 as-of 数据） */
export interface MerchantSeries {
  merchantId: number | null
  name: string
  data: DataPoint[]
}

const props = withDefaults(defineProps<{
  title?: string
  icon?: string
  iconColor?: string
  unit?: string
  emptyText?: string
  data: DataPoint[]
  loading?: boolean
  color?: string
  avgLabel?: string
  countLabel?: string
  /** 商家对比序列；≥2 条时显示「综合/按商家」切换 */
  comparisonSeries?: MerchantSeries[]
  /**
   * 按菜谱成本降级链折算出来的价格（替代/回退/半成品/从属）。
   * 只用于「该原料自己没有直接商品价」的日子；非空时显示「含替代/从属」开关（默认开）。
   */
  computedSeries?: DataPoint[]
  /** 折算序列图例名（默认 charts.computedPrice） */
  computedTitle?: string
}>(), {
  icon: 'mdi-chart-line',
  iconColor: 'primary',
  unit: '',
  loading: false,
  color: '#42b883',
  comparisonSeries: () => [],
  computedSeries: () => [],
  computedTitle: undefined
})
const { t, locale } = useI18n()
const localeStore = useLocaleStore()

const emit = defineEmits<{
  'filter-change': [filter: 'week' | 'month' | 'quarter' | 'year' | 'all']
}>()

const chartRef = ref<HTMLElement>()
let chart: echarts.ECharts | null = null

const { currency: userCurrency } = useUserCurrency()

// 是否曾经有过数据（一旦为 true，图表 DOM 不再销毁）
const hasEverHadData = ref(false)

const selectedFilter = ref<'week' | 'month' | 'quarter' | 'year' | 'all'>('month')

// ---- 按商家对比模式 ----
const viewMode = ref<'avg' | 'merchant'>('avg')
const selectedMerchantIds = ref<Array<number | null>>([])

const hasComparison = computed(() => (props.comparisonSeries?.length ?? 0) >= 2)

// 商家固定色板（与主序列色区分）
const MERCHANT_COLORS = ['#3b82f6', '#f59e0b', '#ef4444', '#8b5cf6', '#14b8a6', '#ec4899', '#84cc16', '#f97316']
const merchantColor = (merchantId: number | null): string => {
  const idx = props.comparisonSeries.findIndex((s) => s.merchantId === merchantId)
  return MERCHANT_COLORS[((idx < 0 ? 0 : idx) % MERCHANT_COLORS.length)]
}

// 商家序列按同一时间区间切片（与主序列口径一致）
const sliceByFilter = (points: DataPoint[]): DataPoint[] => {  if (!points || points.length === 0) return []
  if (selectedFilter.value === 'all') {
    return [...points].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
  }
  const startDate = new Date()
  switch (selectedFilter.value) {
    case 'week': startDate.setDate(startDate.getDate() - 7); break
    case 'month': startDate.setMonth(startDate.getMonth() - 1); break
    case 'quarter': startDate.setMonth(startDate.getMonth() - 3); break
    case 'year': startDate.setFullYear(startDate.getFullYear() - 1); break
  }
  return points
    .filter((d) => new Date(d.date) >= startDate)
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
}

// ---- 折算序列（替代 / 回退 / 半成品 / 从属；与菜谱成本同一降级链）----
// 只在「该原料自己没有直接商品价」的日子有数据；开关默认打开。
const includeComputed = ref(true)
const hasComputed = computed(() => (props.computedSeries?.length ?? 0) > 0)
const computedLabel = computed(() => props.computedTitle ?? t('charts.computedPrice'))
const computedData = computed<DataPoint[]>(() => {
  if (!hasComputed.value || !includeComputed.value) return []
  // 按商家模式不叠加折算序列（商家维度没有该口径）
  if (hasComparison.value && viewMode.value === 'merchant') return []
  return sliceByFilter(props.computedSeries ?? [])
})

// 按商家模式下实际绘制的序列（选中且区间内有数据的）
const visibleMerchantSeries = computed(() => {
  if (!hasComparison.value || viewMode.value !== 'merchant') return []
  const selected = new Set(selectedMerchantIds.value)
  return props.comparisonSeries
    .filter((s) => selected.has(s.merchantId))
    .map((s) => ({ ...s, data: sliceByFilter(s.data) }))
    .filter((s) => s.data.length > 0)
})

// 切到按商家模式 / 商家集合变化时：默认勾选「记录数最多」的前 3 家（避免全画太乱）。
// 注意：时间区间切换会让父页面累积加载记录、序列引用变化，但商家 id 集合不变
// → 此时保留用户已勾选的商家（仅剔除已不存在的 id），不能重置回默认。
const merchantIdsSignature = (list: MerchantSeries[]): string =>
  list.map((s) => String(s.merchantId)).sort().join(',')

const lastMerchantSignature = ref('')

watch([viewMode, () => props.comparisonSeries], ([mode]) => {
  if (!hasComparison.value) {
    if (mode === 'merchant') viewMode.value = 'avg'
    return
  }
  if (mode !== 'merchant') return
  const series = props.comparisonSeries
  const signature = merchantIdsSignature(series)
  // 勾选中仍有效的 id（剔除已消失的商家）
  const validSelection = selectedMerchantIds.value.filter((id) =>
    series.some((s) => s.merchantId === id),
  )
  // 商家集合没变（仅数据刷新 / 区间加载）且有有效勾选 → 保持原选取
  if (signature === lastMerchantSignature.value && validSelection.length > 0) {
    selectedMerchantIds.value = validSelection
    return
  }
  lastMerchantSignature.value = signature
  const ranked = [...series]
    .map((s) => ({ id: s.merchantId, count: s.data.reduce((acc, d) => acc + (d.count ?? 1), 0) }))
    .sort((a, b) => b.count - a.count)
  selectedMerchantIds.value = ranked.slice(0, 3).map((r) => r.id)
})

const chartTitle = computed(() => props.title ?? t('charts.priceTrend'))
const emptyMessage = computed(() => props.emptyText ?? t('charts.noData'))
const averageLabel = computed(() => props.avgLabel ?? t('charts.average'))
const countLabel = computed(() => props.countLabel ?? t('charts.recordCount'))
const filters = computed(() => [
  { label: t('recipes.week'), value: 'week' as const },
  { label: t('recipes.month'), value: 'month' as const },
  { label: t('recipes.quarter'), value: 'quarter' as const },
  { label: t('recipes.year'), value: 'year' as const },
  { label: t('recipes.all'), value: 'all' as const }
])

// 单位后缀
const unitSuffix = computed(() => props.unit ? ` / ${props.unit}` : '')

// 日期 → 本地时间戳：date 为 YYYY-MM-DD，按本地午夜解析，
// 保证 X 轴按真实天数间隔分布且格式化回显的日期跨时区稳定
const toTimestamp = (date: string): number => new Date(`${date}T00:00:00`).getTime()

// 过滤数据
const chartData = computed(() => sliceByFilter(props.data ?? []))

// 当前展示是否为空（按商家模式看选中序列，否则看主序列 + 折算序列）
const displayEmpty = computed(() => {
  if (hasComparison.value && viewMode.value === 'merchant') {
    return visibleMerchantSeries.value.length === 0
  }
  return chartData.value.length === 0 && computedData.value.length === 0
})

// 按需「初始化或重绘」。
// 图表容器由 v-if 控制：首帧没有数据时 DOM 不存在，onMounted 的 initChart 拿不到
// ref → 之后数据（尤其是只有折算序列、没有直接价时）到达，必须在这里补 init，
// 否则 ECharts 从未初始化，图表区域一片空白。
function renderOrInit() {
  if (!chart) {
    if (chartRef.value) initChart()
    return
  }
  updateChart()
}

// 模式 / 商家勾选变化 → 重绘（勾选为空时显示空态）
watch([viewMode, selectedMerchantIds, () => props.comparisonSeries], () => {
  nextTick(renderOrInit)
}, { deep: true })

// 监听筛选变化
watch(selectedFilter, (newFilter) => {
  emit('filter-change', newFilter)
  nextTick(renderOrInit)
})

// 初始化图表
function initChart() {
  if (!chartRef.value) return

  chart = echarts.init(chartRef.value)
  updateChart()

  window.addEventListener('resize', handleResize)
}

// 更新图表
function updateChart() {
  if (!chart) return

  // 按商家对比模式：每个选中商家一条线
  if (hasComparison.value && viewMode.value === 'merchant') {
    const series = visibleMerchantSeries.value
    if (series.length === 0) {
      chart.clear()
      return
    }
    chart.setOption(buildMerchantOption(series), true)
    return
  }

  // 如果没有数据（含折算序列），清空图表
  const computedPoints = computedData.value
  if (chartData.value.length === 0 && computedPoints.length === 0) {
    chart.clear()
    return
  }

  const data = chartData.value
  const allMins = [...data, ...computedPoints].map(d => Number(d.min))
  const minValue = allMins.length ? Math.min(...allMins) : 0
  const base = Math.min(0, minValue - 0.1)

  // 只有一个数据点（实体只有一次价格记录、区间又拿不到更早的携带起点）时：
  // time 轴的 dataMin/dataMax 是同一时刻 → 点被压在轴边缘、几乎看不出图表。
  // 左右各撑开半天，让唯一的数据点落在中间并显示日期刻度。
  const datePoints = [...data, ...computedPoints]
  const singlePoint = datePoints.length === 1
  const singleTs = singlePoint ? toTimestamp(datePoints[0].date) : 0
  const HALF_DAY_MS = 12 * 60 * 60 * 1000

  // 折算来源文案（fallback/name_match/recipe/contains_aggregation）
  const sourceLabel = (source?: string): string => {
    switch (source) {
      case 'fallback': return t('charts.sourceFallback')
      case 'name_match': return t('charts.sourceNameMatch')
      case 'recipe': return t('charts.sourceRecipe')
      case 'contains_aggregation': return t('charts.sourceContains')
      default: return t('charts.sourceDirect')
    }
  }

  const option: EChartsOption = {
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'cross',
        animation: false,
        label: {
          backgroundColor: props.color,
          borderColor: props.color,
          borderWidth: 1,
          color: '#fff'
        }
      },
      formatter: (params: any) => {
        const list = Array.isArray(params) ? params : [params]
        const ts = list[0]?.axisValue ?? (Array.isArray(list[0]?.value) ? list[0].value[0] : null)
        if (ts == null) return ''

        const direct = data.find(d => toTimestamp(d.date) === ts)
        const computedPoint = computedPoints.find(d => toTimestamp(d.date) === ts)
        if (!direct && !computedPoint) return ''

        const dateStr = formatDate(ts, localeStore.effectiveFormatLocale)
        const rows: string[] = []
        if (direct) {
          rows.push(`
            <div style="display: flex; align-items: center; gap: 8px;">
              <span style="display: inline-block; width: 12px; height: 12px; border-radius: 50%; background-color: ${props.color};"></span>
              <span>${averageLabel.value}: ${formatMoney(direct.avg, userCurrency.value)}${unitSuffix.value}</span>
            </div>
            <div style="display: flex; align-items: center; gap: 8px; margin-top: 4px;">
              <span style="display: inline-block; width: 12px; height: 12px; background-color: ${props.color}33; border-radius: 2px;"></span>
              <span>${t('charts.range')}: ${formatMoney(direct.min, userCurrency.value)} - ${formatMoney(direct.max, userCurrency.value)}${unitSuffix.value}</span>
            </div>
            ${direct.count ? `<div style="margin-top: 4px; color: #999; font-size: 12px;">${countLabel.value}: ${direct.count}</div>` : ''}
          `)
        }
        if (computedPoint) {
          const chainText = computedPoint.chain ? `（${computedPoint.chain}）` : ''
          const hasRange = Number(computedPoint.max) > Number(computedPoint.min) + 1e-9
          rows.push(`
            <div style="display: flex; align-items: center; gap: 8px; margin-top: 4px;">
              <span style="display: inline-block; width: 12px; height: 12px; border-radius: 2px; background-color: #7e57c2;"></span>
              <span>${computedLabel.value}: ${formatMoney(computedPoint.avg, userCurrency.value)}${unitSuffix.value}</span>
            </div>
            ${hasRange ? `<div style="margin-top: 2px; color: #666; font-size: 12px;">${t('charts.range')}: ${formatMoney(computedPoint.min, userCurrency.value)} - ${formatMoney(computedPoint.max, userCurrency.value)}${unitSuffix.value}</div>` : ''}
            <div style="margin-top: 2px; color: #999; font-size: 12px;">${sourceLabel(computedPoint.source)}${chainText}</div>
          `)
        }
        return `<div style="padding: 8px 12px;"><div style="font-weight: 600; margin-bottom: 8px;">${dateStr}</div>${rows.join('')}</div>`
      }
    },
    grid: {
      left: '5%',
      right: '4%',
      bottom: '10%',
      containLabel: true
    },
    xAxis: {
      type: 'time',
      // 按真实日期时间分布：记录点之间的距离随天数变化，而非等距排列
      min: singlePoint ? singleTs - HALF_DAY_MS : 'dataMin',
      max: singlePoint ? singleTs + HALF_DAY_MS : 'dataMax',
      axisLabel: {
        hideOverlap: true,
        formatter: (value: number) => {
          return formatDate(value, localeStore.effectiveFormatLocale, {
            month: '2-digit',
            day: '2-digit',
          })
        }
      },
      axisPointer: {
        label: {
          formatter: (params: any) => {
            return formatDate(params.value, localeStore.effectiveFormatLocale)
          }
        }
      },
      splitLine: {
        show: false
      }
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: (value: number) => formatMoney(value, userCurrency.value)
      },
      splitLine: {
        lineStyle: {
          type: 'dashed',
          color: '#e5e5e5'
        }
      },
      axisPointer: {
        label: {
          formatter: (params: any) => {
            return `${formatMoney(params.value, userCurrency.value)}${unitSuffix.value}`
          }
        }
      }
    },
    series: [
      // 下限线（透明，用于堆叠）
      {
        name: 'L',
        type: 'line',
        data: data.map(d => [toTimestamp(d.date), d.min - base]),
        lineStyle: { opacity: 0 },
        stack: 'confidence-band',
        symbol: 'none',
        showSymbol: false
      },
      // 上限区域（置信区间带）
      {
        name: 'U',
        type: 'line',
        data: data.map(d => [toTimestamp(d.date), d.max - d.min]),
        lineStyle: { opacity: 0 },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0, y: 0, x2: 0, y2: 1,
            colorStops: [
              { offset: 0, color: `${props.color}66` },
              { offset: 1, color: `${props.color}1a` }
            ]
          }
        },
        stack: 'confidence-band',
        symbol: 'none',
        showSymbol: false
      },
      // 平均值线（仅真实有记录的日子画点；as-of 携带日只连线）
      {
        name: props.avgLabel,
        type: 'line',
        data: data.map(d => ({
          value: [toTimestamp(d.date), d.avg],
          symbolSize: d.recorded === false ? 0 : 6,
        })),
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: {
          color: props.color,
          width: 2.5
        },
        itemStyle: {
          color: props.color,
          borderColor: '#fff',
          borderWidth: 2
        },
        emphasis: {
          scale: true,
          itemStyle: {
            color: props.color,
            borderColor: '#fff',
            borderWidth: 3,
            shadowBlur: 10,
            shadowColor: `${props.color}80`
          }
        }
      },
      // 折算序列（替代/回退/半成品/从属）：虚线 + 区间带，与直接商品价区分
      ...(computedPoints.length > 0
        ? [
            {
              name: '\u0000computed-lower',
              type: 'line' as const,
              data: computedPoints.map(d => [toTimestamp(d.date), d.min - base]),
              lineStyle: { opacity: 0 },
              stack: 'computed-band',
              symbol: 'none',
              showSymbol: false
            },
            {
              name: '\u0000computed-upper',
              type: 'line' as const,
              data: computedPoints.map(d => [toTimestamp(d.date), Math.max(0, d.max - d.min)]),
              lineStyle: { opacity: 0 },
              stack: 'computed-band',
              symbol: 'none',
              showSymbol: false,
              areaStyle: { color: '#7e57c2', opacity: 0.12 }
            },
            {
              name: computedLabel.value,
              type: 'line' as const,
              data: computedPoints.map(d => [toTimestamp(d.date), d.avg]),
              smooth: true,
              symbol: 'none',
              lineStyle: { color: '#7e57c2', width: 2, type: 'dashed' },
              itemStyle: { color: '#7e57c2' },
              z: 3
            }
          ]
        : [])
    ]
  }

  chart.setOption(option, true)
}

// 按商家对比模式的 ECharts 配置：每个商家一条均价线；
// 该商家当天有多个商品价（min<max）时，额外画一条淡色区间带。
function buildMerchantOption(series: Array<MerchantSeries & { data: DataPoint[] }>): EChartsOption {
  const singlePoint = series.every((s) => s.data.length === 1)
  const allDates = series.flatMap((s) => s.data.map((d) => d.date))
  const singleTs = singlePoint && allDates.length > 0 ? toTimestamp(allDates[0]) : 0
  const HALF_DAY_MS = 12 * 60 * 60 * 1000

  // 区间带的堆叠底座：所有选中序列的全局最小值（同一底座保证带子位置正确）
  const allMins = series.flatMap((s) => s.data.map((d) => d.min))
  const bandBase = allMins.length ? Math.min(0, Math.min(...allMins) - 0.1) : 0

  // 哪些商家需要区间带（当天存在 min < max）
  const hasBand = new Map<number | null, boolean>()
  for (const s of series) {
    hasBand.set(s.merchantId, s.data.some((d) => Number(d.max) > Number(d.min) + 1e-9))
  }

  const bandSeries: any[] = []
  const bandNames = new Set<string>()
  for (const s of series) {
    if (!hasBand.get(s.merchantId)) continue
    const color = merchantColor(s.merchantId)
    // 用 \u0000 前缀避免与真实商家名冲突，也便于 tooltip 过滤
    const lowerName = `\u0000band-lower-${s.merchantId}`
    const upperName = `\u0000band-upper-${s.merchantId}`
    bandNames.add(lowerName)
    bandNames.add(upperName)
    bandSeries.push(
      {
        name: lowerName,
        type: 'line',
        data: s.data.map((d) => [toTimestamp(d.date), Number(d.min) - bandBase]),
        lineStyle: { opacity: 0 },
        symbol: 'none',
        showSymbol: false,
        stack: `merchant-band-${s.merchantId}`,
        z: 1,
      },
      {
        name: upperName,
        type: 'line',
        data: s.data.map((d) => [toTimestamp(d.date), Math.max(0, Number(d.max) - Number(d.min))]),
        lineStyle: { opacity: 0 },
        symbol: 'none',
        showSymbol: false,
        stack: `merchant-band-${s.merchantId}`,
        areaStyle: { color, opacity: 0.15 },
        z: 1,
      },
    )
  }

  // 商家名 → 序列数据：tooltip 里补「区间」数值
  const seriesByName = new Map(series.map((s) => [s.name, s]))

  return {
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'line' },
      formatter: (params: any) => {
        const list = (Array.isArray(params) ? params : [params])
          .filter((p: any) => !bandNames.has(p.seriesName))
        if (list.length === 0) return ''
        const dateStr = formatDate(list[0].value[0], localeStore.effectiveFormatLocale)
        const rows = list.map((p: any) => {
          const value = Array.isArray(p.value) ? p.value[1] : p.value
          const color = p.color ?? '#888'
          // 当天区间（有多个商品价时展示「min – max」）
          const s = seriesByName.get(p.seriesName)
          const ts = Array.isArray(p.value) ? p.value[0] : null
          const point = s && ts != null
            ? s.data.find((d) => toTimestamp(d.date) === ts)
            : undefined
          const rangeText = point && Number(point.max) > Number(point.min) + 1e-9
            ? ` <span style="color:#999;">(${formatMoney(point.min, userCurrency.value)} – ${formatMoney(point.max, userCurrency.value)})</span>`
            : ''
          return `
            <div style="display: flex; align-items: center; gap: 8px; margin-top: 2px;">
              <span style="display: inline-block; width: 10px; height: 10px; border-radius: 50%; background-color: ${color};"></span>
              <span>${p.seriesName}: ${formatMoney(value, userCurrency.value)}${unitSuffix.value}${rangeText}</span>
            </div>
          `
        }).join('')
        return `<div style="padding: 8px 12px;"><div style="font-weight: 600; margin-bottom: 6px;">${dateStr}</div>${rows}</div>`
      }
    },
    grid: {
      left: '5%',
      right: '4%',
      bottom: '10%',
      containLabel: true
    },
    xAxis: {
      type: 'time',
      min: singlePoint ? singleTs - HALF_DAY_MS : 'dataMin',
      max: singlePoint ? singleTs + HALF_DAY_MS : 'dataMax',
      axisLabel: {
        hideOverlap: true,
        formatter: (value: number) =>
          formatDate(value, localeStore.effectiveFormatLocale, { month: '2-digit', day: '2-digit' })
      },
      axisPointer: {
        label: { formatter: (params: any) => formatDate(params.value, localeStore.effectiveFormatLocale) }
      },
      splitLine: { show: false }
    },
    yAxis: {
      type: 'value',
      axisLabel: { formatter: (value: number) => formatMoney(value, userCurrency.value) },
      splitLine: { lineStyle: { type: 'dashed', color: '#e5e5e5' } },
      axisPointer: {
        label: { formatter: (params: any) => `${formatMoney(params.value, userCurrency.value)}${unitSuffix.value}` }
      }
    },
    series: [
      ...bandSeries,
      ...series.map((s) => ({
        name: s.name,
        type: 'line' as const,
        // 仅「当日真实有记录」的日子画点；as-of 携带日只连线（symbolSize 0）
        data: s.data.map((d) => ({
          value: [toTimestamp(d.date), d.avg],
          symbolSize: d.recorded === false ? 0 : 5,
        })),
        smooth: true,
        symbol: 'circle',
        symbolSize: 5,
        lineStyle: { color: merchantColor(s.merchantId), width: 2 },
        itemStyle: { color: merchantColor(s.merchantId), borderColor: '#fff', borderWidth: 1.5 },
        z: 2,
      })),
    ]
  }
}

// 响应式调整
function handleResize() {
  chart?.resize()
}

// 监听数据变化（图表 DOM 不再被销毁，只需更新或首次初始化）
watch(() => props.data, (newData) => {
  if (newData?.length) {
    if (!hasEverHadData.value) hasEverHadData.value = true
    nextTick(renderOrInit)
  }
}, { deep: true })

// 折算序列变化 / 开关切换 → 重绘（首帧只有折算序列时也要补初始化）
watch([includeComputed, () => props.computedSeries], () => {
  nextTick(renderOrInit)
}, { deep: true })

// loading 结束后只需调整尺寸，无需重建图表（DOM 未被销毁）
watch(() => props.loading, () => {
  if (!props.loading) {
    nextTick(() => {
      if (chart) {
        chart.resize()
        updateChart()
      } else {
        renderOrInit()
      }
    })
  }
})

watch(() => [locale.value, localeStore.effectiveFormatLocale], () => {
  renderOrInit()
})

// 生命周期
onMounted(() => {
  nextTick(initChart)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  chart?.dispose()
})
</script>

<style scoped>
.price-trend-chart {
  margin: 0;
}

.chart-container {
  width: 100%;
  height: 300px;
}

.filter-buttons {
  flex-shrink: 0;
}

/* 商家对比 chips */
.merchant-chips {
  border-bottom: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}

.merchant-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-inline-end: 4px;
}

/* 移动端适配 */
@media (max-width: 600px) {
  .chart-container {
    height: 250px;
  }

  .filter-buttons {
    margin-top: 8px;
    width: 100%;
  }
}
</style>

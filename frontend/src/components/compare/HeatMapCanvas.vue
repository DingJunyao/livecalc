<template>
  <div class="heatmap-canvas">
    <div ref="mapEl" class="heatmap-map" />
    <!-- 图例：分档色块 + 区间（buckets 缺省时只显示色序） -->
    <div v-if="buckets && buckets.p50 != null" class="heatmap-legend">
      <div
        v-for="(seg, i) in legendSegments"
        :key="i"
        class="legend-item"
      >
        <span class="legend-dot" :style="{ background: seg.color }" />
        <span class="legend-label">{{ seg.label }}</span>
      </div>
    </div>
    <div v-if="!loading && !items.length" class="heatmap-empty">
      <v-icon size="40" color="medium-emphasis">mdi-map-marker-off-outline</v-icon>
      <div class="text-body-2 mt-2">{{ emptyText }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
// 商家物价热力图画布：Leaflet 统一渲染（底图可切高德/OSM 瓦片），
// 每商家一个 circleMarker 按价格分位分档着色，点击弹商家名+价格。
// 不走 mapEngineManager 的 SDK 分支：热力覆盖层是 Leaflet 专属能力，
// 统一用 Leaflet 瓦片（高德瓦片无 key 可用），保证所有部署一致。
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import L from 'leaflet'
import 'leaflet.chinatmsproviders'
import { formatMoney } from '@/utils/currency'
import { useUserCurrency } from '@/composables/useUserCurrency'

export interface HeatmapItem {
  merchant_id: number
  name: string
  latitude: number
  longitude: number
  price: number
  is_stale: boolean
  sample_count: number
  price_index?: number | null
}

interface Buckets {
  p25?: number | null
  p50?: number | null
  p75?: number | null
  p90?: number | null
}

const props = withDefaults(defineProps<{
  items?: HeatmapItem[]
  buckets?: Buckets | null
  loading?: boolean
  emptyText?: string
  /** item=显示价格；overall=显示物价指数 */
  mode?: 'item' | 'overall'
  /** 底图瓦片：osm | amap */
  engine?: 'osm' | 'amap'
}>(), {
  items: () => [],
  buckets: null,
  loading: false,
  emptyText: '',
  mode: 'item',
  engine: 'osm',
})

const { t } = useI18n()
const { currency: userCurrency } = useUserCurrency()

const mapEl = ref<HTMLDivElement | null>(null)
let map: L.Map | null = null
let tileLayer: L.TileLayer | null = null
let markerGroup: L.LayerGroup | null = null

// 分档色（绿→红）
const COLORS = ['#2e7d32', '#7cb342', '#f9a825', '#ef6c00', '#c62828']

interface LegendSeg {
  color: string
  label: string
}

const legendSegments = computed<LegendSeg[]>(() => {
  const b = props.buckets
  if (!b || b.p50 == null) return []
  const fmt = (v: number | null | undefined) =>
    v == null ? '—' : (props.mode === 'overall'
      ? String(Math.round(v * 10) / 10)
      : formatMoney(v, userCurrency.value))
  return [
    { color: COLORS[0], label: `≤ ${fmt(b.p25)}` },
    { color: COLORS[1], label: `${fmt(b.p25)} ~ ${fmt(b.p50)}` },
    { color: COLORS[2], label: `${fmt(b.p50)} ~ ${fmt(b.p75)}` },
    { color: COLORS[3], label: `${fmt(b.p75)} ~ ${fmt(b.p90)}` },
    { color: COLORS[4], label: `> ${fmt(b.p90)}` },
  ]
})

function colorFor(price: number): string {
  const b = props.buckets
  if (!b || b.p50 == null) return COLORS[1]
  if (price <= (b.p25 ?? b.p50)) return COLORS[0]
  if (price <= b.p50) return COLORS[1]
  if (price <= (b.p75 ?? b.p50)) return COLORS[2]
  if (price <= (b.p90 ?? b.p75 ?? b.p50)) return COLORS[3]
  return COLORS[4]
}

function renderMarkers() {
  if (!map || !markerGroup) return
  markerGroup.clearLayers()
  for (const item of props.items) {
    const color = colorFor(item.price)
    const label = props.mode === 'overall'
      ? `${t('compare.priceIndexUnit')}: ${Math.round((item.price_index ?? 0) * 10) / 10}`
      : formatMoney(item.price, userCurrency.value)
    const marker = L.circleMarker([item.latitude, item.longitude], {
      radius: 9,
      color,
      fillColor: color,
      fillOpacity: 0.65,
      weight: 1.5,
    })
    marker.bindPopup(
      `<strong>${item.name}</strong><br/>${label} / ${t('compare.trendUnitJin')}` +
      (item.is_stale ? `<br/><span style="color:#9e9e9e">${t('compare.staleHint')}</span>` : '') +
      (item.sample_count ? `<br/><span style="color:#9e9e9e">${item.sample_count} ${t('compare.sampleCountUnit')}</span>` : ''),
    )
    markerGroup.addLayer(marker)
  }
  // fitBounds 到全部点
  if (props.items.length) {
    const lats = props.items.map(i => i.latitude)
    const lngs = props.items.map(i => i.longitude)
    map.fitBounds([
      [Math.min(...lats), Math.min(...lngs)],
      [Math.max(...lats), Math.max(...lngs)],
    ], { padding: [32, 32], maxZoom: 15 })
  }
}

function initMap() {
  if (!mapEl.value || map) return
  map = L.map(mapEl.value, { center: [34.5, 113.6], zoom: 10, zoomControl: true })
  if (props.engine === 'amap') {
    tileLayer = (L.tileLayer as any).chinaProvider('GaoDe.Normal.Map', { maxZoom: 18 })
  } else {
    tileLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors', maxZoom: 19,
    })
  }
  tileLayer.addTo(map)
  markerGroup = L.layerGroup().addTo(map)
  renderMarkers()
}

onMounted(() => {
  initMap()
})

onBeforeUnmount(() => {
  if (map) {
    map.remove()
    map = null
    tileLayer = null
    markerGroup = null
  }
})

watch(() => [props.items, props.buckets], () => renderMarkers(), { deep: true })
</script>

<style scoped>
.heatmap-canvas {
  position: relative;
}
.heatmap-map {
  width: 100%;
  height: 420px;
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.12);
  z-index: 0;
}
.heatmap-legend {
  position: absolute;
  right: 12px;
  bottom: 12px;
  z-index: 500;
  background: rgba(255, 255, 255, 0.94);
  border-radius: 8px;
  padding: 8px 10px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
}
.legend-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
}
.legend-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.heatmap-empty {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  z-index: 500;
  background: rgba(255, 255, 255, 0.7);
  pointer-events: none;
}
</style>

<template>
  <!-- 顶部导航栏 - 移到 container 外面以便固定 -->
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('admin.map.title') }}</v-app-bar-title>
    <template #append>
      <v-btn color="primary" variant="tonal" :loading="saving" @click="saveConfig">
        <v-icon start>mdi-content-save</v-icon>
        {{ t('admin.map.saveConfig') }}
      </v-btn>
    </template>
  </v-app-bar>

  <v-container class="pa-4">

    <!-- 地图总开关 -->
    <v-card class="rounded-lg mb-4">
      <v-card-text class="d-flex align-center flex-wrap">
        <v-switch
          v-model="config.map_enabled"
          color="primary"
          :label="t('admin.map.enableMaps')"
          hide-details
          density="compact"
        />
        <v-icon class="ml-4">mdi-map</v-icon>
        <div class="ml-2 text-body-2 text-medium-emphasis">
          {{ t('admin.map.disableDescription') }}
        </div>
      </v-card-text>
    </v-card>

    <v-row>
      <!-- 可用地图 -->
      <v-col cols="12" md="6">
        <v-card class="rounded-lg h-100" :class="{ 'config-disabled': !config.map_enabled }">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2">mdi-map</v-icon>
            <span>{{ t('admin.map.availableMaps') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-4">
            <v-select
              v-model="config.default_map"
              :items="availableMaps"
              :label="t('admin.map.defaultMap')"
              variant="outlined"
              prepend-icon="mdi-star"
              :hint="t('admin.map.defaultMapHint')"
              persistent-hint
            />
            <v-divider class="my-4" />
            <div class="text-caption text-medium-emphasis mb-2">{{ t('admin.map.enabledServices') }}</div>
            <v-chip-group v-model="config.available_maps" multiple column>
              <v-chip
                v-for="map in allMaps"
                :key="map.value"
                :value="map.value"
                filter
                :color="config.available_maps.includes(map.value) ? 'primary' : undefined"
              >
                <v-icon start>{{ map.icon }}</v-icon>
                {{ map.title }}
              </v-chip>
            </v-chip-group>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- API 密钥配置 -->
      <v-col cols="12" md="6">
        <v-card class="rounded-lg h-100" :class="{ 'config-disabled': !config.map_enabled }">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2">mdi-key</v-icon>
            <span>{{ t('admin.map.apiKeys') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-4">
            <v-expansion-panels variant="accordion">
              <!-- 高德地图 -->
              <v-expansion-panel>
                <v-expansion-panel-title>
                  <v-icon class="mr-2" color="success">mdi-map-marker</v-icon>
                  {{ t('admin.map.maps.amap') }}
                </v-expansion-panel-title>
                <v-expansion-panel-text>
                  <v-text-field
                    v-model="config.map_api_keys.amap"
                    label="API Key"
                    variant="outlined"
                    type="password"
                    persistent-placeholder
                    :placeholder="t('admin.map.defaultKeyPlaceholder')"
                  />
                  <v-text-field
                    v-model="config.map_api_keys.amap_security"
                    :label="t('admin.map.amapSecurityKey')"
                    variant="outlined"
                    type="password"
                    persistent-placeholder
                    class="mt-2"
                    :hint="t('admin.map.amapSecurityKeyHint')"
                  />
                </v-expansion-panel-text>
              </v-expansion-panel>

              <!-- 百度地图 -->
              <v-expansion-panel>
                <v-expansion-panel-title>
                  <v-icon class="mr-2" color="primary">mdi-map-marker-radius</v-icon>
                  {{ t('admin.map.maps.baidu') }}
                </v-expansion-panel-title>
                <v-expansion-panel-text>
                  <v-text-field
                    v-model="config.map_api_keys.baidu"
                    label="API Key (AK)"
                    variant="outlined"
                    type="password"
                    persistent-placeholder
                    :placeholder="t('admin.map.defaultKeyPlaceholder')"
                  />
                </v-expansion-panel-text>
              </v-expansion-panel>

              <!-- 腾讯地图 -->
              <v-expansion-panel>
                <v-expansion-panel-title>
                  <v-icon class="mr-2" color="info">mdi-map-marker-plus</v-icon>
                  {{ t('admin.map.maps.tencent') }}
                </v-expansion-panel-title>
                <v-expansion-panel-text>
                  <v-text-field
                    v-model="config.map_api_keys.tencent"
                    label="API Key"
                    variant="outlined"
                    type="password"
                    persistent-placeholder
                    :placeholder="t('admin.map.defaultKeyPlaceholder')"
                  />
                </v-expansion-panel-text>
              </v-expansion-panel>

              <!-- 天地图 -->
              <v-expansion-panel>
                <v-expansion-panel-title>
                  <v-icon class="mr-2" color="warning">mdi-earth</v-icon>
                  {{ t('admin.map.maps.tianditu') }}
                </v-expansion-panel-title>
                <v-expansion-panel-text>
                  <v-text-field
                    v-model="config.map_api_keys.tianditu.token"
                    label="Token"
                    variant="outlined"
                    type="password"
                    persistent-placeholder
                    :placeholder="t('admin.map.defaultKeyPlaceholder')"
                  />
                  <!-- 天地图引擎固定加载矢量底图（TianDiTu.Normal.Map），「地图类型」切换不生效，故不暴露；type 字段保留默认值 'vec' 供结构兼容与后端透传 -->
                </v-expansion-panel-text>
              </v-expansion-panel>
            </v-expansion-panels>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- 地理编码配置 -->
      <v-col cols="12">
        <v-card class="rounded-lg" :class="{ 'config-disabled': !config.map_enabled }">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2">mdi-crosshairs-gps</v-icon>
            <span>{{ t('admin.map.geocoding') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-4">
            <v-row>
              <v-col cols="12" sm="6" md="4">
                <v-select
                  v-model="config.geocoding.enabled_service"
                  :items="geocodingServices"
                  :label="t('admin.map.enabledGeocodingService')"
                  variant="outlined"
                  prepend-icon="mdi-server"
                  :hint="t('admin.map.geocodingHint')"
                  persistent-hint
                />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <v-text-field
                  v-model="config.geocoding.amap_key"
                  :label="t('admin.map.amapKey')"
                  variant="outlined"
                  type="password"
                  persistent-placeholder
                  :placeholder="t('admin.map.defaultKeyPlaceholder')"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <v-text-field
                  v-model="config.geocoding.baidu_key"
                  :label="t('admin.map.baiduKey')"
                  variant="outlined"
                  type="password"
                  persistent-placeholder
                  :placeholder="t('admin.map.defaultKeyPlaceholder')"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <v-text-field
                  v-model="config.geocoding.tencent_key"
                  :label="t('admin.map.tencentKey')"
                  variant="outlined"
                  type="password"
                  persistent-placeholder
                  :placeholder="t('admin.map.defaultKeyPlaceholder')"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <v-text-field
                  v-model="config.geocoding.nominatim_url"
                  label="Nominatim URL"
                  variant="outlined"
                  persistent-placeholder
                  placeholder="https://nominatim.openstreetmap.org/search"
                  :hint="t('admin.map.nominatimUrlHint')"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4">
                <v-text-field
                  v-model="config.geocoding.nominatim_email"
                  label="Nominatim Email"
                  variant="outlined"
                  type="email"
                  persistent-placeholder
                  placeholder="your@email.com"
                  :hint="t('admin.map.nominatimEmailHint')"
                />
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- 保存成功提示 -->
    <v-snackbar v-model="showSuccess" color="success" timeout="3000">
      <v-icon start>mdi-check-circle</v-icon>
      {{ t('admin.map.saved') }}
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useMapConfig } from '@/composables/useMapConfig'
import { api } from '@/api'

const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const { t } = useI18n()
const router = useRouter()

const goBack = () => {
  router.back()
}

interface MapApiKeys {
  amap: string | null
  amap_security: string | null
  baidu: string | null
  tencent: string | null
  tianditu: {
    token: string
    type: string
  }
}

interface GeocodingConfig {
  enabled_service: string
  amap_key: string | null
  baidu_key: string | null
  tencent_key: string | null
  nominatim_url: string
  nominatim_email: string | null
}

interface MapConfig {
  map_enabled: boolean
  available_maps: string[]
  default_map: string
  map_api_keys: MapApiKeys
  geocoding: GeocodingConfig
}

const allMaps = computed(() => [
  { title: t('admin.map.maps.amap'), value: 'amap', icon: 'mdi-map-marker' },
  { title: t('admin.map.maps.baidu'), value: 'baidu', icon: 'mdi-map-marker-radius' },
  { title: t('admin.map.maps.tencent'), value: 'tencent', icon: 'mdi-map-marker-plus' },
  { title: t('admin.map.maps.tianditu'), value: 'tianditu', icon: 'mdi-earth' },
  { title: 'OpenStreetMap', value: 'osm', icon: 'mdi-open-in-new' },
])

const geocodingServices = computed(() => [
  { title: t('admin.map.maps.amap'), value: 'amap' },
  { title: t('admin.map.maps.baidu'), value: 'baidu' },
  { title: t('admin.map.maps.tencent'), value: 'tencent' },
  { title: 'Nominatim (OSM)', value: 'nominatim' },
])

const config = reactive<MapConfig>({
  map_enabled: true,
  available_maps: ['amap', 'baidu', 'tencent', 'tianditu', 'osm'],
  default_map: 'amap',
  map_api_keys: {
    amap: null,
    amap_security: null,
    baidu: null,
    tencent: null,
    tianditu: {
      token: '',
      type: 'vec',
    },
  },
  geocoding: {
    enabled_service: 'amap',
    amap_key: null,
    baidu_key: null,
    tencent_key: null,
    nominatim_url: '',
    nominatim_email: null,
  },
})

const saving = ref(false)
const showSuccess = ref(false)

// 默认地图下拉项跟随「启用的地图服务」联动
const availableMaps = computed(() =>
  allMaps.value.filter((m) => config.available_maps.includes(m.value))
)

// 默认地图不在启用列表时，回退到首个启用项
const ensureDefaultMapValid = () => {
  const maps = config.available_maps
  if (Array.isArray(maps) && maps.length > 0 && !maps.includes(config.default_map)) {
    config.default_map = maps[0]
  }
}

watch(() => [...config.available_maps], ensureDefaultMapValid)

const fetchConfig = async () => {
  try {
    const data = await api.get('/admin/map-config')
    Object.assign(config, data)
    // 兜底：库里 default_map 不在启用列表时回退首个
    ensureDefaultMapValid()
  } catch (error) {
    console.error('Failed to get map config:', error)
  }
}

const saveConfig = async () => {
  saving.value = true
  try {
    await api.put('/admin/map-config', config)
    // 刷新前端地图配置单例缓存，让其他页面立即感知开关变化（无需刷新页面）
    await useMapConfig().reload()
    showSuccess.value = true
  } catch (error) {
    console.error('Failed to save map config:', error)
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  fetchConfig()
})
</script>

<style scoped>
.h-100 {
  height: 100%;
}

.config-disabled {
  opacity: 0.5;
  pointer-events: none;
}
</style>

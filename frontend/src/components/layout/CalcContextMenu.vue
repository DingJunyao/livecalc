<template>
  <div class="d-flex align-center calc-context">
    <!-- 桌面端：内联显示当前地区 / 计算范围 / 币种，点击打开同一弹窗 -->
    <template v-if="isDesktop">
      <v-btn variant="text" size="small" class="px-1" title="切换地区/计算范围/币种" @click="open">
        <v-icon start size="small">mdi-map-marker-outline</v-icon>
        {{ regionLabel }}
      </v-btn>
      <v-btn variant="text" size="small" class="px-1" title="切换计算范围" @click="open">
        <v-icon start size="small">mdi-sitemap-outline</v-icon>
        {{ scopeLabel }}
      </v-btn>
      <v-btn variant="text" size="small" class="px-1" title="切换币种" @click="open">
        <v-icon start size="small">mdi-currency-usd</v-icon>
        {{ currencyLabel }}
      </v-btn>
    </template>
    <!-- 移动端：单个按钮 -->
    <v-btn v-else icon="mdi-tune-variant" variant="text" size="small" title="地区/计算范围/币种" @click="open" />

    <v-dialog v-model="dialog" max-width="520">
      <v-card>
        <v-card-title class="d-flex align-center">
          地区 / 计算范围 / 币种
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="dialog = false" />
        </v-card-title>
        <v-card-text>
          <div class="text-subtitle-2 mb-1">所在地区</div>
          <div class="d-flex flex-wrap ga-2 mb-3">
            <template v-for="(level, i) in regionLevels" :key="i">
              <v-select v-if="i === 0 || regionSelections[i - 1]" v-model="regionSelections[i]"
                :items="regionItems[i]" item-title="name" item-value="id" :label="level.label"
                variant="outlined" density="compact" class="region-select flex-grow-1"
                :loading="regionLoading[i]" hide-details="auto" clearable
                @update:model-value="onRegionChange(i)" />
            </template>
          </div>
          <div class="text-subtitle-2 mb-1">计算范围</div>
          <v-select v-model="scopeValue" :items="scopeOptions" item-title="title" item-value="value"
            label="计算范围" variant="outlined" density="compact" class="mb-3" hide-details />
          <div class="text-subtitle-2 mb-1">币种</div>
          <v-autocomplete v-model="currencyValue" :items="currencies" item-title="name" item-value="code"
            label="币种" variant="outlined" density="compact" clearable placeholder="跟随所在地区" hide-details>
            <template #selection="{ item }">
              {{ item.raw.code }}
            </template>
            <template #item="{ props, item }">
              <v-list-item v-bind="props" :title="`${item.raw.name} ${item.raw.code}`" />
            </template>
          </v-autocomplete>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">取消</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useDisplay } from 'vuetify'
import { api } from '@/api'
import { useUserStore } from '@/stores/user'
import { loadCurrencies } from '@/utils/currency'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'

const { mdAndUp } = useDisplay()
const isDesktop = computed(() => mdAndUp.value)
const userStore = useUserStore()
const { notify } = useGlobalSnackbar()

const dialog = ref(false)
const saving = ref(false)
const currencies = ref<any[]>([])

const scopeOptions = [
  { title: '全部地区', value: '' },
  { title: '国家/地区', value: 'country' },
  { title: '省份', value: 'province' },
  { title: '城市', value: 'city' },
  { title: '区县', value: 'county' },
]

// 地区级联
const regionLevels = [
  { label: '国家/地区', code: 0 },
  { label: '省份', code: 1 },
  { label: '城市', code: 2 },
  { label: '区县', code: 3 },
]
const regionSelections = ref<Array<number | null>>([null, null, null, null])
const regionItems = ref<Array<Array<{ id: number; name: string; has_children: boolean }>>>([[], [], [], []])
const regionLoading = ref<boolean[]>([false, false, false, false])
const regionNames = ref<Record<number, string>>({})
let currentRegionId: number | null = null

const scopeValue = ref<string>('country')
const currencyValue = ref<string | null>(null)

const scopeLabel = computed(() => {
  const scope = userStore.user?.default_calc_scope
  return scopeOptions.find(o => o.value === scope)?.title || '国家/地区'
})

const currencyLabel = computed(() => {
  const c = userStore.user?.default_currency || userStore.user?.effective_currency
  return typeof c === 'string' && c ? c : '跟随地区'
})

const regionLabel = computed(() => {
  const id = userStore.user?.region_id
  return id != null ? (regionNames.value[id] || '地区') : '全部地区'
})

async function loadRegionLevel(level: number, parentId: number | null) {
  regionLoading.value[level] = true
  try {
    const params: Record<string, any> = parentId !== null ? { parent_id: parentId } : { level: 0 }
    const data = await api.get('/regions', { params })
    regionItems.value[level] = (Array.isArray(data) ? data : data?.items || data || [])
      .map((r: any) => ({ id: r.id, name: r.name, has_children: r.has_children }))
  } catch {
    regionItems.value[level] = []
  } finally {
    regionLoading.value[level] = false
  }
}

function onRegionChange(level: number) {
  for (let i = level + 1; i < 4; i++) {
    regionSelections.value[i] = null
    regionItems.value[i] = []
  }
  const id = regionSelections.value[level]
  if (id && level < 3) {
    const selected = regionItems.value[level].find(r => r.id === id)
    if (selected?.has_children) loadRegionLevel(level + 1, id)
  }
}

function selectedRegionId(): number | null {
  for (let i = 3; i >= 0; i--) {
    if (regionSelections.value[i]) return regionSelections.value[i]!
  }
  return null
}

async function ensureRegionName() {
  const id = userStore.user?.region_id
  if (id != null && !regionNames.value[id]) {
    try {
      const detail: any = await api.get(/regions/)
      regionNames.value[id] = detail?.name || ''
    } catch { /* ignore */ }
  }
}

onMounted(() => { void ensureRegionName() })

async function open() {
  currentRegionId = userStore.user?.region_id ?? null
  scopeValue.value = userStore.user?.default_calc_scope ?? 'country'
  currencyValue.value = userStore.user?.default_currency ?? null
  regionSelections.value = [null, null, null, null]
  regionItems.value = [[], [], [], []]
  if (!currencies.value.length) {
    try {
      currencies.value = await loadCurrencies()
    } catch { /* ignore */ }
  }
  if (!regionItems.value[0].length) await loadRegionLevel(0, null)
  if (currentRegionId) {
    try {
      const detail: any = await api.get(`/regions/${currentRegionId}`)
      const chain: Array<{ id: number; level: number }> = [
        ...((detail?.ancestors || []) as any[]).map((a: any) => ({ id: a.id, level: a.level })),
        { id: detail.id, level: detail.level },
      ].sort((a, b) => a.level - b.level)
      for (const a of detail?.ancestors || []) regionNames.value[a.id] = a.name
      regionNames.value[detail.id] = detail?.name || ''
      for (let i = 0; i < chain.length; i++) {
        if (i > 0) await loadRegionLevel(chain[i].level, chain[i - 1].id)
        regionSelections.value[chain[i].level] = chain[i].id
      }
    } catch { /* ignore */ }
  }
  dialog.value = true
}

async function save() {
  saving.value = true
  try {
    await api.patch('/auth/me', {
      default_currency: currencyValue.value || null,
      default_calc_scope: scopeValue.value,
    })
    const newRegionId = selectedRegionId()
    if (newRegionId !== currentRegionId) {
      await api.put('/auth/me/account', { region_id: newRegionId })
    }
    await userStore.fetchUser()
    dialog.value = false
    notify('已更新', 'success')
  } catch (e: any) {
    notify('保存失败：' + (e?.userMessage || e?.message || '未知错误'), 'error')
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.calc-context :deep(.v-btn) { text-transform: none; }
.region-select { max-width: 220px; }
@media (max-width: 600px) {
  .region-select { max-width: none; }
}
</style>
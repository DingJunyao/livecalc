<template>
  <div class="d-flex align-center calc-context">
    <!-- 桌面端：合并为一个当前计算上下文入口 -->
    <v-btn
      v-if="isDesktop"
      variant="text"
      size="large"
      class="context-button ms-2"
      :title="t('context.openTitleDesktop')"
      @click="open"
    >
      <v-icon start>mdi-tune-variant</v-icon>
      <span class="context-button-text">{{ contextSummary }}</span>
      <v-icon end size="small">mdi-chevron-down</v-icon>
    </v-btn>
    <!-- 移动端：单个按钮 -->
    <v-btn v-else icon="mdi-tune-variant" variant="text" size="small" :title="t('context.openTitleMobile')" @click="open" />

    <v-dialog v-model="dialog" max-width="520">
      <v-card>
        <v-card-title class="d-flex align-center">
          {{ t('context.dialogTitle') }}
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" size="small" @click="dialog = false" />
        </v-card-title>
        <v-card-text>
          <p class="text-caption text-medium-emphasis mb-3">
            {{ t('context.description') }}
          </p>
          <div class="text-subtitle-2 mb-1">{{ t('context.region') }}</div>
          <div class="d-flex flex-wrap ga-2 mb-3">
            <template v-for="(level, i) in regionLevels" :key="i">
              <v-select v-if="i === 0 || regionSelections[i - 1]" v-model="regionSelections[i]"
                :items="regionItems[i]" item-title="name" item-value="id" :label="level.label"
                variant="outlined" density="compact" class="region-select flex-grow-1"
                :loading="regionLoading[i]" hide-details="auto" clearable
                @update:model-value="onRegionChange(i)" />
            </template>
          </div>
          <div class="text-subtitle-2 mb-1">{{ t('context.scope') }}</div>
          <v-select v-model="scopeValue" :items="scopeOptions" item-title="title" item-value="value"
            :label="t('context.scope')" variant="outlined" density="compact" class="mb-3" hide-details />
          <div class="text-subtitle-2 mb-1">{{ t('context.currency') }}</div>
          <v-autocomplete v-model="currencyValue" :items="currencies" item-title="name" item-value="code"
            :label="t('context.currency')" variant="outlined" density="compact" clearable :placeholder="t('context.currencyPlaceholder')" hide-details>
            <template #selection="{ item }">
              {{ currencyOptionLabel(item.raw) }}
            </template>
            <template #item="{ props, item }">
              <v-list-item v-bind="props" :title="currencyOptionLabel(item.raw)" />
            </template>
          </v-autocomplete>
        </v-card-text>
        <v-card-actions>
          <v-btn variant="text" :disabled="saving" @click="reset">{{ t('context.resetToProfile') }}</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">{{ t('context.apply') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useDisplay } from 'vuetify'
import { api } from '@/api'
import { useUserStore } from '@/stores/user'
import { useCalcContextStore } from '@/stores/calcContext'
import { loadCurrencies } from '@/utils/currency'

const { t } = useI18n()

const { mdAndUp } = useDisplay()
const isDesktop = computed(() => mdAndUp.value)
const userStore = useUserStore()
const calcContext = useCalcContextStore()

const dialog = ref(false)
const saving = ref(false)
const currencies = ref<any[]>([])

const scopeOptions = computed(() => [
  { title: t('scope.all'), value: '' },
  { title: t('scope.country'), value: 'country' },
  { title: t('scope.province'), value: 'province' },
  { title: t('scope.city'), value: 'city' },
  { title: t('scope.county'), value: 'county' },
])

// 地区级联
const regionLevels = computed(() => [
  { label: t('region.country'), code: 0 },
  { label: t('region.province'), code: 1 },
  { label: t('region.city'), code: 2 },
  { label: t('region.district'), code: 3 },
])
const regionSelections = ref<Array<number | null>>([null, null, null, null])
const regionItems = ref<Array<Array<{ id: number; name: string; has_children: boolean }>>>([[], [], [], []])
const regionLoading = ref<boolean[]>([false, false, false, false])
const regionNames = ref<Record<number, string>>({})
let initialRegionId: number | null = null

const scopeValue = ref<string>('country')
const currencyValue = ref<string | null>(null)

// 当前展示：会话覆盖优先，否则个人配置
const scopeLabel = computed(() => {
  const scope = calcContext.scope ?? userStore.user?.default_calc_scope
  return scopeOptions.value.find(o => o.value === scope)?.title || t('region.country')
})

const currencyLabel = computed(() => {
  const c = calcContext.currency || userStore.user?.default_currency || userStore.user?.effective_currency
  if (typeof c !== 'string' || !c) return t('context.followRegion')
  const hit = currencies.value.find(item => item.code === c)
  return hit?.name && hit.name !== c ? hit.name : c
})

const regionLabel = computed(() => {
  const id = calcContext.regionId ?? userStore.user?.region_id
  return id != null ? (regionNames.value[id] || t('context.regionFallback')) : t('scope.all')
})

const contextSummary = computed(() => `${regionLabel.value} · ${scopeLabel.value} · ${currencyLabel.value}`)

function currencyOptionLabel(item: { code: string; name?: string }) {
  return item.name && item.name !== item.code ? `${item.name} (${item.code})` : item.code
}

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
  const id = calcContext.regionId ?? userStore.user?.region_id
  if (id != null && !regionNames.value[id]) {
    try {
      const detail: any = await api.get(`/regions/${id}`)
      regionNames.value[id] = detail?.name || ''
    } catch { /* ignore */ }
  }
}

onMounted(() => {
  void ensureRegionName()
  void ensureCurrencyOptions()
})

async function ensureCurrencyOptions() {
  if (currencies.value.length) return
  try {
    currencies.value = await loadCurrencies()
  } catch { /* keep the code-only fallback */ }
}

async function open() {
  initialRegionId = calcContext.regionId ?? userStore.user?.region_id ?? null
  scopeValue.value = calcContext.scope ?? userStore.user?.default_calc_scope ?? 'country'
  currencyValue.value = calcContext.currency ?? userStore.user?.default_currency ?? null
  regionSelections.value = [null, null, null, null]
  regionItems.value = [[], [], [], []]
  await ensureCurrencyOptions()
  if (!regionItems.value[0].length) await loadRegionLevel(0, null)
  if (initialRegionId) {
    try {
      const detail: any = await api.get(`/regions/${initialRegionId}`)
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

// 当前级联选择链（含祖先），供 store 解析生效节点，避免重复请求
function currentChain(): Array<{ id: number; level: number }> {
  const chain: Array<{ id: number; level: number }> = []
  for (let i = 0; i < 4; i++) {
    const id = regionSelections.value[i]
    if (id != null) chain.push({ id, level: i })
  }
  return chain
}

async function save() {
  saving.value = true
  try {
    calcContext.apply({
      regionId: selectedRegionId(),
      scope: scopeValue.value,
      currency: currencyValue.value || null,
    }, currentChain())
    dialog.value = false
    window.location.reload()
  } finally {
    saving.value = false
  }
}

function reset() {
  calcContext.clear()
  dialog.value = false
  window.location.reload()
}
</script>

<style scoped>
.calc-context :deep(.v-btn) { text-transform: none; }
.context-button {
  height: 48px;
  padding: 0 12px;
}
.context-button :deep(.v-btn__content) {
  max-width: min(420px, 38vw);
  font-size: 1rem;
  font-weight: 600;
}
.context-button :deep(.v-btn__content .v-icon:first-child) {
  font-size: 22px;
}
.context-button-text {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.region-select { max-width: 220px; }
@media (max-width: 600px) {
  .region-select { max-width: none; }
}
</style>

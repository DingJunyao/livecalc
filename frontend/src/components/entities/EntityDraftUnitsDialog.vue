<template>
  <v-dialog :model-value="modelValue" max-width="520" @update:model-value="onToggle">
    <v-card>
      <v-card-title class="d-flex align-center pa-4">
        <span class="text-h6">{{ t('products.draftUnitsDialogTitle', { target }) }}</span>
        <v-spacer />
        <v-btn
          icon="mdi-close"
          variant="text"
          size="small"
          :aria-label="t('common.close')"
          @click="close"
        />
      </v-card-title>
      <v-card-text>
        <div class="text-caption text-medium-emphasis mb-3">
          {{ t('products.draftSavedTogether', { target }) }}
        </div>
        <div v-if="loading" class="text-center py-4">
          <v-progress-circular indeterminate color="primary" size="24" />
        </div>
        <template v-else>
          <div v-if="units.length === 0" class="text-body-2 text-medium-emphasis">
            {{ t('products.noCustomUnits') }}
          </div>
          <v-list v-else density="compact" class="pa-0">
            <v-list-item v-for="unit in units" :key="unit.id" class="px-0">
              <template #prepend>
                <v-chip size="small" variant="tonal" color="primary" class="me-3">
                  {{ unit.unit_name }}
                </v-chip>
              </template>
              <v-list-item-title class="text-body-2">{{ unitLine(unit) }}</v-list-item-title>
              <v-list-item-subtitle v-if="unit.is_default" class="text-caption text-primary">
                {{ t('products.defaultUnit') }}
              </v-list-item-subtitle>
              <template #append>
                <v-btn
                  icon="mdi-pencil"
                  size="x-small"
                  variant="text"
                  color="primary"
                  :aria-label="t('products.editUnit')"
                  @click="openEditor(unit)"
                />
                <v-btn
                  icon="mdi-delete"
                  size="x-small"
                  variant="text"
                  color="error"
                  :aria-label="t('products.deleteUnit')"
                  @click="removeUnit(unit.id)"
                />
              </template>
            </v-list-item>
          </v-list>
          <v-btn
            variant="tonal"
            color="primary"
            prepend-icon="mdi-plus"
            class="mt-3"
            @click="openEditor()"
          >
            {{ t('products.addUnit') }}
          </v-btn>
        </template>
      </v-card-text>
      <v-card-actions class="pa-4 pt-0">
        <v-spacer />
        <v-btn color="primary" variant="text" @click="close">{{ t('common.close') }}</v-btn>
      </v-card-actions>
    </v-card>

    <!-- 单条单位编辑（只改本地草稿，商品保存时才落库） -->
    <v-dialog v-model="editorOpen" max-width="460">
      <v-card>
        <v-card-title class="text-h6 pa-4">
          {{ editorForm.id == null ? t('products.addUnitTitle') : t('products.editUnit') }}
        </v-card-title>
        <v-card-text>
          <v-text-field
            v-model="editorForm.unit_name"
            :label="t('products.unitName')"
            :placeholder="t('products.unitNamePlaceholder')"
            variant="outlined"
            density="comfortable"
            class="mb-3"
          />
          <v-row dense class="mb-1">
            <v-col cols="5">
              <v-text-field
                v-model="editorForm.weight_per_unit"
                :label="t('products.unitWeightValueLabel')"
                variant="outlined"
                density="comfortable"
                type="number"
              />
            </v-col>
            <v-col cols="7">
              <v-select
                v-model="editorForm.weight_unit"
                :items="unitOptions"
                :label="t('products.unitWeightUnitLabel')"
                variant="outlined"
                density="comfortable"
                clearable
                :hint="t('products.unitWeightUnitHint')"
                persistent-hint
              />
            </v-col>
          </v-row>
          <v-alert
            v-if="volumePreview"
            density="compact"
            type="info"
            variant="tonal"
            class="mt-6 mb-2"
          >
            {{ volumePreview }}
          </v-alert>
          <v-checkbox
            v-model="editorForm.is_default"
            :label="t('products.setDefaultUnit')"
            density="compact"
            hide-details
          />
          <div v-if="editorError" class="text-error text-caption mt-2">{{ editorError }}</div>
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn @click="editorOpen = false">{{ t('products.cancel') }}</v-btn>
          <v-btn color="primary" @click="saveEditor">{{ t('products.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api } from '@/api'
import { formatNumber, formatQuantity } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'
import {
  draftChainReaches,
  draftUnitAmounts,
  nextDraftUnitId,
  type EntityDraftUnit,
} from '@/utils/entityDraftPlan'

// 新增商品/原料对话框里的「自定义单位」草稿编辑器：只改内存里的草稿数组，
// 实体保存成功后再由 entityDrafts.persistEntityDrafts 按依赖顺序落库。
const props = defineProps<{
  modelValue: boolean
  units: EntityDraftUnit[]
  /** 关联原料 id：可继承原料已有的自定义单位（如「盒」定义在原料上）；原料自身传空 */
  ingredientId?: number | null
  /** 实体名（商品/原料），只用于文案 */
  target: string
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'update:units', value: EntityDraftUnit[]): void
}>()

const { t } = useI18n()
const localeStore = useLocaleStore()

const globalUnits = ref<any[]>([])
const ingredientUnits = ref<any[]>([])
const densityKgM3 = ref<number | null>(null)
const loading = ref(false)
// 「是否已加载」必须与「加载的是哪个原料」分开记：新增商品时 ingredientId 就是 null，
// 用它当 sentinel 会把「null === null」误判成已加载 → 下拉永远没有数据。
const globalUnitsLoaded = ref(false)
const loadedIngredientId = ref<number | null>(null)

const editorOpen = ref(false)
const editorError = ref('')
const editorForm = ref<{
  id: number | null
  unit_name: string
  weight_per_unit: number | string | null
  is_default: boolean
  weight_unit: string
}>({ id: null, unit_name: '', weight_per_unit: null, is_default: false, weight_unit: '' })

const globalWeightUnits = computed(() =>
  globalUnits.value.filter((unit: any) => unit.unit_type === 'mass' || unit.unit_type === 'volume'),
)
const density = computed(() => {
  const value = densityKgM3.value
  return value != null && value > 0 ? value : 1000
})

watch(
  () => props.modelValue,
  (open) => {
    if (open) void ensureLoaded()
  },
)
watch(
  () => props.ingredientId,
  () => {
    globalUnitsLoaded.value = false
    if (props.modelValue) void ensureLoaded()
  },
)

async function ensureLoaded() {
  const ingredientId = props.ingredientId ?? null
  if (globalUnitsLoaded.value && loadedIngredientId.value === ingredientId) return
  loading.value = true
  try {
    const [unitsResponse, inheritedResponse, densityResponse] = await Promise.all([
      api.get('/units/', { params: { limit: 200 } }).catch(() => []),
      ingredientId
        ? api.get(`/entities/ingredient/${ingredientId}/units`).catch(() => [])
        : Promise.resolve([]),
      ingredientId
        ? api.get(`/entities/ingredient/${ingredientId}/density`).catch(() => [])
        : Promise.resolve([]),
    ])
    globalUnits.value = Array.isArray(unitsResponse) ? unitsResponse : unitsResponse?.items || []
    const inherited = Array.isArray(inheritedResponse)
      ? inheritedResponse
      : inheritedResponse?.items || []
    ingredientUnits.value = inherited
    const densityRows = Array.isArray(densityResponse) ? densityResponse : densityResponse?.items || []
    densityKgM3.value = densityRows.length > 0 && densityRows[0]?.density != null
      ? Number(densityRows[0].density)
      : null
    globalUnitsLoaded.value = true
    loadedIngredientId.value = ingredientId
  } finally {
    loading.value = false
  }
}

function onToggle(value: boolean) {
  emit('update:modelValue', value)
}

function close() {
  editorOpen.value = false
  emit('update:modelValue', false)
}

const unitOptions = computed(() => {
  const options: { title: string; value: string }[] = []
  for (const unit of globalWeightUnits.value) {
    const name = unit.name || unit.abbreviation || ''
    const label = unit.abbreviation && unit.abbreviation !== name
      ? `${name} (${unit.abbreviation})`
      : name
    options.push({ title: label, value: `u:${unit.id}` })
  }
  const selfId = editorForm.value.id
  for (const unit of props.units) {
    if (unit.id === selfId) continue
    // 引用会成环的候选不提供（与后端环检测同口径）
    if (draftChainReaches(props.units, unit.id, selfId)) continue
    options.push({
      title: `${unit.unit_name}${t('products.unitCustomUnitSuffix')}`,
      value: `d:${unit.id}`,
    })
  }
  for (const row of ingredientUnits.value) {
    if (row?.id == null) continue
    options.push({
      title: `${row.unit_name}${t('products.unitInheritedUnitSuffix')}`,
      value: `i:${row.id}`,
    })
  }
  return options
})

function openEditor(unit?: EntityDraftUnit) {
  editorError.value = ''
  if (unit) {
    editorForm.value = {
      id: unit.id,
      unit_name: unit.unit_name,
      weight_per_unit: unit.weight_per_unit,
      is_default: unit.is_default,
      weight_unit: unit.weight_unit_override_id != null
        ? `${unit.weight_unit_override_id < 0 ? 'd' : 'i'}:${unit.weight_unit_override_id}`
        : (unit.weight_unit_id != null ? `u:${unit.weight_unit_id}` : ''),
    }
  } else {
    editorForm.value = {
      id: null,
      unit_name: '',
      weight_per_unit: null,
      is_default: false,
      weight_unit: '',
    }
  }
  editorOpen.value = true
}

/** 沿引用链找出叶子上的全局单位 id；未设置（按克）返回 null。 */
function leafGlobalId(startRef: string): number | null {
  let cursor = startRef
  const visited = new Set<string>()
  for (let depth = 0; depth <= 8; depth += 1) {
    if (!cursor || visited.has(cursor)) return null
    visited.add(cursor)
    const [kind, rawId] = cursor.split(':')
    const id = Number(rawId)
    if (kind === 'u') return id
    const row = kind === 'i'
      ? ingredientUnits.value.find((item: any) => Number(item.id) === id)
      : props.units.find(item => item.id === id)
    if (!row) return null
    const overrideRef = (row as any).weight_unit_override_id
    if (overrideRef != null) {
      cursor = `${Number(overrideRef) < 0 ? 'd' : 'i'}:${overrideRef}`
      continue
    }
    const globalRef = (row as any).weight_unit_id
    return globalRef != null ? Number(globalRef) : null
  }
  return null
}

const volumePreview = computed(() => {
  const leafId = leafGlobalId(editorForm.value.weight_unit)
  if (leafId == null) return ''
  const leaf = globalUnits.value.find((unit: any) => Number(unit.id) === leafId)
  if (!leaf || leaf.unit_type !== 'volume') return ''
  const amount = Number(editorForm.value.weight_per_unit)
  if (!isFinite(amount) || amount <= 0) return t('products.volumeDensityHintEmpty')
  // 体积：克 = 量 × si_factor(L) × 密度(kg/m³)（0.001 与 1000 抵消）
  const si = Number(leaf.si_factor)
  const grams = amount * (isFinite(si) && si !== 0 ? si : 1) * density.value
  return t('products.volumeDensityHint', {
    density: formatNumber(density.value / 1000, localeStore.effectiveFormatLocale, {
      maximumFractionDigits: 3,
    }),
    grams: formatNumber(grams, localeStore.effectiveFormatLocale, { maximumFractionDigits: 1 }),
  })
})

function saveEditor() {
  const name = editorForm.value.unit_name.trim()
  if (!name) {
    editorError.value = t('products.unitNameRequired')
    return
  }
  const raw = editorForm.value.weight_unit
  const [kind, rawId] = raw ? raw.split(':') : ['', '']
  const amount = editorForm.value.weight_per_unit == null || editorForm.value.weight_per_unit === ''
    ? null
    : Number(editorForm.value.weight_per_unit)
  const next: EntityDraftUnit = {
    id: editorForm.value.id ?? nextDraftUnitId(props.units),
    unit_name: name,
    weight_per_unit: amount != null && isFinite(amount) && amount > 0 ? amount : null,
    is_default: editorForm.value.is_default,
    weight_unit_id: kind === 'u' ? Number(rawId) : null,
    weight_unit_override_id: kind === 'd' || kind === 'i' ? Number(rawId) : null,
  }
  const units = [...props.units]
  const index = units.findIndex(unit => unit.id === next.id)
  if (index >= 0) units.splice(index, 1, next)
  else units.push(next)
  emit('update:units', units)
  editorOpen.value = false
}

function removeUnit(unitId: number) {
  // 删掉被引用的单位时，同批草稿里指向它的引用一并清空，避免留下悬空引用
  const units = props.units
    .filter(unit => unit.id !== unitId)
    .map(unit => (unit.weight_unit_override_id === unitId
      ? { ...unit, weight_unit_override_id: null }
      : unit))
  emit('update:units', units)
}

function refLabel(refId: number): string {
  if (refId < 0) {
    const unit = props.units.find(item => item.id === refId)
    return unit ? `${unit.unit_name}${t('products.unitCustomUnitSuffix')}` : `#${refId}`
  }
  const row = ingredientUnits.value.find((item: any) => Number(item.id) === refId)
  return row ? `${row.unit_name}${t('products.unitInheritedUnitSuffix')}` : `#${refId}`
}

function unitLine(unit: EntityDraftUnit): string {
  const amounts = draftUnitAmounts(unit, props.units, ingredientUnits.value, globalUnits.value, density.value)
  const head = `1${unit.unit_name} = `
  const amountText = unit.weight_per_unit != null
    ? formatQuantity(unit.weight_per_unit, localeStore.effectiveFormatLocale)
    : '1'
  if (unit.weight_unit_override_id != null) {
    const text = `${head}${amountText}${refLabel(unit.weight_unit_override_id)}`
    if (amounts?.milliliters != null) {
      return `${text}${t('products.unitChainVolumeDisplay', {
        grams: formatNumber(amounts.grams, localeStore.effectiveFormatLocale, {
          maximumFractionDigits: 1,
        }),
      })}`
    }
    return text
  }
  if (amounts == null) {
    return unit.weight_per_unit != null ? `${head}${amountText} g` : ''
  }
  if (amounts.milliliters != null) {
    return `${head}${t('products.unitVolumeDisplay', {
      volume: formatQuantity(amounts.milliliters, localeStore.effectiveFormatLocale),
      grams: formatNumber(amounts.grams, localeStore.effectiveFormatLocale, {
        maximumFractionDigits: 1,
      }),
    })}`
  }
  return `${head}${formatQuantity(amounts.grams, localeStore.effectiveFormatLocale)} g`
}
</script>

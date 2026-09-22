<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { previewUsdaNutrients } from '@/api/usda'
import type { Proposal } from '@/api/proposals'
import { formatNumber } from '@/utils/format'
import { nutrientLabel, nutrientUnitLabel } from '@/utils/nutritionLabels'
import { useLocaleStore } from '@/stores/locale'

const props = defineProps<{ proposal: Proposal }>()
const { t } = useI18n()
const localeStore = useLocaleStore()

interface NutrientEntry { value: number | null; unit: string }

function numOrNull(v: any): number | null {
  if (v === null || v === undefined || v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

// Unify multiple source shapes into {display_name → {value, unit}}
// Supports:
//   - Three-layer struct {core_nutrients, all_nutrients} (nutrition/product_nutrition/usda_product_match/USDA preview)
//   - Array of NutritionData rows (usda_ingredient_match snapshot.old_nutrition_data)
function normalizeNutritionMap(source: any): Map<string, NutrientEntry> {
  const out = new Map<string, NutrientEntry>()
  if (!source) return out
  if (Array.isArray(source)) {
    for (const row of source) {
      const m = normalizeNutritionMap(row?.nutrients)
      for (const [k, v] of m) out.set(k, v)
    }
    return out
  }
  // 先处理 all_nutrients（用英文 key 做唯一标识），跳过 nutrient_details（内容同 all）
  const all = source.all_nutrients
  if (all && typeof all === 'object') {
    for (const [key, entry] of Object.entries(all)) {
      const e = entry as any
      if (e && typeof e === 'object') {
        const k = e.key || key
        if (!out.has(k)) {
          out.set(k, { value: numOrNull(e.value), unit: e.unit || '' })
        }
      }
    }
  }
  // core_nutrients 用 e.key 做键（不另加中文名行），与 all_nutrients 去重
  const core = source.core_nutrients
  if (core && typeof core === 'object') {
    for (const [name, entry] of Object.entries(core)) {
      const e = entry as any
      if (e && typeof e === 'object') {
        const k = e.key || name
        if (!out.has(k)) {
          out.set(k, { value: numOrNull(e.value), unit: e.unit || '' })
        }
      }
    }
  }
  return out
}

const entityType = computed(() => props.proposal.entity_type)
const isUsda = computed(() =>
  entityType.value === 'usda_ingredient_match' || entityType.value === 'usda_product_match')

const beforeMap = computed(() => {
  const snap = props.proposal.snapshot || {}
  if (entityType.value === 'nutrition') return normalizeNutritionMap(snap.nutrients)
  if (entityType.value === 'product_nutrition') return normalizeNutritionMap(snap.old_custom_nutrition_data)
  if (entityType.value === 'usda_product_match') return normalizeNutritionMap(snap.old_custom_nutrition_data)
  if (entityType.value === 'usda_ingredient_match') return normalizeNutritionMap(snap.old_nutrition_data)
  return new Map<string, NutrientEntry>()
})

const afterMapFromPayload = computed(() => {
  const p = props.proposal.payload || {}
  if (entityType.value === 'nutrition') return normalizeNutritionMap(p.nutrients)
  if (entityType.value === 'product_nutrition') return normalizeNutritionMap(p.custom_nutrition_data)
  return new Map<string, NutrientEntry>()
})

const fdcId = computed(() => (props.proposal.payload || {}).fdc_id ?? null)
const isClearOp = computed(() => {
  const p = props.proposal.payload || {}
  if (entityType.value === 'product_nutrition' || entityType.value === 'usda_product_match') {
    return 'custom_nutrition_data' in p && p.custom_nutrition_data === null
  }
  return false
})

const usdaAfter = ref<Map<string, NutrientEntry>>(new Map())
const usdaLoading = ref(false)
const usdaError = ref(false)

async function loadUsdaAfter() {
  if (!isUsda.value || fdcId.value == null) return
  usdaLoading.value = true
  usdaError.value = false
  try {
    const struct = await previewUsdaNutrients(fdcId.value as number)
    usdaAfter.value = normalizeNutritionMap(struct)
  } catch {
    usdaError.value = true
    usdaAfter.value = new Map()
  } finally {
    usdaLoading.value = false
  }
}

watch(() => [props.proposal.id, fdcId.value], loadUsdaAfter, { immediate: true })

const afterMap = computed(() => (isUsda.value ? usdaAfter.value : afterMapFromPayload.value))

const hasBeforeData = computed(() => beforeMap.value.size > 0)

function sameNum(a: number | null, b: number | null): boolean {
  if (a === null && b === null) return true
  if (a === null || b === null) return false
  if (a === b) return true
  // 容忍表单精度丢失：四舍五入到 2 位小数后比较（输入框一般为 2 位小数）
  // USDA 原始值 0.037/0.028 经表单回来变 0.04/0.03，应视为未变更
  return Math.round(a * 100) === Math.round(b * 100)
}

interface DiffRow { name: string; displayName: string; before: number | null; after: number | null; unit: string; changed: boolean }

const rows = computed<DiffRow[]>(() => {
  const names = new Set<string>([...beforeMap.value.keys(), ...afterMap.value.keys()])
  const list: DiffRow[] = []
  for (const name of names) {
    const b = beforeMap.value.get(name)
    const a = afterMap.value.get(name)
    const before = b?.value ?? null
    const after = a?.value ?? null
    const displayName = nutrientLabel(name)
    const inBefore = beforeMap.value.has(name)
    const inAfter = afterMap.value.has(name)
    // 只有以下情况才算「已变更」：
    //   - 用户提交了新值（afterMap 有）且值不同
    //   - 纯新增（beforeMap 无）
    // 仅 beforeMap 有的条目（用户未提交）不算变更
    const changed = hasBeforeData.value && inAfter && (!inBefore || !sameNum(before, after))
    list.push({
      name, displayName, before, after,
      unit: a?.unit || b?.unit || '',
      changed,
    })
  }
  return list.sort((x, y) =>
    Number(y.changed) - Number(x.changed) ||
    x.displayName.localeCompare(y.displayName, localeStore.effectiveFormatLocale))
})

const changedRows = computed(() => rows.value.filter(r => r.changed))
const unchangedRows = computed(() => rows.value.filter(r => !r.changed))
const showUnchanged = ref(false)

function formatVal(v: number | null): string {
  return v === null ? t('proposals.emptyValue') : formatNumber(v, localeStore.effectiveFormatLocale)
}
</script>

<template>
  <div>
    <v-alert v-if="usdaError && isUsda" type="warning" variant="tonal" density="compact" class="mb-2">
      {{ t('proposals.usdaPreviewUnavailable') }}
    </v-alert>
    <v-table v-if="rows.length" density="compact" class="nutrition-diff-table">
      <thead>
        <tr>
          <th class="text-caption text-medium-emphasis" style="width: 44%">{{ t('proposals.nutrient') }}</th>
          <th class="text-caption text-medium-emphasis">{{ t('proposals.current') }}</th>
          <th class="text-caption text-medium-emphasis">{{ t('proposals.newValue') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in (showUnchanged ? rows : changedRows)" :key="row.name" :class="{ 'nut-changed': row.changed }">
          <td>{{ row.displayName }}</td>
          <td>
            {{ formatVal(row.before) }}<span class="text-medium-emphasis ms-1">{{ nutrientUnitLabel(row.unit) }}</span>
          </td>
          <td>
            <span v-if="usdaLoading && isUsda" class="text-medium-emphasis">{{ t('proposals.loading') }}</span>
            <span v-else>
              {{ formatVal(row.after) }}<span class="text-medium-emphasis ms-1">{{ nutrientUnitLabel(row.unit) }}</span>
            </span>
          </td>
        </tr>
        <tr v-if="!showUnchanged && unchangedRows.length">
          <td colspan="3">
            <v-btn variant="text" size="small" @click="showUnchanged = true">
              {{ t('proposals.showUnchanged', { count: formatNumber(unchangedRows.length, localeStore.effectiveFormatLocale) }) }}
            </v-btn>
          </td>
        </tr>
        <tr v-else-if="showUnchanged && unchangedRows.length">
          <td colspan="3">
            <v-btn variant="text" size="small" @click="showUnchanged = false">{{ t('proposals.collapseUnchanged') }}</v-btn>
          </td>
        </tr>
      </tbody>
    </v-table>
    <div v-else-if="usdaLoading && isUsda" class="text-caption text-medium-emphasis">{{ t('proposals.usdaNutrientsLoading') }}</div>
    <div v-else-if="isClearOp" class="text-caption text-medium-emphasis">
      <v-icon size="small" color="warning">mdi-alert</v-icon>
      {{ t('proposals.clearAllNutrition') }}
    </div>
    <div v-else class="text-caption text-medium-emphasis">{{ t('proposals.noNutrientData') }}</div>
  </div>
</template>

<style scoped>
.nutrition-diff-table .nut-changed { background: rgba(255, 193, 7, 0.12); }
</style>

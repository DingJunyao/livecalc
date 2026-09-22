<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { Proposal } from '@/api/proposals'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'
import { unitDisplayName } from '@/utils/catalogLabels'

const props = defineProps<{ proposal: Proposal }>()
const snap = computed(() => props.proposal.snapshot || {})
const p = computed(() => props.proposal.payload || {})
const action = computed(() => props.proposal.action)
const { t } = useI18n()
const localeStore = useLocaleStore()

// 字段行定义：label + payload/snapshot 取值函数 + 格式化
interface FieldDef { label: string; key: string; fmt?: (v: any, row: any) => string }

function fmtFactor(v: any): string {
  if (v == null || v === '') return '—'
  return t('proposals.multiplicationFactor', { value: formatNumber(v, localeStore.effectiveFormatLocale) })
}
function fmtWeightPerUnit(v: any, row: any): string {
  if (v == null || v === '') return '—'
  const unitId = row.weight_unit_id
  const amount = formatNumber(v, localeStore.effectiveFormatLocale)
  return unitId != null
    ? t('proposals.valueWithUnitId', { amount, unitId: formatNumber(unitId, localeStore.effectiveFormatLocale) })
    : amount
}

const fields = computed<FieldDef[]>(() => [
  { label: t('proposals.unitName'), key: 'unit_name', fmt: (v) => unitDisplayName({ name: v, abbreviation: v }) },
  { label: t('proposals.conversionFactor'), key: 'conversion_factor', fmt: fmtFactor },
  { label: t('proposals.weightPerUnit'), key: 'weight_per_unit', fmt: fmtWeightPerUnit },
  { label: t('proposals.isDefault'), key: 'is_default', fmt: (v) => v == null ? '—' : (v ? t('proposals.yes') : t('proposals.no')) },
])

function getVal(source: any, f: FieldDef): string {
  const raw = source[f.key]
  if (raw == null || raw === '') return '—'
  return f.fmt ? f.fmt(raw, source) : String(raw)
}
function rowKind(f: FieldDef): string {
  const hasB = f.key in snap.value, hasA = f.key in p.value
  if (action.value === 'create') return 'added'
  if (action.value === 'delete') return 'removed'
  const b = JSON.stringify(snap.value[f.key]), a = JSON.stringify(p.value[f.key])
  if (hasB && hasA && b !== a) return 'changed'
  return 'unchanged'
}
</script>

<template>
  <v-table density="compact" class="diff-table unit-override-table">
    <tbody>
      <tr v-for="f in fields" :key="f.key">
        <td class="text-caption text-medium-emphasis" style="width:24%">{{ f.label }}</td>
        <td :class="['diff-cell', 'before', action === 'create' ? 'unchanged' : rowKind(f)]">
          {{ action === 'create' ? '—' : getVal(snap, f) }}
        </td>
        <td class="text-center text-medium-emphasis" style="width:32px">→</td>
        <td :class="['diff-cell', 'after', action === 'delete' ? 'removed' : rowKind(f)]">
          {{ action === 'delete' ? t('proposals.deletedValue') : getVal(p, f) }}
        </td>
      </tr>
    </tbody>
  </v-table>
</template>

<style scoped>
.unit-override-table :deep(table) { table-layout: fixed; width: 100%; }
.unit-override-table :deep(td) { height: auto !important; vertical-align: top; word-break: break-word; padding: 6px 8px !important; }
.diff-table .diff-cell.changed { background: rgba(255, 193, 7, 0.12); }
.diff-table .diff-cell.added { background: rgba(76, 175, 80, 0.12); }
.diff-table .diff-cell.removed { background: rgba(244, 67, 54, 0.10); }
</style>

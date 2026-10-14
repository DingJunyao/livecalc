<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import type { Proposal } from '@/api/proposals'
import { api } from '@/api'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'
import { unitDisplayName } from '@/utils/catalogLabels'

const props = defineProps<{ proposal: Proposal }>()
const snap = computed(() => props.proposal.snapshot || {})
const p = computed(() => props.proposal.payload || {})
const action = computed(() => props.proposal.action)
const { t } = useI18n()
const localeStore = useLocaleStore()

// weight_unit_id → 缩写（g/mL），用于展示每单位量的类型
const unitAbbrById = ref<Map<number, string>>(new Map())
// 自定义单位覆盖 id → unit_name（嵌套 weight_unit_override_id 的解析）
const overrideNameById = ref<Map<number, string>>(new Map())

// 业务实体上下文：create 在 payload、delete 在 snapshot；
// update 的 payload 只有变更字段，拿不到实体 → 嵌套引用退回显示原始 id。
const entityContext = computed<{ type: string; id: number } | null>(() => {
  const sources = [p.value, snap.value]
  for (const src of sources) {
    const type = src?.entity_type
    const id = src?.entity_id
    if (type && id != null) return { type: String(type), id: Number(id) }
  }
  return null
})

onMounted(async () => {
  try {
    const res = await api.get('/units/', { params: { limit: 500 } })
    const arr: any[] = Array.isArray(res) ? res : (res?.items || [])
    unitAbbrById.value = new Map(arr.map((x: any) => [x.id, x.abbreviation]))
  } catch {
    // 拿不到单位表时回退显示原始 id
  }

  const ctx = entityContext.value
  if (ctx) {
    try {
      const res = await api.get(`/entities/${ctx.type}/${ctx.id}/units`)
      const arr: any[] = Array.isArray(res) ? res : (res?.items || [])
      overrideNameById.value = new Map(arr.map((x: any) => [x.id, x.unit_name]))
    } catch {
      // 拿不到实体自定义单位表时回退显示原始 id
    }
  }
})

/** 嵌套引用：解析成被引用自定义单位的名称；拿不到就显示原始 id。 */
function resolveOverrideLabel(id: any): string {
  if (id == null || id === '') return '—'
  const name = overrideNameById.value.get(Number(id))
  return name ? String(name) : `#${id}`
}

// 字段行定义：label + payload/snapshot 取值函数 + 格式化
interface FieldDef {
  label: string
  key: string
  /** 参与变更比较的字段（缺省只有 key；嵌套引用需要一并比较） */
  keys?: string[]
  fmt?: (v: any, row: any) => string
  /** 原值为空时也交给 fmt（用于「换算系数/每单位量 + 嵌套引用」这类组合值） */
  fmtOnEmpty?: boolean
}

function fmtFactor(v: any): string {
  if (v == null || v === '') return '—'
  return t('proposals.multiplicationFactor', { value: formatNumber(v, localeStore.effectiveFormatLocale) })
}
function fmtWeightPerUnit(v: any, row: any): string {
  const refId = row?.weight_unit_override_id
  const hasRef = refId != null && refId !== ''
  // 嵌套引用时 weight_per_unit 缺省按 1（1 个该单位 = 1 × 被引用单位）
  const raw = (v == null || v === '') && hasRef ? 1 : v
  if (raw == null || raw === '') return '—'
  const amount = formatNumber(raw, localeStore.effectiveFormatLocale)
  const unit = hasRef
    ? resolveOverrideLabel(refId)
    : (row.weight_unit_id != null ? unitAbbrById.value.get(row.weight_unit_id) : null)
  return unit
    ? t('proposals.valueWithUnit', { amount, unit })
    : amount
}

const fields = computed<FieldDef[]>(() => [
  { label: t('proposals.unitName'), key: 'unit_name', fmt: (v) => unitDisplayName({ name: v, abbreviation: v }) },
  { label: t('proposals.conversionFactor'), key: 'conversion_factor', fmt: fmtFactor },
  {
    label: t('proposals.weightPerUnit'),
    key: 'weight_per_unit',
    // 嵌套自定义单位（weight_unit_override_id）变化也要高亮本行
    keys: ['weight_per_unit', 'weight_unit_override_id'],
    fmt: fmtWeightPerUnit,
    fmtOnEmpty: true,
  },
  { label: t('proposals.isDefault'), key: 'is_default', fmt: (v) => v == null ? '—' : (v ? t('proposals.yes') : t('proposals.no')) },
])

function getVal(source: any, f: FieldDef): string {
  const raw = source[f.key]
  if (f.fmt && (f.fmtOnEmpty || (raw != null && raw !== ''))) return f.fmt(raw, source)
  if (raw == null || raw === '') return '—'
  return String(raw)
}
function rowKind(f: FieldDef): string {
  const keys = f.keys ?? [f.key]
  const hasB = keys.some((k) => k in snap.value)
  const hasA = keys.some((k) => k in p.value)
  if (action.value === 'create') return 'added'
  if (action.value === 'delete') return 'removed'
  const b = JSON.stringify(keys.map((k) => snap.value[k]))
  const a = JSON.stringify(keys.map((k) => p.value[k]))
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

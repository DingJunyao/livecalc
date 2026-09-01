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

function fmtDensity(d: any, u: any): string {
  if (d == null) return '—'
  const value = formatNumber(d, localeStore.effectiveFormatLocale)
  return u ? `${value} ${unitDisplayName({ name: u, abbreviation: u })}` : value
}
</script>

<template>
  <v-table density="compact" class="diff-table">
    <tbody>
      <tr>
        <td class="text-caption text-medium-emphasis" style="width:28%">{{ t('proposals.density') }}</td>
        <td class="diff-cell before unchanged">
          {{ action === 'create' ? '—' : fmtDensity(snap.density, snap.unit) }}
        </td>
        <td class="text-center text-medium-emphasis" style="width:32px">→</td>
        <td class="diff-cell after added">
          {{ action === 'delete' ? t('proposals.deletedValue') : fmtDensity(p.density, p.unit) }}
        </td>
      </tr>
      <tr v-if="p.confidence !== undefined || snap.confidence !== undefined">
        <td class="text-caption text-medium-emphasis">{{ t('proposals.confidence') }}</td>
        <td class="diff-cell before unchanged">{{ snap.confidence == null ? '—' : formatNumber(snap.confidence, localeStore.effectiveFormatLocale) }}</td>
        <td class="text-center text-medium-emphasis">→</td>
        <td class="diff-cell after added">{{ p.confidence == null ? '—' : formatNumber(p.confidence, localeStore.effectiveFormatLocale) }}</td>
      </tr>
      <tr v-if="p.condition !== undefined || snap.condition !== undefined">
        <td class="text-caption text-medium-emphasis">{{ t('proposals.condition') }}</td>
        <td class="diff-cell before unchanged">{{ snap.condition ?? '—' }}</td>
        <td class="text-center text-medium-emphasis">→</td>
        <td class="diff-cell after added">{{ p.condition ?? '—' }}</td>
      </tr>
    </tbody>
  </v-table>
</template>

<style scoped>
.diff-table .diff-cell.changed { background: rgba(255, 193, 7, 0.12); }
.diff-table .diff-cell.added { background: rgba(76, 175, 80, 0.12); }
.diff-table .diff-cell.removed { background: rgba(244, 67, 54, 0.10); }
</style>

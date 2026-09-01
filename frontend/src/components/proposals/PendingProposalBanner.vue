<template>
  <v-alert
    v-if="allProposals.length"
    :type="alertType"
    variant="tonal"
    density="comfortable"
    class="mb-3"
    :icon="icon"
  >
    <div class="text-body-2">
      {{ message }}
    </div>
  </v-alert>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useLocaleStore } from '@/stores/locale'

type PendingProposal = {
  id: number
  entity_type?: string
  action: string
  payload: Record<string, any>
}

const props = defineProps<{
  proposal?: PendingProposal | null
  proposals?: PendingProposal[]
  fieldLabels?: Record<string, string>
  proposalLabels?: Record<string, string>
}>()
const { t } = useI18n()
const localeStore = useLocaleStore()

const allProposals = computed(() => {
  if (props.proposals?.length) return props.proposals
  return props.proposal ? [props.proposal] : []
})

const hasDelete = computed(() =>
  allProposals.value.some(proposal => proposal.action === 'delete')
)

const alertType = computed(() => (hasDelete.value ? 'warning' : 'info'))

const icon = computed(() =>
  hasDelete.value ? 'mdi-delete-clock-outline' : 'mdi-clock-edit-outline'
)

const internalFields = new Set(['updated_by', 'update_by'])

const modificationLabels = computed(() => {
  const labels: string[] = []
  for (const proposal of allProposals.value) {
    const wholeItemLabel = proposal.entity_type
      ? props.proposalLabels?.[proposal.entity_type]
      : null
    if (wholeItemLabel) {
      if (!labels.includes(wholeItemLabel)) labels.push(wholeItemLabel)
      continue
    }
    if (proposal.action !== 'update') continue
    const changes = proposal.payload?.update_data || proposal.payload || {}
    for (const field of Object.keys(changes)) {
      if (internalFields.has(field)) continue
      const label = props.fieldLabels?.[field] || field
      if (label && !labels.includes(label)) labels.push(label)
    }
  }
  return labels
})

const message = computed(() => {
  const labels = modificationLabels.value
  if (!props.proposals?.length && props.proposal) {
    if (props.proposal.action === 'delete') {
      return t('proposals.pendingDeleteSingle')
    }
    return t('proposals.pendingUpdateSingle')
  }
  if (!hasDelete.value) {
    return t('proposals.pendingUpdates', {
      fields: new Intl.ListFormat(localeStore.effectiveFormatLocale, { type: 'conjunction' }).format(labels),
    })
  }
  if (!labels.length) {
    return t('proposals.pendingDeleteSingle')
  }
  return t('proposals.pendingUpdatesAndDelete', {
    fields: new Intl.ListFormat(localeStore.effectiveFormatLocale, { type: 'conjunction' }).format(labels),
  })
})
</script>

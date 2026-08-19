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

type PendingProposal = {
  id: number
  action: string
  payload: Record<string, any>
}

const props = defineProps<{
  proposal?: PendingProposal | null
  proposals?: PendingProposal[]
  fieldLabels?: Record<string, string>
}>()

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
      return '该条目已提交删除申请，待管理员审核。审核通过后该条目将被删除。'
    }
    return '修改待审核——您看到的是已提交的修改内容。审核通过后将正式生效。'
  }
  if (!hasDelete.value) {
    return `修改待管理员审核：${labels.join('、')}`
  }
  if (!labels.length) {
    return '该条目已提交删除申请，待管理员审核。审核通过后该条目将被删除。'
  }
  return `待管理员审核：修改${labels.join('、')}、删除该条目`
})
</script>

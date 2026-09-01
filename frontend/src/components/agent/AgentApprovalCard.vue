<!--
  SQL 审批 inline 卡片：显示 SQL + danger_reason + affected_estimate
  approve/reject → emit
-->
<template>
  <v-card
    variant="outlined"
    class="approval-card mb-3"
    :class="borderClass"
  >
    <v-card-text class="pa-3">
      <div class="d-flex align-center mb-2">
        <v-icon size="18" class="mr-2" :color="iconColor">{{ icon }}</v-icon>
        <span class="text-subtitle-2 font-weight-bold">{{ t('agent.approval.title') }}</span>
        <v-spacer />
        <v-chip size="x-small" :color="statusColor" variant="tonal">{{ statusLabel }}</v-chip>
      </div>

      <div v-if="approval.danger_reason" class="text-body-2 mb-2" :class="dangerTextClass">
        <v-icon size="14" class="mr-1">mdi-alert</v-icon>{{ approval.danger_reason }}
      </div>

      <div v-if="approval.affected_estimate != null" class="text-caption text-medium-emphasis mb-2">
        {{ t('agent.approval.estimatedRows', { count: approval.affected_estimate }) }}
      </div>

      <pre class="sql-block"><code>{{ approval.sql }}</code></pre>

      <div v-if="!isPending" class="mt-2 text-caption text-medium-emphasis">
        <span v-if="approval.status === 'approved' || approval.status === 'auto_executed'">
          {{ approval.decided_at
            ? t('agent.approval.approvedAt', { time: formatTime(approval.decided_at) })
            : t('agent.approval.approved') }}
        </span>
        <span v-else-if="approval.status === 'rejected'">
          {{ approval.decided_at
            ? t('agent.approval.rejectedAt', { time: formatTime(approval.decided_at) })
            : t('agent.approval.rejected') }}
        </span>
        <span v-else-if="approval.status === 'failed'">{{ t('agent.approval.failed') }}</span>
        <span v-else-if="approval.status === 'timeout'">{{ t('agent.approval.timeout') }}</span>
      </div>
    </v-card-text>

    <v-card-actions v-if="isPending" class="px-3 pb-3 pt-0">
      <v-spacer />
      <v-btn
        variant="text"
        color="error"
        :loading="loading === 'reject'"
        :disabled="loading === 'approve'"
        @click="onDecide(false)"
      >
        <v-icon start>mdi-close</v-icon>{{ t('agent.approval.reject') }}
      </v-btn>
      <v-btn
        variant="flat"
        color="warning"
        :loading="loading === 'approve'"
        :disabled="loading === 'reject'"
        @click="onDecide(true)"
      >
        <v-icon start>mdi-check</v-icon>{{ t('agent.approval.approve') }}
      </v-btn>
    </v-card-actions>
  </v-card>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import type { AgentApproval } from '@/types/agent'
import { formatDateTime } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'

const props = defineProps<{ approval: AgentApproval }>()
const { t } = useI18n()
const emit = defineEmits<{
  (e: 'decide', aid: number, approved: boolean): void
}>()

const loading = ref<'approve' | 'reject' | null>(null)
const localeStore = useLocaleStore()

const isPending = computed(() => props.approval.status === 'pending')

const statusColor = computed(() => {
  switch (props.approval.status) {
    case 'pending':
      return 'warning'
    case 'approved':
    case 'auto_executed':
      return 'success'
    case 'rejected':
      return 'error'
    case 'failed':
      return 'error'
    case 'timeout':
      return 'grey'
    default:
      return 'default'
  }
})

const statusLabel = computed(() => {
  const map: Record<string, string> = {
    pending: t('agent.approval.statusPending'),
    approved: t('agent.approval.statusApproved'),
    auto_executed: t('agent.approval.statusExecuted'),
    rejected: t('agent.approval.statusRejected'),
    failed: t('agent.approval.failed'),
    timeout: t('agent.approval.statusTimedOut'),
  }
  return map[props.approval.status] || props.approval.status
})

const icon = computed(() => {
  switch (props.approval.status) {
    case 'approved':
    case 'auto_executed':
      return 'mdi-check-circle'
    case 'rejected':
      return 'mdi-close-circle'
    case 'failed':
      return 'mdi-alert-circle'
    case 'timeout':
      return 'mdi-clock-alert'
    default:
      return 'mdi-shield-key'
  }
})

const iconColor = computed(() => statusColor.value)

const borderClass = computed(() => {
  return props.approval.status === 'pending' ? 'border-pending' : ''
})

const dangerTextClass = computed(() =>
  props.approval.danger_reason ? 'text-warning' : '',
)

function formatTime(s: string): string {
  return formatDateTime(s, localeStore.effectiveFormatLocale)
}

async function onDecide(approved: boolean) {
  loading.value = approved ? 'approve' : 'reject'
  try {
    emit('decide', props.approval.id, approved)
  } finally {
    loading.value = null
  }
}
</script>

<style scoped>
.approval-card.border-pending {
  border-color: rgb(var(--v-theme-warning)) !important;
  border-width: 2px !important;
}
.sql-block {
  background: rgb(var(--v-theme-code, 30, 30, 30));
  color: rgb(var(--v-theme-on-code, 245, 245, 245));
  padding: 8px 10px;
  border-radius: 6px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 12.5px;
  overflow-x: auto;
  white-space: pre-wrap;
  word-break: break-word;
  margin: 0;
}
</style>

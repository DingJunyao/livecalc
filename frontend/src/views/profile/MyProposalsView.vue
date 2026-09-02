<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('proposals.title') }}</v-app-bar-title>
    <template #append>
      <v-btn icon="mdi-refresh" variant="text" @click="loadList" />
    </template>
  </v-app-bar>

  <v-container class="pa-4">
    <!-- 待审提示 -->
    <v-alert
      v-if="pendingProposals.length > 0"
      type="info"
      variant="tonal"
      density="comfortable"
      class="mb-4"
    >
      {{ t('proposals.pendingAlert', { count: pendingProposals.length }) }}
    </v-alert>

    <!-- 状态筛选 -->
    <v-card class="rounded-lg mb-4">
      <v-card-text class="d-flex flex-wrap align-center ga-3 py-3">
        <div class="text-subtitle-2 text-medium-emphasis me-2">{{ t('proposals.statusLabel') }}</div>
        <v-chip-group v-model="statusFilter" mandatory column>
          <v-chip
            v-for="opt in statusOptions"
            :key="opt.value"
            :value="opt.value"
            :color="opt.color"
            filter
            variant="tonal"
            size="small"
          >
            <v-icon start size="small">{{ opt.icon }}</v-icon>
            {{ opt.label }}
          </v-chip>
        </v-chip-group>
        <v-spacer />
        <div class="text-caption text-medium-emphasis">
          {{ t('proposals.totalCount', { count: proposals.length }) }}
        </div>
      </v-card-text>
    </v-card>

    <!-- 提议列表 -->
    <v-card class="rounded-lg">
      <v-data-table
        :headers="headers"
        :items="proposals"
        :loading="loading"
        item-value="id"
        hover
        density="comfortable"
        :no-data-text="t('proposals.noData')"
      >
        <template #item.status="{ item }">
          <v-chip :color="statusColor(item.status)" size="small" variant="tonal">
            <v-icon start size="small">{{ statusIcon(item.status) }}</v-icon>
            {{ statusLabel(item.status) }}
          </v-chip>
        </template>

        <template #item.type="{ item }">
          <div class="d-flex flex-column">
            <span class="text-body-2 font-weight-medium">
              {{ entityTypeLabel(item.entity_type) }} · {{ actionLabel(item.action) }}
            </span>
            <span class="text-caption text-medium-emphasis">#{{ item.id }}</span>
          </div>
        </template>

        <template #item.summary="{ item }">
          <span class="text-body-2 text-medium-emphasis">
            {{ payloadSummary(item) }}
          </span>
        </template>

        <template #item.time="{ item }">
          <div class="text-caption">
            <div v-if="item.applied_at" class="text-success">
              {{ t('proposals.applied') }}{{ formatToLocalDateTimeShort(item.applied_at) }}
            </div>
            <div v-else-if="item.reviewed_at" class="text-medium-emphasis">
              {{ t('proposals.reviewed') }}{{ formatToLocalDateTimeShort(item.reviewed_at) }}
            </div>
            <div v-else class="text-warning">
              {{ t('proposals.submitted') }}{{ formatToLocalDateTimeShort(item.created_at) }}
            </div>
          </div>
        </template>

        <template #item.actions="{ item }">
          <v-btn
            icon="mdi-eye-outline"
            size="small"
            variant="text"
            color="primary"
            @click="openDetail(item)"
          />
        </template>
      </v-data-table>
    </v-card>

    <!-- 详情对话框 -->
    <v-dialog v-model="detailDialog" max-width="780px" scrollable>
      <v-card class="rounded-lg" v-if="detailItem">
        <v-card-title class="d-flex align-center py-4 pe-2">
          <v-icon class="me-2">mdi-clipboard-text-clock</v-icon>
          <span class="text-h6">{{ t('proposals.detailTitle', { id: detailItem.id }) }}</span>
          <v-spacer />
          <v-chip :color="statusColor(detailItem.status)" size="small" variant="tonal">
            {{ statusLabel(detailItem.status) }}
          </v-chip>
          <v-btn icon="mdi-close" variant="text" size="small" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />

        <v-card-text class="py-4">
          <v-alert
            v-if="detailItem.entity_label"
            type="info"
            variant="tonal"
            density="comfortable"
            class="mb-4"
          >
            <div class="text-caption text-medium-emphasis">{{ t('proposals.targetEntity') }}</div>
            <div class="text-body-2">{{ detailItem.entity_label }}</div>
          </v-alert>

          <v-row dense>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">{{ t('proposals.entityType') }}</div>
              <div class="text-body-2">{{ entityTypeLabel(detailItem.entity_type) }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">{{ t('proposals.action') }}</div>
              <div class="text-body-2">{{ actionLabel(detailItem.action) }}</div>
            </v-col>
            <v-col cols="6" sm="4">
              <div class="text-caption text-medium-emphasis">{{ t('proposals.submittedAt') }}</div>
              <div class="text-body-2">{{ formatToLocalDateTimeShort(detailItem.created_at) }}</div>
            </v-col>
            <v-col cols="6" sm="4" v-if="detailItem.review_note">
              <div class="text-caption text-medium-emphasis">{{ t('proposals.reviewNote') }}</div>
              <div class="text-body-2">{{ detailItem.review_note }}</div>
            </v-col>
          </v-row>

          <div class="mt-4">
            <div class="text-subtitle-2 mb-2">
              <v-icon size="small" start>mdi-compare-horizontal</v-icon>
              {{ t('proposals.changes') }}
            </div>
            <component
              v-if="detailRenderer"
              :is="detailRenderer"
              :proposal="detailItem"
            />
            <template v-else>
              <v-table v-if="diffRows.length" density="compact" class="diff-table">
                <tbody>
                  <tr v-for="row in diffRows" :key="row.field">
                    <td class="text-caption text-medium-emphasis" style="width: 28%">{{ row.field }}</td>
                    <td class="diff-cell before">{{ row.before ?? '—' }}</td>
                    <td class="text-center text-medium-emphasis" style="width: 32px">→</td>
                    <td class="diff-cell after">{{ row.after ?? '—' }}</td>
                  </tr>
                </tbody>
              </v-table>
            </template>
          </div>
        </v-card-text>

        <v-divider />
        <v-card-actions class="pa-4">
          <v-btn variant="tonal" @click="detailDialog = false">{{ t('actions.close') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { formatToLocalDateTimeShort } from '@/utils/timezone'
import { listProposals, getProposal, type Proposal } from '@/api/proposals'
import { resolveProposalRenderer } from '@/proposalRenderers'

const { t } = useI18n()
const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const router = useRouter()
const goBack = () => router.back()

type FilterValue = 'all' | 'pending' | 'applied' | 'rejected' | 'reverted'
const statusFilter = ref<FilterValue>('all')
const statusOptions = computed(() => [
  { value: 'all', label: t('proposals.status.all'), color: 'default', icon: 'mdi-format-list-bulleted' },
  { value: 'pending', label: t('proposals.status.pending'), color: 'warning', icon: 'mdi-clock-outline' },
  { value: 'applied', label: t('proposals.status.applied'), color: 'success', icon: 'mdi-check-circle' },
  { value: 'rejected', label: t('proposals.status.rejected'), color: 'error', icon: 'mdi-close-circle' },
  { value: 'reverted', label: t('proposals.status.reverted'), color: 'info', icon: 'mdi-undo' },
])

const proposals = ref<Proposal[]>([])
const loading = ref(false)
const itemsPerPage = ref(20)

const headers = computed(() => [
  { title: t('proposals.headerStatus'), key: 'status', sortable: false, width: 110 },
  { title: t('proposals.headerTypeAction'), key: 'type', sortable: false },
  { title: t('proposals.headerSummary'), key: 'summary', sortable: false },
  { title: t('proposals.headerTime'), key: 'time', sortable: false, width: 180 },
  { title: t('proposals.headerActions'), key: 'actions', sortable: false, align: 'end' as const, width: 80 },
])

const pendingProposals = computed(() => proposals.value.filter(p => p.status === 'pending'))

const loadList = async () => {
  loading.value = true
  try {
    const status = statusFilter.value === 'all' ? undefined : statusFilter.value
    proposals.value = await listProposals(status as any, 100, 'mine')
  } catch (e: any) {
    console.error('Failed to load proposals', e)
  } finally {
    loading.value = false
  }
}

watch(statusFilter, () => loadList())

const detailDialog = ref(false)
const detailItem = ref<Proposal | null>(null)

const openDetail = async (item: Proposal) => {
  detailItem.value = item
  detailDialog.value = true
}

const detailRenderer = computed(() => {
  return detailItem.value ? resolveProposalRenderer(detailItem.value) : null
})

const diffRows = computed(() => {
  const item = detailItem.value
  if (!item) return []
  const before = item.snapshot || {}
  const after = item.payload || {}
  const fields = Array.from(new Set([...Object.keys(before), ...Object.keys(after)]))
  return fields.map(f => ({
    field: f,
    before: f in before ? before[f] : null,
    after: f in after ? after[f] : null,
  }))
})

function statusColor(s: string): string {
  switch (s) {
    case 'pending': return 'warning'
    case 'applied': return 'success'
    case 'rejected': return 'error'
    case 'reverted': return 'info'
    default: return 'default'
  }
}
function statusIcon(s: string): string {
  switch (s) {
    case 'pending': return 'mdi-clock-outline'
    case 'applied': return 'mdi-check-circle'
    case 'rejected': return 'mdi-close-circle'
    case 'reverted': return 'mdi-undo'
    default: return 'mdi-circle-outline'
  }
}
function statusLabel(s: string): string {
  switch (s) {
    case 'pending': return t('proposals.status.pending')
    case 'applied': return t('proposals.status.applied')
    case 'rejected': return t('proposals.status.rejected')
    case 'reverted': return t('proposals.status.reverted')
    default: return s
  }
}
function entityTypeLabel(t: string): string {
  const map: Record<string, string> = {
    ingredient: t('proposals.entity.ingredient'), nutrition: t('proposals.entity.nutrition'), unit: t('proposals.entity.unit'),
    merchant: t('proposals.entity.merchant'), product: t('proposals.entity.product'), recipe: t('proposals.entity.recipe'),
    entity_unit_override: t('proposals.entity.entity_unit_override'), entity_density: t('proposals.entity.entity_density'),
    hierarchy: t('proposals.entity.hierarchy'), merchant_merge: t('proposals.entity.merchant_merge'),
    product_split: t('proposals.entity.product_split'), product_merge: t('proposals.entity.product_merge'),
    usda_ingredient_match: t('proposals.entity.usda_ingredient_match'), usda_product_match: t('proposals.entity.usda_product_match'),
  }
  return map[t] || t
}
function actionLabel(a: string): string {
  const map: Record<string, string> = {
    create: t('proposals.actionLabels.create'), update: t('proposals.actionLabels.update'), delete: t('proposals.actionLabels.delete'),
    merge: t('proposals.actionLabels.merge'), publish: t('proposals.actionLabels.publish'),
  }
  return map[a] || a
}
function payloadSummary(item: Proposal): string {
  const label = item.entity_label ? `${item.entity_label}` : ''
  const p = item.payload || {}
  const candidates = ['name', 'source_name', 'target_name', 'unit_name']
  const parts = candidates.filter(k => p[k] != null).map(k => p[k])
  const detail = parts.length ? parts.slice(0, 2).join(', ') : JSON.stringify(p).slice(0, 60)
  return label ? `${label} · ${detail}` : detail
}

onMounted(() => { loadList() })
</script>

<style scoped>
.diff-table .diff-cell { font-size: 0.8rem; word-break: break-all; }
</style>

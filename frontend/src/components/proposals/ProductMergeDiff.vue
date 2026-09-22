<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import type { Proposal } from '@/api/proposals'
import { api } from '@/api'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'

const props = defineProps<{ proposal: Proposal }>()
const { t } = useI18n()
const localeStore = useLocaleStore()

const snap = computed(() => props.proposal.snapshot || {})
const payload = computed(() => props.proposal.payload || {})

const targetProductId = computed(() => payload.value.target_product_id as number | undefined)
const targetNameFallback = ref<string | null>(null)
const loadingTarget = ref(false)
const recordsCountFallback = ref<number | null>(null)
const loadingRecords = ref(false)

function extractLabelName(label: string | null): string {
  if (!label) return ''
  const m = label.match(/「(.+?)」/)
  return m ? m[1] : label
}

const sourceName = computed(() =>
  snap.value.source_name || extractLabelName(props.proposal.entity_label) || `#${props.proposal.entity_id}`,
)
const targetName = computed(() =>
  snap.value.target_name ||
  targetNameFallback.value ||
  (loadingTarget.value ? t('proposals.loading') : t('proposals.idOnly', { id: targetProductId.value })),
)
const recordsCount = computed(() => snap.value.affected_records_count ?? recordsCountFallback.value ?? 0)

async function fetchPriceRecordsCount(productId: number): Promise<number> {
  try {
    const res = await api.get('/products', { params: { product_id: productId, limit: 1 } })
    return res?.total ?? 0
  } catch {
    return 0
  }
}

async function loadBackfill() {
  const sourceId = props.proposal.entity_id
  const tid = targetProductId.value

  // 并行的回填：目标商品名 + 源价格记录数
  const tasks: Promise<void>[] = []

  if (tid && !snap.value.target_name) {
    loadingTarget.value = true
    tasks.push(
      (async () => {
        try {
          const product = await api.get(`/products/entity/${tid}`)
          if (product?.name) targetNameFallback.value = product.name
        } catch { /* ignore */ }
      })().finally(() => { loadingTarget.value = false }),
    )
  }

  if (sourceId && !snap.value.affected_records_count && sourceId != null) {
    loadingRecords.value = true
    tasks.push(
      (async () => {
        recordsCountFallback.value = await fetchPriceRecordsCount(sourceId)
      })().finally(() => { loadingRecords.value = false }),
    )
  }

  await Promise.allSettled(tasks)
}

onMounted(loadBackfill)
</script>

<template>
  <div class="pa-2">
    <v-alert type="warning" variant="tonal" density="compact" class="mb-2">
      <div class="text-body-2">
        {{ t('proposals.productMergeIntro', { source: sourceName, target: targetName }) }}
        <template v-if="loadingRecords">{{ t('proposals.loadingPriceRecordCount') }}</template>
        <template v-else-if="recordsCount > 0">
          {{ t('proposals.migratePriceRecords', {
            count: formatNumber(recordsCount, localeStore.effectiveFormatLocale),
          }) }}
        </template>
        <template v-else>{{ t('proposals.noPriceRecordsToMigrate') }}</template>
      </div>
    </v-alert>
    <div class="text-caption text-medium-emphasis">
      {{ t('proposals.productMergeResult') }}
    </div>
  </div>
</template>

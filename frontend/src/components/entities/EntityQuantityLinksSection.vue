<template>
  <div class="entity-links-section">
    <div class="d-flex align-center mb-1">
      <span class="text-body-2 font-weight-medium">{{ t('ingredients.quantityLinksTitle') }}</span>
      <v-spacer />
      <v-btn
        size="small"
        variant="text"
        color="primary"
        prepend-icon="mdi-link-variant"
        @click="openAdd"
      >
        {{ t('ingredients.quantityLinksAdd') }}
      </v-btn>
    </div>
    <div class="text-caption text-medium-emphasis mb-2">
      {{ t('ingredients.quantityLinksHint') }}
    </div>

    <div v-if="loading" class="text-center py-4">
      <v-progress-circular indeterminate size="22" color="primary" />
    </div>

    <template v-else>
      <div v-if="allLinks.length === 0" class="text-caption text-medium-emphasis py-2">
        {{ t('ingredients.quantityLinksEmpty') }}
      </div>

      <div
        v-for="link in allLinks"
        :key="`link-${link.id}-${link.pending ? 'pending' : 'active'}`"
        class="entity-link-row"
        :class="{ 'entity-link-pending': link.pending }"
      >
        <div class="d-flex align-center flex-wrap ga-1">
          <span class="font-weight-medium">{{ formatLinkSentence(link) }}</span>
          <v-chip v-if="link.pending" size="x-small" color="info" variant="tonal">
            {{ t('ingredients.quantityLinksPending') }}
          </v-chip>
          <v-spacer />
          <template v-if="!link.pending">
            <v-btn
              icon="mdi-pencil"
              size="x-small"
              variant="text"
              color="primary"
              :aria-label="t('ingredients.quantityLinksEdit')"
              @click="openEdit(link)"
            />
            <v-btn
              icon="mdi-delete"
              size="x-small"
              variant="text"
              color="error"
              :aria-label="t('ingredients.quantityLinksDelete')"
              @click="confirmDelete(link)"
            />
          </template>
        </div>

        <div class="text-caption mt-1">
          <span v-if="formatGramsSelfCheck(link)" class="text-medium-emphasis">
            {{ formatGramsSelfCheck(link) }}
          </span>
          <span v-if="link.equivalent_current_price != null" class="ms-2">
            ≈ {{ formatMoney(link.equivalent_current_price, currency) }} / {{ link.current.unit }}
            <span class="text-medium-emphasis">
              （{{ t('ingredients.quantityLinksByOther', {
                price: formatMoney(link.other_latest_price, currency),
                unit: link.other_latest_price_unit || link.other.unit,
                name: link.other.name || '—',
              }) }}）
            </span>
          </span>
          <span v-else class="ms-2 text-medium-emphasis">
            {{ t('ingredients.quantityLinksNoPrice') }}
          </span>
        </div>

        <div v-if="!link.resolvable" class="text-caption text-warning mt-1">
          {{ t('ingredients.quantityLinksUnresolvable', { unit: link.current.unit, other: link.other.unit }) }}
        </div>
        <div v-if="link.note" class="text-caption text-medium-emphasis mt-1">
          {{ link.note }}
        </div>
      </div>

      <div v-if="ingredientLinks.length > 0" class="mt-4">
        <div class="text-caption text-medium-emphasis mb-1">
          {{ t('ingredients.quantityLinksIngredientScope', { name: ingredientName || '—' }) }}
        </div>
        <div
          v-for="link in ingredientLinks"
          :key="`ingredient-link-${link.id}`"
          class="entity-link-row entity-link-readonly"
        >
          <div class="font-weight-medium">{{ formatLinkSentence(link) }}</div>
          <div class="text-caption mt-1">
            <span v-if="formatGramsSelfCheck(link)" class="text-medium-emphasis">
              {{ formatGramsSelfCheck(link) }}
            </span>
            <span v-if="link.equivalent_current_price != null" class="ms-2">
              ≈ {{ formatMoney(link.equivalent_current_price, currency) }} / {{ link.current.unit }}
            </span>
          </div>
          <div v-if="link.note" class="text-caption text-medium-emphasis mt-1">{{ link.note }}</div>
        </div>
      </div>
    </template>

    <!-- 添加 / 编辑对话框 -->
    <v-dialog v-model="dialogOpen" max-width="640" persistent>
      <v-card>
        <v-card-title class="d-flex align-center pa-4">
          <v-icon start color="primary">mdi-link-variant</v-icon>
          <span class="text-h6">
            {{ editingLink ? t('ingredients.quantityLinksEditTitle') : t('ingredients.quantityLinksAddTitle') }}
          </span>
          <v-spacer />
          <v-btn
            icon="mdi-close"
            variant="text"
            size="small"
            :aria-label="t('common.close')"
            @click="dialogOpen = false"
          />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <div class="text-body-2 mb-3">
            {{ t('ingredients.quantityLinksCurrent') }}：
            <strong>{{ entityName || `#${entityId}` }}</strong>
            <span class="text-medium-emphasis ms-1">（{{ typeLabel(entityType) }}）</span>
          </div>

          <div class="d-flex align-center ga-2 mb-3">
            <span class="text-body-2">{{ t('ingredients.quantityLinksTarget') }}：</span>
            <v-btn-toggle
              v-model="targetType"
              mandatory
              density="compact"
              variant="outlined"
              divided
              :disabled="!!editingLink"
              @update:model-value="onTargetTypeChange"
            >
              <v-btn value="product" size="small">{{ t('ingredients.quantityLinksProduct') }}</v-btn>
              <v-btn value="ingredient" size="small">{{ t('ingredients.quantityLinksIngredient') }}</v-btn>
            </v-btn-toggle>
          </div>

          <v-autocomplete
            v-model="target"
            v-model:search="targetSearch"
            :items="targetOptions"
            :item-title="targetTitle"
            return-object
            :label="t('ingredients.quantityLinksTargetPlaceholder')"
            variant="outlined"
            density="comfortable"
            :loading="searching"
            :disabled="!!editingLink"
            hide-selected
            auto-select-first
            :custom-filter="() => true"
            class="mb-3"
            @update:search="onTargetSearch"
            @update:model-value="onTargetChange"
          />

          <v-row dense>
            <v-col cols="12" sm="6">
              <div class="text-caption text-medium-emphasis mb-1">{{ entityName || t('ingredients.quantityLinksCurrent') }}</div>
              <div class="d-flex ga-2">
                <v-text-field
                  v-model.number="currentQuantity"
                  type="number"
                  min="0.000001"
                  step="1"
                  :label="t('ingredients.quantityLinksQuantity')"
                  variant="outlined"
                  density="comfortable"
                  hide-details
                  class="flex-grow-0"
                  style="max-width: 120px"
                />
                <v-combobox
                  v-model="currentUnit"
                  :items="currentUnitOptions"
                  :label="t('ingredients.quantityLinksUnit')"
                  variant="outlined"
                  density="comfortable"
                  hide-details
                  class="flex-grow-1"
                />
              </div>
            </v-col>
            <v-col cols="12" sm="6">
              <div class="text-caption text-medium-emphasis mb-1">{{ target?.name || t('ingredients.quantityLinksTarget') }}</div>
              <div class="d-flex ga-2">
                <v-text-field
                  v-model.number="otherQuantity"
                  type="number"
                  min="0.000001"
                  step="1"
                  :label="t('ingredients.quantityLinksQuantity')"
                  variant="outlined"
                  density="comfortable"
                  hide-details
                  class="flex-grow-0"
                  style="max-width: 120px"
                />
                <v-combobox
                  v-model="otherUnit"
                  :items="otherUnitOptions"
                  :label="t('ingredients.quantityLinksUnit')"
                  variant="outlined"
                  density="comfortable"
                  hide-details
                  class="flex-grow-1"
                />
              </div>
            </v-col>
          </v-row>

          <v-alert type="info" variant="tonal" density="compact" class="mt-4">
            <div class="text-body-2">
              {{ t('ingredients.quantityLinksPreview') }}：
              <strong>{{ previewSentence }}</strong>
            </div>
            <div class="text-caption mt-1 text-medium-emphasis">
              {{ t('ingredients.quantityLinksPreviewHint') }}
            </div>
          </v-alert>

          <v-text-field
            v-model="note"
            :label="t('ingredients.quantityLinksNote')"
            variant="outlined"
            density="comfortable"
            class="mt-3"
            maxlength="200"
            counter
          />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" :disabled="saving" @click="dialogOpen = false">{{ t('common.cancel') }}</v-btn>
          <v-btn color="primary" variant="elevated" :loading="saving" @click="save">
            {{ t('common.save') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="3000">
      {{ snackbarText }}
    </v-snackbar>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import { api } from '@/api'
import { formatMoney } from '@/utils/currency'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { useConfirmDialog } from '@/composables/useConfirmDialog'
import { getErrorMessage } from '@/utils/errorHandler'
import { loadEntityUnitOptions } from '@/utils/entityUnits'
import {
  formatGramsSelfCheck,
  formatLinkSentence,
  mergeLinkUnits,
  type EntityLinkEntityType,
  type EntityQuantityLink,
} from '@/utils/entityLinks'

const props = defineProps<{
  entityType: EntityLinkEntityType
  entityId: number
  entityName?: string | null
  ingredientId?: number | null
  ingredientName?: string | null
}>()

const { t } = useI18n()
const { currency } = useUserCurrency()
const { ask } = useConfirmDialog()

const links = ref<EntityQuantityLink[]>([])
const pendingLinks = ref<EntityQuantityLink[]>([])
const ingredientLinks = ref<EntityQuantityLink[]>([])
const loading = ref(false)
const saving = ref(false)
const snackbar = ref(false)
const snackbarText = ref('')
const snackbarColor = ref('success')

const dialogOpen = ref(false)
const editingLink = ref<EntityQuantityLink | null>(null)
const targetType = ref<EntityLinkEntityType>('product')
const target = ref<any>(null)
const targetSearch = ref('')
const targetOptions = ref<any[]>([])
const searching = ref(false)
const currentQuantity = ref<number | null>(1)
const currentUnit = ref('')
const otherQuantity = ref<number | null>(1)
const otherUnit = ref('')
const note = ref('')
const currentUnitOptions = ref<string[]>([])
const otherUnitOptions = ref<string[]>([])

let searchTimer: ReturnType<typeof setTimeout> | null = null
let searchSequence = 0

const allLinks = computed(() => [...links.value, ...pendingLinks.value])

const typeLabel = (type: string) => (
  type === 'ingredient'
    ? t('ingredients.quantityLinksIngredient')
    : t('ingredients.quantityLinksProduct')
)

const targetTitle = (item: any) => {
  if (!item) return ''
  const name = item.name || item.display_name || `#${item.id}`
  const extra = item.ingredient_name || item.brand
  return extra ? `${name}（${extra}）` : name
}

const previewSentence = computed(() => formatLinkSentence({
  id: 0,
  current: {
    type: props.entityType, id: props.entityId, name: props.entityName,
    quantity: Number(currentQuantity.value) || 0, unit: currentUnit.value,
  },
  other: {
    type: targetType.value, id: target.value?.id || 0, name: target.value?.name,
    quantity: Number(otherQuantity.value) || 0, unit: otherUnit.value,
  },
  other_per_current: 0,
  current_per_other: 0,
  resolvable: false,
  pending: false,
}))

const notify = (text: string, color = 'success') => {
  snackbarText.value = text
  snackbarColor.value = color
  snackbar.value = true
}

const loadLinks = async () => {
  loading.value = true
  try {
    const res = await api.get(`/entities/${props.entityType}/${props.entityId}/quantity-links`, {
      params: { include_prices: true },
    })
    links.value = res?.items || []
  } catch {
    links.value = []
  } finally {
    loading.value = false
  }
}

const loadIngredientLinks = async () => {
  if (props.entityType !== 'product' || !props.ingredientId) {
    ingredientLinks.value = []
    return
  }
  try {
    const res = await api.get(`/entities/ingredient/${props.ingredientId}/quantity-links`, {
      params: { include_prices: true },
    })
    ingredientLinks.value = res?.items || []
  } catch {
    ingredientLinks.value = []
  }
}

const loadAll = async () => {
  await Promise.all([loadLinks(), loadIngredientLinks()])
}

const unitValues = async (
  entityType: EntityLinkEntityType,
  entityId: number,
  ingredientId?: number | null,
  extra: EntityQuantityLink[] = [],
) => {
  const options = await loadEntityUnitOptions(entityType, entityId, { ingredientId })
  return mergeLinkUnits(
    options.map(option => ({ title: option.title, value: option.value })),
    extra,
  ).map(option => option.value)
}

const openAdd = async () => {
  editingLink.value = null
  targetType.value = props.entityType === 'product' ? 'product' : 'ingredient'
  target.value = null
  targetSearch.value = ''
  targetOptions.value = []
  currentQuantity.value = 1
  otherQuantity.value = 1
  currentUnit.value = ''
  otherUnit.value = ''
  note.value = ''
  currentUnitOptions.value = await unitValues(
    props.entityType, props.entityId, props.ingredientId, links.value,
  )
  otherUnitOptions.value = []
  currentUnit.value = currentUnitOptions.value[0] || ''
  dialogOpen.value = true
}

const openEdit = async (link: EntityQuantityLink) => {
  editingLink.value = link
  targetType.value = link.other.type
  target.value = {
    id: link.other.id,
    name: link.other.name,
    ingredient_id: link.other.ingredient_id,
  }
  targetSearch.value = ''
  targetOptions.value = [target.value]
  currentQuantity.value = Number(link.current.quantity)
  currentUnit.value = link.current.unit
  otherQuantity.value = Number(link.other.quantity)
  otherUnit.value = link.other.unit
  note.value = link.note || ''
  currentUnitOptions.value = await unitValues(
    props.entityType, props.entityId, props.ingredientId, links.value,
  )
  otherUnitOptions.value = await unitValues(
    link.other.type, link.other.id, link.other.ingredient_id, links.value,
  )
  dialogOpen.value = true
}

const onTargetTypeChange = () => {
  target.value = null
  targetSearch.value = ''
  targetOptions.value = []
  otherUnit.value = ''
  otherUnitOptions.value = []
}

const onTargetSearch = (value: string) => {
  targetSearch.value = value
  if (searchTimer) clearTimeout(searchTimer)
  const query = (value || '').trim()
  if (!query) {
    targetOptions.value = []
    return
  }
  const sequence = ++searchSequence
  searchTimer = setTimeout(async () => {
    searching.value = true
    try {
      let items: any[] = []
      if (targetType.value === 'product') {
        const res = await api.get('/products/entity', {
          params: { search: query, limit: 20 },
        })
        items = res?.items || []
      } else {
        const res = await api.get('/ingredients', {
          params: { q: query, limit: 20 },
        })
        items = res?.items || []
      }
      if (sequence !== searchSequence) return
      targetOptions.value = items.filter((item: any) => item.id !== props.entityId)
    } catch {
      if (sequence === searchSequence) targetOptions.value = []
    } finally {
      if (sequence === searchSequence) searching.value = false
    }
  }, 300)
}

const onTargetChange = async (item: any) => {
  if (!item) {
    otherUnitOptions.value = []
    return
  }
  otherUnitOptions.value = await unitValues(
    targetType.value,
    item.id,
    item.ingredient_id,
    links.value,
  )
  if (!otherUnit.value || !otherUnitOptions.value.includes(otherUnit.value)) {
    otherUnit.value = otherUnitOptions.value[0] || ''
  }
}

const save = async () => {
  if (!target.value?.id) {
    notify(t('ingredients.quantityLinksTargetRequired'), 'error')
    return
  }
  const fromQty = Number(currentQuantity.value)
  const toQty = Number(otherQuantity.value)
  if (!Number.isFinite(fromQty) || fromQty <= 0 || !Number.isFinite(toQty) || toQty <= 0) {
    notify(t('ingredients.quantityLinksQuantityInvalid'), 'error')
    return
  }
  if (!currentUnit.value.trim() || !otherUnit.value.trim()) {
    notify(t('ingredients.quantityLinksUnitRequired'), 'error')
    return
  }

  saving.value = true
  try {
    let response: any
    if (editingLink.value) {
      response = await api.put(
        `/entities/${props.entityType}/${props.entityId}/quantity-links/${editingLink.value.id}`,
        {
          from_quantity: fromQty,
          from_unit: currentUnit.value.trim(),
          to_quantity: toQty,
          to_unit: otherUnit.value.trim(),
          note: note.value.trim() || null,
        },
      )
    } else {
      response = await api.post(
        `/entities/${props.entityType}/${props.entityId}/quantity-links`,
        {
          to_type: targetType.value,
          to_id: target.value.id,
          from_quantity: fromQty,
          from_unit: currentUnit.value.trim(),
          to_quantity: toQty,
          to_unit: otherUnit.value.trim(),
          note: note.value.trim() || null,
        },
      )
    }
    dialogOpen.value = false
    if (response?.pending) {
      pendingLinks.value = [response, ...pendingLinks.value.filter(row => row.id !== response.id)]
      notify(t('ingredients.quantityLinksPendingSubmitted'), 'info')
    } else {
      notify(t('ingredients.quantityLinksSaved'))
      await loadLinks()
    }
  } catch (error: any) {
    notify(getErrorMessage(error, t('ingredients.quantityLinksSaveFailed')), 'error')
  } finally {
    saving.value = false
  }
}

const confirmDelete = async (link: EntityQuantityLink) => {
  const ok = await ask({
    text: t('ingredients.quantityLinksDeleteConfirm'),
    color: 'error',
    confirmText: t('common.delete'),
  })
  if (!ok) return
  try {
    const res = await api.delete(`/entities/${props.entityType}/${props.entityId}/quantity-links/${link.id}`)
    if (res?.pending) {
      notify(t('ingredients.quantityLinksDeletePending'), 'info')
    } else {
      notify(t('ingredients.quantityLinksDeleted'))
      await loadLinks()
    }
  } catch (error: any) {
    notify(getErrorMessage(error, t('ingredients.quantityLinksDeleteFailed')), 'error')
  }
}

watch(
  () => [props.entityType, props.entityId, props.ingredientId],
  () => { void loadAll() },
)

onMounted(() => { void loadAll() })
onBeforeUnmount(() => { if (searchTimer) clearTimeout(searchTimer) })
</script>

<style scoped>
.entity-link-row {
  border: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
  border-radius: 8px;
  padding: 8px 10px;
  margin-bottom: 6px;
}
.entity-link-readonly {
  background: rgba(var(--v-theme-surface-variant), 0.25);
}
.entity-link-pending {
  border-style: dashed;
  background: rgba(var(--v-theme-info), 0.04);
}
</style>

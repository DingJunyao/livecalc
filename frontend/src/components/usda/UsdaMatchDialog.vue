<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { searchUsdaFoods, getUsdaFood, matchIngredient, matchProduct } from '@/api/usda'
import { useUserStore } from '@/stores/user'
import { useLocaleStore } from '@/stores/locale'
import { formatNumber } from '@/utils/format'
import { usdaDescription } from '@/utils/catalogLabels'
import { nutrientLabel, nutrientUnitLabel } from '@/utils/nutritionLabels'
import { pendingReviewMarker } from '@/utils/localDisplay'

const userStore = useUserStore()
const { t } = useI18n()
const localeStore = useLocaleStore()

const props = defineProps<{
  modelValue: boolean
  entityType: 'ingredient' | 'product'
  entityId: number
}>()
const emit = defineEmits<{
  (e: 'update:modelValue', v: boolean): void
  (e: 'matched'): void
}>()

// 行内提示（管理员直写 / 补空自动通过 / 待审核 区分）
const snackbar = ref<{ show: boolean; message: string; color: string }>({
  show: false,
  message: '',
  color: 'success',
})

const query = ref('')
const results = ref<any[]>([])
const loading = ref(false)
const selected = ref<any | null>(null)
const matching = ref(false)
let debounceTimer: ReturnType<typeof setTimeout> | null = null

const SOURCE_TYPE_KEYS: Record<string, string> = {
  foundation: 'usda.sources.foundation',
  sr_legacy: 'usda.sources.srLegacy',
  survey_fndds: 'usda.sources.surveyFndds',
  branded: 'usda.sources.branded',
  suggested: 'usda.sources.suggested',
}

function sourceTypeLabel(value: string): string {
  const normalized = value.trim().toLowerCase().replace(/\s+/g, '_')
  const key = SOURCE_TYPE_KEYS[normalized]
  return key ? t(key) : value
}

async function onSearch() {
  if (!query.value || !query.value.trim()) {
    results.value = []
    return
  }
  loading.value = true
  try {
    results.value = await searchUsdaFoods(query.value)
  } finally {
    loading.value = false
  }
}

function onInput() {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(onSearch, 300)
}

async function pick(fdcId: number) {
  loading.value = true
  try {
    selected.value = await getUsdaFood(fdcId)
  } finally {
    loading.value = false
  }
}

// 二级确认对话框状态（替代浏览器原生 confirm，避免阻塞且样式不统一）
const confirmDialog = ref(false)

function onConfirmClick() {
  if (!selected.value) return
  confirmDialog.value = true
}

async function confirmMatch() {
  confirmDialog.value = false
  matching.value = true
  try {
    let res: any
    if (props.entityType === 'ingredient') {
      res = await matchIngredient(props.entityId, selected.value.fdc_id)
    } else {
      res = await matchProduct(props.entityId, selected.value.fdc_id)
    }

    // 后端返回 message：管理员直写 / 补空自动通过 / 待审核
    const message: string = res?.message || ''
    const isAdmin = !!userStore.user?.is_admin
    const isPending = message.includes(pendingReviewMarker()) || /status=pending/.test(message)

    if (isAdmin) {
      snackbar.value = { show: true, message: t('usda.matchSuccess'), color: 'success' }
    } else if (isPending) {
      // 普通用户、有数据：提议待审，营养数据未变
      snackbar.value = {
        show: true,
        message: t('usda.submittedPendingReview'),
        color: 'info',
      }
    } else {
      // 普通用户补空自动通过
      snackbar.value = {
        show: true,
        message: t('usda.matchSuccessAutoApproved'),
        color: 'success',
      }
    }

    // 数据已落地才刷新营养（管理员直写 / 补空自动通过）；pending 时数据未变，不触发刷新
    if (!isPending) {
      emit('matched')
    }
    emit('update:modelValue', false)
  } finally {
    matching.value = false
  }
}
</script>

<template>
  <v-dialog
    :model-value="modelValue"
    max-width="780"
    persistent
    @update:model-value="emit('update:modelValue', $event)"
  >
    <v-card>
      <v-card-title>{{ t('usda.matchFoodTitle') }}</v-card-title>
      <v-card-text>
        <v-text-field
          v-model="query"
          :label="t('usda.searchLabel')"
          prepend-inner-icon="mdi-magnify"
          @update:model-value="onInput"
          @keyup.enter="onSearch"
          clearable
        />
        <v-progress-linear v-if="loading" indeterminate />

        <v-list v-if="results.length && !selected" density="compact">
          <v-list-item v-for="r in results" :key="r.fdc_id" @click="pick(r.fdc_id)">
            <v-list-item-title>{{ usdaDescription(r, localeStore.locale) }}</v-list-item-title>
            <v-list-item-subtitle>
              {{ t('usda.resultMetadata', {
                source: r.description,
                type: sourceTypeLabel(r.data_type),
                count: formatNumber(r.nutrient_count, localeStore.effectiveFormatLocale),
              }) }}
            </v-list-item-subtitle>
          </v-list-item>
        </v-list>

        <div v-if="selected">
          <v-btn variant="text" size="small" @click="selected = null">{{ t('usda.backToResults') }}</v-btn>
          <h3 class="mt-2">{{ usdaDescription(selected, localeStore.locale) }}</h3>
          <p class="text-caption">{{ selected.description }}</p>
          <v-table density="compact" class="mt-2">
            <thead>
              <tr>
                <th>{{ t('usda.nutrient') }}</th>
                <th>{{ t('usda.value') }}</th>
                <th>{{ t('usda.unit') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="n in selected.nutrients" :key="n.name">
                <td>{{ nutrientLabel(n.name) }}</td>
                <td>{{ formatNumber(n.amount, localeStore.effectiveFormatLocale) }}</td>
                <td>{{ nutrientUnitLabel(n.unit_name) }}</td>
              </tr>
            </tbody>
          </v-table>
        </div>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" @click="emit('update:modelValue', false)">{{ t('usda.cancel') }}</v-btn>
        <v-btn color="primary" :disabled="!selected" :loading="matching" @click="onConfirmClick">
          {{ t('usda.confirmMatch') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <!-- 二级确认：模态对话框替代浏览器原生 confirm -->
  <v-dialog v-model="confirmDialog" max-width="420" persistent>
    <v-card>
      <v-card-title class="text-h6 d-flex align-center">
        <v-icon color="warning" class="mr-2">mdi-alert-circle-outline</v-icon>
        {{ t('usda.confirmMatch') }}
      </v-card-title>
      <v-card-text>
        {{ t('usda.confirmMatchBody') }}
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" :disabled="matching" @click="confirmDialog = false">{{ t('usda.cancel') }}</v-btn>
        <v-btn color="primary" :loading="matching" @click="confirmMatch">{{ t('usda.confirmWrite') }}</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <!-- 行内提示：按角色/status 区分（管理员直写 / 补空自动通过 / 待审核） -->
  <v-snackbar v-model="snackbar.show" :color="snackbar.color" :timeout="3000">
    {{ snackbar.message }}
  </v-snackbar>
</template>

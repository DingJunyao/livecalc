<template>
  <v-dialog v-model="visible" max-width="600" persistent>
    <v-card>
      <v-card-title class="d-flex align-center">
        <v-icon start>mdi-upload</v-icon>
        {{ t('imports.title') }}
      </v-card-title>

      <v-card-text>
        <v-alert v-if="result" :type="result.success ? 'success' : 'error'"
                 variant="tonal" class="mb-4" closable>
          <div v-if="result.success">
            {{ t('imports.completed') }}
            <span v-for="(v, k) in displayStats" :key="k" class="mr-2">
              {{ k }}={{ v }}
            </span>
            <div v-if="skippedItems.length" class="mt-2">
              <div class="text-caption text-medium-emphasis">{{ t('imports.skippedPermission') }}</div>
              <div v-for="item in skippedItems" :key="item.key" class="text-caption">
                · {{ t('imports.skippedCount', { label: skippedLabel[item.key] || item.key, count: item.count }) }}
              </div>
            </div>
          </div>
          <div v-else>{{ result.errors?.join('; ') }}</div>
          <div v-if="result.warnings?.length" class="mt-1">
            <div v-for="(w, i) in result.warnings" :key="i" class="text-caption">{{ w }}</div>
          </div>
        </v-alert>

        <v-file-input
          v-model="file"
          :label="t('imports.selectZip')"
          accept=".zip"
          :loading="uploading"
          :disabled="uploading"
          @update:model-value="result = null"
        />

        <div v-if="uploading" class="text-center py-4">
          <v-progress-circular indeterminate color="primary" />
          <div class="mt-2">
            {{ currentTask?.progress?.message || t('imports.importing') }}
          </div>
          <div
            v-if="currentTask?.progress?.total"
            class="text-caption text-medium-emphasis mt-1"
          >
            {{ importTaskStageLabel(currentTask.progress.stage) }}：{{ currentTask.progress.current }}/{{
              currentTask.progress.total
            }}
          </div>
        </div>

        <v-btn block color="primary" :loading="uploading" :disabled="!file"
               class="mt-2" @click="handleUpload">
          <v-icon start>mdi-upload</v-icon>
          {{ t('imports.startImport') }}
        </v-btn>
      </v-card-text>

      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" :disabled="uploading" @click="close">{{ t('imports.close') }}</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useImportTask } from '@/composables/useImportTask'
import type { ImportTask } from '@/composables/useImportTask'
import { importTaskStageLabel } from '@/utils/importTaskStages'
import { importTaskErrorLabel } from '@/utils/importTaskErrors'

const { t } = useI18n()

const props = defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [v: boolean] }>()

const visible = ref(props.modelValue)
watch(() => props.modelValue, (v) => { visible.value = v })

const { tasks, startUploadTask } = useImportTask()

const file = ref<File | null>(null)
const uploading = ref(false)
const result = ref<any>(null)
const currentTaskId = ref<number | null>(null)

const currentTask = computed<ImportTask | undefined>(() => {
  if (!currentTaskId.value) return undefined
  return tasks.value.find((t) => t.id === currentTaskId.value)
})

// 导入统计（排除 skipped 子表，skipped 单独展示）
const displayStats = computed<Record<string, any>>(() => {
  const s = result.value?.stats || {}
  const rest: Record<string, any> = {}
  for (const [k, v] of Object.entries(s)) {
    if (k !== 'skipped') rest[k] = v
  }
  return rest
})

const skippedItems = computed<{ key: string; count: number }[]>(() => {
  const skipped = result.value?.stats?.skipped
  if (!skipped || typeof skipped !== 'object') return []
  return Object.entries(skipped).map(([key, count]) => ({ key, count: count as number }))
})

const skippedLabel: Record<string, string> = {
  blacklist_groups: t('imports.skippedLabels.blacklist_groups'),
  unit_conversions: t('imports.skippedLabels.unit_conversions'),
  product_barcodes: t('imports.skippedLabels.product_barcodes'),
  user_places: t('imports.skippedLabels.user_places'),
  price_records: t('imports.skippedLabels.price_records'),
  user_ingredient_blacklist: t('imports.skippedLabels.user_ingredient_blacklist'),
  blacklist_group_subscriptions: t('imports.skippedLabels.blacklist_group_subscriptions'),
}

// 监听任务状态变化，终态时展示结果
watch(
  () => {
    const t = currentTask.value
    return t ? { status: t.status, stats: t.stats, error: t.error } : null
  },
  (snapshot) => {
    if (!snapshot) return
    if (snapshot.status === 'success') {
      result.value = {
        success: true,
        stats: snapshot.stats,
        warnings: snapshot.error ? [importTaskErrorLabel(snapshot.error)] : [],
      }
      uploading.value = false
      currentTaskId.value = null
    } else if (snapshot.status === 'failed') {
      result.value = {
        success: false,
        errors: [snapshot.error ? importTaskErrorLabel(snapshot.error) : t('imports.importFailed')],
      }
      uploading.value = false
      currentTaskId.value = null
    } else if (snapshot.status === 'cancelled') {
      result.value = {
        success: false,
        errors: [t('imports.importCancelled')],
      }
      uploading.value = false
      currentTaskId.value = null
    }
  },
)

async function handleUpload() {
  if (!file.value) return
  uploading.value = true
  result.value = null
  const taskId = await startUploadTask(file.value)
  if (taskId) {
    currentTaskId.value = taskId
  } else {
    result.value = {
      success: false,
      errors: [t('imports.uploadFailed')],
    }
    uploading.value = false
  }
}

function close() {
  emit('update:modelValue', false)
}
</script>

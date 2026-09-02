<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('admin.unusedImages.title') }}</v-app-bar-title>
    <template #append>
      <v-btn
        v-if="selected.length > 0"
        color="error"
        variant="tonal"
        size="small"
        class="me-2"
        :loading="deleting"
        :disabled="deleting"
        @click="confirmDelete"
      >
        <v-icon start size="small">mdi-delete</v-icon>
        {{ t('admin.unusedImages.deleteSelected', { count: formatCount(selected.length) }) }}
      </v-btn>
    </template>
  </v-app-bar>

  <v-container class="pa-4 pt-0" style="margin-top: 12px">
    <v-alert
      v-if="errorMsg"
      type="error"
      closable
      class="mb-4"
      @click:close="errorMsg = ''"
    >{{ errorMsg }}</v-alert>

    <v-alert
      v-if="successMsg"
      type="success"
      closable
      class="mb-4"
      @click:close="successMsg = ''"
    >{{ successMsg }}</v-alert>

    <v-skeleton-loader
      v-if="scanning"
      type="card, list-item-two-line, card"
      class="mx-auto"
      max-width="600"
    />

    <template v-else>
      <!-- 存储概览 -->
      <v-card class="mb-4" elevation="0">
        <v-card-text class="d-flex ga-4 flex-wrap">
          <div class="text-body-2">
            <v-icon class="me-1" color="success">mdi-check-circle</v-icon>
            {{ t('admin.unusedImages.used', { count: formatCount(stats.used_images) }) }}
            · {{ formatSize(stats.used_size) }}
          </div>
          <div class="text-body-2">
            <v-icon class="me-1" color="warning">mdi-alert-circle</v-icon>
            {{ t('admin.unusedImages.unused', { count: formatCount(stats.unused_images) }) }}
            · {{ formatSize(stats.unused_size) }}
          </div>
          <div class="text-body-2">
            <v-icon class="me-1" color="medium-emphasis">mdi-folder</v-icon>
            {{ t('admin.unusedImages.total', { count: formatCount(stats.total_images) }) }}
            · {{ formatSize(stats.used_size + stats.unused_size) }}
          </div>
        </v-card-text>
      </v-card>

      <!-- 分组列表 -->
      <v-expansion-panels v-model="expandedPanels" multiple>
        <v-expansion-panel v-for="group in groups" :key="group.key" :value="group.key">
          <v-expansion-panel-title class="text-subtitle-2 font-weight-medium">
            <span>{{ groupLabel(group) }}</span>
            <v-chip size="x-small" class="ms-2">
              {{ t('admin.unusedImages.imageCount', { count: formatCount(group.count) }) }} · {{ formatSize(group.total_size) }}
            </v-chip>
            <v-spacer />
            <v-btn
              v-if="group.count > 0"
              size="x-small"
              variant="text"
              :color="isGroupAllSelected(group.key) ? 'primary' : undefined"
              @click.stop="toggleGroup(group.key)"
            >
              <v-icon size="small">mdi-checkbox-{{ isGroupAllSelected(group.key) ? 'marked' : 'blank-outline' }}</v-icon>
              {{ isGroupAllSelected(group.key) ? t('admin.unusedImages.clearSelection') : t('admin.unusedImages.selectGroup') }}
            </v-btn>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-row>
              <v-col
                v-for="img in group.images"
                :key="img.key"
                cols="6"
                sm="4"
                md="3"
                lg="2"
              >
                <v-card
                  elevation="1"
                  :color="selected.includes(img.key) ? 'primary' : undefined"
                  @click="toggleSelect(img.key)"
                  style="cursor: pointer"
                >
                  <v-img
                    :src="img.url"
                    height="100"
                    cover
                    class="bg-grey-lighten-3"
                  >
                    <template #placeholder>
                      <div class="d-flex align-center justify-center fill-height">
                        <v-icon color="grey">mdi-image-off</v-icon>
                      </div>
                    </template>
                  </v-img>
                 <v-card-text class="pa-1 text-caption text-center">
                   <div class="text-truncate">{{ img.filename }}</div>
                   <div class="text-medium-emphasis">{{ formatSize(img.file_size) }}</div>
                 </v-card-text>
                </v-card>
              </v-col>
            </v-row>

            <div v-if="group.images.length === 0" class="text-center py-4 text-body-2 text-medium-emphasis">
              {{ t('admin.unusedImages.none') }}
            </div>
          </v-expansion-panel-text>
        </v-expansion-panel>
      </v-expansion-panels>

      <v-card-text
        v-if="!scanning && groups.length === 0"
        class="text-center py-8"
      >
        <v-icon size="64" color="success">mdi-check-circle-outline</v-icon>
        <div class="text-body-1 mt-2">{{ t('admin.unusedImages.empty') }}</div>
      </v-card-text>
    </template>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useDisplay } from 'vuetify'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useRouter } from 'vue-router'
import { api } from '@/api'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'

const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const { t } = useI18n()
const localeStore = useLocaleStore()
const router = useRouter()

const goBack = () => { router.back() }

const scanning = ref(false)
const deleting = ref(false)
const errorMsg = ref('')
const successMsg = ref('')
const expandedPanels = ref<string[]>([])

interface ImageItem {
  key: string
  filename: string
  url: string
  file_size: number
  last_used_at: string | null
}

interface ImageGroup {
  key: string
  label: string
  images: ImageItem[]
  count: number
  total_size: number
}

interface Stats {
  total_images: number
  used_images: number
  unused_images: number
  used_size: number
  unused_size: number
}

const stats = ref<Stats>({ total_images: 0, used_images: 0, unused_images: 0, used_size: 0, unused_size: 0 })
const groups = ref<ImageGroup[]>([])
const selected = ref<string[]>([])

const formatCount = (value: number) => formatNumber(value, localeStore.effectiveFormatLocale)

const formatSize = (bytes: number): string => {
  if (bytes === 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(1024))
  const idx = Math.min(i, units.length - 1)
  const size = formatNumber(bytes / Math.pow(1024, idx), localeStore.effectiveFormatLocale, {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  })
  return `${size} ${units[idx]}`
}

const groupLabels = computed<Record<string, string>>(() => ({
  never_used: t('admin.unusedImages.groups.neverUsed'),
  '180d': t('admin.unusedImages.groups.over180Days'),
  '90d': t('admin.unusedImages.groups.days90To180'),
  '60d': t('admin.unusedImages.groups.days60To90'),
  '30d': t('admin.unusedImages.groups.days30To60'),
  recent: t('admin.unusedImages.groups.recent'),
}))

const groupLabel = (group: ImageGroup) => groupLabels.value[group.key] || group.label

const isGroupAllSelected = (groupKey: string): boolean => {
  const group = groups.value.find(g => g.key === groupKey)
  if (!group || group.images.length === 0) return false
  return group.images.every(img => selected.value.includes(img.key))
}

const toggleGroup = (groupKey: string): void => {
  const group = groups.value.find(g => g.key === groupKey)
  if (!group) return
  const allSelected = isGroupAllSelected(groupKey)
  const groupKeys = group.images.map(img => img.key)
  if (allSelected) {
    selected.value = selected.value.filter(k => !groupKeys.includes(k))
  } else {
    const existing = new Set(selected.value)
    for (const k of groupKeys) existing.add(k)
    selected.value = [...existing]
  }
}

const toggleSelect = (key: string): void => {
  const idx = selected.value.indexOf(key)
  if (idx >= 0) {
    selected.value.splice(idx, 1)
  } else {
    selected.value.push(key)
  }
}


const loadData = async () => {
  scanning.value = true
  errorMsg.value = ''
  selected.value = []

  try {
    // 先扫描
    await api.post('/admin/images/scan')
    // 获取分组数据
    const resp = await api.get('/admin/images/unused')
    stats.value = resp.stats || { total_images: 0, used_images: 0, unused_images: 0, used_size: 0, unused_size: 0 }
    groups.value = resp.groups || []
    // 默认展开所有组
    expandedPanels.value = (resp.groups || []).map((g: ImageGroup) => g.key)
  } catch (e: any) {
    errorMsg.value = e.response?.data?.detail || e.message || t('admin.unusedImages.loadFailed')
  } finally {
    scanning.value = false
  }
}

const confirmDelete = async () => {
  if (!selected.value.length) return
  deleting.value = true
  errorMsg.value = ''
  successMsg.value = ''
  try {
    const resp = await api.post('/admin/images/unused/delete', {
      keys: selected.value,
    })
    successMsg.value = t('admin.unusedImages.deleted', { count: formatCount(resp.deleted?.length || 0) })
    if (resp.errors?.length) {
      errorMsg.value = t('admin.unusedImages.deleteFailedWithErrors', { errors: resp.errors.join('; ') })
    }
    await loadData()
  } catch (e: any) {
    errorMsg.value = e.response?.data?.detail || e.message || t('admin.unusedImages.deleteFailed')
  } finally {
    deleting.value = false
  }
}

onMounted(() => {
  loadData()
})
</script>

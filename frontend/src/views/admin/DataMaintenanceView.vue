<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('adminData.maintenance.title') }}</v-app-bar-title>
  </v-app-bar>

  <v-container class="pa-4">
    <!-- 成功提示 -->
    <v-alert v-if="successMessage" type="success" variant="tonal" class="mb-4" closable
             @click:close="successMessage = ''">
      {{ successMessage }}
    </v-alert>
    <!-- 错误提示 -->
    <v-alert v-if="errorMessage" type="error" variant="tonal" class="mb-4" closable
             @click:close="errorMessage = ''">
      {{ errorMessage }}
    </v-alert>

    <v-row>
      <!-- 从仓库导入 -->
      <v-col v-if="!isLocalMode" cols="12" md="6" lg="4">
        <v-card class="rounded-lg h-100">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2" color="github">mdi-source-repository</v-icon>
            <span>{{ t('adminData.maintenance.repoImport') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-6">
            <p class="text-body-2 mb-4">
              {{ t('adminData.maintenance.repoIntro') }}
              <code>DATA_REPO_URL</code>, <code>DATA_REPO_BRANCH</code>,
              <code>DATA_REPO_DIR</code>.
            </p>
            <v-alert type="info" variant="tonal" density="compact">
              <div class="text-caption">
                {{ t('adminData.maintenance.supportedFormatsAuto') }}
              </div>
            </v-alert>
          </v-card-text>
          <v-divider />
          <v-card-actions class="pa-4">
            <v-spacer />
            <v-btn
              color="github"
              variant="tonal"
              size="large"
              :loading="submitting.repo"
              @click="importFromRepo"
            >
              <v-icon start>mdi-source-repository</v-icon>
              {{ t('adminData.maintenance.startImport') }}
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-col>

      <!-- 从本地路径导入 -->
      <v-col v-if="!isLocalMode" cols="12" md="6" lg="4">
        <v-card class="rounded-lg h-100">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2" color="primary">mdi-folder-open</v-icon>
            <span>{{ t('adminData.maintenance.localImport') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-6">
            <p class="text-body-2 mb-4">
              {{ t('adminData.maintenance.localIntro') }}
              <code>backend/.env</code> - <code>DATA_LOCAL_PATH</code>.
            </p>
            <v-alert
              :type="localPathConfig.configured ? 'info' : 'warning'"
              variant="tonal"
              density="compact"
              class="mb-4"
            >
              <div v-if="!localPathConfig.loaded" class="text-caption">
                {{ t('adminData.maintenance.loadingConfig') }}
              </div>
              <div v-else-if="localPathConfig.configured" class="text-caption">
                {{ t('adminData.maintenance.willImport') }} <code>{{ localPathConfig.path }}</code>
              </div>
              <div v-else class="text-caption">
                {{ t('adminData.maintenance.localNotConfigured') }}
              </div>
            </v-alert>
            <v-alert type="info" variant="tonal" density="compact">
              <div class="text-caption">
                {{ t('adminData.maintenance.supportedFormatsDetailed') }}
              </div>
            </v-alert>
          </v-card-text>
          <v-divider />
          <v-card-actions class="pa-4">
            <v-spacer />
            <v-btn
              color="primary"
              variant="tonal"
              size="large"
              :loading="submitting.local"
              :disabled="!localPathConfig.loaded || !localPathConfig.configured"
              @click="importFromLocalPath"
            >
              <v-icon start>mdi-folder-open</v-icon>
              {{ t('adminData.maintenance.startImport') }}
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-col>

      <!-- 上传 ZIP 导入 -->
      <v-col cols="12" md="6" lg="4">
        <v-card class="rounded-lg h-100">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2" color="success">mdi-upload</v-icon>
            <span>{{ t('adminData.maintenance.uploadImport') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-6">
            <p class="text-body-2 mb-4">
              {{ t('adminData.maintenance.uploadIntro') }}
            </p>
            <v-file-input
              v-model="uploadFile"
              :label="t('adminData.maintenance.chooseZip')"
              accept=".zip"
              variant="outlined"
              prepend-icon="mdi-zip-box"
              :loading="submitting.upload"
              :disabled="submitting.upload"
              hide-details
            />
          </v-card-text>
          <v-divider />
          <v-card-actions class="pa-4">
            <v-spacer />
            <v-btn
              color="success"
              variant="tonal"
              size="large"
              :loading="submitting.upload"
              :disabled="!uploadFile"
              @click="uploadImport"
            >
              <v-icon start>mdi-upload</v-icon>
              {{ t('adminData.maintenance.uploadAndImport') }}
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-col>

      <!-- USDA 数据管理 -->
      <v-col cols="12" md="6" lg="4">
        <v-card class="rounded-lg h-100">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2" color="deep-orange">mdi-database</v-icon>
            <span>{{ t('adminData.maintenance.usda.title') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-6">
            <p class="text-body-2 mb-4">
              {{ t('adminData.maintenance.usda.intro') }}
            </p>
            <!-- Statistics -->
            <div v-if="usdaStats.total != null && usdaStats.total > 0" class="mb-4">
              <v-chip size="small" variant="tonal" class="mr-2 mb-2">
                {{ t('adminData.maintenance.usda.foods') }}: {{ formatCount(usdaStats.total) }}
              </v-chip>
              <v-chip size="small" variant="tonal" class="mr-2 mb-2">
                {{ t('adminData.maintenance.usda.nutrients') }}: {{ formatCount(usdaStats.nutrients || 0) }}
              </v-chip>
              <v-chip size="small" variant="tonal" class="mb-2">
                {{ t('adminData.maintenance.usda.mapped') }}: {{ formatPercent(usdaStats.mapped_pct || 0) }}
              </v-chip>
            </div>
           <v-alert v-else type="info" variant="tonal" density="compact">
             <div class="text-caption">{{ t('adminData.maintenance.usda.statsUnavailable') }}</div>
           </v-alert>
            <v-alert v-if="isLocalMode" type="info" variant="tonal" density="compact" class="mt-3">
              <div class="text-caption">
                {{ t('adminData.maintenance.usda.localModeIntro') }}
              </div>
            </v-alert>
         </v-card-text>
         <v-divider />
         <v-card-actions class="pa-4 d-flex flex-wrap justify-end ga-2">
           <v-btn
             v-if="!isLocalMode"
             color="deep-orange"
             variant="tonal"
             size="large"
             :loading="usdaDownloading"
             :disabled="usdaDownloading"
             @click="downloadUsdaData"
           >
             <v-icon start>mdi-download</v-icon>
             {{ t('adminData.maintenance.usda.download') }}
           </v-btn>
            <v-btn
              v-else
              color="deep-orange"
              variant="tonal"
              size="large"
              href="https://fdc.nal.usda.gov/download-datasets.html"
              target="_blank"
              rel="noopener noreferrer"
            >
              <v-icon start>mdi-open-in-new</v-icon>
              {{ t('adminData.maintenance.usda.downloadPage') }}
            </v-btn>
            <v-btn
              color="deep-orange"
              variant="tonal"
              size="large"
              :loading="usdaUploading"
              :disabled="usdaUploading"
              @click="triggerUsdaUpload"
            >
              <v-icon start>mdi-upload</v-icon>
              {{ t('adminData.maintenance.usda.uploadZip') }}
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-col>

      <!-- 行政区划 -->
      <v-col cols="12" md="6" lg="4">
        <v-card class="rounded-lg h-100">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2" color="blue">mdi-map-marker-multiple</v-icon>
            <span>{{ t('adminData.maintenance.regions.title') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-6">
            <p class="text-body-2 mb-4">
              {{ t('adminData.maintenance.regions.intro') }}
            </p>
            <v-alert v-if="regionStatus?.needed" type="warning" variant="tonal" density="compact" class="mb-3">
              {{ t('adminData.maintenance.regions.missingWarning') }}
            </v-alert>
            <div class="d-flex flex-wrap ga-3 mb-3 text-body-2">
              <v-chip size="small">{{ t('region.country') }}: {{ formatOptionalCount(regionStatus?.counts?.['0']) }}</v-chip>
              <v-chip size="small">{{ t('region.province') }}: {{ formatOptionalCount(regionStatus?.counts?.['1']) }}</v-chip>
              <v-chip size="small">{{ t('region.city') }}: {{ formatOptionalCount(regionStatus?.counts?.['2']) }}</v-chip>
              <v-chip size="small">{{ t('region.district') }}: {{ formatOptionalCount(regionStatus?.counts?.['3']) }}</v-chip>
              <v-chip size="small" color="primary">{{ t('adminData.maintenance.regions.total') }}: {{ formatOptionalCount(regionStatus?.total) }}</v-chip>
            </div>
          </v-card-text>
          <v-divider />
          <v-card-actions class="pa-4">
            <v-spacer />
            <v-btn
              color="primary"
              variant="tonal"
              size="large"
              :loading="regionSeeding"
              prepend-icon="mdi-database-refresh"
              @click="seedRegions"
            >
              {{ regionStatus?.needed ? t('adminData.maintenance.regions.import') : t('adminData.maintenance.regions.update') }}
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-col>

      <!-- AI 后处理 -->
      <v-col cols="12" md="6" lg="4">
        <v-card class="rounded-lg h-100">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2" color="purple">mdi-robot</v-icon>
            <span>{{ t('adminData.maintenance.ai.title') }}</span>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-6">
            <p class="text-body-2 mb-4">
              {{ t('adminData.maintenance.ai.intro') }}
            </p>

            <!-- AI 推断后端选择 -->
            <v-select
              v-model="aiInferProvider"
              :items="aiProviderOptions"
              item-title="label"
              item-value="value"
              :label="t('adminData.maintenance.ai.inferProvider')"
              variant="outlined"
              prepend-icon="mdi-robot"
              :hint="t('adminData.maintenance.ai.inferProviderHint')"
              persistent-hint
              hide-details
              class="mb-3"
            />

            <!-- 翻译后端选择 -->
            <v-select
              v-model="translateProvider"
              :items="translateProviderOptions"
              item-title="label"
              item-value="value"
              :label="t('adminData.maintenance.ai.translateProvider')"
              variant="outlined"
              prepend-icon="mdi-translate"
              :hint="t('adminData.maintenance.ai.translateProviderHint')"
              persistent-hint
              hide-details
              class="mb-3"
            />

            <v-checkbox v-model="aiForce" :label="t('adminData.maintenance.ai.force')" hide-details class="mb-3" />

            <v-row>
              <v-col cols="6">
                <v-btn
                  block
                  color="purple"
                  variant="tonal"
                  :loading="submitting.aiPieceWeight"
                  :disabled="!enabledAiProviders.length"
                  @click="fillPieceWeight"
                >
                  <v-icon start>mdi-weight</v-icon>
                  {{ t('adminData.maintenance.ai.pieceWeight') }}
                </v-btn>
              </v-col>
              <v-col cols="6">
                <v-btn
                  block
                  color="purple"
                  variant="tonal"
                  :loading="submitting.aiDensities"
                  :disabled="!enabledAiProviders.length"
                  @click="inferDensities"
                >
                  <v-icon start>mdi-database</v-icon>
                  {{ t('adminData.maintenance.ai.densities') }}
                </v-btn>
              </v-col>
            </v-row>
            <v-row class="mt-1">
              <v-col cols="6">
                <v-btn
                  block
                  color="purple"
                  variant="tonal"
                  :loading="submitting.translateFoods"
                  :disabled="!enabledTranslateProviders.length"
                  @click="onTranslateFoods"
                >
                  <v-icon start>mdi-food-apple</v-icon>
                  {{ t('adminData.maintenance.ai.translateFoods') }}
                </v-btn>
              </v-col>
              <v-col cols="6">
                <v-btn
                  block
                  color="purple"
                  variant="tonal"
                  :loading="submitting.translateNutrients"
                  :disabled="!enabledTranslateProviders.length"
                  @click="onTranslateNutrients"
                >
                  <v-icon start>mdi-table</v-icon>
                  {{ t('adminData.maintenance.ai.translateNutrients') }}
                </v-btn>
              </v-col>
            </v-row>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- 未映射营养素 -->
      <v-col cols="12">
        <v-card v-if="unmappedNutrients.length" class="rounded-lg mb-4">
          <v-card-title
            class="d-flex align-center py-3 cursor-pointer"
            style="cursor: pointer;"
            @click="showUnmapped = !showUnmapped"
          >
            <v-icon class="mr-2" color="warning">mdi-alert-outline</v-icon>
            <span>{{ t('adminData.maintenance.unmappedNutrients', { count: formatCount(unmappedNutrients.length) }) }}</span>
            <v-spacer />
            <v-icon>{{ showUnmapped ? 'mdi-chevron-up' : 'mdi-chevron-down' }}</v-icon>
          </v-card-title>
          <v-divider v-if="showUnmapped" />
          <v-card-text v-if="showUnmapped" class="pt-4">
            <v-chip
              v-for="name in unmappedNutrients"
              :key="name"
              size="small"
              variant="tonal"
              color="warning"
              class="mr-2 mb-2"
            >
              {{ name }}
            </v-chip>
          </v-card-text>
        </v-card>
      </v-col>

      <!-- 任务列表 -->
      <v-col cols="12">
        <v-card class="rounded-lg">
          <v-card-title class="d-flex align-center py-4">
            <v-icon class="mr-2">mdi-format-list-bulleted</v-icon>
            <span>{{ t('adminData.maintenance.tasks.title') }}</span>
            <v-spacer />
            <v-btn variant="text" size="small" @click="fetchTasks(10)">{{ t('common.refresh') }}</v-btn>
          </v-card-title>
          <v-divider />
          <v-card-text class="pt-4">
            <v-alert v-if="mergedTasks.length === 0" type="info" variant="tonal" density="compact">
              {{ t('adminData.maintenance.tasks.empty') }}
            </v-alert>
            <v-list v-else>
              <v-list-item
                v-for="t in mergedTasks"
                :key="t._kind === 'import' ? 'imp-' + t.id : t._kind === 'usda' ? 'usda-' + t.id : 'agt-' + t.session_id"
                class="mb-2 border rounded"
                :class="(t._kind === 'import' || t._kind === 'usda') ? taskRunningClass(t.status) : ''"
                :style="hasAgentLink(t) ? { cursor: 'pointer' } : {}"
                @click="onTaskClick(t)"
              >
                <template #prepend>
                  <v-icon :color="statusColor(t.status)" class="mr-3">
                    {{ statusIcon(t.status) }}
                  </v-icon>
                </template>
                <v-list-item-title class="font-weight-medium">
                  {{ t._kind === 'agent' ? t.label : taskTypeLabel(t.task_type, t.stats) }}
                  <v-chip :color="statusColor(t.status)" size="x-small" variant="tonal" class="ml-2">
                    {{ statusLabel(t.status) }}
                  </v-chip>
                </v-list-item-title>
                <v-list-item-subtitle>
                  <!-- import 任务：进度条 / 统计 / 错误 -->
                  <template v-if="t._kind === 'import'">
                    <div v-if="t.progress?.stage" class="text-caption mt-1">
                      {{ t.progress.stage }}: {{ t.progress.message }}
                    </div>
                    <div v-if="t.progress?.total > 0" class="mt-1">
                      <v-progress-linear
                        :model-value="Math.round((t.progress.current / t.progress.total) * 100)"
                        height="6" rounded color="primary"
                      />
                      <div class="text-caption text-medium-emphasis mt-1">
                        {{ formatCount(t.progress.current) }} / {{ formatCount(t.progress.total) }}
                        ({{ formatPercent(Math.round((t.progress.current / t.progress.total) * 100)) }})
                      </div>
                    </div>
                    <div v-if="t.stats && Object.keys(t.stats).length" class="text-caption mt-1">
                      <!-- storage_migrate 任务的友好统计显示 -->
                      <template v-if="t.task_type === 'storage_migrate'">
                        <v-chip v-if="t.stats.uploaded != null" size="x-small" variant="tonal" color="success" class="mr-1 mb-1">
                          {{ t('adminData.maintenance.tasks.succeeded', { count: formatCount(t.stats.uploaded) }) }}
                        </v-chip>
                        <v-chip v-if="t.stats.skipped != null" size="x-small" variant="tonal" color="grey" class="mr-1 mb-1">
                          {{ t('adminData.maintenance.tasks.skipped', { count: formatCount(t.stats.skipped) }) }}
                        </v-chip>
                        <v-chip v-if="t.stats.failed != null" size="x-small" variant="tonal" color="error" class="mr-1 mb-1">
                          {{ t('adminData.maintenance.tasks.failedCount', { count: formatCount(t.stats.failed) }) }}
                        </v-chip>
                      </template>
                      <!-- 其他任务显示所有 stats 字段 -->
                      <template v-else>
                        <v-chip v-for="(v, k) in t.stats" :key="k" size="x-small" variant="tonal"
                                class="mr-1 mb-1">{{ k }}: {{ v }}</v-chip>
                      </template>
                    </div>
                    <div v-if="t.error" class="text-caption text-error mt-1">{{ t.error }}</div>
                  </template>
                  <!-- usda 任务：完成统计 / 错误 / 运行中提示 -->
                  <template v-else-if="t._kind === 'usda'">
                    <div v-if="t.progress?.foods != null" class="text-caption mt-1">
                      {{ t('adminData.maintenance.usda.foods') }}: {{ formatCount(t.progress.foods) }}
                    </div>
                    <div v-if="t.error" class="text-caption text-error mt-1">{{ t.error }}</div>
                    <div v-else-if="t.status === 'running' || t.status === 'pending'" class="text-caption text-medium-emphasis mt-1">
                      {{ t('adminData.maintenance.tasks.background') }}
                    </div>
                  </template>
                  <!-- agent 任务：简洁状态 -->
                  <template v-else>
                    <div v-if="agentErrorMap[t.session_id]" class="text-caption text-error mt-1">
                      {{ agentErrorMap[t.session_id] }}
                    </div>
                    <div class="text-caption text-medium-emphasis mt-1">{{ t('adminData.maintenance.tasks.viewLive') }}</div>
                  </template>
                  <div class="text-caption text-medium-emphasis mt-1">{{ formatTime(t.created_at) }}</div>
                </v-list-item-subtitle>
                <template #append>
                  <v-btn
                    v-if="(t.status === 'running' || t.status === 'pending') && t._kind !== 'usda'"
                    icon="mdi-close-circle-outline" size="small" variant="text"
                    color="grey"
                    @click.stop="cancelTask(t)"
                  />
                  <v-progress-circular
                    v-if="t.status === 'running' || t.status === 'pending'"
                    indeterminate size="20" width="2" color="primary"
                  />
                </template>
              </v-list-item>
            </v-list>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useImportTask } from '@/composables/useImportTask'
import {
  getTranslationConfig,
  getUsdaStatistics,
  getUnmappedNutrients,
  downloadUsda,
  uploadUsda,
  getUsdaTasks,
  getUsdaTaskById,
} from '@/api/usda'
import { createSession, getSession, listSessions, cancelSession, type AgentProvider } from '@/api/agent'
import { api } from '@/api'
import { enabledProviderOptions, type ProviderOption } from '@/utils/agentProviders'
import { formatDateTime, formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'

const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const { t } = useI18n()
const localeStore = useLocaleStore()
const { tasks, fetchTasks, startTask, startUploadTask } = useImportTask()
const router = useRouter()

const goBack = () => router.back()
const formatCount = (value: number) => formatNumber(value, localeStore.effectiveFormatLocale)
const formatPercent = (value: number) =>
  formatNumber(value / 100, localeStore.effectiveFormatLocale, {
    style: 'percent',
    maximumFractionDigits: 0,
  })
const formatOptionalCount = (value: number | null | undefined) =>
  value == null ? '--' : formatCount(value)

const isLocalMode = computed(() => import.meta.env.VITE_STORAGE_MODE === 'local')

// 各卡片提交中状态
const submitting = reactive({ aiPieceWeight: false,
  repo: false,
  local: false,
  upload: false,
  aiQuantities: false,
  aiDensities: false,
  translateFoods: false,
  translateNutrients: false,
})

// 简短错误提示（仅在启动任务失败时显示）
const errorMessage = ref('')
const successMessage = ref('')

interface AgentTaskItem {
  session_id: number
  task_type: string
  label: string
  status: 'pending' | 'running' | 'success' | 'failed' | 'cancelled'
  created_at: string
}

const agentTasks = ref<AgentTaskItem[]>([])
const agentPollingMap = new Map<number, ReturnType<typeof setInterval>>()
const agentErrorMap = ref<Record<number, string>>({})

interface UsdaTaskItem {
  id: number
  task_type: string
  status: 'pending' | 'running' | 'success' | 'failed'
  progress?: Record<string, any> | null
  error?: string | null
  created_at: string
}

const usdaTasks = ref<UsdaTaskItem[]>([])
const usdaPollingMap = new Map<number, ReturnType<typeof setInterval>>()

// 本地导入路径配置（从后端 GET /import/data/local-path-config 读取，只读展示）
const localPathConfig = reactive({
  loaded: false,
  configured: false,
  path: '',
})
const uploadFile = ref<File | null>(null)
const aiForce = ref(false)

// AI 提供方选择（从翻译配置读取）
const aiInferProvider = ref('')
const translateProvider = ref('')
const translationConfig = ref<any>(null)

// USDA 状态
const usdaStats = ref<any>({})
const unmappedNutrients = ref<string[]>([])
const showUnmapped = ref(false)
const usdaDownloading = ref(false)
const usdaUploading = ref(false)

// 行政区划状态
const regionStatus = ref<{ counts: Record<string, number>; needed: boolean; total: number } | null>(null)
const regionSeeding = ref(false)

const AGENT_TASK_TYPES = ['fill_piece_weight', 'infer_densities', 'usda_translate', 'unmapped_nutrient_translate']
const taskLabels = computed<Record<string, string>>(() => ({
  fill_piece_weight: t('adminData.maintenance.tasks.agentPieceWeight'),
  infer_densities: t('adminData.maintenance.tasks.agentDensities'),
  usda_translate: t('adminData.maintenance.tasks.agentFoodTranslation'),
  unmapped_nutrient_translate: t('adminData.maintenance.tasks.agentNutrientTranslation'),
}))

const makeAgentLabel = (type: string, force = false) =>
  taskLabels.value[type] + (force ? ` (${t('adminData.maintenance.ai.forceShort')})` : '')

const setAgentTask = (sessionId: number, taskType: string, force = false) => {
  agentTasks.value.unshift({
    session_id: sessionId,
    task_type: taskType,
    label: makeAgentLabel(taskType, force),
    status: 'pending',
    created_at: new Date().toISOString(),
  })
  startAgentPolling(sessionId)
}

const aiProviderOptions = computed<ProviderOption[]>(() =>
  enabledProviderOptions(translationConfig.value, ['ai'], isLocalMode.value),
)
const translateProviderOptions = computed<ProviderOption[]>(() =>
  enabledProviderOptions(translationConfig.value, ['ai', 'machine'], isLocalMode.value),
)
const enabledAiProviders = computed<string[]>(() => aiProviderOptions.value.map((o) => o.value))
const enabledTranslateProviders = computed<string[]>(() =>
  translateProviderOptions.value.map((o) => o.value),
)

onMounted(async () => {
  // 加载近期任务列表，恢复对运行中任务的轮询
  fetchTasks(10)

  // 加载本地导入路径配置（只读展示用，失败降级为「未配置」）
  if (isLocalMode.value) {
    // 本地模式无服务器文件系统，「从本地路径导入」卡片隐藏，跳过该调用
    localPathConfig.configured = false
    localPathConfig.loaded = true
  } else {
    api
      .get('/import/data/local-path-config')
      .then((cfg: any) => {
        localPathConfig.configured = !!cfg?.configured
        localPathConfig.path = cfg?.path || ''
      })
      .catch(() => {
        localPathConfig.configured = false
      })
      .finally(() => {
        localPathConfig.loaded = true
      })
  }

  // 加载翻译配置
  try {
    translationConfig.value = await getTranslationConfig()
    if (enabledAiProviders.value.length) {
      aiInferProvider.value = enabledAiProviders.value[0]
    }
    if (enabledTranslateProviders.value.length) {
      translateProvider.value = enabledTranslateProviders.value[0]
    }
  } catch {
    // 忽略错误
  }

  // 加载 USDA 统计
  try {
    const stats = await getUsdaStatistics()
    usdaStats.value = {
      ...stats,
      mapped_pct: stats.total > 0 ? Math.round((stats.translated / stats.total) * 100) : 0,
    }
  } catch {
    // 忽略错误
  }

  // 加载未映射营养素
  try {
    unmappedNutrients.value = await getUnmappedNutrients()
  } catch {
    // 忽略错误
  }

  // 加载行政区划状态
  await loadRegionStatus()

  // 恢复最近的 agent 会话到任务列表（刷新后重建）
  try {
    const recent = await listSessions(20)
    const relevant = recent.filter(
      (s) => AGENT_TASK_TYPES.includes(s.task_type) && !(s.title || '').startsWith('[后台]')
    )
    for (const s of relevant) {
      if (!agentTasks.value.find((t) => t.session_id === s.id)) {
        agentTasks.value.push({
          session_id: s.id,
          task_type: s.task_type,
          label: taskLabels.value[s.task_type] || s.task_type,
          status: s.status === 'completed' ? 'success' : (s.status as any),
          created_at: s.created_at || new Date().toISOString(),
        })
      }
    }
  } catch {
    // 列表加载失败不阻塞
  }

  // 恢复 agent 任务的轮询
  const pendingAgent = agentTasks.value.filter(
    (t) => t.status === 'pending' || t.status === 'running'
  )
  pendingAgent.forEach((t) => startAgentPolling(t.session_id))

  // 恢复最近的 USDA 任务（下载 / 上传）到任务列表（刷新后重建）
  try {
    const usdaRecent: any[] = await getUsdaTasks(20)
    for (const s of usdaRecent || []) {
      // 翻译类 UsdaTask 是内部实现细节，不在任务列表显示（由 ImportTask + AgentSession 承载）。
      if (s.task_type === 'translate' || s.task_type === 'translate_nutrients') continue
      if (!usdaTasks.value.find((t) => t.id === s.id)) {
        usdaTasks.value.push({
          id: s.id,
          task_type: s.task_type,
          status: s.status,
          progress: s.progress,
          error: s.error_log || null,
          created_at: s.created_at || new Date().toISOString(),
        })
      }
    }
  } catch {
    // 列表加载失败不阻塞
  }

  // 恢复 USDA 运行中任务的轮询
  usdaTasks.value
    .filter((t) => t.status === 'running' || t.status === 'pending')
    .forEach((t) => startUsdaPolling(t.id))
})

onUnmounted(() => {
  agentPollingMap.forEach((interval) => clearInterval(interval))
  agentPollingMap.clear()
  usdaPollingMap.forEach((interval) => clearInterval(interval))
  usdaPollingMap.clear()
})

// === 任务操作 ===

async function importFromRepo() {
  submitting.repo = true
  const taskId = await startTask('/import/data/import-from-repo')
  if (!taskId) {
    errorMessage.value = t('adminData.maintenance.repoStartFailed')
  }
  submitting.repo = false
}

async function importFromLocalPath() {
  submitting.local = true
  const taskId = await startTask('/import/data/import-from-local')
  if (!taskId) {
    errorMessage.value = t('adminData.maintenance.localStartFailed')
  }
  submitting.local = false
}

async function uploadImport() {
  if (!uploadFile.value) return
  submitting.upload = true
  const taskId = await startUploadTask(uploadFile.value)
  if (taskId) {
    uploadFile.value = null
  } else {
    errorMessage.value = t('adminData.maintenance.uploadStartFailed')
  }
  submitting.upload = false
}

async function fillPieceWeight() {
  submitting.aiPieceWeight = true
  try {
    const provider = (aiInferProvider.value || 'claude_code') as AgentProvider
    const { session_id } = await createSession('fill_piece_weight', aiForce.value, provider)
    setAgentTask(session_id, 'fill_piece_weight', aiForce.value)
  } catch (e: any) {
    errorMessage.value = e?.response?.data?.detail || e?.message || t('adminData.maintenance.pieceWeightStartFailed')
  } finally {
    submitting.aiPieceWeight = false
  }
}

async function inferDensities() {
  submitting.aiDensities = true
  try {
    const provider = aiInferProvider.value || 'claude_code'
    // 本地模式：后端任务端点不存在，统一走 Agent 会话（runner 驱动）
    if (provider === 'claude_code' || isLocalMode.value) {
      const { session_id } = await createSession('infer_densities', aiForce.value, provider as AgentProvider)
      setAgentTask(session_id, 'infer_densities', aiForce.value)
    } else {
      const taskId = await startTask('/import/ai-infer/densities', {
        params: { force: aiForce.value, provider },
      })
      if (!taskId) {
        errorMessage.value = t('adminData.maintenance.densitiesStartFailed')
      }
    }
  } catch (e: any) {
    errorMessage.value = e?.response?.data?.detail || t('adminData.maintenance.densitiesStartFailed')
  }
  submitting.aiDensities = false
}

async function onTranslateFoods() {
  submitting.translateFoods = true
  try {
    const provider = translateProvider.value || 'claude_code'
    // 本地模式：后端任务端点不存在，统一走 Agent 会话（runner 驱动）
    if (provider === 'claude_code' || (isLocalMode.value && (provider === 'openai' || provider === 'anthropic'))) {
      const { session_id } = await createSession('usda_translate', aiForce.value, provider as AgentProvider)
      setAgentTask(session_id, 'usda_translate', aiForce.value)
    } else if (isLocalMode.value) {
      errorMessage.value = t('adminData.maintenance.localMachineUnsupported')
    } else {
      const taskId = await startTask('/import/translate/foods', {
        params: { provider, force: aiForce.value },
      })
      if (!taskId) {
        errorMessage.value = t('adminData.maintenance.foodTranslationStartFailed')
      } else {
        successMessage.value = t('adminData.maintenance.foodTranslationStarted')
      }
    }
  } catch (e: any) {
    errorMessage.value = e?.response?.data?.detail || t('adminData.maintenance.foodTranslationStartFailed')
  }
  submitting.translateFoods = false
}

async function onTranslateNutrients() {
  submitting.translateNutrients = true
  try {
    const provider = translateProvider.value || 'claude_code'
    // 本地模式：后端任务端点不存在，统一走 Agent 会话（runner 驱动）
    if (provider === 'claude_code' || (isLocalMode.value && (provider === 'openai' || provider === 'anthropic'))) {
      const { session_id } = await createSession('unmapped_nutrient_translate', aiForce.value, provider as AgentProvider)
      setAgentTask(session_id, 'unmapped_nutrient_translate', aiForce.value)
    } else if (isLocalMode.value) {
      errorMessage.value = t('adminData.maintenance.localMachineUnsupported')
    } else {
      const taskId = await startTask('/import/translate/nutrients', {
        params: { provider, force: aiForce.value },
      })
      if (!taskId) {
        errorMessage.value = t('adminData.maintenance.nutrientTranslationStartFailed')
      } else {
        successMessage.value = t('adminData.maintenance.nutrientTranslationStarted')
      }
    }
  } catch (e: any) {
    errorMessage.value = e?.response?.data?.detail || t('adminData.maintenance.nutrientTranslationStartFailed')
  }
  submitting.translateNutrients = false
}

// === USDA 操作 ===

async function loadUsdaStats() {
  try {
    const stats = await getUsdaStatistics()
    usdaStats.value = {
      ...stats,
      mapped_pct: stats.total > 0 ? Math.round((stats.translated / stats.total) * 100) : 0,
    }
  } catch {
    // 忽略
  }
}

async function loadUnmapped() {
  try {
    unmappedNutrients.value = await getUnmappedNutrients()
  } catch {
    // 忽略
  }
}

async function downloadUsdaData() {
  usdaDownloading.value = true
  try {
    const data: any = await downloadUsda()
    if (data?.task_id) {
      addUsdaTask(data.task_id, 'download')
    }
    successMessage.value = t('adminData.maintenance.usda.downloadStarted')
  } catch (e: any) {
    errorMessage.value = e?.userMessage || t('adminData.maintenance.usda.downloadFailed')
  } finally {
    usdaDownloading.value = false
  }
}

function triggerUsdaUpload() {
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = '.zip'
  input.onchange = async () => {
    const file = input.files?.[0]
    if (!file) return
    usdaUploading.value = true
    try {
      const data: any = await uploadUsda(file)
      if (data?.task_id) {
        addUsdaTask(data.task_id, 'upload')
      }
      successMessage.value = t('adminData.maintenance.usda.uploadSuccess')
      loadUsdaStats()
    } catch (e: any) {
      errorMessage.value = e?.response?.data?.detail || t('adminData.maintenance.usda.uploadFailed')
    } finally {
      usdaUploading.value = false
    }
  }
  input.click()
}

// === 行政区划操作 ===

async function loadRegionStatus() {
  try {
    const data = await api.get('/admin/regions/seed-status')
    regionStatus.value = data
  } catch (e: any) {
    console.error("[loadRegionStatus] error:", e)
  }
}

async function seedRegions() {
  regionSeeding.value = true
  try {
    const result = await api.post('/admin/regions/seed')
    successMessage.value = t('adminData.maintenance.regions.updated', {
      created: formatCount(result.created),
      skipped: formatCount(result.skipped),
    })
    await loadRegionStatus()
  } catch (e: any) {
    errorMessage.value = t('adminData.maintenance.regions.updateFailed', {
      message: e?.userMessage || e?.message || t('errors.unknown'),
    })
  } finally {
    regionSeeding.value = false
  }
}

// === Agent 轮询 ===

function startAgentPolling(sessionId: number) {
  if (agentPollingMap.has(sessionId)) return
  const interval = setInterval(async () => {
    try {
      const data = await getSession(sessionId) as any
      const idx = agentTasks.value.findIndex(t => t.session_id === sessionId)
      if (idx >= 0) {
        const status = data.status === 'completed' ? 'success' : data.status
        if (status !== agentTasks.value[idx].status) {
          agentTasks.value[idx] = { ...agentTasks.value[idx], status }
        }
        if (data.error) {
          agentErrorMap.value[sessionId] = data.error
        }
      }
      if (data.status === 'success' || data.status === 'completed' || data.status === 'failed' || data.status === 'cancelled') {
        stopAgentPolling(sessionId)
      }
    } catch {
      const idx = agentTasks.value.findIndex(t => t.session_id === sessionId)
      if (idx >= 0) {
        agentTasks.value[idx] = { ...agentTasks.value[idx], status: 'failed' }
      }
      stopAgentPolling(sessionId)
    }
  }, 3000)
  agentPollingMap.set(sessionId, interval)
}

function stopAgentPolling(sessionId: number) {
  const interval = agentPollingMap.get(sessionId)
  if (interval) {
    clearInterval(interval)
    agentPollingMap.delete(sessionId)
  }
}

// === USDA 任务（下载 / 上传）入列 + 轮询 ===

function addUsdaTask(taskId: number, taskType: string) {
  if (usdaTasks.value.find((t) => t.id === taskId)) return
  usdaTasks.value.unshift({
    id: taskId,
    task_type: taskType,
    status: 'running',
    progress: null,
    error: null,
    created_at: new Date().toISOString(),
  })
  startUsdaPolling(taskId)
}

function startUsdaPolling(taskId: number) {
  if (usdaPollingMap.has(taskId)) return
  const interval = setInterval(async () => {
    try {
      const data: any = await getUsdaTaskById(taskId)
      const idx = usdaTasks.value.findIndex((t) => t.id === taskId)
      if (idx >= 0) {
        usdaTasks.value[idx] = {
          ...usdaTasks.value[idx],
          status: data.status,
          progress: data.progress,
          error: data.error_log || null,
        }
      }
      if (data.status === 'success' || data.status === 'failed') {
        stopUsdaPolling(taskId)
        loadUsdaStats()
      }
    } catch {
      stopUsdaPolling(taskId)
    }
  }, 3000)
  usdaPollingMap.set(taskId, interval)
}

function stopUsdaPolling(taskId: number) {
  const interval = usdaPollingMap.get(taskId)
  if (interval) {
    clearInterval(interval)
    usdaPollingMap.delete(taskId)
  }
}

// === 取消任务 ===

async function cancelTask(t: any) {
  try {
    if (t._kind === 'agent') {
      await cancelSession(t.session_id)
      stopAgentPolling(t.session_id)
      const idx = agentTasks.value.findIndex(x => x.session_id === t.session_id)
      if (idx >= 0) agentTasks.value[idx] = { ...agentTasks.value[idx], status: 'cancelled' }
    } else {
      await api.post(`/import/task/${t.id}/cancel`)
      successMessage.value = t('adminData.maintenance.tasks.cancelled')
    }
  } catch (e: any) {
    errorMessage.value = e?.response?.data?.detail || t('adminData.maintenance.tasks.cancelFailed')
  }
}

// === 辅助函数 ===

interface ImportTaskLike {
  id: number
  task_type: string
  status: string
  progress?: { stage: string; current: number; total: number; message: string }
  stats?: Record<string, number>
  error?: string | null
  created_at: string
  _kind: 'import'
}

interface AgentTaskLike extends AgentTaskItem {
  _kind: 'agent'
}

interface UsdaTaskLike extends UsdaTaskItem {
  _kind: 'usda'
}

type MergedTask = ImportTaskLike | AgentTaskLike | UsdaTaskLike

const mergedTasks = computed<MergedTask[]>(() => {
  const imports: ImportTaskLike[] = tasks.value.map(t => ({ ...t, _kind: 'import' as const }))
  // 排除已被 ImportTask 的 stats.agent_session_id 关联的 Agent（避免同一操作显示两条）。
  const _importAgentIds = new Set(
    imports.filter(t => t.stats?.agent_session_id).map(t => t.stats!.agent_session_id!)
  )
  const agents: AgentTaskLike[] = agentTasks.value
    .filter(t => !_importAgentIds.has(t.session_id))
    .map(t => ({ ...t, _kind: 'agent' as const }))
  const usdas: UsdaTaskLike[] = usdaTasks.value
    .filter(t => t.task_type !== 'translate' && t.task_type !== 'translate_nutrients')
    .map(t => ({ ...t, _kind: 'usda' as const }))
  return [...imports, ...agents, ...usdas].sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  )
})

// 是否可跳转到任务台对话：agent 任务，或带 agent_session_id 的 import 任务（AI 推测
// 走 Agent 路径时，inferrer 把 [后台] AgentSession.id 写进 ImportTask.stats.agent_session_id）。
function hasAgentLink(t: MergedTask): boolean {
  if (t._kind === 'agent') return true
  if (t._kind === 'import') return !!t.stats?.agent_session_id
  return false
}

// 点击任务条目跳转任务台对话。
function onTaskClick(t: MergedTask) {
  if (t._kind === 'agent') {
    router.push('/admin/agent-console?session_id=' + t.session_id)
  } else if (t._kind === 'import' && t.stats?.agent_session_id) {
    router.push('/admin/agent-console?session_id=' + t.stats.agent_session_id)
  }
}

const taskTypeLabels = computed<Record<string, string>>(() => ({
  git_import: t('adminData.maintenance.tasks.gitImport'),
  local_import: t('adminData.maintenance.tasks.localImport'),
  upload_import: t('adminData.maintenance.tasks.uploadImport'),
  ai_quantities: t('adminData.maintenance.tasks.aiQuantities'),
  ai_densities: t('adminData.maintenance.tasks.aiDensities'),
  usda_translate: t('adminData.maintenance.tasks.foodTranslation'),
  nutrient_translate: t('adminData.maintenance.tasks.nutrientTranslation'),
  download: t('adminData.maintenance.usda.download'),
  upload: t('adminData.maintenance.usda.upload'),
}))

function taskTypeLabel(type: string, stats?: Record<string, any>): string {
  if (type === 'storage_migrate') {
    const direction = stats?.direction
    if (direction === 'to_s3') return t('adminData.maintenance.tasks.storageMigrateToS3')
    if (direction === 'to_local') return t('adminData.maintenance.tasks.storageMigrateToLocal')
    return t('adminData.maintenance.tasks.storageMigrate')
  }
  return taskTypeLabels.value[type] || type
}

const statusConfig = computed<Record<string, { color: string; icon: string; label: string }>>(() => ({
  pending: { color: 'grey', icon: 'mdi-clock-outline', label: t('adminData.status.pending') },
  running: { color: 'primary', icon: 'mdi-loading', label: t('adminData.status.running') },
  success: { color: 'success', icon: 'mdi-check-circle', label: t('adminData.status.success') },
  failed: { color: 'error', icon: 'mdi-alert-circle', label: t('adminData.status.failed') },
  cancelled: { color: 'warning', icon: 'mdi-cancel', label: t('adminData.status.cancelled') },
}))

function statusColor(status: string): string {
  return statusConfig.value[status]?.color || 'grey'
}

function statusIcon(status: string): string {
  return statusConfig.value[status]?.icon || 'mdi-help-circle'
}

function statusLabel(status: string): string {
  return statusConfig.value[status]?.label || status
}

function taskRunningClass(status: string): string {
  return status === 'running' ? 'status-running' : ''
}

function formatTime(iso: string): string {
  return iso ? formatDateTime(iso, localeStore.effectiveFormatLocale) : ''
}
</script>

<style scoped>
.v-theme--light .v-btn.color-github {
  color: rgb(31, 31, 31);
}
.v-theme--dark .v-btn.color-github {
  color: rgb(220, 220, 220);
}
.v-theme--light .v-btn.color-github.v-btn--variant-tonal {
  background-color: rgb(31, 31, 31);
  color: white;
}
.v-theme--dark .v-btn.color-github.v-btn--variant-tonal {
  background-color: rgb(220, 220, 220);
  color: black;
}

/* 运行中任务脉冲动画 */
:deep(.v-list-item.status-running) {
  animation: pulse-bg 2s ease-in-out infinite;
}

@keyframes pulse-bg {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.65; }
}
</style>

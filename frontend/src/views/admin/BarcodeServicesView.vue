<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">条码服务配置</v-app-bar-title>
    <template #append>
      <v-btn color="primary" variant="tonal" :loading="saving" @click="save">
        <v-icon start>mdi-content-save</v-icon>
        保存
      </v-btn>
    </template>
  </v-app-bar>

  <v-container v-if="config" class="pa-4">
    <v-alert v-if="loadError" type="error" class="mb-4" closable @click:close="loadError = ''">
      {{ loadError }}
    </v-alert>

    <v-card class="rounded-lg mb-4" elevation="0">
      <v-card-text>
        <v-row dense>
          <v-col cols="12" sm="6" md="4">
            <v-text-field
              v-model.number="config.cache_ttl_minutes"
              label="缓存有效期"
              type="number"
              min="1"
              suffix="分钟"
              variant="outlined"
              hint="外部条码结果缓存时长，保存配置后会清空现有缓存"
              persistent-hint
            />
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <v-card
      v-for="(service, index) in config.services"
      :key="service.id"
      class="rounded-lg mb-4"
      elevation="0"
      border
    >
      <v-card-title class="d-flex align-center flex-wrap ga-2 py-3">
        <v-chip size="small" variant="tonal" color="primary">{{ index + 1 }}</v-chip>
        <div class="text-subtitle-1 font-weight-medium">
          {{ service.type === 'custom' ? service.name || '未命名自定义服务' : typeLabel(service.type) }}
        </div>
        <v-chip size="small" variant="tonal">{{ typeLabel(service.type) }}</v-chip>
        <div class="d-flex align-center ga-1">
          <v-btn
            icon="mdi-arrow-up"
            size="small"
            variant="text"
            :disabled="index === 0"
            aria-label="提高优先级"
            @click="moveService(index, -1)"
          />
          <v-btn
            icon="mdi-arrow-down"
            size="small"
            variant="text"
            :disabled="index === config.services.length - 1"
            aria-label="降低优先级"
            @click="moveService(index, 1)"
          />
        </div>
        <v-spacer />
        <v-switch
          v-model="service.enabled"
          color="primary"
          label="启用"
          density="compact"
          hide-details
        />
      </v-card-title>

      <v-card-subtitle class="d-flex align-center flex-wrap ga-2 pb-3">
        <span class="text-medium-emphasis">ID: {{ service.id }}</span>
        <span class="text-caption text-medium-emphasis">上方服务优先查询</span>
        <v-btn
          v-if="docLink(service)"
          :href="docLink(service)"
          target="_blank"
          rel="noopener noreferrer"
          size="small"
          variant="text"
          color="primary"
          prepend-icon="mdi-open-in-new"
        >
          {{ service.type === 'custom' ? 'API 文档' : '申请 / 文档' }}
        </v-btn>
      </v-card-subtitle>

      <v-divider />
      <v-card-text>
        <v-row dense>
          <v-col cols="12" sm="6" md="3">
            <v-text-field
              v-model.number="service.timeout_seconds"
              label="请求超时"
              type="number"
              min="0.1"
              max="30"
              step="0.1"
              suffix="秒"
              variant="outlined"
            />
          </v-col>

          <template v-if="service.type === 'mxnzp'">
            <v-col cols="12" sm="6" md="4">
              <v-text-field
                v-model="service.app_id"
                label="App ID"
                variant="outlined"
                :type="service.has_app_id ? 'password' : 'text'"
                autocomplete="new-password"
              />
            </v-col>
            <v-col cols="12" sm="6" md="5">
              <v-text-field
                v-model="service.app_secret"
                label="App Secret"
                variant="outlined"
                type="password"
                autocomplete="new-password"
              />
            </v-col>
          </template>

          <template v-else-if="service.type === 'yunji'">
            <v-col cols="12" sm="6" md="4">
              <v-text-field
                v-model="service.app_code"
                label="AppCode"
                variant="outlined"
                type="password"
                autocomplete="new-password"
              />
            </v-col>
          </template>

          <template v-else-if="service.type === 'openfoodfacts'">
            <v-col cols="12" class="text-body-2 text-medium-emphasis">
              Open Food Facts 开放数据无需 API 密钥。
            </v-col>
          </template>
        </v-row>

        <template v-if="service.type === 'custom'">
          <v-divider class="my-4" />
          <v-row dense>
            <v-col cols="12" sm="6" md="4">
              <v-text-field v-model="service.name" label="服务名称" variant="outlined" />
            </v-col>
            <v-col cols="12" sm="6" md="8">
              <v-text-field v-model="service.doc_url" label="API 文档链接" variant="outlined" />
            </v-col>
            <v-col cols="12">
              <v-text-field
                v-model="service.url_template"
                label="请求 URL 模板"
                variant="outlined"
                placeholder="https://api.example.com/barcode/{barcode}"
                hint="使用 {barcode} 占位，条码会安全编码后替换"
                persistent-hint
              />
            </v-col>
          </v-row>

          <div class="text-subtitle-2 mt-4 mb-2">请求 Header</div>
          <v-row
            v-for="(value, name) in service.headers"
            :key="name"
            dense
            align="center"
          >
            <v-col cols="12" sm="5" md="4">
              <v-text-field
                :model-value="name"
                label="Header 名"
                variant="outlined"
                density="compact"
                @update:model-value="renameHeader(service, name, String($event))"
              />
            </v-col>
            <v-col cols="12" sm="6" md="7">
              <v-text-field
                v-model="service.headers[name]"
                label="Header 值"
                variant="outlined"
                density="compact"
                :type="value === '***' ? 'password' : 'text'"
                autocomplete="new-password"
              />
            </v-col>
            <v-col cols="12" sm="1" class="d-flex justify-end">
              <v-btn icon="mdi-delete" variant="text" color="error" @click="removeHeader(service, name)" />
            </v-col>
          </v-row>
          <v-btn size="small" variant="tonal" prepend-icon="mdi-plus" @click="addHeader(service)">
            添加 Header
          </v-btn>

          <v-divider class="my-4" />
          <div class="text-subtitle-2 mb-2">字段 JSONPath 映射</div>
          <v-row dense>
            <v-col
              v-for="field in mappingFields"
              :key="field.key"
              cols="12"
              sm="6"
              md="4"
            >
              <v-text-field
                v-model="service.mappings[field.key]"
                :label="field.label"
                :required="field.key === 'name'"
                variant="outlined"
                density="compact"
                placeholder="$.data.name"
              />
            </v-col>
          </v-row>
        </template>

        <v-divider class="my-4" />
        <v-row dense align="center">
          <v-col cols="12" sm="6" md="4">
            <v-text-field
              v-model="testBarcode"
              label="测试条码"
              variant="outlined"
              density="compact"
            />
          </v-col>
          <v-col cols="auto">
            <v-btn
              variant="tonal"
              color="primary"
              :loading="testingId === service.id"
              :disabled="!testBarcode.trim()"
              prepend-icon="mdi-play"
              @click="testService(service)"
            >
              测试服务
            </v-btn>
          </v-col>
          <v-col cols="auto">
            <v-btn
              icon="mdi-arrow-up"
              variant="text"
              :disabled="index === 0"
              aria-label="上移服务"
              @click="moveService(index, -1)"
            />
            <v-btn
              icon="mdi-arrow-down"
              variant="text"
              :disabled="index === config.services.length - 1"
              aria-label="下移服务"
              @click="moveService(index, 1)"
            />
            <v-btn
              v-if="service.type === 'custom'"
              icon="mdi-delete"
              variant="text"
              color="error"
              aria-label="删除自定义服务"
              @click="pendingDeleteId = service.id"
            />
          </v-col>
        </v-row>

        <v-alert
          v-if="testResults[service.id]"
          class="mt-3"
          density="compact"
          :type="testResults[service.id].found ? 'success' : 'warning'"
        >
          <div v-if="testResults[service.id].found">
            {{ testResults[service.id].product?.name }}（{{ testResults[service.id].source }}）
          </div>
          <div v-else>
            {{ testResults[service.id].errors.join('；') || '未找到商品' }}
          </div>
        </v-alert>
      </v-card-text>
    </v-card>

    <v-btn color="primary" variant="tonal" prepend-icon="mdi-plus" @click="addCustomService">
      添加自定义 API
    </v-btn>

    <v-alert v-if="saveMessage" class="mt-4" density="compact" :type="saveFailed ? 'error' : 'success'">
      {{ saveMessage }}
    </v-alert>
  </v-container>

  <v-container v-else class="d-flex justify-center align-center fill-height">
    <v-progress-circular indeterminate color="primary" />
  </v-container>

  <v-dialog :model-value="!!pendingDeleteId" max-width="420">
    <v-card v-if="serviceToDelete">
      <v-card-title>删除自定义服务</v-card-title>
      <v-card-text>确定删除“{{ serviceToDelete.name || serviceToDelete.id }}”吗？</v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" @click="pendingDeleteId = ''">取消</v-btn>
        <v-btn color="error" variant="text" @click="deleteCustomService">删除</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { api } from '@/api'

type ServiceType = 'openfoodfacts' | 'mxnzp' | 'yunji' | 'custom'

interface BarcodeService {
  id: string
  type: ServiceType
  enabled: boolean
  timeout_seconds: number
  name?: string | null
  doc_url?: string | null
  app_id?: string | null
  app_secret?: string | null
  app_code?: string | null
  has_app_id?: boolean
  has_app_secret?: boolean
  has_app_code?: boolean
  url_template?: string | null
  headers: Record<string, string>
  mappings: Record<string, string>
}

interface BarcodeConfig {
  cache_ttl_minutes: number
  services: BarcodeService[]
}

interface TestResult {
  found: boolean
  source?: string | null
  product?: { name?: string | null }
  errors: string[]
}

const TYPE_LABELS: Record<ServiceType, string> = {
  openfoodfacts: 'Open Food Facts',
  mxnzp: 'mxnzp',
  yunji: '云际（云 API 市场）',
  custom: '自定义',
}

const BUILTIN_LINKS: Record<string, string> = {
  openfoodfacts: 'https://world.openfoodfacts.org/',
  mxnzp: 'https://www.mxnzp.com/doc/detail?id=6',
  yunji: 'https://market.aliyun.com/detail/cmapi031448',
}

const MAPPING_FIELDS = [
  { key: 'name', label: '商品名 *' },
  { key: 'brand', label: '品牌' },
  { key: 'spec', label: '规格' },
  { key: 'manufacturer', label: '厂商' },
  { key: 'image_url', label: '图片 URL' },
]

const router = useRouter()
const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const config = ref<BarcodeConfig | null>(null)
const loading = ref(false)
const saving = ref(false)
const loadError = ref('')
const saveMessage = ref('')
const saveFailed = ref(false)
const testingId = ref('')
const testBarcode = ref('')
const testResults = ref<Record<string, TestResult>>({})
const pendingDeleteId = ref('')

const serviceToDelete = computed(() =>
  config.value?.services.find((service) => service.id === pendingDeleteId.value)
)

const goBack = () => router.back()
const typeLabel = (type: ServiceType) => TYPE_LABELS[type] || type
const docLink = (service: BarcodeService) =>
  service.type === 'custom' ? service.doc_url || '' : BUILTIN_LINKS[service.type]

function normalizeService(service: BarcodeService): BarcodeService {
  return {
    ...service,
    headers: service.headers || {},
    mappings: Object.fromEntries(
      MAPPING_FIELDS.map((field) => [field.key, service.mappings?.[field.key] || ''])
    ),
  }
}

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const data = await api.get('/admin/barcode-services')
    config.value = {
      cache_ttl_minutes: data.cache_ttl_minutes,
      services: data.services.map(normalizeService),
    }
  } catch (error: any) {
    loadError.value = error.userMessage || '获取条码服务配置失败'
  } finally {
    loading.value = false
  }
}

function moveService(index: number, offset: number) {
  const services = config.value?.services
  if (!services) return
  const target = index + offset
  if (target < 0 || target >= services.length) return
  const [service] = services.splice(index, 1)
  services.splice(target, 0, service)
}

function addHeader(service: BarcodeService) {
  let index = 1
  while (`X-Header-${index}` in service.headers) index += 1
  service.headers[`X-Header-${index}`] = ''
}

function removeHeader(service: BarcodeService, name: string) {
  delete service.headers[name]
}

function renameHeader(service: BarcodeService, oldName: string, newName: string) {
  if (!newName || newName === oldName) return
  const entries = Object.entries(service.headers).map(([name, value]) => [
    name === oldName ? newName : name,
    value,
  ])
  service.headers = Object.fromEntries(entries)
}

function addCustomService() {
  const id = `custom-${Date.now().toString(36)}`
  config.value?.services.push(normalizeService({
    id,
    type: 'custom',
    enabled: false,
    timeout_seconds: 5,
    name: '',
    doc_url: '',
    url_template: '',
    headers: {},
    mappings: {},
  }))
}

function deleteCustomService() {
  if (!config.value || !pendingDeleteId.value) return
  config.value.services = config.value.services.filter(
    (service) => service.id !== pendingDeleteId.value
  )
  pendingDeleteId.value = ''
}

function servicePayload(service: BarcodeService) {
  return {
    ...service,
    timeout_seconds: Number(service.timeout_seconds) || 5,
    headers: Object.fromEntries(
      Object.entries(service.headers).filter(([name]) => name.trim())
    ),
  }
}

async function save() {
  if (!config.value) return
  saving.value = true
  saveMessage.value = ''
  try {
    await api.put('/admin/barcode-services', {
      cache_ttl_minutes: Number(config.value.cache_ttl_minutes) || 10080,
      services: config.value.services.map(servicePayload),
    })
    saveFailed.value = false
    saveMessage.value = '配置已保存，条码缓存已清空'
  } catch (error: any) {
    saveFailed.value = true
    saveMessage.value = error.userMessage || error.response?.data?.detail || '保存配置失败'
  } finally {
    saving.value = false
  }
}

async function testService(service: BarcodeService) {
  testingId.value = service.id
  try {
    const result = await api.post('/admin/barcode-services/test', {
      barcode: testBarcode.value.trim(),
      service: servicePayload(service),
    })
    testResults.value[service.id] = result
  } catch (error: any) {
    testResults.value[service.id] = {
      found: false,
      errors: [error.userMessage || error.response?.data?.detail || '测试失败'],
    }
  } finally {
    testingId.value = ''
  }
}

onMounted(load)
</script>

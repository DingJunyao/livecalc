<!-- frontend/src/views/admin/AiConfigView.vue -->
<!-- AI 与机翻合并配置页：两个折叠面板（默认全展开），统一保存 -->
<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { getTranslationConfig, putTranslationConfig, testTranslationConnection } from '@/api/usda'
import ProviderCard from '@/components/admin/ProviderCard.vue'

const router = useRouter()
const { t } = useI18n()
const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const goBack = () => router.back()

const isLocalMode = computed(() => import.meta.env.VITE_STORAGE_MODE === 'local')
// claude_code 依赖服务器 PATH 中的 claude CLI，纯前端本地模式不可用，隐藏该 provider
type FieldType = 'text' | 'password' | 'switch'
interface ProviderField { key: string; label: string; type?: FieldType }
interface ProviderDef { key: string; title: string; hint?: string; fields: ProviderField[] }

// AI 翻译 provider 字段配置（Claude Code / OpenAI 兼容 / Anthropic 兼容）
const AI_PROVIDERS = computed<ProviderDef[]>(() => [
  {
    key: 'claude_code',
    title: t('adminAI.providers.claudeCode'),
    hint: t('adminAI.providers.claudeCodeHint'),
    fields: [{ key: 'enabled', label: t('adminAI.fields.enabled'), type: 'switch' }],
  },
  {
    key: 'codex',
    title: t('adminAI.providers.codex'),
    hint: t('adminAI.providers.codexHint'),
    fields: [{ key: 'enabled', label: t('adminAI.fields.enabled'), type: 'switch' }],
  },
  {
    key: 'openai',
    title: t('adminAI.providers.openaiCompatible'),
    fields: [
      { key: 'enabled', label: t('adminAI.fields.enabled'), type: 'switch' },
      { key: 'base_url', label: t('adminAI.fields.baseUrl') },
      { key: 'api_key', label: t('adminAI.fields.apiKey'), type: 'password' },
      { key: 'model', label: t('adminAI.fields.model') },
    ],
  },
  {
    key: 'anthropic',
    title: t('adminAI.providers.anthropicCompatible'),
    fields: [
      { key: 'enabled', label: t('adminAI.fields.enabled'), type: 'switch' },
      { key: 'base_url', label: t('adminAI.fields.baseUrl') },
      { key: 'api_key', label: t('adminAI.fields.apiKey'), type: 'password' },
      { key: 'model', label: t('adminAI.fields.model') },
    ],
  },
])

const aiProviders = computed(() =>
  isLocalMode.value
    ? AI_PROVIDERS.value.filter((p) => p.key !== 'claude_code' && p.key !== 'codex')
    : AI_PROVIDERS.value,
)

// 机器翻译 provider 字段配置（百度 / 阿里云 / DeepL）
const MT_PROVIDERS = computed<ProviderDef[]>(() => [
  {
    key: 'baidu',
    title: t('adminAI.providers.baidu'),
    fields: [
      { key: 'enabled', label: t('adminAI.fields.enabled'), type: 'switch' },
      { key: 'appid', label: t('adminAI.fields.appId') },
      { key: 'secret', label: t('adminAI.fields.secret'), type: 'password' },
    ],
  },
  {
    key: 'aliyun',
    title: t('adminAI.providers.aliyun'),
    fields: [
      { key: 'enabled', label: t('adminAI.fields.enabled'), type: 'switch' },
      { key: 'access_key_id', label: t('adminAI.fields.accessKeyId') },
      { key: 'access_key_secret', label: t('adminAI.fields.accessKeySecret'), type: 'password' },
    ],
  },
  {
    key: 'deepl',
    title: t('adminAI.providers.deepl'),
    fields: [
      { key: 'enabled', label: t('adminAI.fields.enabled'), type: 'switch' },
      { key: 'auth_key', label: t('adminAI.fields.authKey'), type: 'password' },
    ],
  },
])

const config = ref<any>(null)
const testing = ref('')
const saving = ref(false)
const saveMessage = ref('')
// 每个 provider 的测试结果在按钮旁就地显示（成功/失败 + 后端返回的 detail）
const testResult = reactive<Record<string, { ok: boolean; detail: string }>>({})
// 两个折叠面板默认全展开
const openPanels = ref<number[]>([0, 1])

onMounted(async () => { config.value = await getTranslationConfig() })

// 写入某分组下某 provider 的某字段
function setField(group: 'ai' | 'machine', provider: string, field: string, value: any) {
  config.value[group].providers[provider][field] = value
}

// 测试某 provider 连接（先保存当前配置，再触发后端测试）
async function testProvider(provider: string) {
  testing.value = provider
  delete testResult[provider]
  try {
    await putTranslationConfig(config.value)
    const r: any = await testTranslationConnection(provider)
    testResult[provider] = {
      ok: !!r.ok,
      detail: r.detail || (r.ok ? t('adminAI.connectionSuccess') : t('adminAI.connectionFailed')),
    }
  } catch (e: any) {
    testResult[provider] = { ok: false, detail: e.userMessage || t('adminAI.testFailed') }
  } finally {
    testing.value = ''
  }
}

// 统一保存 AI + 机翻配置
async function save() {
  saving.value = true
  try {
    await putTranslationConfig(config.value)
    saveMessage.value = t('adminAI.saved')
  } catch (e: any) {
    saveMessage.value = e.userMessage || t('errors.unknown')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <!-- 顶部导航栏 -->
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('adminAI.title') }}</v-app-bar-title>
  </v-app-bar>

  <v-container v-if="config" class="pa-4">
    <p class="text-caption mb-2">
      {{ isLocalMode ? t('adminAI.summaryLocal') : t('adminAI.summaryServer') }}
    </p>

    <v-expansion-panels multiple v-model="openPanels" class="my-3">
      <v-expansion-panel>
        <v-expansion-panel-title>
          <v-icon class="mr-2">mdi-robot</v-icon>{{ t('adminAI.aiTranslation') }}
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <ProviderCard
            v-for="p in aiProviders"
            :key="p.key"
            :title="p.title"
            :hint="p.hint"
            :fields="p.fields"
            :values="config.ai.providers[p.key]"
            :testing="testing === p.key"
            :test-result="testResult[p.key]"
            @update:field="setField('ai', p.key, $event.field, $event.value)"
            @test="testProvider(p.key)"
          />
        </v-expansion-panel-text>
      </v-expansion-panel>

      <v-expansion-panel>
        <v-expansion-panel-title>
          <v-icon class="mr-2">mdi-translate</v-icon>{{ t('adminAI.machineTranslation') }}
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <ProviderCard
            v-for="p in MT_PROVIDERS"
            :key="p.key"
            :title="p.title"
            :fields="p.fields"
            :values="config.machine.providers[p.key]"
            :testing="testing === p.key"
            :test-result="testResult[p.key]"
            @update:field="setField('machine', p.key, $event.field, $event.value)"
            @test="testProvider(p.key)"
          />
        </v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>

    <v-btn color="primary" :loading="saving" @click="save">{{ t('adminAI.saveConfig') }}</v-btn>
    <v-alert v-if="saveMessage" class="mt-3" density="compact" :text="saveMessage" />
  </v-container>
</template>

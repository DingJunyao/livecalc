<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('adminEmail.title') }}</v-app-bar-title>
    <template #append>
      <v-btn icon="mdi-refresh" variant="text" @click="loadAll" />
    </template>
  </v-app-bar>

  <v-container class="pa-4">
    <v-expansion-panels variant="accordion" multiple>
      <!-- 面板一：SMTP 配置 -->
      <v-expansion-panel :value="0">
        <v-expansion-panel-title>
          <v-icon start class="me-2">mdi-server-network-outline</v-icon>
          {{ t('adminEmail.smtpConfig') }}
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <v-row dense>
            <v-col cols="12" sm="6">
              <v-text-field v-model="smtp.host" :label="t('adminEmail.smtpServer')" placeholder="smtp.example.com"
                variant="outlined" density="compact" hide-details="auto" />
            </v-col>
            <v-col cols="6" sm="2">
              <v-text-field v-model.number="smtp.port" :label="t('adminEmail.port')" type="number"
                variant="outlined" density="compact" hide-details="auto" />
            </v-col>
            <v-col cols="6" sm="2" class="d-flex align-center">
              <v-switch v-model="smtp.use_ssl" label="SSL" density="compact" hide-details
                @update:model-value="onSslChanged" />
            </v-col>
            <v-col cols="6" sm="2" class="d-flex align-center">
              <v-switch v-model="smtp.use_tls" label="STARTTLS" density="compact" hide-details
                @update:model-value="onTlsChanged" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="smtp.username" :label="t('adminEmail.username')"
                variant="outlined" density="compact" hide-details="auto" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="passwordField" :label="t('adminEmail.password')" type="password"
                variant="outlined" density="compact" hide-details="auto"
                :placeholder="t('adminEmail.passwordPlaceholder')" />
            </v-col>
            <v-col cols="12" sm="6">
              <v-text-field v-model="smtp.from_address" :label="t('adminEmail.fromAddress')" placeholder="noreply@example.com"
                variant="outlined" density="compact" hide-details="auto" />
            </v-col>
            <v-col cols="12" sm="3">
              <v-text-field v-model="smtp.from_name" :label="t('adminEmail.fromName')"
                variant="outlined" density="compact" hide-details="auto" />
            </v-col>
            <v-col cols="12" sm="3" class="d-flex align-center">
              <v-switch v-model="smtp.enabled" :label="t('adminEmail.enabled')" density="compact" hide-details />
            </v-col>
          </v-row>

          <v-row class="mt-4">
            <v-col cols="12" class="d-flex ga-2 flex-wrap">
              <v-btn color="primary" :loading="savingSmtp" @click="saveSmtp">
                {{ t('adminEmail.saveSmtp') }}
              </v-btn>
              <v-spacer />
              <v-text-field v-model="testEmail" :label="t('adminEmail.testEmailAddress')" variant="outlined"
                density="compact" hide-details style="max-width: 250px" />
              <v-btn variant="tonal" :loading="testing" :disabled="!testEmail || !smtp.enabled"
                @click="sendTest">
                {{ t('adminEmail.sendTest') }}
              </v-btn>
            </v-col>
          </v-row>
        </v-expansion-panel-text>
      </v-expansion-panel>

      <!-- 面板二：邮件模板 -->
      <v-expansion-panel :value="1">
        <v-expansion-panel-title>
          <v-icon start class="me-2">mdi-email-edit-outline</v-icon>
          {{ t('adminEmail.templates') }}
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <v-alert type="info" variant="tonal" density="comfortable" class="mb-4">
            {{ t('adminEmail.availableVariables') }}<code>${proposal_id}</code> <code>${entity_type_label}</code>
            <code>${action_label}</code> <code>${entity_label}</code>
            <code>${proposer_name}</code> <code>${review_note}</code>
          </v-alert>

          <v-tabs
            v-model="templateLocale"
            :items="localeOptions"
            item-title="label"
            item-value="value"
            density="comfortable"
            color="primary"
            class="mb-4"
          />

          <v-card
            v-for="tpl in templates"
            :key="tpl.key"
            variant="outlined"
            class="mb-4 rounded-lg"
          >
            <v-card-text>
              <div class="text-subtitle-2 mb-2">
                {{ tpl.name }}
                <v-chip size="x-small" variant="tonal" class="ms-2">{{ tpl.key }}</v-chip>
              </div>
              <div class="text-caption text-medium-emphasis mb-2">{{ tpl.description }}</div>

              <v-text-field v-model="tpl.subject" :label="t('adminEmail.subject')"
                variant="outlined" density="compact" hide-details="auto" class="mb-3" />

              <v-textarea v-model="tpl.body_html" :label="t('adminEmail.htmlBody')"
                variant="outlined" density="compact" hide-details="auto"
                rows="8" class="font-mono" />

              <v-btn
                color="primary"
                variant="tonal"
                size="small"
                class="mt-2"
                :loading="savingTemplate === tpl.key"
                @click="saveTemplate(tpl)"
              >
                {{ t('adminEmail.saveTemplate') }}
              </v-btn>
            </v-card-text>
          </v-card>
        </v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>
  </v-container>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { api } from '@/api'
import {
  getSmtpConfig,
  updateSmtpConfig,
  testSmtpConfig,
  type SmtpConfig,
  type EmailTemplate,
} from '@/api/emailConfig'
import { createLatestRequestGuard } from '@/utils/latestRequest'

const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const router = useRouter()
const { notify } = useGlobalSnackbar()
const { t } = useI18n()
const goBack = () => router.back()

const templateLocale = ref<'zh-CN' | 'en-US' | 'ar'>('zh-CN')
const localeOptions = computed(() => [
  { value: 'zh-CN', label: t('adminEmail.locales.zh-CN') },
  { value: 'en-US', label: t('adminEmail.locales.en-US') },
  { value: 'ar', label: t('adminEmail.locales.ar') },
])

const smtp = reactive<SmtpConfig>({
  host: '', port: 587, username: '', use_tls: true, use_ssl: false,
  from_address: '', from_name: 'LiveCalc', enabled: false,
})
const passwordField = ref('')
const savingSmtp = ref(false)

const onSslChanged = (val: boolean) => {
  if (val) {
    smtp.use_tls = false
    if (smtp.port === 587 || smtp.port === 25) smtp.port = 465
  }
}

const onTlsChanged = (val: boolean) => {
  if (val) {
    smtp.use_ssl = false
    if (smtp.port === 465 || smtp.port === 25) smtp.port = 587
  }
}

const saveSmtp = async () => {
  savingSmtp.value = true
  try {
    const body: Record<string, any> = { ...smtp }
    if (passwordField.value) body.password = passwordField.value
    await updateSmtpConfig(body)
    notify(t('adminEmail.smtpSaved'), 'success')
  } catch (e: any) {
    notify(e?.userMessage || t('errors.unknown'), 'error')
  } finally {
    savingSmtp.value = false
  }
}

const testEmail = ref('')
const testing = ref(false)

const sendTest = async () => {
  if (!testEmail.value) return
  testing.value = true
  try {
    const res = await testSmtpConfig(testEmail.value)
    notify(res.message || t('adminEmail.testSent'), 'success')
  } catch (e: any) {
    notify(e?.userMessage || t('adminEmail.sendTestFailed'), 'error')
  } finally {
    testing.value = false
  }
}

const templates = ref<EmailTemplate[]>([])
const savingTemplate = ref('')
const runLatestTemplateRequest = createLatestRequestGuard()

const saveTemplate = async (tpl: EmailTemplate) => {
  savingTemplate.value = tpl.key
  try {
    await api.put(`/admin/email-config/templates/${tpl.key}`, {
      subject: tpl.subject,
      body_html: tpl.body_html,
    }, {
      params: { locale: templateLocale.value },
    })
    notify(t('adminEmail.templateSaved', { name: tpl.name }), 'success')
  } catch (e: any) {
    notify(e?.userMessage || t('errors.unknown'), 'error')
  } finally {
    savingTemplate.value = ''
  }
}

const loadAll = async () => {
  try {
    const config = await getSmtpConfig()
    Object.assign(smtp, config)
  } catch { /* ignore */ }
  await loadTemplates()
}

const loadTemplates = async () => {
  try {
    templates.value = await runLatestTemplateRequest(() =>
      api.get('/admin/email-config/templates', {
        params: { locale: templateLocale.value },
      })
    )
  } catch { /* ignore */ }
}

watch(templateLocale, () => {
  templates.value = []
  loadTemplates()
})

onMounted(() => { loadAll() })
</script>

<style scoped>
.font-mono :deep(textarea) {
  font-family: 'Courier New', monospace;
  font-size: 0.85rem;
}
</style>

<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('adminCompliance.title') }}</v-app-bar-title>
    <template #append>
      <v-btn icon="mdi-content-save" variant="text" :loading="saving" @click="save" />
      <v-btn icon="mdi-refresh" variant="text" @click="load" />
    </template>
  </v-app-bar>

  <v-container class="pa-4">
    <v-alert type="info" variant="tonal" density="comfortable" class="mb-4">
      {{ t('adminCompliance.hint') }}
    </v-alert>

    <!-- AI 服务：模型名称 + 备案号 -->
    <v-card class="mb-4">
      <v-card-title class="text-subtitle-1">{{ t('adminCompliance.aiTitle') }}</v-card-title>
      <v-card-subtitle class="pb-2">{{ t('adminCompliance.aiHint') }}</v-card-subtitle>
      <v-card-text>
        <v-table density="compact">
          <thead>
            <tr>
              <th style="width: 140px">{{ t('adminCompliance.providerKey') }}</th>
              <th style="width: 190px">{{ t('adminCompliance.displayName') }}</th>
              <th style="width: 200px">{{ t('adminCompliance.modelName') }}</th>
              <th style="width: 200px">{{ t('adminCompliance.filingNo') }}</th>
              <th>{{ t('adminCompliance.note') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(info, key) in aiProviders" :key="key">
              <td class="text-caption">{{ key }}</td>
              <td>
                <v-text-field v-model="info.display_name" density="compact" variant="outlined"
                  hide-details="auto" />
              </td>
              <td>
                <v-text-field v-model="info.model_name" density="compact" variant="outlined"
                  hide-details="auto" />
              </td>
              <td>
                <v-text-field v-model="info.filing_no" density="compact" variant="outlined"
                  hide-details="auto" :placeholder="t('adminCompliance.filingNoPlaceholder')" />
              </td>
              <td>
                <v-text-field v-model="info.note" density="compact" variant="outlined"
                  hide-details="auto" />
              </td>
            </tr>
          </tbody>
        </v-table>
      </v-card-text>
    </v-card>

    <!-- 地图服务：审图号 -->
    <v-card class="mb-4">
      <v-card-title class="text-subtitle-1">{{ t('adminCompliance.mapTitle') }}</v-card-title>
      <v-card-subtitle class="pb-2">{{ t('adminCompliance.mapHint') }}</v-card-subtitle>
      <v-card-text>
        <v-table density="compact">
          <thead>
            <tr>
              <th style="width: 140px">{{ t('adminCompliance.providerKey') }}</th>
              <th style="width: 190px">{{ t('adminCompliance.displayName') }}</th>
              <th style="width: 240px">{{ t('adminCompliance.approvalNo') }}</th>
              <th>{{ t('adminCompliance.note') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(info, key) in mapProviders" :key="key">
              <td class="text-caption">{{ key }}</td>
              <td>
                <v-text-field v-model="info.display_name" density="compact" variant="outlined"
                  hide-details="auto" />
              </td>
              <td>
                <v-text-field v-model="info.approval_no" density="compact" variant="outlined"
                  hide-details="auto" :placeholder="t('adminCompliance.approvalNoPlaceholder')" />
              </td>
              <td>
                <v-text-field v-model="info.note" density="compact" variant="outlined"
                  hide-details="auto" />
              </td>
            </tr>
          </tbody>
        </v-table>
      </v-card-text>
    </v-card>

    <!-- 法律文档 -->
    <v-card class="mb-4">
      <v-card-title class="text-subtitle-1">{{ t('adminCompliance.legalTitle') }}</v-card-title>
      <v-card-subtitle class="pb-2">{{ t('adminCompliance.legalHint') }}</v-card-subtitle>
      <v-card-text>
        <v-row dense>
          <v-col cols="12" sm="6">
            <v-text-field v-model="legal.contact_email" :label="t('adminCompliance.contactEmail')"
              variant="outlined" density="compact" hide-details="auto"
              :placeholder="t('adminCompliance.contactEmailPlaceholder')" />
          </v-col>
          <v-col cols="12" sm="6" class="d-flex align-center text-caption text-medium-emphasis">
            <span v-if="legal.updated_at">{{ t('adminCompliance.updatedAt') }}: {{ legal.updated_at }}</span>
          </v-col>
        </v-row>

        <v-expansion-panels multiple variant="accordion" class="mt-3">
          <v-expansion-panel :value="0">
            <v-expansion-panel-title>{{ t('adminCompliance.privacyZh') }}</v-expansion-panel-title>
            <v-expansion-panel-text>
              <v-textarea v-model="legal.privacy.zh" rows="14" variant="outlined" density="compact"
                hide-details auto-grow class="font-monospace" />
            </v-expansion-panel-text>
          </v-expansion-panel>
          <v-expansion-panel :value="1">
            <v-expansion-panel-title>{{ t('adminCompliance.privacyEn') }}</v-expansion-panel-title>
            <v-expansion-panel-text>
              <v-textarea v-model="legal.privacy.en" rows="14" variant="outlined" density="compact"
                hide-details auto-grow class="font-monospace" />
            </v-expansion-panel-text>
          </v-expansion-panel>
          <v-expansion-panel :value="2">
            <v-expansion-panel-title>{{ t('adminCompliance.termsZh') }}</v-expansion-panel-title>
            <v-expansion-panel-text>
              <v-textarea v-model="legal.terms.zh" rows="14" variant="outlined" density="compact"
                hide-details auto-grow class="font-monospace" />
            </v-expansion-panel-text>
          </v-expansion-panel>
          <v-expansion-panel :value="3">
            <v-expansion-panel-title>{{ t('adminCompliance.termsEn') }}</v-expansion-panel-title>
            <v-expansion-panel-text>
              <v-textarea v-model="legal.terms.en" rows="14" variant="outlined" density="compact"
                hide-details auto-grow class="font-monospace" />
            </v-expansion-panel-text>
          </v-expansion-panel>
        </v-expansion-panels>

        <div class="mt-3 text-caption text-medium-emphasis">
          {{ t('adminCompliance.publicUrls') }}:
          <a :href="privacyUrl" target="_blank" rel="noopener">{{ privacyUrl }}</a> ·
          <a :href="termsUrl" target="_blank" rel="noopener">{{ termsUrl }}</a>
          <div class="mt-1">{{ t('adminCompliance.publicUrlsHint') }}</div>
        </div>
      </v-card-text>
    </v-card>

    <!-- 生效预览 -->
    <v-card v-if="effective" variant="outlined">
      <v-card-title class="text-subtitle-1">{{ t('adminCompliance.effectiveTitle') }}</v-card-title>
      <v-card-text>
        <div class="mb-2 text-caption text-medium-emphasis">{{ t('adminCompliance.effectiveAi') }}</div>
        <div v-if="!effective.ai.providers.length" class="text-body-2">
          {{ t('adminCompliance.effectiveAiEmpty') }}
        </div>
        <v-chip v-for="p in effective.ai.providers" :key="p.key" class="me-2 mb-2" size="small">
          {{ p.display_name }}<span v-if="p.model_name"> · {{ p.model_name }}</span>
          <span v-if="p.filing_no"> · {{ p.filing_no }}</span>
        </v-chip>

        <div class="mt-3 mb-2 text-caption text-medium-emphasis">{{ t('adminCompliance.effectiveMap') }}</div>
        <v-chip v-for="p in effective.map.providers" :key="p.key" class="me-2 mb-2" size="small">
          {{ p.display_name }}<span v-if="p.approval_no"> · {{ p.approval_no }}</span>
        </v-chip>
      </v-card-text>
    </v-card>

    <div class="d-flex justify-end mt-4">
      <v-btn color="primary" :loading="saving" @click="save">{{ t('adminCompliance.save') }}</v-btn>
    </div>
  </v-container>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { api } from '@/api'

interface AiProviderInfo {
  display_name: string
  model_name: string
  filing_no: string
  note: string
}
interface MapProviderInfo {
  display_name: string
  approval_no: string
  note: string
}

const { t } = useI18n()
const router = useRouter()
const goBack = () => router.back()
const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const { notify } = useGlobalSnackbar()

const saving = ref(false)
// 公开法律页由后端根路径提供；VITE_API_URL 为绝对地址时据此推出后端根，
// 相对地址（/api/v1）时按同域代理处理。
const apiBase = import.meta.env.VITE_API_URL || '/api/v1'
const publicBase = apiBase.replace(/\/api\/v1\/?$/, '')
const privacyUrl = computed(() => `${publicBase}/legal/privacy`)
const termsUrl = computed(() => `${publicBase}/legal/terms`)
const aiProviders = reactive<Record<string, AiProviderInfo>>({})
const mapProviders = reactive<Record<string, MapProviderInfo>>({})
const legal = reactive({
  contact_email: '',
  updated_at: '',
  privacy: { zh: '', en: '' },
  terms: { zh: '', en: '' },
})
const effective = ref<any>(null)

function replaceRecord<T>(target: Record<string, T>, next: Record<string, T>) {
  Object.keys(target).forEach((k) => delete target[k])
  Object.entries(next || {}).forEach(([k, v]) => {
    target[k] = { ...(v as any) }
  })
}

const load = async () => {
  try {
    const data: any = await api.get('/admin/compliance')
    replaceRecord(aiProviders, data.ai?.providers || {})
    replaceRecord(mapProviders, data.map?.providers || {})
    legal.contact_email = data.legal?.contact_email || ''
    legal.updated_at = data.legal?.updated_at || ''
    legal.privacy.zh = data.legal?.privacy?.zh || ''
    legal.privacy.en = data.legal?.privacy?.en || ''
    legal.terms.zh = data.legal?.terms?.zh || ''
    legal.terms.en = data.legal?.terms?.en || ''
    effective.value = data.effective || null
  } catch (e: any) {
    notify(e?.message || t('adminCompliance.loadFailed'), 'error')
  }
}

const save = async () => {
  saving.value = true
  try {
    const data: any = await api.put('/admin/compliance', {
      ai: { providers: aiProviders },
      map: { providers: mapProviders },
      legal: {
        contact_email: legal.contact_email,
        privacy: { zh: legal.privacy.zh, en: legal.privacy.en },
        terms: { zh: legal.terms.zh, en: legal.terms.en },
      },
    })
    legal.updated_at = data.legal?.updated_at || legal.updated_at
    effective.value = data.effective || null
    notify(t('adminCompliance.saved'), 'success')
  } catch (e: any) {
    notify(e?.message || t('adminCompliance.saveFailed'), 'error')
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

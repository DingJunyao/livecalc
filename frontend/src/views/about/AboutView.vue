<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-app-bar-title class="text-h6">{{ t('profile.about') }}</v-app-bar-title>
  </v-app-bar>

  <v-container class="pa-4" max-width="900">
    <!-- 应用信息 -->
    <v-card class="mb-4" elevation="0">
      <v-card-text class="d-flex align-center ga-4">
        <v-avatar size="64" rounded="lg">
          <v-img src="/logo.svg" :alt="appInfo.name" cover />
        </v-avatar>
        <div class="flex-grow-1 min-w-0">
          <div class="text-h6 font-weight-bold">{{ appInfo.name }}</div>
          <div class="text-body-2 text-medium-emphasis">
            {{ t('profile.version', { version: appInfo.version }) }}
          </div>
          <div v-if="serverDisplay" class="text-caption text-medium-emphasis text-truncate">
            {{ t('about.server') }}: {{ serverDisplay }}
          </div>
        </div>
      </v-card-text>
      <v-divider />
      <v-list density="compact" class="bg-transparent">
        <v-list-item :href="appInfo.homepage" target="_blank" rel="noopener">
          <template #prepend><v-icon>mdi-github</v-icon></template>
          <v-list-item-title>{{ t('profile.projectHomepage') }}</v-list-item-title>
          <v-list-item-subtitle class="text-truncate">{{ appInfo.homepage }}</v-list-item-subtitle>
        </v-list-item>
        <v-list-item :href="appInfo.authorHomepage" target="_blank" rel="noopener">
          <template #prepend><v-icon>mdi-web</v-icon></template>
          <v-list-item-title>{{ t('profile.authorHomepage') }}</v-list-item-title>
          <v-list-item-subtitle class="text-truncate">{{ appInfo.authorHomepage }}</v-list-item-subtitle>
        </v-list-item>
      </v-list>
    </v-card>

    <v-alert v-if="isLocalMode" type="info" variant="tonal" density="comfortable" class="mb-4">
      {{ t('about.localModeHint') }}
    </v-alert>
    <v-alert v-else-if="loadFailed" type="warning" variant="tonal" density="comfortable" class="mb-4">
      {{ t('about.loadFailed') }}
    </v-alert>

    <!-- 法律文档 -->
    <v-card v-if="!isLocalMode" class="mb-4" elevation="0">
      <v-list density="compact">
        <v-list-subheader>{{ t('about.legalSection') }}</v-list-subheader>
        <v-list-item :href="privacyUrl" target="_blank" rel="noopener">
          <template #prepend><v-icon>mdi-shield-lock-outline</v-icon></template>
          <v-list-item-title>{{ t('about.privacyPolicy') }}</v-list-item-title>
          <template #append><v-icon icon="mdi-open-in-new" size="small" /></template>
        </v-list-item>
        <v-list-item :href="termsUrl" target="_blank" rel="noopener">
          <template #prepend><v-icon>mdi-file-document-outline</v-icon></template>
          <v-list-item-title>{{ t('about.termsOfService') }}</v-list-item-title>
          <template #append><v-icon icon="mdi-open-in-new" size="small" /></template>
        </v-list-item>
        <v-list-item v-if="contactEmail">
          <template #prepend><v-icon>mdi-email-outline</v-icon></template>
          <v-list-item-title>{{ t('about.contact') }}</v-list-item-title>
          <v-list-item-subtitle>{{ contactEmail }}</v-list-item-subtitle>
        </v-list-item>
        <v-list-item v-if="updatedAt">
          <template #prepend><v-icon>mdi-clock-outline</v-icon></template>
          <v-list-item-title>{{ t('about.updatedAt') }}</v-list-item-title>
          <v-list-item-subtitle>{{ updatedAt }}</v-list-item-subtitle>
        </v-list-item>
      </v-list>
    </v-card>

    <!-- AI 服务 -->
    <v-card v-if="!isLocalMode" class="mb-4" elevation="0">
      <v-card-title class="text-subtitle-1">{{ t('about.aiSection') }}</v-card-title>
      <v-card-text>
        <div v-if="!aiProviders.length" class="text-body-2 text-medium-emphasis">
          {{ t('about.aiDisabled') }}
        </div>
        <v-table v-else density="compact">
          <thead>
            <tr>
              <th>{{ t('about.provider') }}</th>
              <th>{{ t('about.model') }}</th>
              <th>{{ t('about.filingNo') }}</th>
              <th>{{ t('about.note') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in aiProviders" :key="p.key">
              <td>{{ p.display_name }}</td>
              <td>{{ p.model_name || '—' }}</td>
              <td>{{ p.filing_no || '—' }}</td>
              <td>{{ p.note || '' }}</td>
            </tr>
          </tbody>
        </v-table>
      </v-card-text>
    </v-card>

    <!-- 地图服务 -->
    <v-card v-if="!isLocalMode" elevation="0">
      <v-card-title class="text-subtitle-1">{{ t('about.mapSection') }}</v-card-title>
      <v-card-text>
        <div v-if="!mapProviders.length" class="text-body-2 text-medium-emphasis">
          {{ t('about.mapDisabled') }}
        </div>
        <v-table v-else density="compact">
          <thead>
            <tr>
              <th>{{ t('about.provider') }}</th>
              <th>{{ t('about.approvalNo') }}</th>
              <th>{{ t('about.note') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in mapProviders" :key="p.key">
              <td>{{ p.display_name }}</td>
              <td>{{ p.approval_no || '—' }}</td>
              <td>{{ p.note || '' }}</td>
            </tr>
          </tbody>
        </v-table>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useLocaleStore } from '@/stores/locale'
import { api } from '@/api'
import { appInfo } from '@/config/appInfo'
import { legalPageUrl } from '@/utils/publicUrl'

type AiProvider = {
  key: string
  display_name: string
  model_name?: string
  filing_no?: string
  note?: string
}
type MapProvider = {
  key: string
  display_name: string
  approval_no?: string
  note?: string
}

const { t } = useI18n()
const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const localeStore = useLocaleStore()
const isLocalMode = computed(() => import.meta.env.VITE_STORAGE_MODE === 'local')

const aiProviders = ref<AiProvider[]>([])
const mapProviders = ref<MapProvider[]>([])
const contactEmail = ref('')
const updatedAt = ref('')
const loadFailed = ref(false)

const serverDisplay = computed(() => import.meta.env.VITE_API_URL || '/api/v1')
const privacyUrl = computed(() => legalPageUrl('privacy', localeStore.locale || 'zh-CN'))
const termsUrl = computed(() => legalPageUrl('terms', localeStore.locale || 'zh-CN'))

const load = async () => {
  if (isLocalMode.value) return
  try {
    const config: any = await api.get('/app/config')
    aiProviders.value = config?.ai?.providers || []
    mapProviders.value = config?.map?.providers || []
    contactEmail.value = config?.legal?.contact_email || ''
    const stamp = config?.legal?.updated_at || ''
    updatedAt.value = stamp ? String(stamp).split('T')[0] : ''
  } catch {
    loadFailed.value = true
  }
}

onMounted(load)

</script>

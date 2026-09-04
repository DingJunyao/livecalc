<template>
  <!-- 顶部导航栏 - 移到 container 外面以便固定 -->
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-app-bar-title class="text-h6">{{ t('admin.dashboard.title') }}</v-app-bar-title>
    <template #append>
      <v-chip v-if="!isLocalMode" color="primary" variant="tonal" size="small">
        <v-icon start size="small">mdi-shield-account</v-icon>
        {{ t('admin.dashboard.administrator') }}
      </v-chip>
    </template>
  </v-app-bar>

  <v-container class="pa-4">
    <!-- 统计卡片 -->
    <v-row class="ma-2 mb-4">
      <v-col v-if="!isLocalMode" cols="12" sm="6" lg="3">
        <v-card
          elevation="0"
          class="user-stats-card"
          hover
          :to="'/admin/users'"
        >
          <v-card-text class="text-center pa-4">
            <v-avatar color="primary" variant="tonal" size="48" class="mb-2">
              <v-icon size="28">mdi-account-group</v-icon>
            </v-avatar>
            <div v-if="loading" class="text-h5 font-weight-bold text-primary">--</div>
            <div v-else class="text-h5 font-weight-bold text-primary">{{ formatCount(stats?.users || 0) }}</div>
            <div class="text-caption text-medium-emphasis mt-1">
              {{ t('admin.dashboard.totalUsers') }}
              <v-icon size="14" class="ms-1">mdi-arrow-right-thin</v-icon>
            </div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" sm="6" :lg="isLocalMode ? 4 : 3">
        <v-card elevation="0">
          <v-card-text class="text-center pa-4">
            <v-avatar color="success" variant="tonal" size="48" class="mb-2">
              <v-icon size="28">mdi-package-variant-closed</v-icon>
            </v-avatar>
            <div v-if="loading" class="text-h5 font-weight-bold text-success">--</div>
            <div v-else class="text-h5 font-weight-bold text-success">{{ formatCount(stats?.products || 0) }}</div>
            <div class="text-caption text-medium-emphasis mt-1">{{ t('admin.dashboard.products') }}</div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" sm="6" :lg="isLocalMode ? 4 : 3">
        <v-card elevation="0">
          <v-card-text class="text-center pa-4">
            <v-avatar color="warning" variant="tonal" size="48" class="mb-2">
              <v-icon size="28">mdi-book-open-variant</v-icon>
            </v-avatar>
            <div v-if="loading" class="text-h5 font-weight-bold text-warning">--</div>
            <div v-else class="text-h5 font-weight-bold text-warning">{{ formatCount(stats?.recipes || 0) }}</div>
            <div class="text-caption text-medium-emphasis mt-1">{{ t('admin.dashboard.recipes') }}</div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" sm="6" :lg="isLocalMode ? 4 : 3">
        <v-card elevation="0">
          <v-card-text class="text-center pa-4">
            <v-avatar color="info" variant="tonal" size="48" class="mb-2">
              <v-icon size="28">mdi-store</v-icon>
            </v-avatar>
            <div v-if="loading" class="text-h5 font-weight-bold text-info">--</div>
            <div v-else class="text-h5 font-weight-bold text-info">{{ formatCount(stats?.merchants || 0) }}</div>
            <div class="text-caption text-medium-emphasis mt-1">{{ t('admin.dashboard.merchants') }}</div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- 管理功能 -->
    <v-card class="ma-4" elevation="0">
      <v-list>
        <!-- 本地模式隐藏：无多用户功能 -->
        <v-list-item
          v-if="!isLocalMode"
          prepend-icon="mdi-clipboard-check-multiple"
          :title="t('admin.dashboard.proposalsTitle')"
          :subtitle="t('admin.dashboard.proposalsSubtitle')"
          to="/admin/proposals"
        >
          <template #append>
            <v-chip v-if="pendingProposalCount > 0" color="warning" size="small" class="me-1">
              {{ t('admin.dashboard.pendingCount', { count: formatCount(pendingProposalCount) }) }}
            </v-chip>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
          v-if="!isLocalMode"
          prepend-icon="mdi-account-cog"
          :title="t('admin.dashboard.usersTitle')"
          :subtitle="t('admin.dashboard.usersSubtitle')"
          to="/admin/users"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
          v-if="!isLocalMode"
          prepend-icon="mdi-ticket-outline"
          :title="t('admin.dashboard.inviteCodesTitle')"
          :subtitle="t('admin.dashboard.inviteCodesSubtitle')"
          to="/admin/invite-codes"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
          prepend-icon="mdi-shield-alert"
          :title="t('admin.dashboard.blacklistTitle')"
          :subtitle="t('admin.dashboard.blacklistSubtitle')"
          to="/admin/blacklist-groups"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
          prepend-icon="mdi-ruler"
          :title="t('admin.dashboard.unitsTitle')"
          :subtitle="t('admin.dashboard.unitsSubtitle')"
          to="/admin/units"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>
        <v-list-item
          prepend-icon="mdi-currency-usd"
          :title="t('admin.dashboard.currenciesTitle')"
          :subtitle="t('admin.dashboard.currenciesSubtitle')"
          to="/admin/currencies"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>
        <v-list-item
          prepend-icon="mdi-swap-horizontal"
          :title="t('admin.dashboard.exchangeRatesTitle')"
          :subtitle="t('admin.dashboard.exchangeRatesSubtitle')"
          to="/admin/exchange-rates"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
          prepend-icon="mdi-barcode-scan"
          :title="t('admin.dashboard.barcodeTitle')"
          :subtitle="t('admin.dashboard.barcodeSubtitle')"
          to="/admin/barcode-services"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
          prepend-icon="mdi-map-marker-path"
          :title="t('admin.dashboard.mapTitle')"
          :subtitle="t('admin.dashboard.mapSubtitle')"
          to="/admin/map-settings"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <!-- 本地模式隐藏：图片固定存 IndexedDB Blob -->
        <v-list-item
          v-if="!isLocalMode"
          prepend-icon="mdi-cloud-outline"
          :title="t('admin.dashboard.storageTitle')"
          :subtitle="t('admin.dashboard.storageSubtitle')"
          to="/admin/storage"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <!-- 本地模式隐藏：无需 SMTP 配置 -->
        <v-list-item
          v-if="!isLocalMode"
          prepend-icon="mdi-email-sync-outline"
          :title="t('admin.dashboard.emailTitle')"
          :subtitle="t('admin.dashboard.emailSubtitle')"
          to="/admin/email-config"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
          prepend-icon="mdi-robot"
          :title="t('admin.dashboard.aiTitle')"
          :subtitle="t('admin.dashboard.aiSubtitle')"
          to="/admin/ai-config"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <!-- 本地模式隐藏：无服务端图片扫描 -->
        <v-list-item
          v-if="!isLocalMode"
          prepend-icon="mdi-image-off-outline"
          :title="t('admin.dashboard.unusedImagesTitle')"
          :subtitle="t('admin.dashboard.unusedImagesSubtitle')"
          to="/admin/images-unused"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
          prepend-icon="mdi-database-cog"
          :title="t('admin.dashboard.dataTitle')"
          :subtitle="t('admin.dashboard.dataSubtitle')"
          to="/admin/data-maintenance"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>

        <v-list-item
        v-if="!isLocalMode"
        prepend-icon="mdi-robot-outline"
        :title="t('admin.dashboard.agentTitle')"
          :subtitle="t('admin.dashboard.agentSubtitle')"
          to="/admin/agent-console"
        >
          <template #append>
            <v-icon>mdi-chevron-right</v-icon>
          </template>
        </v-list-item>
      </v-list>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { api } from '@/api'
import { listProposals } from '@/api/proposals'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'

const isLocalMode = computed(() => import.meta.env.VITE_STORAGE_MODE === 'local')
const { t } = useI18n()
const localeStore = useLocaleStore()
const formatCount = (value: number) => formatNumber(value, localeStore.effectiveFormatLocale)

interface AdminStats {
  users: number
  products: number
  recipes: number
  merchants: number
}

const { isDesktop, toggleSidebar } = useMobileDrawerControl()

const stats = ref<AdminStats | null>(null)
const loading = ref(false)

const fetchStats = async () => {
  loading.value = true
  try {
    stats.value = await api.get('/admin/stats')
  } catch (error) {
    console.error('Failed to get statistics:', error)
  } finally {
    loading.value = false
  }
}

// 待审提议数（全表、管理员视角）——展示在「提议审核台」入口，提示有未处理提议
const pendingProposalCount = ref(0)
const loadPendingCount = async () => {
  try {
    const items = await listProposals('pending', 100)
    pendingProposalCount.value = items.length
  } catch {
    pendingProposalCount.value = 0
  }
}

onMounted(() => {
  fetchStats()
  loadPendingCount()
})
</script>

<style scoped>
.user-stats-card {
  cursor: pointer;
  transition: transform 0.15s ease;
}
.user-stats-card:hover {
  transform: translateY(-2px);
}
</style>

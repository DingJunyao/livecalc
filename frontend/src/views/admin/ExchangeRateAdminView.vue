<template>
  <v-container fluid>
    <v-card elevation="0">
      <v-card-title>汇率管理</v-card-title>
      <v-card-text>
        <v-alert type="info" variant="tonal" class="mb-4">
          最新快照：{{ status.latest || '暂无' }}（{{ status.source || '-' }}）
        </v-alert>
        <v-btn color="primary" :loading="loading" @click="onRefresh">立即刷新</v-btn>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ratesStatus, refreshRates } from '@/api/currencies'
const status = ref<{ latest: string | null; source: string | null }>({ latest: null, source: null })
const loading = ref(false)
onMounted(async () => { status.value = await ratesStatus() })
async function onRefresh() {
  loading.value = true
  try { await refreshRates(); status.value = await ratesStatus() } finally { loading.value = false }
}
</script>

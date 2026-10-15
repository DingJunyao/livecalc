<template>
  <!-- 移动端：列表项（对齐商家管理列表） -->
  <v-list-item v-if="mobile" :to="`/data/merchants/${item.id}`">
    <template #prepend>
      <v-avatar color="tertiary" size="40">
        <v-icon>mdi-store</v-icon>
      </v-avatar>
    </template>
    <v-list-item-title>
      {{ item.name }}
      <v-chip v-if="item.is_open === false" size="x-small" color="warning" variant="tonal" class="ms-1">{{ t('merchants.closed') }}</v-chip>
    </v-list-item-title>
    <v-list-item-subtitle>{{ item.address || t('merchants.noAddress') }}</v-list-item-subtitle>
    <template #append>
      <FavoriteButton :active="true" @toggle="$emit('unfavorite', item.id)" />
      <v-btn :icon="localeStore.isRtl ? 'mdi-chevron-left' : 'mdi-chevron-right'" size="small" variant="text" />
    </template>
  </v-list-item>

  <!-- 桌面端：卡片（对齐商家管理卡片网格） -->
  <v-card v-else elevation="0" class="list-grid-card cursor-pointer h-100" :to="`/data/merchants/${item.id}`">
    <v-card-text>
      <div class="d-flex align-center mb-2">
        <v-avatar color="tertiary" size="40" class="me-3"><v-icon>mdi-store</v-icon></v-avatar>
        <div class="text-body-2 font-weight-medium text-truncate">
          {{ item.name }}
          <v-chip v-if="item.is_open === false" size="x-small" color="warning" variant="tonal" class="ms-1">{{ t('merchants.closed') }}</v-chip>
        </div>
      </div>
      <div class="text-caption text-medium-emphasis mb-1 text-truncate">{{ item.address || t('merchants.noAddress') }}</div>
    </v-card-text>
    <v-divider />
    <v-card-actions>
      <v-spacer />
      <FavoriteButton :active="true" @toggle="$emit('unfavorite', item.id)" />
    </v-card-actions>
  </v-card>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import FavoriteButton from '@/components/common/FavoriteButton.vue'
import { useLocaleStore } from '@/stores/locale'

defineProps<{ item: any; mobile?: boolean }>()
defineEmits<{ (e: 'unfavorite', id: number): void }>()

const { t } = useI18n()
const localeStore = useLocaleStore()
</script>

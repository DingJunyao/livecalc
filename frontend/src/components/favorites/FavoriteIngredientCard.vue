<template>
  <!-- 移动端：列表项（对齐原料管理列表） -->
  <v-list-item v-if="mobile" :to="`/data/ingredients/${item.id}`">
    <template #prepend>
      <v-avatar color="secondary" size="40">
        <span class="text-white font-weight-bold">{{ item.name?.charAt(0) }}</span>
      </v-avatar>
    </template>
    <v-list-item-title>{{ item.name }}</v-list-item-title>
    <v-list-item-subtitle>
      <span>{{ item.category || t('ingredients.noCategory') }}</span>
      <span v-if="item.latest_price != null" class="text-tertiary font-weight-bold ms-2">
        {{ formatMoney(item.latest_price, userCurrency) }}<span v-if="item.latest_price_unit" class="text-caption font-weight-regular text-medium-emphasis"> / {{ item.latest_price_unit }}</span>
      </span>
    </v-list-item-subtitle>
    <template #append>
      <div
        v-if="item.sparkline_data"
        style="width: 64px; height: 36px; position: relative; flex-shrink: 0; margin-inline-end: 4px"
      >
        <SparklineBackground :data="item.sparkline_data" color="secondary" height="36" />
      </div>
      <FavoriteButton :active="true" @toggle="$emit('unfavorite', item.id)" />
      <v-btn :icon="localeStore.isRtl ? 'mdi-chevron-left' : 'mdi-chevron-right'" size="small" variant="text" />
    </template>
  </v-list-item>

  <!-- 桌面端：卡片（对齐原料管理卡片网格） -->
  <v-card v-else elevation="0" class="list-grid-card h-100" :to="`/data/ingredients/${item.id}`" hover>
    <SparklineBackground
      v-if="item.sparkline_data"
      :data="item.sparkline_data"
      color="secondary"
    />
    <v-card-text style="position: relative; z-index: 1">
      <div class="d-flex align-center mb-2">
        <v-avatar color="secondary" size="40" class="me-3">
          <span class="text-white font-weight-bold">{{ item.name?.charAt(0) }}</span>
        </v-avatar>
        <div class="text-body-2 font-weight-medium text-truncate">{{ item.name }}</div>
      </div>
      <v-chip size="x-small" color="default" variant="outlined">
        {{ item.category || t('ingredients.noCategory') }}
      </v-chip>
      <div v-if="item.latest_price != null" class="text-subtitle-1 font-weight-bold text-tertiary mb-1">
        {{ formatMoney(item.latest_price, userCurrency) }}<span v-if="item.latest_price_unit" class="text-caption font-weight-regular text-medium-emphasis"> / {{ item.latest_price_unit }}</span>
      </div>
    </v-card-text>
    <v-divider />
    <v-card-actions style="position: relative; z-index: 1">
      <v-spacer />
      <FavoriteButton :active="true" @toggle="$emit('unfavorite', item.id)" />
    </v-card-actions>
  </v-card>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import SparklineBackground from '@/components/charts/SparklineBackground.vue'
import FavoriteButton from '@/components/common/FavoriteButton.vue'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { useLocaleStore } from '@/stores/locale'
import { formatMoney } from '@/utils/currency'

defineProps<{ item: any; mobile?: boolean }>()
defineEmits<{ (e: 'unfavorite', id: number): void }>()

const { t } = useI18n()
const { currency: userCurrency } = useUserCurrency()
const localeStore = useLocaleStore()
</script>

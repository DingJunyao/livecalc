<template>
  <!-- 菜谱卡片（对齐菜谱管理卡片）：图片/占位 + 名称 + 成本·热量 -->
  <v-card
    elevation="0"
    class="list-grid-card h-100 cursor-pointer"
    @click="$router.push(`/recipes/${item.id}`)"
    hover
  >
    <v-img v-if="imageUrl" :src="imageUrl" height="140" cover />
    <div
      v-else
      class="d-flex align-center justify-center"
      style="height: 140px; background: rgb(var(--v-theme-primary-container))"
    >
      <v-icon size="64" color="primary">mdi-food</v-icon>
    </div>

    <div class="text-center pa-2 text-subtitle-1">
      {{ item.name }}
      <v-chip v-if="item.is_public === false" size="x-small" color="warning" variant="tonal" class="ms-1">{{ t('recipes.unpublished') }}</v-chip>
      <FavoriteButton :active="true" size="x-small" class="ms-1" @toggle="$emit('unfavorite', item.id)" />
    </div>

    <v-card-text class="text-center pa-2">
      <div class="d-flex justify-center align-center ga-2 text-body-2">
        <span class="font-weight-bold text-tertiary">{{ costText }}</span>
        <span class="text-caption text-medium-emphasis">·</span>
        <span class="text-caption text-medium-emphasis">{{ caloriesText }}</span>
      </div>
    </v-card-text>
  </v-card>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import FavoriteButton from '@/components/common/FavoriteButton.vue'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { useUserUnits } from '@/composables/useUserUnits'
import { useLocaleStore } from '@/stores/locale'
import { formatMoney } from '@/utils/currency'
import { formatNumber } from '@/utils/format'
import { resolveImageUrl } from '@/utils/image'

const props = defineProps<{ item: any; cost?: number | null; calories?: number | null }>()
defineEmits<{ (e: 'unfavorite', id: number): void }>()

const { t } = useI18n()
const { currency: userCurrency } = useUserCurrency()
const { energyUnit, toDisplayCalorie } = useUserUnits()
const localeStore = useLocaleStore()

const imageUrl = computed(() => {
  const first = props.item?.image_urls?.[0]
  return first ? resolveImageUrl(first) : undefined
})

const costText = computed(() => {
  if (props.cost == null) return '--'
  const servings = props.item?.servings || 1
  return t('recipes.costPerServings', {
    amount: formatMoney(Number(props.cost), userCurrency.value),
    count: formatNumber(servings, localeStore.effectiveFormatLocale),
  })
})

const caloriesText = computed(() => {
  if (props.calories == null) return '-'
  const servings = props.item?.servings || 1
  const perServing = Math.round(Number(props.calories) / servings)
  return t('recipes.caloriesPerServing', {
    amount: formatNumber(Number(toDisplayCalorie(perServing)), localeStore.effectiveFormatLocale),
    unit: energyUnit.value,
  })
})
</script>

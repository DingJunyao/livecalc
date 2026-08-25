<template>
  <span class="price-with-convert">
    <span class="price-native">{{ formatMoney(price, currency) }}</span>
    <span v-if="converted != null" class="price-converted text-caption text-medium-emphasis">
      ≈ {{ formatMoney(converted, userCurrency) }}
    </span>
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { formatMoney, convertAmount } from '@/utils/currency'
import { useUserCurrency } from '@/composables/useUserCurrency'

const props = defineProps<{
  price: number
  currency: string
  exchangeRate?: number | null
}>()
const { currency: userCurrency } = useUserCurrency()
const converted = computed(() => {
  if (!props.exchangeRate || props.currency === userCurrency.value) return null
  return convertAmount(props.price, props.exchangeRate)
})
</script>

<style scoped>
.price-with-convert { display: inline-flex; align-items: baseline; gap: 6px; }
</style>
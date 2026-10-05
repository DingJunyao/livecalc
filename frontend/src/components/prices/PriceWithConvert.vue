<template>
  <span class="price-with-convert">
    <span class="price-native">{{ formatMoney(numericPrice, currency) }}</span>
    <span v-if="converted != null" class="price-converted text-caption text-medium-emphasis">
      ≈ {{ formatMoney(converted, userCurrency) }}
    </span>
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { formatMoney, convertAmount } from '@/utils/currency'
import { useUserCurrency } from '@/composables/useUserCurrency'

// 后端 Pydantic v2 会把 Decimal 序列化为字符串（如 "8.98"），此处统一归一化为 number
const props = defineProps<{
  price: number | string
  currency: string
  exchangeRate?: number | string | null
}>()
const { currency: userCurrency } = useUserCurrency()
const numericPrice = computed(() => Number(props.price))
const numericExchangeRate = computed(() =>
  props.exchangeRate == null ? null : Number(props.exchangeRate),
)
const converted = computed(() => {
  const rate = numericExchangeRate.value
  if (!rate || props.currency === userCurrency.value) return null
  return convertAmount(numericPrice.value, rate)
})
</script>

<style scoped>
.price-with-convert { display: inline-flex; align-items: baseline; gap: 6px; }
</style>
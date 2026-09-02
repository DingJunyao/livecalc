<template>
  <div class="mb-4">
    <div class="d-flex align-center mb-3">
      <v-icon start color="info">mdi-store-outline</v-icon>
      <span class="text-h6 font-weight-regular">{{ t('recipes.merchantCostEstimates') }}</span>
    </div>

    <div v-if="loading" class="d-flex ga-3">
      <v-skeleton-loader v-for="i in 3" :key="i" type="card" class="flex-1-1" max-width="240" />
    </div>
    <div v-else-if="!merchantList.length" class="text-center py-6 text-medium-emphasis">
      <v-icon size="40" color="medium-emphasis">mdi-store-off</v-icon>
      <div class="text-body-2 mt-2">{{ t('recipes.noMerchantPriceData') }}</div>
    </div>
    <div v-else class="merchant-cards">
      <v-card
        v-for="m in merchantList"
        :key="m.merchant_id"
        :class="['merchant-card', { 'merchant-card-recommended': m.is_recommended }]"
        elevation="0"
        variant="outlined"
      >
        <v-card-text>
          <div class="d-flex align-center mb-1">
            <span class="text-body-1 font-weight-medium text-truncate">{{ m.merchant_name }}</span>
            <v-spacer />
            <v-chip v-if="m.is_recommended" size="x-small" color="orange-darken-2" variant="flat" class="font-weight-bold text-white">
              {{ t('recipes.bestValue') }}
            </v-chip>
          </div>
          <div class="text-caption text-medium-emphasis mb-2">
            {{ t('recipes.coveredIngredients', {
              covered: formatNumber(m.covered_count, localeStore.effectiveFormatLocale),
              total: formatNumber(m.total_ingredients, localeStore.effectiveFormatLocale),
            }) }}
            <v-tooltip v-if="m.fallback_chains?.length" location="top">
              <template #activator="{ props }">
                <v-icon v-bind="props" size="x-small" color="info" class="ms-1">mdi-information</v-icon>
              </template>
              <div class="text-caption">{{ t('recipes.calculatedFromIngredients') }}</div>
              <div v-for="chain in m.fallback_chains" :key="chain" class="text-body-2 font-weight-bold">{{ chain }}</div>
            </v-tooltip>
          </div>
          <div class="text-h5 font-weight-bold mb-1">
            {{ formatMoney(Number(m.total_cost || 0), userCurrency) }}
          </div>
          <div class="text-caption mb-1">
            <span class="text-green-darken-2">{{ t('recipes.inStore', { amount: formatMoney(Number(m.covered_cost || 0), userCurrency) }) }}</span>
            <span v-if="Number(m.external_cost || 0) > 0" class="ms-2 text-orange-darken-2">
              {{ t('recipes.external', { amount: formatMoney(Number(m.external_cost || 0), userCurrency) }) }}
            </span>
          </div>
          <div v-if="m.missing_ingredients?.length" class="text-caption text-warning">
            <v-icon size="12" color="warning">mdi-alert-circle-outline</v-icon>
            {{ t('recipes.missingIngredients', { ingredients: formatIngredientList(m.missing_ingredients) }) }}
          </div>
        </v-card-text>
      </v-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { formatMoney } from '@/utils/currency'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  merchantCosts?: { merchants?: any[] } | null
  loading?: boolean
}>()

const { currency: userCurrency } = useUserCurrency()
const { t } = useI18n()
const localeStore = useLocaleStore()

const merchantList = computed(() => {
  return props.merchantCosts?.merchants || []
})

function formatIngredientList(ingredients: string[]) {
  return new Intl.ListFormat(localeStore.effectiveFormatLocale, {
    type: 'conjunction',
  }).format(ingredients)
}
</script>

<style scoped>
.merchant-cards {
  display: flex;
  gap: 12px;
  overflow-x: auto;
  padding-bottom: 4px;
}
.merchant-card {
  min-width: 180px;
  max-width: 240px;
  flex: 1;
}
.merchant-card-recommended {
  border-color: #ff9800 !important;
  border-width: 2px !important;
  background: #fff8e1;
}
</style>

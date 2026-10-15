<template>
  <div class="d-flex align-center flex-wrap ga-2">
    <span class="text-caption text-medium-emphasis">{{ t('products.nutritionBasis') }}</span>
    <v-text-field
      :model-value="amountModel"
      type="number"
      min="0"
      step="any"
      variant="outlined"
      density="compact"
      hide-details
      :aria-label="t('products.nutritionBasis')"
      class="nutrition-basis-amount text-end"
      @update:model-value="onAmountInput"
    />
    <v-select
      :model-value="unitModel"
      :items="optionsWithCurrent"
      variant="outlined"
      density="compact"
      hide-details
      :aria-label="t('products.nutritionBasisUnit')"
      class="nutrition-basis-unit"
      @update:model-value="onUnitInput"
    />
    <span class="text-caption text-medium-emphasis">{{ t('products.nutritionBasisHint') }}</span>
  </div>
</template>

<script setup lang="ts">
// 营养基准（「每 X 单位」）：数据录入按包装标签写，避免用户心算折成 100 g。
// 单位候选由调用方加载（含本实体可折算的自定义单位）；这里只负责取值与回显。
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  formatBasisAmount,
  normalizeBasisAmount,
  normalizeBasisUnit,
  withCurrentBasisUnit,
  type BasisUnitOption,
} from '@/utils/nutritionBasis'

const props = withDefaults(
  defineProps<{
    amount: number
    unit: string
    options: BasisUnitOption[]
  }>(),
  { options: () => [] },
)

const emit = defineEmits<{
  (e: 'update:amount', value: number): void
  (e: 'update:unit', value: string): void
}>()

const { t } = useI18n()

const amountModel = computed(() => formatBasisAmount(props.amount))
const unitModel = computed(() => normalizeBasisUnit(props.unit))
// 后端返回的基准单位可能已不在候选里（单位被删/改名），仍要能原样回显
const optionsWithCurrent = computed(() => withCurrentBasisUnit(props.options, unitModel.value))

function onAmountInput(value: unknown) {
  // 输入过程中允许留空（v-text-field 会给空串）：先按默认值提交，失焦后再显示
  emit('update:amount', normalizeBasisAmount(value))
}

function onUnitInput(value: unknown) {
  const unit = String(value ?? '').trim()
  if (!unit) return
  emit('update:unit', unit)
}
</script>

<style scoped>
.nutrition-basis-amount {
  max-width: 110px;
}

.nutrition-basis-unit {
  max-width: 200px;
}
</style>

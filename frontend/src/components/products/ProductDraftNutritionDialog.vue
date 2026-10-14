<template>
  <v-dialog :model-value="modelValue" max-width="600" @update:model-value="onToggle">
    <v-card>
      <v-card-title class="d-flex align-center pa-4">
        <span class="text-h6">{{ t('products.draftNutritionDialogTitle') }}</span>
        <span class="text-caption text-medium-emphasis ms-2">{{ t('products.per100g') }}</span>
        <v-spacer />
        <v-btn
          icon="mdi-close"
          variant="text"
          size="small"
          :aria-label="t('common.close')"
          @click="close"
        />
      </v-card-title>
      <v-card-text>
        <div class="text-caption text-medium-emphasis mb-3">
          {{ t('products.draftSavedTogether') }}
        </div>
        <div v-if="rows.length === 0" class="text-body-2 text-medium-emphasis">
          {{ t('products.noNutritionData') }}
        </div>
        <div v-for="(row, index) in rows" :key="index" class="d-flex align-center ga-2 mb-2">
          <v-combobox
            v-model="row.name"
            :items="defs"
            item-title="label"
            item-value="label"
            :placeholder="t('products.chooseNutrient')"
            variant="outlined"
            density="compact"
            hide-details
            class="flex-grow-1"
            @update:model-value="(value: any) => onNutrientChange(index, value)"
          />
          <v-text-field
            v-model.number="row.value"
            type="number"
            variant="outlined"
            density="compact"
            hide-details
            placeholder="0"
            style="max-width: 110px"
          />
          <v-select
            v-model="row.unit"
            :items="row.units"
            variant="outlined"
            density="compact"
            hide-details
            style="max-width: 100px"
          />
          <v-btn
            icon="mdi-delete"
            size="x-small"
            variant="text"
            color="error"
            :aria-label="t('products.deleteNutrient')"
            @click="removeRow(index)"
          />
        </div>
        <v-btn
          size="small"
          variant="tonal"
          color="primary"
          prepend-icon="mdi-plus"
          class="mt-2"
          @click="addRow"
        >
          {{ t('products.addNutrient') }}
        </v-btn>
      </v-card-text>
      <v-card-actions class="pa-4 pt-0">
        <v-spacer />
        <v-btn color="primary" variant="text" @click="close">{{ t('common.close') }}</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { buildNutrientDefinitions } from '@/composables/nutrientDefinitions'
import { useUserUnits } from '@/composables/useUserUnits'
import type { ProductDraftNutrient } from '@/utils/productDraftPlan'

// 新增商品对话框里的「营养信息」草稿编辑器：只维护本地数组，
// 商品保存成功后再由 productDrafts.persistProductDrafts 一次性写入。
const props = defineProps<{
  modelValue: boolean
  nutrients: ProductDraftNutrient[]
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'update:nutrients', value: ProductDraftNutrient[]): void
}>()

const { t } = useI18n()
const { energyUnit } = useUserUnits()

interface DraftRow {
  key: string
  name: string
  value: number | null
  unit: string
  units: string[]
}

const rows = ref<DraftRow[]>([])

const defs = computed(() => buildNutrientDefinitions(energyUnit.value))

const DEFAULT_UNITS = ['g', 'mg', 'μg', 'kcal', 'kJ', 'IU']

function toRow(nutrient: ProductDraftNutrient): DraftRow {
  const def = defs.value.find(item => item.key === nutrient.key || item.label === nutrient.name)
  return {
    key: nutrient.key,
    name: nutrient.name,
    value: nutrient.value,
    unit: nutrient.unit || def?.defaultUnit || 'g',
    units: def ? [...def.units] : [...DEFAULT_UNITS],
  }
}

function emitRows() {
  emit('update:nutrients', rows.value.map(row => ({
    key: row.key,
    name: row.name,
    value: row.value,
    unit: row.unit,
  })))
}

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return
    rows.value = (props.nutrients || []).map(toRow)
    if (rows.value.length === 0) addRow()
  },
)

function onToggle(value: boolean) {
  emit('update:modelValue', value)
}

function close() {
  emitRows()
  emit('update:modelValue', false)
}

function addRow() {
  rows.value.push({ key: '', name: '', value: null, unit: 'g', units: [...DEFAULT_UNITS] })
  emitRows()
}

function removeRow(index: number) {
  rows.value.splice(index, 1)
  emitRows()
}

function onNutrientChange(index: number, value: any) {
  const row = rows.value[index]
  if (!row) return
  const text = typeof value === 'string' ? value : value?.label ?? ''
  const def = defs.value.find(item => item.label === text || item.key === text)
  if (def) {
    row.key = def.key
    row.name = def.label
    row.unit = def.defaultUnit
    row.units = [...def.units]
  } else {
    // 自定义营养素：只按名称写入，键盘单位保持可编辑
    row.key = ''
    row.name = text
    if (!row.units.includes(row.unit)) row.units = [row.unit || 'g', ...DEFAULT_UNITS]
  }
  emitRows()
}
</script>

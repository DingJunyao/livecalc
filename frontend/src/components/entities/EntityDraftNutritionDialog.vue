<template>
  <v-dialog :model-value="modelValue" max-width="600" @update:model-value="onToggle">
    <v-card>
      <v-card-title class="d-flex align-center pa-4">
        <span class="text-h6">{{ t('products.draftNutritionDialogTitle', { target }) }}</span>
        <span class="text-caption text-medium-emphasis ms-2">{{ basisLabel }}</span>
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
          {{ t('products.draftSavedTogether', { target }) }}
        </div>
        <div class="mb-3">
          <NutritionBasisField
            v-model:amount="basisAmount"
            v-model:unit="basisUnit"
            :options="basisOptions"
          />
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
import { buildNutrientDefinitions, orderNutrientDefsDefaultsFirst } from '@/composables/nutrientDefinitions'
import { useUserUnits } from '@/composables/useUserUnits'
import type { EntityDraftNutrient } from '@/utils/entityDraftPlan'
import NutritionBasisField from '@/components/nutrition/NutritionBasisField.vue'
import { loadNutritionBasisUnitOptions } from '@/utils/entityUnits'
import {
  buildDefaultNutrientRows,
  formatBasisAmount,
  normalizeBasisUnit,
  type BasisUnitOption,
} from '@/utils/nutritionBasis'

// 新增商品/原料对话框里的「营养信息」草稿编辑器：只维护本地数组，
// 实体保存成功后再由 entityDrafts.persistEntityDrafts 一次性写入。
const props = defineProps<{
  modelValue: boolean
  nutrients: EntityDraftNutrient[]
  /** 实体名（商品/原料），只用于文案 */
  target: string
  /** 营养基准（「每 X 单位」）：草稿态由父组件持有，实体创建后一并落库 */
  amount: number
  unit: string
  /** 商品草稿：已选中的关联原料 id（其可折算的自定义单位可作基准单位） */
  ingredientId?: number | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'update:nutrients', value: EntityDraftNutrient[]): void
  (e: 'update:amount', value: number): void
  (e: 'update:unit', value: string): void
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

// 营养素下拉：默认七项置顶，其余按定义表顺序
const defs = computed(() =>
  orderNutrientDefsDefaultsFirst(buildNutrientDefinitions(energyUnit.value)),
)

// 基准单位候选：草稿态实体还没有 id，商品草稿可借已选关联原料的自定义单位
const basisOptions = ref<BasisUnitOption[]>([])
const basisAmount = computed({
  get: () => props.amount,
  set: value => emit('update:amount', value),
})
const basisUnit = computed({
  get: () => props.unit,
  set: value => emit('update:unit', value),
})
const basisLabel = computed(() =>
  t('products.perBasis', {
    amount: formatBasisAmount(props.amount),
    unit: normalizeBasisUnit(props.unit),
  }),
)

const loadBasisOptions = async () => {
  try {
    basisOptions.value = await loadNutritionBasisUnitOptions(
      'product',
      null,
      props.ingredientId ?? null,
    )
  } catch {
    basisOptions.value = []
  }
}

const DEFAULT_UNITS = ['g', 'mg', 'μg', 'kcal', 'kJ', 'IU']

function toRow(nutrient: EntityDraftNutrient): DraftRow {
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
    if (rows.value.length === 0) {
      // 首次打开：预填营养成分表常见五项（能量 kJ / 蛋白质 / 脂肪 / 碳水化合物 /
      // 钠 mg）。全部留空时不会落库任何营养数据（见 persistEntityDrafts 的过滤）。
      rows.value = buildDefaultNutrientRows(defs.value).map(row => ({ ...row }))
      emitRows()
    }
    void loadBasisOptions()
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

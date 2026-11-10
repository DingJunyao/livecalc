// composables/nutrientDefinitions.ts
// 营养素定义公共模块（DRY）：从 ProductDetail/IngredientDetail 抽离。
// 能量行的 defaultUnit 由 buildNutrientDefinitions 参数化，跟随用户能量单位偏好；
// 除宏量营养素（蛋白质/脂肪/饱和脂肪/反式脂肪/碳水/糖/膳食纤维，默认 g）外，
// 其余营养素默认单位统一为 mg（单位候选里 mg 也排在最前）。

export interface NutrientDef {
  key: string
  label: string
  units: string[]
  defaultUnit: string
}

// 基础定义（defaultUnit 在 buildNutrientDefinitions 中填充）
const BASE_DEFS: Omit<NutrientDef, 'defaultUnit'>[] = [
  { key: 'energy', label: 'nutrients.energy', units: ['kcal', 'kJ'] },
  { key: 'protein', label: 'nutrients.protein', units: ['g', 'mg'] },
  { key: 'fat', label: 'nutrients.fat', units: ['g', 'mg'] },
  { key: 'carbohydrate', label: 'nutrients.carbohydrate', units: ['g', 'mg'] },
  { key: 'fiber', label: 'nutrients.fiber', units: ['g'] },
  { key: 'calcium', label: 'nutrients.calcium', units: ['mg', 'μg', 'g'] },
  { key: 'iron', label: 'nutrients.iron', units: ['mg', 'μg'] },
  { key: 'sodium', label: 'nutrients.sodium', units: ['mg', 'g'] },
  { key: 'potassium', label: 'nutrients.potassium', units: ['mg', 'g'] },
  { key: 'vitamin_a_rae', label: 'nutrients.vitaminA', units: ['mg', 'μg', 'IU'] },
  { key: 'vitamin_c', label: 'nutrients.vitaminC', units: ['mg', 'g'] },
  { key: 'vitamin_b1', label: 'nutrients.vitaminB1', units: ['mg', 'μg'] },
  { key: 'vitamin_b2', label: 'nutrients.vitaminB2', units: ['mg', 'μg'] },
  { key: 'vitamin_b12', label: 'nutrients.vitaminB12', units: ['mg', 'μg'] },
  { key: 'vitamin_d', label: 'nutrients.vitaminD', units: ['mg', 'μg', 'IU'] },
  { key: 'vitamin_e', label: 'nutrients.vitaminE', units: ['mg', 'IU'] },
  { key: 'vitamin_k', label: 'nutrients.vitaminK', units: ['mg', 'μg'] },
  { key: 'magnesium', label: 'nutrients.magnesium', units: ['mg', 'g'] },
  { key: 'zinc', label: 'nutrients.zinc', units: ['mg', 'μg'] },
  { key: 'selenium', label: 'nutrients.selenium', units: ['mg', 'μg'] },
  { key: 'cholesterol', label: 'nutrients.cholesterol', units: ['mg', 'g'] },
  { key: 'saturated_fat', label: 'nutrients.saturatedFat', units: ['g', 'mg'] },
  { key: 'sugar', label: 'nutrients.sugar', units: ['g', 'mg'] },
  { key: 'trans_fat', label: 'nutrients.transFat', units: ['g', 'mg'] },
  { key: 'folate', label: 'nutrients.folate', units: ['mg', 'μg'] },
  { key: 'phosphorus', label: 'nutrients.phosphorus', units: ['mg', 'g'] },
  { key: 'copper', label: 'nutrients.copper', units: ['mg', 'μg'] },
  { key: 'manganese', label: 'nutrients.manganese', units: ['mg', 'μg'] },
  { key: 'vitamin_b6', label: 'nutrients.vitaminB6', units: ['mg', 'μg'] },
  { key: 'pantothenic_acid', label: 'nutrients.vitaminB5', units: ['mg'] },
  { key: 'monounsaturated_fat', label: 'nutrients.monounsaturatedFat', units: ['mg', 'g'] },
  { key: 'polyunsaturated_fat', label: 'nutrients.polyunsaturatedFat', units: ['mg', 'g'] },
]

/** 默认单位保持克的营养素（含常见英文别名）；其余非能量营养素默认 mg。 */
const GRAM_DEFAULT_KEYS = new Set([
  'protein',
  'fat', 'total_fat',
  'carbohydrate', 'carbs',
  'fiber', 'dietary_fiber',
  'saturated', 'saturated_fat',
  'trans', 'trans_fat', 'fatty_acids_total_trans',
  'sugar', 'sugars', 'total_sugars',
])

/**
 * 营养素默认单位：能量随用户偏好（kcal | kJ），宏量营养素（蛋白质/脂肪/
 * 饱和脂肪/反式脂肪/碳水/糖/膳食纤维）为 g，其余统一 mg。
 * 供静态定义表与动态（USDA 扩展键）定义共用，保证两端口径一致。
 */
export function defaultUnitForNutrientKey(
  key: string,
  energyUnit: 'kcal' | 'kJ' = 'kcal',
): string {
  if (key === 'energy') return energyUnit
  return GRAM_DEFAULT_KEYS.has(key) ? 'g' : 'mg'
}

export function buildNutrientDefinitions(energyUnit: 'kcal' | 'kJ' = 'kcal'): NutrientDef[] {
  return BASE_DEFS.map(d => ({
    ...d,
    label: t(d.label),
    defaultUnit: defaultUnitForNutrientKey(d.key, energyUnit),
  }))
}

import { t } from '@/plugins/i18n'
import { DEFAULT_NUTRIENT_KEYS } from '@/utils/nutritionBasis'

/**
 * 行内营养素下拉的顺序：默认七项（DEFAULT_NUTRIENT_KEYS，即新建预填项）
 * 始终排在最前，其余按定义表顺序。定义表里没有的默认键静默跳过。
 */
export function orderNutrientDefsDefaultsFirst<T extends { key: string }>(defs: T[]): T[] {
  const byKey = new Map(defs.map(def => [def.key, def]))
  const head: T[] = []
  for (const key of DEFAULT_NUTRIENT_KEYS) {
    const def = byKey.get(key)
    if (def) {
      head.push(def)
      byKey.delete(key)
    }
  }
  return [...head, ...byKey.values()]
}

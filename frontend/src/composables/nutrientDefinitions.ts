// composables/nutrientDefinitions.ts
// 营养素定义公共模块（DRY）：从 ProductDetail/IngredientDetail 抽离。
// 能量行的 defaultUnit 由 buildNutrientDefinitions 参数化，跟随用户能量单位偏好；
// 其它营养素保持各自习惯单位（蛋白质 g、钙 mg、硒 μg…）。

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
  { key: 'vitamin_a_rae', label: 'nutrients.vitaminA', units: ['μg', 'IU', 'mg'] },
  { key: 'vitamin_c', label: 'nutrients.vitaminC', units: ['mg', 'g'] },
  { key: 'vitamin_b1', label: 'nutrients.vitaminB1', units: ['mg', 'μg'] },
  { key: 'vitamin_b2', label: 'nutrients.vitaminB2', units: ['mg', 'μg'] },
  { key: 'vitamin_b12', label: 'nutrients.vitaminB12', units: ['μg', 'mg'] },
  { key: 'vitamin_d', label: 'nutrients.vitaminD', units: ['μg', 'IU'] },
  { key: 'vitamin_e', label: 'nutrients.vitaminE', units: ['mg', 'IU'] },
  { key: 'vitamin_k', label: 'nutrients.vitaminK', units: ['μg', 'mg'] },
  { key: 'magnesium', label: 'nutrients.magnesium', units: ['mg', 'g'] },
  { key: 'zinc', label: 'nutrients.zinc', units: ['mg', 'μg'] },
  { key: 'selenium', label: 'nutrients.selenium', units: ['μg', 'mg'] },
  { key: 'cholesterol', label: 'nutrients.cholesterol', units: ['mg', 'g'] },
  { key: 'saturated_fat', label: 'nutrients.saturatedFat', units: ['g', 'mg'] },
  { key: 'folate', label: 'nutrients.folate', units: ['μg', 'mg'] },
  { key: 'phosphorus', label: 'nutrients.phosphorus', units: ['mg', 'g'] },
  { key: 'copper', label: 'nutrients.copper', units: ['mg', 'μg'] },
  { key: 'manganese', label: 'nutrients.manganese', units: ['mg', 'μg'] },
  { key: 'vitamin_b6', label: 'nutrients.vitaminB6', units: ['mg', 'μg'] },
  { key: 'pantothenic_acid', label: 'nutrients.vitaminB5', units: ['mg'] },
  { key: 'monounsaturated_fat', label: 'nutrients.monounsaturatedFat', units: ['g', 'mg'] },
  { key: 'polyunsaturated_fat', label: 'nutrients.polyunsaturatedFat', units: ['g', 'mg'] },
]

const DEFAULT_UNIT_BY_KEY: Record<string, string> = {
  energy: 'kcal',
  protein: 'g', fat: 'g', carbohydrate: 'g', fiber: 'g',
  calcium: 'mg', iron: 'mg', sodium: 'mg', potassium: 'mg',
  vitamin_a_rae: 'μg', vitamin_c: 'mg', vitamin_b1: 'mg', vitamin_b2: 'mg',
  vitamin_b12: 'μg', vitamin_d: 'μg', vitamin_e: 'mg', vitamin_k: 'μg',
  magnesium: 'mg', zinc: 'mg', selenium: 'μg', cholesterol: 'mg',
  saturated_fat: 'g', folate: 'μg', phosphorus: 'mg', copper: 'mg',
  manganese: 'mg', vitamin_b6: 'mg', pantothenic_acid: 'mg',
  monounsaturated_fat: 'g', polyunsaturated_fat: 'g',
}

export function buildNutrientDefinitions(energyUnit: 'kcal' | 'kJ' = 'kcal'): NutrientDef[] {
  return BASE_DEFS.map(d => ({
    ...d,
    label: t(d.label),
    defaultUnit: d.key === 'energy' ? energyUnit : DEFAULT_UNIT_BY_KEY[d.key],
  }))
}
import { t } from '@/plugins/i18n'

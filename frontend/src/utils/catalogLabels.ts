import type { Unit } from '@/types'
import { t } from '@/plugins/i18n'

const UNIT_KEYS: Record<string, string> = {
  m: 'units.meter', kg: 'units.kilogram', g: 'units.gram',
  L: 'units.liter', mL: 'units.milliliter', s: 'units.second',
  斤: 'units.jin', 两: 'units.liang', lb: 'units.pound', oz: 'units.ounce',
  cup: 'units.cup', tbsp: 'units.tablespoon', tsp: 'units.teaspoon',
  'fl oz': 'units.fluidOunce', cm: 'units.centimeter', mm: 'units.millimeter',
  in: 'units.inch', 个: 'units.piece', 只: 'units.pieceClass',
  条: 'units.strip', 片: 'units.slice',
}

const CATEGORY_KEYS: Record<string, string> = {
  grains: 'ingredientCategories.grains',
  vegetables: 'ingredientCategories.vegetables',
  fruits: 'ingredientCategories.fruits',
  meat: 'ingredientCategories.meat',
  seafood: 'ingredientCategories.seafood',
  eggs: 'ingredientCategories.eggs',
  dairy: 'ingredientCategories.dairy',
  soy: 'ingredientCategories.soy',
  seasoning: 'ingredientCategories.seasoning',
  oil: 'ingredientCategories.oil',
  nuts: 'ingredientCategories.nuts',
  beverages: 'ingredientCategories.beverages',
  others: 'ingredientCategories.others',
}

export function unitDisplayName(unit: Pick<Unit, 'name' | 'abbreviation'>): string {
  const key = UNIT_KEYS[unit.abbreviation]
  return key ? t(key) : unit.name
}

export function categoryDisplayName(category: {
  name: string
  display_name?: string | null
}): string {
  const key = CATEGORY_KEYS[category.name]
  return key ? t(key) : (category.display_name || category.name)
}

export function usdaDescription(
  food: {
    description: string
    description_zh?: string | null
    description_ar?: string | null
  },
  locale: string,
): string {
  if (locale === 'zh-CN') return food.description_zh || food.description
  if (locale === 'ar') return food.description_ar || food.description
  return food.description
}

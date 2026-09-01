import {
  ENERGY_NAMES,
  KJ_UNITS,
  NUTRIENT_NAME_MAP,
} from '../../../data/nutritionAggregatorAliases.ts'

export interface NutritionRecord {
  id?: number
  ingredient_id: number
  nutrient_name: string
  amount_per_100g: number
  unit: string
  source?: string
  is_verified?: boolean
}

export interface NutritionItem {
  nutrient_name: string
  amount: number
  amount_per_100g: number
  unit: string
  nrv_pct?: number
}

export interface AggregationInput {
  ingredient_id: number
  quantity_g: number
  nutrition_data: NutritionRecord[]
}

export interface AggregationInputMulti {
  items: AggregationInput[]
}

/** Scale per-100g nutrition values to the actual quantity. */
export function aggregateIngredient(input: AggregationInput): NutritionItem[] {
  const { quantity_g, nutrition_data } = input
  const factor = quantity_g / 100

  return nutrition_data.map(n => ({
    nutrient_name: n.nutrient_name,
    amount: n.amount_per_100g * factor,
    amount_per_100g: n.amount_per_100g,
    unit: n.unit,
    nrv_pct: calcNRV(n.nutrient_name, n.amount_per_100g),
  }))
}

/** Aggregate ingredients and merge nutrients by name. */
// Energy units that should be converted from kJ to kcal (1 kcal = 4.184 kJ)

export function aggregateIngredients(input: AggregationInputMulti): NutritionItem[] {
  const merged = new Map<string, { amount: number; unit: string }>()

  for (const item of input.items) {
    const factor = item.quantity_g / 100
    for (const n of item.nutrition_data) {
      // Normalize energy: USDA data may store it as kJ; convert to kcal
      // (1 kcal = 4.184 kJ) to match the cloud backend and avoid ~4x inflation.
      const isEnergy = ENERGY_NAMES.has(n.nutrient_name)
      let unitVal = n.unit || ''
      let amountVal = n.amount_per_100g
      if (isEnergy && KJ_UNITS.has(unitVal.toLowerCase())) {
        amountVal = amountVal * 0.239006
        unitVal = 'kcal'
      }
      const existing = merged.get(n.nutrient_name)
      if (existing) {
        existing.amount += amountVal * factor
      } else {
        merged.set(n.nutrient_name, {
          amount: amountVal * factor,
          unit: unitVal,
        })
      }
    }
  }

  const totalQuantityG = input.items.reduce((s, i) => s + i.quantity_g, 0)

  return Array.from(merged.entries()).map(([name, data]) => ({
    nutrient_name: name,
    amount: Math.round(data.amount * 100) / 100,
    amount_per_100g: totalQuantityG > 0 ? Math.round((data.amount / totalQuantityG) * 100 * 100) / 100 : 0,
    unit: data.unit,
    nrv_pct: totalQuantityG > 0 ? calcNRV(name, (data.amount / totalQuantityG) * 100) : undefined,
  }))
}

/** 中文营养素名 → 英文 NRV 键名映射 */
/** China NRV reference values from GB 28050-2011, keyed by nutrient. */
const NRV_TABLE: Record<string, number> = {
  energy: 8400, // kJ
  protein: 60,           // g
  fat: 60,               // g
  carbohydrate: 300,     // g
  dietary_fiber: 25,     // g
  sodium: 2000,          // mg
  vitamin_a: 800,        // µg RE
  vitamin_d: 5,          // µg
  vitamin_e: 14, // mg alpha-TE
  vitamin_k: 80,         // µg
  vitamin_c: 100,        // mg
  thiamin: 1.4,          // mg (B1)
  riboflavin: 1.4,       // mg (B2)
  niacin: 14,            // mg (B3)
  vitamin_b6: 1.4,       // mg
  vitamin_b12: 2.4,      // µg
  folate: 400,           // µg DFE
  pantothenic_acid: 5,   // mg (B5)
  biotin: 30,            // µg (B7)
  calcium: 800,          // mg
  phosphorus: 700,       // mg
  potassium: 2000,       // mg
  magnesium: 300,        // mg
  iron: 12,              // mg
  zinc: 12,              // mg
  iodine: 150,           // µg
  selenium: 60,          // µg
  copper: 1.5,           // mg
  fluoride: 1,           // mg
  manganese: 4.5,        // mg
  chromium: 50,          // µg
  molybdenum: 60,        // µg
  cholesterol: 300,      // mg
}

/** Calculate China NRV percentage. */
export function calcNRV(nutrientName: string, amountPer100g: number): number | undefined {
  if (amountPer100g == null || amountPer100g === 0) return undefined

  // Match the stored Chinese nutrient names first.
  const mappedKey = NUTRIENT_NAME_MAP[nutrientName]
  if (mappedKey) {
    const nrv = NRV_TABLE[mappedKey]
    if (nrv && nrv > 0) return Math.round((amountPer100g / nrv) * 100 * 10) / 10
  }

  // Otherwise normalize the nutrient name and retry.
  const key = nutrientName
    .toLowerCase()
    .replace(/[^a-z\u3400-\u9fff]/g, '_')
    .replace(/_{2,}/g, '_')
    .replace(/^_|_$/g, '')

  const nrv = NRV_TABLE[key]
  if (nrv == null || nrv === 0) return undefined

  return Math.round((amountPer100g / nrv) * 100 * 10) / 10
}

/** Convert kcal to kJ. */
export function kcalToKj(kcal: number): number {
  return kcal * 4.184
}

/** Convert kJ to kcal. */
export function kjToKcal(kj: number): number {
  return kj / 4.184
}

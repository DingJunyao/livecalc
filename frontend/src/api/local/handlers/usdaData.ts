import { NUTRIENT_TRANSLATIONS } from '../../../data/usdaNutrientTranslations.ts'

// Build a case-insensitive lookup index matching the backend parser.
const _LOWER_INDEX: Map<string, string> = new Map(
  Object.entries(NUTRIENT_TRANSLATIONS).map(([k, v]) => [k.toLowerCase(), v])
)

/** Map a USDA nutrient name to its stored Chinese name. */
export function mapNutrientName(nameEn: string): string | null {
  if (!nameEn) return null
  return _LOWER_INDEX.get(nameEn.trim().toLowerCase()) ?? null
}

const _TYPE_PRIORITY: Record<string, number> = { foundation: 0, sr_legacy: 1 }

export interface ParsedNutrient {
  nutrient_no: string | null
  name: string
  name_zh: string | null
  amount: number
  unit_name: string
}

export interface ParsedFood {
  fdc_id: number | null
  data_type: string
  description: string
  publication_date: string | null
  nutrients: ParsedNutrient[]
}

/**
 * Parse one raw USDA food into the internal structure. New and legacy USDA
 * layouts are both accepted.
 */
export function parseUsdaFood(raw: any, dataType: string): ParsedFood {
  if (raw == null) {
    return { fdc_id: 0, data_type: dataType, description: '', publication_date: null, nutrients: [] }
  }
  const nutrients: ParsedNutrient[] = []
  const foodNutrients: any[] = raw.foodNutrients || raw.foodComponents || []
  for (const fn of foodNutrients) {
    if (typeof fn !== "object" || fn === null) continue
    const nutrient = fn.nutrient || fn
    if (typeof nutrient !== "object" || nutrient === null) continue
    const name: string | undefined = nutrient.name
    if (!name) continue
    const nutrientNo = nutrient.number
    nutrients.push({
      nutrient_no: nutrientNo != null ? String(nutrientNo) : null,
      name,
      name_zh: mapNutrientName(name),
      amount: Number(fn.amount ?? 0) || 0,
      unit_name: fn.unitName || nutrient.unitName || '',
    })
  }
  return {
    fdc_id: raw.fdcId ?? null,
    data_type: dataType,
    description: (raw.description || '').trim(),
    publication_date: raw.publicationDate ?? null,
    nutrients,
  }
}

function foodSortKey(food: ParsedFood): [number, number] {
  return [_TYPE_PRIORITY[food.data_type] ?? 99, -food.nutrients.length]
}

/** Keep the best record for each description. */
export function dedupeFoods(foods: ParsedFood[]): ParsedFood[] {
  const best = new Map<string, ParsedFood>()
  for (const food of foods) {
    const desc = food.description
    if (!desc) continue
    const cur = best.get(desc)
    if (!cur || cmp(foodSortKey(food), foodSortKey(cur)) < 0) {
      best.set(desc, food)
    }
  }
  return [...best.values()]
}

function cmp(a: [number, number], b: [number, number]): number {
  if (a[0] !== b[0]) return a[0] - b[0]
  return a[1] - b[1]
}

/** Parse a raw USDA export and return deduplicated foods. */
export function parseUsdaDataset(data: any): ParsedFood[] {
  const keyMap: Record<string, string> = { FoundationFoods: 'foundation', SRLegacyFoods: 'sr_legacy' }
  const foods: ParsedFood[] = []
  if (Array.isArray(data)) {
    for (const r of data) {
      if (r != null) foods.push(parseUsdaFood(r, 'foundation'))
    }
  } else if (data && typeof data === "object") {
    for (const key of Object.keys(keyMap)) {
      const arr = data[key]
      if (Array.isArray(arr)) {
        const dtype = keyMap[key]
        for (const r of arr) {
          if (r != null) foods.push(parseUsdaFood(r, dtype))
        }
      }
    }
  }
  return dedupeFoods(foods)
}

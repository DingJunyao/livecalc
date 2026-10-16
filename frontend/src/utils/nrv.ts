/** 营养素参考值（NRV）——与后端 `app/services/nutrition_reference.py` 同口径。
 *
 * 来源：GB 28050-2011《食品安全国家标准 预包装食品营养标签通则》成人每日推荐摄入量。
 * 本地模式（纯前端）没有后端算 NRV%，用这里的常量补上，保证两端展示一致。
 */
export const NRV_REFERENCE_VALUES: Record<string, number> = {
  energy: 2000,
  protein: 60,
  fat: 60,
  carbohydrate: 300,
  fiber: 25,
  calcium: 800,
  iron: 15,
  sodium: 2000,
  potassium: 2000,
  vitamin_a_rae: 800,
  vitamin_c: 100,
  vitamin_b1: 1.2,
  vitamin_b2: 1.4,
  vitamin_b12: 2.4,
  vitamin_d: 5,
  vitamin_e: 14,
  vitamin_k: 80,
}

export const NUTRIENT_UNIT_BY_KEY: Record<string, string> = {
  energy: 'kcal',
  protein: 'g',
  fat: 'g',
  carbohydrate: 'g',
  fiber: 'g',
  calcium: 'mg',
  iron: 'mg',
  sodium: 'mg',
  potassium: 'mg',
  vitamin_a_rae: '\u03bcg',
  vitamin_c: 'mg',
  vitamin_b1: 'mg',
  vitamin_b2: 'mg',
  vitamin_b12: '\u03bcg',
  vitamin_d: '\u03bcg',
  vitamin_e: 'mg',
  vitamin_k: '\u03bcg',
}

/** NRV 百分比 = 数值 / 标准值 × 100；没有标准值的营养素返回 null */
export function nrvPct(key: string, value: number | null | undefined): number | null {
  const reference = NRV_REFERENCE_VALUES[key]
  if (!reference || value == null || !Number.isFinite(Number(value))) return null
  return Math.round((Number(value) / reference) * 100 * 100) / 100
}

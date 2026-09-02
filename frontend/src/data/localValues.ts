// Stored local-mode values and aliases. They are data keys, not UI copy.
export const CHINESE_GRAM_NAME = '克'
export const CHINESE_JIN_NAME = '斤'
export const CHINESE_LIANG_NAME = '两'
export const CHINESE_PIECE_NAME = '个'

export const VAGUE_QUANTITY_GRAM_MAP: Record<string, number> = {
  '适量': 100,
  '少许': 5,
}

export const QUANTITY_TYPE_KEYS: Record<string, string> = {
  '适量': 'quantityTypes.toTaste',
  '少许': 'quantityTypes.smallAmount',
}

export const VAGUE_QUANTITY_VALUES = Object.keys(VAGUE_QUANTITY_GRAM_MAP)

export const ENERGY_NUTRIENT_NAMES = ['能量', '热量'] as const
export const CANONICAL_ENERGY_NAME = '能量'

export const BASIC_NUTRIENT_NAMES = [
  '能量',
  '热量',
  '蛋白质',
  '脂肪',
  '碳水化合物',
  '钠',
] as const

export const DEFAULT_NUTRIENT_NAMES = [
  '能量',
  '蛋白质',
  '脂肪',
  '碳水化合物',
  '钠',
  '膳食纤维',
  '钙',
  '铁',
  '钾',
  '维生素A',
  '维生素B1',
  '维生素B2',
  '维生素B12',
  '维生素C',
  '维生素D',
  '维生素E',
  '维生素K',
] as const

export const RECIPE_CORE_NUTRIENT_NAMES = [
  '能量',
  '蛋白质',
  '脂肪',
  '碳水化合物',
  '膳食纤维',
  '钠',
  '钙',
  '铁',
  '钾',
  '维生素A',
  '维生素C',
  '维生素B1',
  '维生素B2',
  '维生素B12',
  '维生素D',
  '维生素E',
  '维生素K',
] as const

export const NO_STANDARD_VALUES = ['无标准', '无标准值'] as const
export const ENERGY_UNIT_ALIASES = ['千卡', '千焦'] as const
export const CHINESE_MASS_UNITS = ['斤', '两'] as const
export const CURRENCY_PREFIX = '元'

export const CORE_NUTRIENT_KEYS = [
  '能量',
  '蛋白质',
  '脂肪',
  '碳水化合物',
  '钠',
] as const

export const CHART_UNIT_FACTORS_TO_GRAMS: Record<string, number> = {
  g: 1,
  kg: 1000,
  斤: 500,
  两: 50,
  mg: 0.001,
  oz: 28.3495,
  lb: 453.592,
  mL: 1,
  ml: 1,
  L: 1000,
}

export const COMMON_SI_FACTORS_TO_KILOGRAMS: Record<string, number> = {
  kg: 1,
  g: 0.001,
  [CHINESE_JIN_NAME]: 0.5,
  [CHINESE_LIANG_NAME]: 0.05,
  '磅': 0.453592,
}

export const LOCAL_UNIT_ALIASES: Record<string, { preferredName: string; fallbackId: number }> = {
  g: { preferredName: CHINESE_GRAM_NAME, fallbackId: 2 },
  ml: { preferredName: 'mL', fallbackId: 5 },
  l: { preferredName: '升', fallbackId: 4 },
  kg: { preferredName: '千克', fallbackId: 1 },
  '片': { preferredName: CHINESE_GRAM_NAME, fallbackId: 2 },
  '根': { preferredName: CHINESE_PIECE_NAME, fallbackId: 6 },
  '瓣': { preferredName: CHINESE_PIECE_NAME, fallbackId: 6 },
  '颗': { preferredName: CHINESE_PIECE_NAME, fallbackId: 6 },
  '只': { preferredName: CHINESE_PIECE_NAME, fallbackId: 6 },
}

export const LOCAL_UNIT_TRANSLATION_KEYS: Record<string, string> = {
  斤: 'prices.units.jin',
  两: 'prices.units.liang',
  个: 'prices.units.piece',
  包: 'prices.units.package',
  袋: 'prices.units.bag',
  盒: 'prices.units.box',
  瓶: 'prices.units.bottle',
  罐: 'prices.units.can',
}

export const LOCAL_UNIT_VALUES = [
  'g',
  'kg',
  '斤',
  '两',
  'ml',
  'L',
  '个',
  '包',
  '袋',
  '盒',
  '瓶',
  '罐',
] as const

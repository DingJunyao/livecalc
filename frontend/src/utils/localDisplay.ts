import { t } from '../plugins/i18n.ts'
import {
  CHINESE_GRAM_NAME,
  CHINESE_JIN_NAME,
  CHINESE_LIANG_NAME,
  CHINESE_PIECE_NAME,
} from '../data/localValues.ts'

const UNIT_LABEL_KEYS: Record<string, string> = {
  [CHINESE_JIN_NAME]: 'prices.units.jin',
  [CHINESE_LIANG_NAME]: 'prices.units.liang',
  [CHINESE_PIECE_NAME]: 'prices.units.piece',
  [CHINESE_GRAM_NAME]: 'prices.units.gram',
  'kg': 'prices.units.kilogram',
  'g': 'prices.units.gram',
  'mL': 'prices.units.milliliter',
  'L': 'prices.units.liter',
  '\u5347': 'prices.units.liter',
  '\u6beb\u5347': 'prices.units.milliliter',
  '\u76d2': 'prices.units.box',
  '\u5305': 'prices.units.package',
  '\u888b': 'prices.units.bag',
  '\u74f6': 'prices.units.bottle',
  '\u7f50': 'prices.units.can',
}

export function localUserNickname(): string {
  return t('localValues.userNickname')
}

export function adminBackgroundMarker(): string {
  return '[\u540e\u53f0]'
}

export function unknownIngredientName(): string {
  return t('localValues.unknownIngredientName')
}

export function pendingReviewMarker(): string {
  return '\u5f85\u7ba1\u7406\u5458\u5ba1\u6838'
}

export function proposalMarker(): string {
  return '\u63d0\u8bae'
}

export function newNameSuffix(): string {
  return t('localValues.newNameSuffix')
}

export function canonicalMassUnitName(): string {
  return CHINESE_JIN_NAME
}

export function canonicalPriceUnitName(): string {
  return CHINESE_JIN_NAME
}

export function localizedUnitLabel(value: string): string {
  const key = UNIT_LABEL_KEYS[value]
  return key ? t(key) : value
}

export function localizedMassUnitLabel(value: string = canonicalMassUnitName()): string {
  return localizedUnitLabel(value)
}

export function localizedPriceUnitLabel(value: string = canonicalPriceUnitName()): string {
  return localizedUnitLabel(value)
}

export function fallbackPriceUnitValues(): string[] {
  return [
    CHINESE_JIN_NAME,
    CHINESE_PIECE_NAME,
    'kg',
    CHINESE_GRAM_NAME,
    '\u5347',
    '\u6beb\u5347',
    '\u76d2',
    '\u5305',
    '\u888b',
    '\u74f6',
  ]
}

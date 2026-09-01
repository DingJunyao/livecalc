import { t } from '@/plugins/i18n'

/**
 * Stable nutrient keys are shared by recipe, nutrition, USDA, product, and
 * ingredient surfaces. English source keys and common stored Chinese aliases
 * normalize to these catalog keys before display.
 */
export const NUTRIENT_KEYS: Record<string, string> = {
  energy_kcal: 'nutrients.energy', energy: 'nutrients.energy',
  calorie: 'nutrients.energy', calories: 'nutrients.energy',
  protein: 'nutrients.protein',
  total_fat: 'nutrients.fat', fat: 'nutrients.fat',
  carbohydrate: 'nutrients.carbohydrate', carbs: 'nutrients.carbohydrate',
  fiber: 'nutrients.fiber', dietary_fiber: 'nutrients.fiber',
  sugar: 'nutrients.sugars', total_sugars: 'nutrients.sugars',
  starch: 'nutrients.starch', water: 'nutrients.water',
  alcohol: 'nutrients.alcohol', alcohol_ethyl: 'nutrients.alcohol',
  ash: 'nutrients.ash',
  saturated: 'nutrients.saturatedFat', saturated_fat: 'nutrients.saturatedFat',
  monounsaturated: 'nutrients.monounsaturatedFat', monounsaturated_fat: 'nutrients.monounsaturatedFat',
  polyunsaturated: 'nutrients.polyunsaturatedFat', polyunsaturated_fat: 'nutrients.polyunsaturatedFat',
  trans: 'nutrients.transFat', trans_fat: 'nutrients.transFat', fatty_acids_total_trans: 'nutrients.transFat',
  cholesterol: 'nutrients.cholesterol',
  'sfa_4:0': 'nutrients.butyricAcid', 'sfa_6:0': 'nutrients.caproicAcid',
  'sfa_8:0': 'nutrients.caprylicAcid', 'sfa_10:0': 'nutrients.capricAcid',
  'sfa_12:0': 'nutrients.lauricAcid', 'sfa_14:0': 'nutrients.myristicAcid',
  'sfa_16:0': 'nutrients.palmiticAcid', 'sfa_18:0': 'nutrients.stearicAcid',
  'mufa_14:1': 'nutrients.myristoleicAcid', 'mufa_15:1': 'nutrients.pentadecenoicAcid',
  'mufa_16:1': 'nutrients.palmitoleicAcid', 'mufa_17:1': 'nutrients.heptadecenoicAcid',
  'mufa_18:1': 'nutrients.oleicAcid', 'mufa_20:1': 'nutrients.gondoicAcid',
  'mufa_22:1': 'nutrients.erucicAcid', 'mufa_24:1': 'nutrients.nervonicAcid',
  'pufa_18:2': 'nutrients.linoleicAcid', 'pufa_18:3': 'nutrients.linolenicAcid',
  'pufa_18:4': 'nutrients.stearidonicAcid', 'pufa_20:2': 'nutrients.eicosadienoicAcid',
  'pufa_20:3': 'nutrients.meadAcid', 'pufa_20:4': 'nutrients.arachidonicAcid',
  'pufa_20:5_n_3_epa': 'nutrients.epa', 'pufa_20:5_n_3_(epa)': 'nutrients.epa',
  'pufa_22:5_n_3_dpa': 'nutrients.dpa', 'pufa_22:5_n_3_(dpa)': 'nutrients.dpa',
  'pufa_22:6_n_3_dha': 'nutrients.dha', 'pufa_22:6_n_3_(dha)': 'nutrients.dha',
  vitamin_a: 'nutrients.vitaminA', vitamin_a_rae: 'nutrients.vitaminA',
  vitamin_a_iu: 'nutrients.vitaminA', retinol: 'nutrients.retinol',
  vitamin_c: 'nutrients.vitaminC', vitamin_d: 'nutrients.vitaminD',
  vitamin_e: 'nutrients.vitaminE', vitamin_k: 'nutrients.vitaminK',
  thiamin: 'nutrients.vitaminB1', vitamin_b1: 'nutrients.vitaminB1',
  riboflavin: 'nutrients.vitaminB2', vitamin_b2: 'nutrients.vitaminB2',
  niacin: 'nutrients.niacin', vitamin_b3: 'nutrients.niacin',
  pantothenic_acid: 'nutrients.vitaminB5', vitamin_b5: 'nutrients.vitaminB5',
  b6: 'nutrients.vitaminB6', vitamin_b6: 'nutrients.vitaminB6',
  b12: 'nutrients.vitaminB12', vitamin_b12: 'nutrients.vitaminB12',
  folate: 'nutrients.folate', folate_food: 'nutrients.folate',
  folate_dfe: 'nutrients.folate', folic_acid: 'nutrients.folate',
  biotin: 'nutrients.biotin', choline: 'nutrients.choline', choline_total: 'nutrients.choline',
  betaine: 'nutrients.betaine', vitamin_e_added: 'nutrients.vitaminEAdded',
  vitamin_b_12_added: 'nutrients.vitaminB12Added',
  carotene_beta: 'nutrients.betaCarotene', carotene_alpha: 'nutrients.alphaCarotene',
  cryptoxanthin_beta: 'nutrients.betaCryptoxanthin',
  calcium: 'nutrients.calcium', iron: 'nutrients.iron', magnesium: 'nutrients.magnesium',
  phosphorus: 'nutrients.phosphorus', potassium: 'nutrients.potassium',
  sodium: 'nutrients.sodium', zinc: 'nutrients.zinc', copper: 'nutrients.copper',
  manganese: 'nutrients.manganese', selenium: 'nutrients.selenium',
  iodine: 'nutrients.iodine', chromium: 'nutrients.chromium',
  molybdenum_mo: 'nutrients.molybdenum', molybdenum: 'nutrients.molybdenum',
  fluoride_f: 'nutrients.fluoride', fluoride: 'nutrients.fluoride',
  tryptophan: 'nutrients.tryptophan', threonine: 'nutrients.threonine',
  isoleucine: 'nutrients.isoleucine', leucine: 'nutrients.leucine',
  lysine: 'nutrients.lysine', methionine: 'nutrients.methionine',
  phenylalanine: 'nutrients.phenylalanine', tyrosine: 'nutrients.tyrosine',
  valine: 'nutrients.valine', arginine: 'nutrients.arginine',
  histidine: 'nutrients.histidine', alanine: 'nutrients.alanine',
  aspartic_acid: 'nutrients.asparticAcid', glutamic_acid: 'nutrients.glutamicAcid',
  glycine: 'nutrients.glycine', proline: 'nutrients.proline', serine: 'nutrients.serine',
  caffeine: 'nutrients.caffeine', theobromine: 'nutrients.theobromine',
  lutein_plus_zeaxanthin: 'nutrients.luteinAndZeaxanthin',
  'lutein_+_zeaxanthin': 'nutrients.luteinAndZeaxanthin', lutein: 'nutrients.lutein',
  zeaxanthin: 'nutrients.zeaxanthin', lycopene: 'nutrients.lycopene',
  beta_glucan: 'nutrients.betaGlucan', glutathione: 'nutrients.glutathione',
  nitrogen: 'nutrients.nitrogen',
}

const CHINESE_ALIASES: Record<string, string> = {
  '能量': 'nutrients.energy', '热量': 'nutrients.energy',
  '蛋白质': 'nutrients.protein', '脂肪': 'nutrients.fat',
  '碳水化合物': 'nutrients.carbohydrate', '膳食纤维': 'nutrients.fiber',
  '糖': 'nutrients.sugars', '总糖': 'nutrients.sugars', '淀粉': 'nutrients.starch',
  '水分': 'nutrients.water', '酒精': 'nutrients.alcohol', '灰分': 'nutrients.ash',
  '饱和脂肪': 'nutrients.saturatedFat', '饱和脂肪酸': 'nutrients.saturatedFat',
  '单不饱和脂肪': 'nutrients.monounsaturatedFat', '单不饱和脂肪酸': 'nutrients.monounsaturatedFat',
  '多不饱和脂肪': 'nutrients.polyunsaturatedFat', '多不饱和脂肪酸': 'nutrients.polyunsaturatedFat',
  '反式脂肪': 'nutrients.transFat', '反式脂肪酸': 'nutrients.transFat',
  '胆固醇': 'nutrients.cholesterol', '维生素A': 'nutrients.vitaminA',
  '维生素C': 'nutrients.vitaminC', '维生素D': 'nutrients.vitaminD',
  '维生素E': 'nutrients.vitaminE', '维生素K': 'nutrients.vitaminK',
  '维生素B1': 'nutrients.vitaminB1', '维生素B2': 'nutrients.vitaminB2',
  '维生素B3（烟酸）': 'nutrients.niacin', '维生素B5（泛酸）': 'nutrients.vitaminB5',
  '维生素B6': 'nutrients.vitaminB6', '维生素B12': 'nutrients.vitaminB12',
  '叶酸': 'nutrients.folate', '烟酸': 'nutrients.niacin', '泛酸': 'nutrients.vitaminB5',
  '生物素': 'nutrients.biotin', '胆碱': 'nutrients.choline', '甜菜碱': 'nutrients.betaine',
  '钙': 'nutrients.calcium', '铁': 'nutrients.iron', '镁': 'nutrients.magnesium',
  '磷': 'nutrients.phosphorus', '钾': 'nutrients.potassium', '钠': 'nutrients.sodium',
  '锌': 'nutrients.zinc', '铜': 'nutrients.copper', '锰': 'nutrients.manganese',
  '硒': 'nutrients.selenium', '碘': 'nutrients.iodine', '铬': 'nutrients.chromium',
  '钼': 'nutrients.molybdenum', '氟': 'nutrients.fluoride',
}

export function nutrientKey(name: string): string | null {
  return NUTRIENT_KEYS[name] ?? CHINESE_ALIASES[name] ?? null
}

export function nutrientLabel(name: string): string {
  const key = nutrientKey(name)
  return key ? t(key) : name
}

const NUTRIENT_UNIT_KEYS: Record<string, string> = {
  kcal: 'nutrientUnits.kcal',
  kJ: 'nutrientUnits.kJ',
  g: 'nutrientUnits.g',
  mg: 'nutrientUnits.mg',
  ug: 'nutrientUnits.ug',
  IU: 'nutrientUnits.IU',
}

export function nutrientUnitLabel(unit: string): string {
  const key = NUTRIENT_UNIT_KEYS[unit]
  return key ? t(key) : unit
}

function translatedKeyFor(target: string): string | null {
  const key = nutrientKey(target)
  if (key) return key
  const stableKeys = new Set(Object.values(NUTRIENT_KEYS))
  for (const stableKey of stableKeys) {
    if (t(stableKey) === target) return stableKey
  }
  return null
}

function stringKey(key: string | symbol): string | null {
  return typeof key === 'string' ? key : null
}

function proxiedDescriptor(key: string | symbol, hasValue: boolean) {
  if (!hasValue || typeof key !== 'string') return undefined
  return {
    enumerable: true,
    configurable: true,
    get: () => nutrientLabel(key),
  }
}

/** Compatibility display map for consumers outside this task. */
export const NUTRITION_LABEL_MAP: Record<string, string> = new Proxy({} as Record<string, string>, {
  get(_target, key) {
    const name = stringKey(key)
    if (!name) return undefined
    return translatedKeyFor(name) ? nutrientLabel(name) : undefined
  },
  has(_target, key) {
    const name = stringKey(key)
    return !!name && !!translatedKeyFor(name)
  },
  ownKeys() {
    return [...Object.keys(NUTRIENT_KEYS), ...Object.keys(CHINESE_ALIASES)]
  },
  getOwnPropertyDescriptor(_target, key) {
    const name = stringKey(key)
    return proxiedDescriptor(key, !!name && !!translatedKeyFor(name))
  },
})

/**
 * Legacy exported name retained for unlisted product/ingredient consumers.
 * Its values are catalog translations rather than hard-coded display strings.
 */
export const ENGLISH_TO_CHINESE_MAP: Record<string, string> = new Proxy({} as Record<string, string>, {
  get(_target, key) {
    const name = stringKey(key)
    return name && NUTRIENT_KEYS[name] ? nutrientLabel(name) : undefined
  },
  has(_target, key) {
    const name = stringKey(key)
    return !!name && !!NUTRIENT_KEYS[name]
  },
  ownKeys() {
    return Object.keys(NUTRIENT_KEYS)
  },
  getOwnPropertyDescriptor(_target, key) {
    const name = stringKey(key)
    return proxiedDescriptor(key, !!name && !!NUTRIENT_KEYS[name])
  },
})

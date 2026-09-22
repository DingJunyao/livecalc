import { t } from '../plugins/i18n.ts'

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
  sucrose: 'nutrients.sucrose', glucose: 'nutrients.glucose',
  fructose: 'nutrients.fructose', galactose: 'nutrients.galactose',
  lactose: 'nutrients.lactose', maltose: 'nutrients.maltose',
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
  'sfa_15:0': 'nutrients.pentadecanoicAcid', 'sfa_16:0': 'nutrients.palmiticAcid',
  'sfa_17:0': 'nutrients.heptadecanoicAcid', 'sfa_18:0': 'nutrients.stearicAcid',
  'sfa_20:0': 'nutrients.arachidicAcid', 'sfa_22:0': 'nutrients.behenicAcid',
  'sfa_24:0': 'nutrients.lignocericAcid', 'sfa_11:0': 'nutrients.undecanoicAcid',
  'sfa_13:0': 'nutrients.tridecanoicAcid',
  'mufa_14:1': 'nutrients.myristoleicAcid', 'mufa_15:1': 'nutrients.pentadecenoicAcid',
  'mufa_16:1': 'nutrients.palmitoleicAcid', 'mufa_17:1': 'nutrients.heptadecenoicAcid',
  'mufa_18:1': 'nutrients.oleicAcid', 'mufa_20:1': 'nutrients.gondoicAcid',
  'mufa_22:1': 'nutrients.erucicAcid', 'mufa_24:1': 'nutrients.nervonicAcid',
  'mufa_16:1_c': 'nutrients.palmitoleicAcid', 'mufa_18:1_c': 'nutrients.oleicAcid',
  'mufa_22:1_c': 'nutrients.erucicAcid', 'mufa_24:1_c': 'nutrients.nervonicAcid',
  'pufa_18:2': 'nutrients.linoleicAcid', 'pufa_18:3': 'nutrients.linolenicAcid',
  'pufa_18:4': 'nutrients.stearidonicAcid', 'pufa_20:2': 'nutrients.eicosadienoicAcid',
  'pufa_20:3': 'nutrients.meadAcid', 'pufa_20:4': 'nutrients.arachidonicAcid',
  'pufa_20:5_n_3_epa': 'nutrients.epa', 'pufa_20:5_n_3_(epa)': 'nutrients.epa',
  'pufa_22:5_n_3_dpa': 'nutrients.dpa', 'pufa_22:5_n_3_(dpa)': 'nutrients.dpa',
  'pufa_22:6_n_3_dha': 'nutrients.dha', 'pufa_22:6_n_3_(dha)': 'nutrients.dha',
  'pufa_18:2_n_6_cc': 'nutrients.linoleicAcid', 'pufa_18:2_n_6_c,c': 'nutrients.linoleicAcid',
  'pufa_18:2_clas': 'nutrients.conjugatedLinoleicAcid', 'pufa_18:2_i': 'nutrients.linoleicAcidIsomers',
  'pufa_18:3_n_3_ccc_(ala)': 'nutrients.alphaLinolenicAcid',
  'pufa_18:3_n_3_c,c,c_ala': 'nutrients.alphaLinolenicAcid',
  'pufa_18:3_n_6_ccc': 'nutrients.gammaLinolenicAcid',
  'pufa_18:3_n_6_c,c,c': 'nutrients.gammaLinolenicAcid',
  'pufa_20:2_n_6_cc': 'nutrients.eicosadienoicAcid', 'pufa_20:2_n_6_c,c': 'nutrients.eicosadienoicAcid',
  'pufa_20:3_n_3': 'nutrients.meadAcid', 'pufa_20:3_n_6': 'nutrients.dihomoGammaLinolenicAcid',
  'pufa_20:4_n_6': 'nutrients.arachidonicAcid', 'pufa_21:5': 'nutrients.heneicosapentaenoicAcid',
  'pufa_22:2': 'nutrients.docosadienoicAcid', 'pufa_22:4': 'nutrients.docosatetraenoicAcid',
  'pufa_22:5': 'nutrients.dpa', 'pufa_18:3i': 'nutrients.linolenicAcidIsomers',
  fatty_acids_total_trans_monoenoic: 'nutrients.transMonoenoicFat',
  fatty_acids_total_trans_polyenoic: 'nutrients.transPolyenoicFat',
  'tfa_16:1_t': 'nutrients.transPalmitoleicAcid', 'tfa_18:1_t': 'nutrients.transOleicAcid',
  'tfa_18:2_t_not_further_defined': 'nutrients.transLinoleicAcid',
  'tfa_18:2_t,t': 'nutrients.transLinoleicAcid', 'tfa_22:1_t': 'nutrients.transErucicAcid',
  'tfa_18:2_tt': 'nutrients.transLinoleicDitransIsomers',
  'mufa_18:1_11_t_(18:1t_n_7)': 'nutrients.trans11OleicAcid',
  vitamin_a: 'nutrients.vitaminA', vitamin_a_rae: 'nutrients.vitaminA',
  vitamin_a_iu: 'nutrients.vitaminA', retinol: 'nutrients.retinol',
  vitamin_c: 'nutrients.vitaminC', vitamin_d: 'nutrients.vitaminD',
  vitamin_d2: 'nutrients.vitaminD2', 'vitamin_d2_(ergocalciferol)': 'nutrients.vitaminD2',
  vitamin_d3: 'nutrients.vitaminD3', 'vitamin_d3_(cholecalciferol)': 'nutrients.vitaminD3',
  'vitamin_d_(d2_+_d3)_international_units': 'nutrients.vitaminD',
  vitamin_e: 'nutrients.vitaminE', vitamin_k: 'nutrients.vitaminK',
  vitamin_k1: 'nutrients.vitaminK1', vitamin_k2: 'nutrients.vitaminK2',
  'vitamin_k_(dihydrophylloquinone)': 'nutrients.vitaminK1',
  'vitamin_k_(menaquinone_4)': 'nutrients.vitaminK2',
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
  tocopherol_alpha: 'nutrients.alphaTocopherol', tocopherol_beta: 'nutrients.betaTocopherol',
  tocopherol_gamma: 'nutrients.gammaTocopherol', tocopherol_delta: 'nutrients.deltaTocopherol',
  tocotrienol_alpha: 'nutrients.alphaTocotrienol', tocotrienol_beta: 'nutrients.betaTocotrienol',
  tocotrienol_gamma: 'nutrients.gammaTocotrienol', tocotrienol_delta: 'nutrients.deltaTocotrienol',
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
  cystine: 'nutrients.cystine', hydroxyproline: 'nutrients.hydroxyproline',
  cysteine: 'nutrients.cysteine',
  caffeine: 'nutrients.caffeine', theobromine: 'nutrients.theobromine',
  lutein_plus_zeaxanthin: 'nutrients.luteinAndZeaxanthin',
  'lutein_+_zeaxanthin': 'nutrients.luteinAndZeaxanthin', lutein: 'nutrients.lutein',
  zeaxanthin: 'nutrients.zeaxanthin', lycopene: 'nutrients.lycopene',
  beta_glucan: 'nutrients.betaGlucan', glutathione: 'nutrients.glutathione',
  nitrogen: 'nutrients.nitrogen',
  total_fat_nlea: 'nutrients.fatNlea',
  beta_sitosterol: 'nutrients.betaSitosterol', campesterol: 'nutrients.campesterol',
  stigmasterol: 'nutrients.stigmasterol', phytosterols: 'nutrients.phytosterols',
  delta_7_stigmastenol: 'nutrients.delta7Stigmastenol',
  beta_sitostanol: 'nutrients.betaSitostanol',
  delta_5_avenasterol: 'nutrients.delta5Avenasterol', ergosterol: 'nutrients.ergosterol',
  ergothioneine: 'nutrients.ergothioneine', brassicasterol: 'nutrients.brassicasterol',
  campestanol: 'nutrients.campestanol',
  choline_from_sphingomyelin: 'nutrients.cholineFromSphingomyelin',
  choline_free: 'nutrients.freeCholine',
  choline_from_glycerophosphocholine: 'nutrients.cholineFromGlycerophosphocholine',
  choline_from_phosphotidyl_choline: 'nutrients.cholineFromPhosphotidylCholine',
  choline_from_phosphocholine: 'nutrients.cholineFromPhosphocholine',
}

import { CHINESE_ALIASES } from '../data/nutritionChineseAliases.ts'

export function nutrientKey(name: string): string | null {
  return NUTRIENT_KEYS[name] ?? CHINESE_ALIASES[name] ?? null
}

export function isDefaultNutrient(name: string, defaultKeys: Set<string>): boolean {
  const stableKey = nutrientKey(name)
  return !!stableKey && defaultKeys.has(stableKey)
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

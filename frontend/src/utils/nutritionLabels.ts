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
  '视黄醇': 'nutrients.retinol',
  '维生素C': 'nutrients.vitaminC', '维生素D': 'nutrients.vitaminD',
  '维生素D2': 'nutrients.vitaminD2', '维生素D2（麦角钙化醇）': 'nutrients.vitaminD2',
  '维生素D3': 'nutrients.vitaminD3', '维生素D3（胆钙化醇）': 'nutrients.vitaminD3',
  '维生素E': 'nutrients.vitaminE', '维生素E（强化）': 'nutrients.vitaminEAdded',
  '维生素K': 'nutrients.vitaminK',
  '维生素K1': 'nutrients.vitaminK1', '维生素K1（二氢叶绿醌）': 'nutrients.vitaminK1',
  '维生素K2': 'nutrients.vitaminK2', '维生素K2（甲萘醌-4）': 'nutrients.vitaminK2',
  '维生素B1': 'nutrients.vitaminB1', '维生素B2': 'nutrients.vitaminB2',
  '维生素B3': 'nutrients.niacin', '维生素B3（烟酸）': 'nutrients.niacin',
  '维生素B5': 'nutrients.vitaminB5', '维生素B5（泛酸）': 'nutrients.vitaminB5',
  '维生素B6': 'nutrients.vitaminB6', '维生素B12': 'nutrients.vitaminB12',
  '维生素B12（强化）': 'nutrients.vitaminB12Added',
  '叶酸': 'nutrients.folate', '烟酸': 'nutrients.niacin', '泛酸': 'nutrients.vitaminB5',
  '生物素': 'nutrients.biotin', '胆碱': 'nutrients.choline', '甜菜碱': 'nutrients.betaine',
  '钙': 'nutrients.calcium', '铁': 'nutrients.iron', '镁': 'nutrients.magnesium',
  '磷': 'nutrients.phosphorus', '钾': 'nutrients.potassium', '钠': 'nutrients.sodium',
  '锌': 'nutrients.zinc', '铜': 'nutrients.copper', '锰': 'nutrients.manganese',
  '硒': 'nutrients.selenium', '碘': 'nutrients.iodine', '铬': 'nutrients.chromium',
  '钼': 'nutrients.molybdenum', '氟': 'nutrients.fluoride',
  '咖啡因': 'nutrients.caffeine', '可可碱': 'nutrients.theobromine',
  'α-胡萝卜素': 'nutrients.alphaCarotene', 'β-胡萝卜素': 'nutrients.betaCarotene',
  'β-隐黄质': 'nutrients.betaCryptoxanthin', '番茄红素': 'nutrients.lycopene',
  '叶黄素和玉米黄质': 'nutrients.luteinAndZeaxanthin', '叶黄素': 'nutrients.lutein',
  '玉米黄质': 'nutrients.zeaxanthin',
  '丁酸': 'nutrients.butyricAcid', '己酸': 'nutrients.caproicAcid',
  '辛酸': 'nutrients.caprylicAcid', '癸酸': 'nutrients.capricAcid',
  '月桂酸': 'nutrients.lauricAcid', '肉豆蔻酸': 'nutrients.myristicAcid',
  '棕榈酸': 'nutrients.palmiticAcid', '硬脂酸': 'nutrients.stearicAcid',
  '肉豆蔻油酸': 'nutrients.myristoleicAcid', '十五碳烯酸': 'nutrients.pentadecenoicAcid',
  '棕榈油酸': 'nutrients.palmitoleicAcid', '十七碳烯酸': 'nutrients.heptadecenoicAcid',
  '油酸': 'nutrients.oleicAcid', '二十碳烯酸': 'nutrients.gondoicAcid',
  '二十二碳烯酸': 'nutrients.erucicAcid', '二十四碳烯酸': 'nutrients.nervonicAcid',
  '亚油酸': 'nutrients.linoleicAcid', '亚麻酸': 'nutrients.linolenicAcid',
  '十八碳四烯酸': 'nutrients.stearidonicAcid', '二十碳二烯酸': 'nutrients.eicosadienoicAcid',
  '二十碳三烯酸': 'nutrients.meadAcid', '花生四烯酸': 'nutrients.arachidonicAcid',
  '二十碳五烯酸（EPA）': 'nutrients.epa', '二十二碳五烯酸（DPA）': 'nutrients.dpa',
  '二十二碳六烯酸（DHA）': 'nutrients.dha',
  '二十碳五烯酸': 'nutrients.epa', '二十二碳五烯酸': 'nutrients.dpa',
  '二十二碳六烯酸': 'nutrients.dha',
  '蔗糖': 'nutrients.sucrose', '葡萄糖': 'nutrients.glucose', '果糖': 'nutrients.fructose',
  '半乳糖': 'nutrients.galactose', '乳糖': 'nutrients.lactose', '麦芽糖': 'nutrients.maltose',
  'α-生育酚': 'nutrients.alphaTocopherol', 'β-生育酚': 'nutrients.betaTocopherol',
  'γ-生育酚': 'nutrients.gammaTocopherol', 'δ-生育酚': 'nutrients.deltaTocopherol',
  'α-生育三烯酚': 'nutrients.alphaTocotrienol', 'β-生育三烯酚': 'nutrients.betaTocotrienol',
  'γ-生育三烯酚': 'nutrients.gammaTocotrienol', 'δ-生育三烯酚': 'nutrients.deltaTocotrienol',
  '十一烷酸': 'nutrients.undecanoicAcid', '十三烷酸': 'nutrients.tridecanoicAcid',
  '十五烷酸': 'nutrients.pentadecanoicAcid', '十七烷酸': 'nutrients.heptadecanoicAcid',
  '花生酸': 'nutrients.arachidicAcid', '山嵛酸': 'nutrients.behenicAcid',
  '木焦油酸': 'nutrients.lignocericAcid',
  '顺式-棕榈油酸': 'nutrients.palmitoleicAcid', '顺式-油酸': 'nutrients.oleicAcid',
  '顺式-二十二碳烯酸': 'nutrients.erucicAcid', '顺式-二十四碳烯酸': 'nutrients.nervonicAcid',
  '共轭亚油酸': 'nutrients.conjugatedLinoleicAcid', '顺式-亚油酸': 'nutrients.linoleicAcid',
  'α-亚麻酸': 'nutrients.alphaLinolenicAcid', 'γ-亚麻酸': 'nutrients.gammaLinolenicAcid',
  '二高-γ-亚麻酸': 'nutrients.dihomoGammaLinolenicAcid',
  '二十二碳四烯酸': 'nutrients.docosatetraenoicAcid',
  '二十一碳五烯酸': 'nutrients.heneicosapentaenoicAcid',
  '二十二碳二烯酸': 'nutrients.docosadienoicAcid',
  '亚油酸异构体': 'nutrients.linoleicAcidIsomers', '亚麻酸异构体': 'nutrients.linolenicAcidIsomers',
  '单烯反式脂肪酸': 'nutrients.transMonoenoicFat', '多烯反式脂肪酸': 'nutrients.transPolyenoicFat',
  '反式-棕榈油酸': 'nutrients.transPalmitoleicAcid', '反式-油酸': 'nutrients.transOleicAcid',
  '反式-11-油酸': 'nutrients.trans11OleicAcid', '反式-亚油酸': 'nutrients.transLinoleicAcid',
  '反式-二十二碳烯酸': 'nutrients.transErucicAcid',
  '反式-亚油酸二反式异构体': 'nutrients.transLinoleicDitransIsomers',
  '胱氨酸': 'nutrients.cystine', '羟脯氨酸': 'nutrients.hydroxyproline',
  '半胱氨酸': 'nutrients.cysteine',
  '丙氨酸': 'nutrients.alanine', '丝氨酸': 'nutrients.serine',
  '亮氨酸': 'nutrients.leucine', '天冬氨酸': 'nutrients.asparticAcid',
  '异亮氨酸': 'nutrients.isoleucine', '甘氨酸': 'nutrients.glycine',
  '精氨酸': 'nutrients.arginine', '组氨酸': 'nutrients.histidine',
  '缬氨酸': 'nutrients.valine', '脯氨酸': 'nutrients.proline',
  '色氨酸': 'nutrients.tryptophan', '苏氨酸': 'nutrients.threonine',
  '苯丙氨酸': 'nutrients.phenylalanine', '蛋氨酸': 'nutrients.methionine',
  '谷氨酸': 'nutrients.glutamicAcid', '赖氨酸': 'nutrients.lysine',
  '酪氨酸': 'nutrients.tyrosine',
  'β-谷甾醇': 'nutrients.betaSitosterol', '菜油固醇': 'nutrients.campesterol',
  '豆固醇': 'nutrients.stigmasterol', '植物固醇': 'nutrients.phytosterols',
  'δ7-豆甾烷醇': 'nutrients.delta7Stigmastenol', 'β-谷烷醇': 'nutrients.betaSitostanol',
  'δ5-燕麦固醇': 'nutrients.delta5Avenasterol', '麦角固醇': 'nutrients.ergosterol',
  '麦角硫因': 'nutrients.ergothioneine', '菜籽固醇': 'nutrients.brassicasterol',
  '菜烷醇': 'nutrients.campestanol', '总脂肪（NLEA）': 'nutrients.fatNlea',
  '鞘磷脂来源胆碱': 'nutrients.cholineFromSphingomyelin', '游离胆碱': 'nutrients.freeCholine',
  '甘油磷胆碱来源胆碱': 'nutrients.cholineFromGlycerophosphocholine',
  '磷脂酰胆碱来源胆碱': 'nutrients.cholineFromPhosphotidylCholine',
  '磷酸胆碱来源胆碱': 'nutrients.cholineFromPhosphocholine',
}

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

import assert from 'node:assert/strict'
import { test } from 'node:test'
import * as nutritionLabels from './nutritionLabels.ts'

const { nutrientKey } = nutritionLabels

test('representative USDA source aliases normalize to stable catalog keys', () => {
  assert.equal(nutrientKey('vitamin_d2'), 'nutrients.vitaminD2')
  assert.equal(nutrientKey('vitamin_d3_(cholecalciferol)'), 'nutrients.vitaminD3')
  assert.equal(nutrientKey('tocopherol_alpha'), 'nutrients.alphaTocopherol')
  assert.equal(nutrientKey('tocotrienol_gamma'), 'nutrients.gammaTocotrienol')
  assert.equal(nutrientKey('beta_sitosterol'), 'nutrients.betaSitosterol')
  assert.equal(nutrientKey('sucrose'), 'nutrients.sucrose')
  assert.equal(nutrientKey('glucose'), 'nutrients.glucose')
  assert.equal(nutrientKey('fructose'), 'nutrients.fructose')
  assert.equal(nutrientKey('galactose'), 'nutrients.galactose')
  assert.equal(nutrientKey('lactose'), 'nutrients.lactose')
  assert.equal(nutrientKey('maltose'), 'nutrients.maltose')
})

test('legacy USDA and stored nutrient aliases do not fall back to source keys', () => {
  const sourceAliases = [
    'sfa_15:0', 'sfa_20:0', 'sfa_24:0',
    'mufa_16:1_c', 'mufa_24:1_c',
    'pufa_18:2_n_6_cc', 'pufa_18:2_clas', 'pufa_18:3_n_3_ccc_(ala)',
    'pufa_20:3_n_6', 'pufa_22:4', 'pufa_22:5',
    'fatty_acids_total_trans_monoenoic', 'fatty_acids_total_trans_polyenoic',
    'tfa_16:1_t', 'tfa_18:2_tt', 'tfa_22:1_t',
    'campesterol', 'stigmasterol', 'phytosterols',
    'delta_7_stigmastenol', 'beta_sitostanol', 'delta_5_avenasterol',
    'ergosterol', 'ergothioneine', 'brassicasterol', 'campestanol',
    'cysteine', 'hydroxyproline', 'cystine',
    'pufa_22:2', 'sfa_11:0', 'total_fat_nlea',
    'choline_from_sphingomyelin', 'choline_free',
    'choline_from_glycerophosphocholine',
    'choline_from_phosphotidyl_choline', 'choline_from_phosphocholine',
    '\u7ef4\u751f\u7d20D2\uff08\u9ea6\u89d2\u9499\u5316\u9187\uff09', '\u7ef4\u751f\u7d20K2\uff08\u7532\u8418\u918c-4\uff09',
    '\u5171\u8f6d\u4e9a\u6cb9\u9178', '\u987a\u5f0f-\u68d5\u6988\u6cb9\u9178', '\u03b2-\u8c37\u753e\u9187', '\u8c46\u56fa\u9187',
  ]

  for (const source of sourceAliases) {
    assert.notEqual(nutrientKey(source), null, `missing stable key for ${source}`)
  }
})

test('raw default nutrient keys are compared after normalization', () => {
  const isDefaultNutrient = nutritionLabels.isDefaultNutrient
  assert.equal(typeof isDefaultNutrient, 'function', 'normalization helper should be exported')
  if (typeof isDefaultNutrient !== 'function') return

  const defaultKeys = new Set(
    ['\u80fd\u91cf', '\u86cb\u767d\u8d28', '\u8102\u80aa', '\u78b3\u6c34\u5316\u5408\u7269', '\u94a0']
      .map(nutrientKey)
      .filter((key): key is string => key !== null)
  )

  for (const source of ['\u80fd\u91cf', 'energy_kcal', '\u86cb\u767d\u8d28', 'protein', '\u8102\u80aa', 'fat']) {
    assert.equal(isDefaultNutrient(source, defaultKeys), true, `${source} should be excluded`)
  }

  assert.equal(isDefaultNutrient('\u81b3\u98df\u7ea4\u7ef4', defaultKeys), false)
  assert.equal(isDefaultNutrient('energy_kcal', new Set()), false)
})

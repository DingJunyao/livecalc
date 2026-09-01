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
    '维生素D2（麦角钙化醇）', '维生素K2（甲萘醌-4）',
    '共轭亚油酸', '顺式-棕榈油酸', 'β-谷甾醇', '豆固醇',
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
    ['能量', '蛋白质', '脂肪', '碳水化合物', '钠']
      .map(nutrientKey)
      .filter((key): key is string => key !== null)
  )

  for (const source of ['能量', 'energy_kcal', '蛋白质', 'protein', '脂肪', 'fat']) {
    assert.equal(isDefaultNutrient(source, defaultKeys), true, `${source} should be excluded`)
  }

  assert.equal(isDefaultNutrient('膳食纤维', defaultKeys), false)
  assert.equal(isDefaultNutrient('energy_kcal', new Set()), false)
})

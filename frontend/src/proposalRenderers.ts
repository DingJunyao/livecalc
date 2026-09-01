import type { Component } from 'vue'
import type { Proposal } from '@/api/proposals'
import RecipeEditDiff from '@/components/proposals/RecipeEditDiff.vue'
import NutritionDiff from '@/components/proposals/NutritionDiff.vue'
import MergeMapDiff from '@/components/proposals/MergeMapDiff.vue'
import HierarchyDiff from '@/components/proposals/HierarchyDiff.vue'
import EntityDensityDiff from '@/components/proposals/EntityDensityDiff.vue'
import EntityUnitOverrideDiff from '@/components/proposals/EntityUnitOverrideDiff.vue'
import MerchantDiff from '@/components/proposals/MerchantDiff.vue'
import ProductSplitDiff from '@/components/proposals/ProductSplitDiff.vue'
import ProductMergeDiff from '@/components/proposals/ProductMergeDiff.vue'
import { t } from '@/plugins/i18n'

export const PROPOSAL_ENTITY_KEYS: Record<string, string> = {
  ingredient: 'proposalEntityTypes.ingredient',
  nutrition: 'proposalEntityTypes.nutrition',
  unit: 'proposalEntityTypes.unit',
  merchant: 'proposalEntityTypes.merchant',
  merchant_merge: 'proposalEntityTypes.merchantMerge',
  product: 'proposalEntityTypes.product',
  product_split: 'proposalEntityTypes.productSplit',
  product_merge: 'proposalEntityTypes.productMerge',
  recipe: 'proposalEntityTypes.recipe',
  recipe_edit: 'proposalEntityTypes.recipeEdit',
  entity_unit_override: 'proposalEntityTypes.unitOverride',
  entity_density: 'proposalEntityTypes.density',
  hierarchy: 'proposalEntityTypes.hierarchy',
  usda_ingredient_match: 'proposalEntityTypes.usdaIngredientMatch',
  usda_product_match: 'proposalEntityTypes.usdaProductMatch',
}

export const PROPOSAL_ACTION_KEYS: Record<string, string> = {
  create: 'proposalActions.create',
  update: 'proposalActions.update',
  delete: 'proposalActions.delete',
  merge: 'proposalActions.merge',
  split: 'proposalActions.split',
  publish: 'proposalActions.publish',
}

export function proposalEntityTypeLabel(entityType: string): string {
  const key = PROPOSAL_ENTITY_KEYS[entityType]
  return key ? t(key) : entityType
}

export function proposalActionLabel(action: string): string {
  const key = PROPOSAL_ACTION_KEYS[action]
  return key ? t(key) : action
}

/**
 * 按 entity_type (+ action) 选专用渲染器。
 * 未命中返回 null —— 调用方回退现状 diffRows（CRUD 类零影响）。
 */
export function resolveProposalRenderer(p: Proposal): Component | null {
  const t = p.entity_type
  if (t === 'recipe_edit') return RecipeEditDiff
  if (t === 'nutrition' || t === 'product_nutrition'
      || t === 'usda_ingredient_match' || t === 'usda_product_match') {
    return NutritionDiff
  }
  if ((t === 'ingredient' && p.action === 'merge') || t === 'merchant_merge') {
    return MergeMapDiff
  }
  if (t === 'merchant') return MerchantDiff
  if (t === 'product_split') return ProductSplitDiff
  if (t === 'product_merge') return ProductMergeDiff
  if (t === 'hierarchy') return HierarchyDiff
  if (t === 'entity_density') return EntityDensityDiff
  if (t === 'entity_unit_override') return EntityUnitOverrideDiff
  return null
}

// Meal plans handler — 本地模式试算方案（与云端同契约）。
// 存储：meal_plans 单 store，条目以 items 数组内嵌行内（本地单用户，无跨表查询需求）。

import { getAll, addOne, deleteOne, getById, putOne } from '../database'
import { NUTRIENT_UNIT_BY_KEY, nrvPct } from '@/utils/nrv'
import * as recipes from './recipes'
import { resolveImageUrl } from '@/utils/image'
import { localError } from '../../../utils/localErrors'

function getTodayDate(): string {
  return new Date().toISOString().split('T')[0]
}

async function loadOwnedPlans(): Promise<any[]> {
  const all = await getAll('meal_plans')
  return all.filter((p: any) => p.is_active !== false)
}

async function loadOwned(planId: number): Promise<any> {
  const plan = await getById('meal_plans', planId)
  if (!plan || plan.is_active === false) {
    throw localError('planNotFound', 404, { id: planId })
  }
  return plan
}

async function buildBrief(recipeId: number): Promise<any | null> {
  const recipe = await getById('recipes', recipeId)
  if (!recipe) return null
  const servings = recipe.servings || 1
  let cost_estimate: number | null = null
  let nutrition_per_serving: any = null
  try {
    const cost = await recipes.getRecipeCost({ id: String(recipeId) })
    if (cost?.cost_per_serving != null && Number.isFinite(cost.cost_per_serving)) {
      cost_estimate = Math.round(cost.cost_per_serving * 100) / 100
    }
  } catch { /* ignore */ }
  try {
    const nutrition = await recipes.getRecipeNutrition({ id: String(recipeId) })
    if (servings > 0 && nutrition) {
      nutrition_per_serving = {
        calories: Math.round((nutrition.calories || 0) / servings * 10) / 10,
        protein_g: Math.round((nutrition.protein || 0) / servings * 10) / 10,
        carbs_g: Math.round((nutrition.carbohydrate || 0) / servings * 10) / 10,
        fat_g: Math.round((nutrition.fat || 0) / servings * 10) / 10,
      }
    }
  } catch { /* ignore */ }
  return {
    id: recipeId,
    name: recipe.name || '',
    category: recipe.category || undefined,
    images: recipe.images || [],
    image_urls: (recipe.images || []).map(resolveImageUrl),
    servings,
    cost_estimate,
    nutrition_per_serving,
  }
}

/** 原料营养：nutrition_data.all_nutrients 标准 key × 折算克数（简化：数量≈克） */
async function ingredientNutrition(ingredientId: number | null | undefined, quantity: any): Promise<any> {
  if (ingredientId == null) return null
  const nutritionData = await getAll('nutrition_data')
  const nd = nutritionData.find((n: any) => n.ingredient_id === ingredientId)
  if (!nd?.nutrients) return null
  const allN = nd.nutrients.all_nutrients || {}
  const ref = Number(nd.reference_amount) || 100
  const grams = Number(quantity ?? 0)
  const factor = grams / ref
  return {
    calories: Math.round((Number(allN.energy?.value ?? 0)) * factor * 100) / 100,
    protein_g: Math.round((Number(allN.protein?.value ?? 0)) * factor * 100) / 100,
    carbs_g: Math.round((Number(allN.carbohydrate?.value ?? 0)) * factor * 100) / 100,
    fat_g: Math.round((Number(allN.fat?.value ?? 0)) * factor * 100) / 100,
  }
}

/** 单条目求值：recipe 走菜谱引擎；ingredient/product 用本地价格记录最新价 × 数量。 */
export async function evaluateItem(item: any): Promise<{ cost: number | null; currency: string | null; nutrition: any }> {
  if (item.item_type === 'recipe' && item.recipe_id != null) {
    const brief = await buildBrief(item.recipe_id)
    return { cost: brief?.cost_estimate ?? null, currency: 'CNY', nutrition: brief?.nutrition_per_serving ?? null }
  }
  if (item.item_type === 'ingredient' && item.ingredient_id != null) {
    // 原料：找其活跃商品的最新价格记录，单价 × 数量（数量即按该记录单位）
    const [products, records] = await Promise.all([
      getAll('products'), getAll('product_records'),
    ])
    const productIds = new Set(
      products.filter((p: any) => p.ingredient_id === item.ingredient_id && p.is_active !== false).map((p: any) => p.id)
    )
    const relevant = records.filter((r: any) => productIds.has(r.product_id) && r.is_active !== false)
    const latest = relevant.sort((a: any, b: any) =>
      ((b.recorded_at || '') > (a.recorded_at || '') ? 1 : -1))[0]
    let cost: number | null = null
    if (latest?.price != null) {
      const stdQty = Number(latest.standard_quantity) || 1
      cost = Math.round((Number(latest.price) / stdQty) * Number(item.quantity ?? 0) * 100) / 100
    }
    const nutrition = await ingredientNutrition(item.ingredient_id, item.quantity)
    return { cost, currency: latest?.currency || 'CNY', nutrition }
  }
  if (item.item_type === 'product' && item.product_id != null) {
    const records = (await getAll('product_records'))
      .filter((r: any) => r.product_id === item.product_id && r.is_active !== false)
      .sort((a: any, b: any) => ((b.recorded_at || '') > (a.recorded_at || '') ? 1 : -1))
    const latest = records[0]
    let cost: number | null = null
    if (latest?.price != null) {
      const stdQty = Number(latest.standard_quantity) || 1
      cost = Math.round((Number(latest.price) / stdQty) * Number(item.quantity ?? 0) * 100) / 100
    }
    // 营养：商品自建营养（custom_nutrition_data，基准 reference_amount/reference_unit）优先，
    // 其次继承关联原料的 nutrition_data —— 与云端 NutritionMixin 合并口径一致
    const product = (await getAll('products')).find((p: any) => p.id === item.product_id)
    const custom = product?.custom_nutrition_data
    const customAll = custom?.nutrients?.all_nutrients
    let nutrition: any = null
    if (customAll) {
      const ref = Number(custom.reference_amount) || 100
      const factor = Number(item.quantity ?? 0) / ref
      nutrition = {
        calories: Math.round((Number(customAll.energy?.value ?? 0)) * factor * 100) / 100,
        protein_g: Math.round((Number(customAll.protein?.value ?? 0)) * factor * 100) / 100,
        carbs_g: Math.round((Number(customAll.carbohydrate?.value ?? 0)) * factor * 100) / 100,
        fat_g: Math.round((Number(customAll.fat?.value ?? 0)) * factor * 100) / 100,
      }
    } else {
      nutrition = await ingredientNutrition(product?.ingredient_id, item.quantity)
    }
    return { cost, currency: latest?.currency || 'CNY', nutrition }
  }
  return { cost: null, currency: null, nutrition: null }
}

/** 与云端 evaluate 的 `nutrition` 块同形状（本地模式只有 4 个核心营养素/条目） */
function buildLocalNutrition(
    totals: Record<string, number>,
    details: any[],
): any {
  const keys = Object.keys(totals).filter(k => totals[k])
  if (!keys.length) return {}
  const core: Record<string, any> = {}
  const all: Record<string, any> = {}
  for (const key of keys) {
    const value = Math.round(totals[key] * 100) / 100
    const unit = NUTRIENT_UNIT_BY_KEY[key] || ''
    const pct = nrvPct(key, value)
    all[key] = { value, unit, nrp_pct: pct }
    core[key] = { value, unit, key, nrp_pct: pct, name_zh: key }
  }
  return {
    per_serving_nutrition: { core_nutrients: core, all_nutrients: all },
    ingredient_details: details,
  }
}

async function evaluateRows(kind: string, mealType: string, items: any[]): Promise<any> {
  const evalItems: any[] = []
  const nutrientTotals: Record<string, number> = {}
  const nutrientDetails: any[] = []
  const totals = { cost: 0, currency: null as string | null, calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 }
  for (const item of items) {
    const { cost, currency, nutrition } = await evaluateItem(item)
    let name: string | null = null
    if (item.item_type === 'recipe' && item.recipe_id != null) {
      name = (await getById('recipes', item.recipe_id))?.name || null
    } else if (item.item_type === 'ingredient' && item.ingredient_id != null) {
      name = (await getById('ingredients', item.ingredient_id))?.name || null
    } else if (item.item_type === 'product' && item.product_id != null) {
      name = (await getById('products', item.product_id))?.name || null
    }
    evalItems.push({
      item_type: item.item_type, group: item.group, name,
      servings: item.servings ?? null, quantity: item.quantity ?? null, unit: null,
      cost, currency, nutrition,
    })
    if (cost != null) {
      totals.cost = Math.round((totals.cost + cost) * 100) / 100
      totals.currency = currency || totals.currency
    }
    if (nutrition) {
      totals.calories += nutrition.calories || 0
      totals.protein_g += nutrition.protein_g || 0
      totals.carbs_g += nutrition.carbs_g || 0
      totals.fat_g += nutrition.fat_g || 0
      const values: Record<string, number> = {
        energy: Number(nutrition.calories) || 0,
        protein: Number(nutrition.protein_g) || 0,
        carbohydrate: Number(nutrition.carbs_g) || 0,
        fat: Number(nutrition.fat_g) || 0,
      }
      const contribution: Record<string, { value: number; unit: string }> = {}
      for (const [key, value] of Object.entries(values)) {
        if (!value) continue
        nutrientTotals[key] = (nutrientTotals[key] || 0) + value
        contribution[key] = {
          value: Math.round(value * 100) / 100,
          unit: NUTRIENT_UNIT_BY_KEY[key] || '',
        }
      }
      if (Object.keys(contribution).length) {
        nutrientDetails.push({
          ingredient_id: null,
          ingredient_name: name || '',
          item_type: item.item_type,
          nutrition_contribution: contribution,
        })
      }
    }
  }
  // 目标（本地无用户资料存储，用默认值；与云端默认一致）
  const ratio = kind === 'day' ? 1 : (mealType === 'breakfast' ? 0.25 : mealType === 'lunch' ? 0.4 : 0.35)
  const targets = {
    calories: Math.round(2000 * ratio * 100) / 100,
    protein_g: Math.round(60 * ratio * 100) / 100,
    carbs_g: Math.round(300 * ratio * 100) / 100,
    fat_g: Math.round(65 * ratio * 100) / 100,
  }
  const deltas: Record<string, number> = {}
  for (const k of Object.keys(targets)) deltas[k] = Math.round((totals[k] - targets[k]) * 100) / 100
  return {
    items: evalItems,
    totals,
    targets,
    deltas,
    nutrition: buildLocalNutrition(nutrientTotals, nutrientDetails),
  }
}

// ============================================================
// Handlers
// ============================================================

export async function listPlans(_params: Record<string, string>): Promise<any> {
  const plans = await loadOwnedPlans()
  return { items: plans.sort((a: any, b: any) => ((b.updated_at || '') > (a.updated_at || '') ? 1 : -1)) }
}

export async function getPlan(params: Record<string, string>): Promise<any> {
  return await loadOwned(parseInt(params.id))
}

export async function createPlan(_params: Record<string, string>, data?: any): Promise<any> {
  const now = new Date().toISOString()
  const id = await addOne('meal_plans', {
    name: data?.name || '',
    kind: data?.kind || 'meal',
    note: data?.note || null,
    items: data?.items || [],
    is_active: true,
    created_at: now,
    updated_at: now,
  })
  return await loadOwned(id as number)
}

export async function updatePlan(params: Record<string, string>, data?: any): Promise<any> {
  const plan = await loadOwned(parseInt(params.id))
  if (data?.name != null) plan.name = data.name
  if (data?.kind != null) plan.kind = data.kind
  if (data?.note != null) plan.note = data.note
  if (data?.items != null) plan.items = data.items
  plan.updated_at = new Date().toISOString()
  await putOne('meal_plans', plan)
  return plan
}

export async function deletePlan(params: Record<string, string>): Promise<any> {
  const plan = await loadOwned(parseInt(params.id))
  plan.is_active = false
  plan.updated_at = new Date().toISOString()
  await putOne('meal_plans', plan)
  return { ok: true }
}

export async function evaluate(_params: Record<string, string>, data?: any): Promise<any> {
  return await evaluateRows(data?.kind || 'meal', data?.meal_type || 'lunch', data?.items || [])
}

/** GET /{id}/cost-trend — 按天取最新记录 ≤ 当日（前向填充），Σ 条目。 */
export async function costTrend(params: Record<string, string>, query?: any): Promise<any> {
  const plan = await loadOwned(parseInt(params.id))
  const days = Math.min(Math.max(Number(query?.days) || 90, 7), 3650)
  const offset = Number(query?.offset_days) || 0
  const records = await getAll('product_records')
  const products = await getAll('products')

  const out: any[] = []
  const today = new Date()
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(today)
    d.setDate(d.getDate() - i - offset)
    const dayStr = d.toISOString().split('T')[0]
    let total = 0
    for (const item of plan.items || []) {
      let productId: number | null = null
      if (item.item_type === 'recipe') {
        // 简化：菜谱项用当前成本（本地无逐日菜谱成本快照）
        const brief = await buildBrief(item.recipe_id)
        total += brief?.cost_estimate ?? 0
        continue
      }
      if (item.item_type === 'ingredient') {
        productId = products.find(
          (p: any) => p.ingredient_id === item.ingredient_id && p.is_active !== false
        )?.id ?? null
      } else if (item.item_type === 'product') {
        productId = item.product_id
      }
      if (productId == null) continue
      const dayRecords = records.filter(
        (r: any) => r.product_id === productId && r.is_active !== false && (r.recorded_at || '').split('T')[0] <= dayStr
      ).sort((a: any, b: any) => ((b.recorded_at || '') > (a.recorded_at || '') ? 1 : -1))
      const latest = dayRecords[0]
      if (latest?.price != null) {
        const stdQty = Number(latest.standard_quantity) || 1
        total += (Number(latest.price) / stdQty) * Number(item.quantity ?? 0)
      }
    }
    out.push({
      date: dayStr,
      total_cost: Math.round(total * 100) / 100,
      // 本地没有逐日价格区间：min = max = avg（前端照样画区间带，只是重合）
      min_cost: Math.round(total * 100) / 100,
      max_cost: Math.round(total * 100) / 100,
      avg_cost: Math.round(total * 100) / 100,
      currency: 'CNY',
    })
  }
  return out
}

/** set-plan 本地模式：写 meal_recommendations 的 plan 来源行。 */
export async function setPlan(_params: Record<string, string>, data?: any): Promise<any> {
  const plan = await loadOwned(parseInt(data?.plan_id))
  const today = getTodayDate()
  const targets: string[] =
    plan.kind === 'day' ? ['breakfast', 'lunch', 'dinner'] : [data?.meal_type || 'lunch']

  const all = await getAll('meal_recommendations')
  for (const mt of targets) {
    const existing = all.find((r: any) => r.date === today && r.meal_type === mt)
    if (existing) {
      existing.source = 'plan'
      existing.plan_id = plan.id
      existing.plan_name = plan.name
      existing.plan_items = (plan.items || []).map((i: any) => ({
        item_type: i.item_type, recipe_id: i.recipe_id,
        ingredient_id: i.ingredient_id, product_id: i.product_id,
        servings: i.servings ?? null, quantity: i.quantity ?? null,
      }))
      existing.updated_at = new Date().toISOString()
      await putOne('meal_recommendations', existing)
    } else {
      await addOne('meal_recommendations', {
        date: today, meal_type: mt, recipe_id: null,
        dishes: [], source: 'plan', plan_id: plan.id, plan_name: plan.name,
        plan_items: (plan.items || []).map((i: any) => ({
          item_type: i.item_type, recipe_id: i.recipe_id,
          ingredient_id: i.ingredient_id, product_id: i.product_id,
          servings: i.servings ?? null, quantity: i.quantity ?? null,
        })),
        refresh_count: 0, created_at: new Date().toISOString(),
      })
    }
  }
  return { ok: true }
}

// Meals handler — 餐食推荐（多道菜套餐，与云端后端同契约）。
// 组合方式：AI（浏览器直连 OpenAI 兼容/Anthropic）优先，规则兜底；
// 未配置 AI 或调用/校验失败时自动降级并在 note 标注。

import { getAll, addOne, deleteOne, getById, putOne } from '../database'
import { resolveImageUrl } from '@/utils/image'
import * as recipes from './recipes'
import { getTranslationConfig } from './admin'
import { evaluateItem } from './mealPlans'
import { localError } from '../../../utils/localErrors'
import {
  composeByRule,
  validateComposition,
  buildComposePrompt,
  aiComplete,
  RETRY_SUFFIX,
  MEAL_POOL_CATEGORIES,
  type ComposerCandidate,
  type ComposedMeal,
  type ComposedDish,
  type MealType,
  type DishRole,
} from '../business/mealComposer'

// ============================================================
// 内部辅助
// ============================================================

function getTodayDate(): string {
  return new Date().toISOString().split('T')[0]
}

function daysAgoDate(days: number): string {
  const d = new Date()
  d.setDate(d.getDate() - days)
  return d.toISOString().split('T')[0]
}

async function getTodayRecommendationsFromDb(): Promise<any[]> {
  const all = await getAll('meal_recommendations')
  const today = getTodayDate()
  return all.filter((r: any) => r.date === today)
}

/** 近 days 天推荐过的菜谱 id 与名字（跨餐次，供去重与提示词）。 */
async function getRecentRecommendations(days: number): Promise<{ ids: number[]; names: string[] }> {
  const all = await getAll('meal_recommendations')
  const start = daysAgoDate(days - 1)
  const rows = all.filter((r: any) => r.date >= start && r.date <= getTodayDate())
  const ids: number[] = []
  const names: string[] = []
  for (const row of rows) {
    for (const d of row.dishes || []) {
      if (d.recipe_id != null && !ids.includes(d.recipe_id)) {
        ids.push(d.recipe_id)
        const recipe = await getById('recipes', d.recipe_id)
        if (recipe?.name) names.push(recipe.name)
      }
    }
  }
  return { ids, names }
}

/** 加载候选菜谱（分类池内 + 活跃 + 收藏标记）。 */
async function loadCandidates(mealType: MealType): Promise<ComposerCandidate[]> {
  const [all, favorites] = await Promise.all([
    getAll('recipes'),
    getAll('user_favorites'),
  ])
  const favoriteIds = new Set(
    favorites
      .filter((f: any) => f.entity_type === 'recipe' && f.entity_id != null)
      .map((f: any) => f.entity_id)
  )
  const categories = MEAL_POOL_CATEGORIES[mealType]
  return all
    .filter((r: any) => r.is_active !== false && categories.includes(r.category || ''))
    .map((r: any) => ({
      id: r.id,
      name: r.name || '',
      category: r.category || '',
      cost_estimate: r.cost_estimate != null ? Number(r.cost_estimate) : null,
      calories_per_serving: r.calories_per_serving != null ? Number(r.calories_per_serving) : null,
      protein_per_serving: r.protein_per_serving != null ? Number(r.protein_per_serving) : null,
      is_favorite: favoriteIds.has(r.id),
    }))
}

async function loadRecipeNames(ids: number[]): Promise<string[]> {
  const names: string[] = []
  for (const id of ids) {
    const r = await getById('recipes', id)
    if (r?.name) names.push(r.name)
  }
  return names
}

/** 本地 AI 配置（meal_plan.provider 仅支持浏览器直连的 openai/anthropic）。 */
async function resolveLocalAi(): Promise<{
  provider: 'openai' | 'anthropic'
  apiKey: string
  model: string
  baseUrl?: string
  timeoutSeconds: number
} | null> {
  try {
    const cfg: any = await getTranslationConfig()
    const mealPlan = cfg?.meal_plan || {}
    const provider = mealPlan.provider
    if (provider !== 'openai' && provider !== 'anthropic') return null
    const section = cfg?.ai?.providers?.[provider]
    if (!section?.enabled || !section.api_key || !section.base_url) return null
    return {
      provider,
      apiKey: section.api_key,
      model: section.model || (provider === 'anthropic' ? 'claude-sonnet-4-6' : 'gpt-4o-mini'),
      baseUrl: section.base_url,
      timeoutSeconds: Number(mealPlan.timeout_seconds) || 120,
    }
  } catch {
    return null
  }
}

async function composeMeal(
  mealType: MealType,
  excludeIds: number[],
  preference: string | undefined,
  singleRole?: DishRole,
): Promise<ComposedMeal> {
  const candidates = (await loadCandidates(mealType)).filter(c => !excludeIds.includes(c.id))
  if (candidates.length === 0) {
    return { dishes: [], note: '', source: 'rule' }
  }

  const ai = await resolveLocalAi()
  if (ai) {
    const excludedNames = await loadRecipeNames(excludeIds)
    const recent = await getRecentRecommendations(7)
    const { system, user } = buildComposePrompt(
      candidates, mealType, preference || '', excludedNames, recent.names, singleRole)
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const text = await aiComplete(
          ai.provider, ai, system,
          attempt === 0 ? user : user + RETRY_SUFFIX,
          ai.timeoutSeconds * 1000)
        const errors = validateComposition(text, candidates, mealType, excludeIds, singleRole)
        if (errors.length === 0) {
          const parsed = JSON.parse(text)
          return {
            dishes: parsed.dishes.map((d: any) => ({
              recipe_id: Number(d.recipe_id),
              role: d.role,
              reason: typeof d.reason === 'string' ? d.reason : null,
            })),
            note: typeof parsed.note === 'string' ? parsed.note : '',
            source: 'system_ai',
          }
        }
      } catch {
        // 超时/网络/解析失败 → 重试一次后降级规则
      }
    }
  }

  return composeByRule(candidates, mealType, excludeIds)
}

// ============================================================
// Handlers
// ============================================================

const MEAL_TYPES: MealType[] = ['breakfast', 'lunch', 'dinner']

/** GET /meals/recommendations */
export async function getRecommendations(_params: Record<string, string>, _query?: any): Promise<any> {
  const cached = await getTodayRecommendationsFromDb()
  if (cached.length > 0) {
    return await buildResponse(cached)
  }
  return await generateAll()
}

/** POST /meals/recommendations/generate  body: {preference?} */
export async function generate(_params: Record<string, string>, data?: any): Promise<any> {
  return await generateAll(data?.preference)
}

/** POST /meals/recommendations/refresh  body: {meal_type, recipe_id?, preference?} */
export async function refresh(_params: Record<string, string>, data?: any): Promise<any> {
  const mealType: MealType = data?.meal_type
  if (!mealType || !MEAL_TYPES.includes(mealType)) {
    throw localError('mealTypeInvalid')
  }
  const recipeId: number | undefined = data?.recipe_id != null ? Number(data.recipe_id) : undefined
  const preference: string | undefined = data?.preference || undefined

  const existing = (await getTodayRecommendationsFromDb()).find(r => r.meal_type === mealType)
  if (!existing) {
    throw localError('mealNotGenerated')
  }
  const refreshCount = Number(existing.refresh_count) || 0
  if (refreshCount >= 5) {
    throw localError('mealRefreshLimit', 429, { meal_type: mealType, max: 5 })
  }

  const otherIds = (await getTodayRecommendationsFromDb())
    .filter(r => r.meal_type !== mealType)
    .flatMap(r => (r.dishes || []).map((d: any) => d.recipe_id))

  let composed: ComposedMeal
  if (recipeId != null) {
    // 单道换：保持其它菜，仅重选该道；换 staple 则新道也 staple
    const dishes: ComposedDish[] = existing.dishes || []
    const target = dishes.find(d => d.recipe_id === recipeId)
    if (!target) throw localError('mealDishNotInRecommendation', 404, { id: recipeId })
    const singleRole = target.role
    const exclude = [
      ...otherIds,
      ...dishes.filter(d => d.recipe_id !== recipeId).map(d => d.recipe_id),
    ]
    composed = await composeMeal(mealType, exclude, preference, singleRole as DishRole)
    if (!composed.dishes.length) throw localError('mealNoCandidates')
    const newDish = composed.dishes[0]
    const remaining = dishes.filter(d => d.recipe_id !== recipeId)
    const insertAt = dishes.findIndex(d => d.recipe_id === recipeId)
    remaining.splice(insertAt, 0, {
      recipe_id: newDish.recipe_id,
      role: newDish.role,
      reason: newDish.reason,
    })
    existing.dishes = remaining
  } else {
    const ownIds = (existing.dishes || []).map((d: any) => d.recipe_id)
    composed = await composeMeal(mealType, [...otherIds, ...ownIds], preference)
    if (!composed.dishes.length) throw localError('mealNoCandidates')
    existing.dishes = composed.dishes
  }

  existing.source = composed.source
  if (composed.note) existing.reason = composed.note
  if (preference) existing.preference = preference
  existing.refresh_count = refreshCount + 1
  existing.updated_at = new Date().toISOString()
  await putOne('meal_recommendations', existing)

  return await buildResponse(await getTodayRecommendationsFromDb())
}

// ============================================================
// 生成（三餐）
// ============================================================

async function generateAll(preference?: string): Promise<any> {
  const today = getTodayDate()
  for (const rec of await getTodayRecommendationsFromDb()) {
    await deleteOne('meal_recommendations', rec.id)
  }

  const usedIds: number[] = []
  const rows: any[] = []
  for (const mealType of MEAL_TYPES) {
    const composed = await composeMeal(mealType, usedIds, preference)
    if (composed.dishes.length === 0) continue
    usedIds.push(...composed.dishes.map(d => d.recipe_id))
    const row = {
      date: today,
      meal_type: mealType,
      dishes: composed.dishes,
      source: composed.source,
      reason: composed.note,
      preference: preference || null,
      refresh_count: 0,
      created_at: new Date().toISOString(),
    }
    await addOne('meal_recommendations', row)
    rows.push(row)
  }

  return await buildResponse(rows)
}

// ============================================================
// Response building
// ============================================================

function getCurrentMeal(): MealType | null {
  const h = new Date().getHours()
  if (h >= 5 && h < 10) return 'breakfast'
  if (h >= 10 && h < 14) return 'lunch'
  if (h >= 14 && h < 22) return 'dinner'
  return null
}

function round1(v: number): number { return Math.round(v * 10) / 10 }
function round2(v: number): number { return Math.round(v * 100) / 100 }

async function buildRecipeBrief(recipeId: number): Promise<any | null> {
  const recipe = await getById('recipes', recipeId)
  if (!recipe) return null
  const servings = recipe.servings || 1

  let cost_estimate: number | null = null
  let nutrition_per_serving: { calories: number; protein_g: number; carbs_g: number; fat_g: number } | null = null

  try {
    const cost = await recipes.getRecipeCost({ id: String(recipeId) })
    if (cost?.cost_per_serving != null && Number.isFinite(cost.cost_per_serving)) {
      cost_estimate = round2(cost.cost_per_serving)
    }
  } catch { /* no price records — leave null */ }

  try {
    const nutrition = await recipes.getRecipeNutrition({ id: String(recipeId) })
    if (servings > 0 && nutrition) {
      nutrition_per_serving = {
        calories: round1((nutrition.calories || 0) / servings),
        protein_g: round1((nutrition.protein || 0) / servings),
        carbs_g: round1((nutrition.carbohydrate || 0) / servings),
        fat_g: round1((nutrition.fat || 0) / servings),
      }
    }
  } catch { /* no nutrition data — leave null */ }

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

async function buildResponse(rows: any[]): Promise<any> {
  const today = getTodayDate()
  const currentMeal = getCurrentMeal()
  const recommendations = []
  const totals = { cost: 0, calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 }
  const refreshCounts: Record<string, number> = {}

  for (const mt of MEAL_TYPES) {
    const row = rows.find(r => r.meal_type === mt)
    if (!row) continue
    refreshCounts[row.meal_type] = Number(row.refresh_count) || 0
    const dishBriefs: any[] = []
    for (const dish of row.dishes || []) {
      const brief = await buildRecipeBrief(dish.recipe_id)
      if (!brief) continue
      dishBriefs.push({ ...brief, role: dish.role || 'main', reason: dish.reason || null })
      if (brief.cost_estimate != null && Number.isFinite(brief.cost_estimate)) {
        totals.cost += brief.cost_estimate
      }
      const n = brief.nutrition_per_serving
      if (n) {
        totals.calories += Number.isFinite(n.calories) ? n.calories : 0
        totals.protein_g += Number.isFinite(n.protein_g) ? n.protein_g : 0
        totals.carbs_g += Number.isFinite(n.carbs_g) ? n.carbs_g : 0
        totals.fat_g += Number.isFinite(n.fat_g) ? n.fat_g : 0
      }
    }
    const staple = dishBriefs.find(d => d.role === 'staple')
    // 方案来源餐：渲染方案视图
    let planView: any = null
    if (row.source === 'plan' && row.plan_id != null) {
      const plan = await getById('meal_plans', row.plan_id)
      if (plan && plan.is_active !== false) {
        const planItems = []
        for (const it of plan.items || []) {
          let name: string | null = null
          const entity = it.recipe_id != null
            ? await getById('recipes', it.recipe_id)
            : it.ingredient_id != null ? await getById('ingredients', it.ingredient_id)
            : it.product_id != null ? await getById('products', it.product_id)
            : null
          name = entity?.name || null
          const { cost } = await evaluateItem(it)
          planItems.push({
            item_type: it.item_type, name, group: it.group,
            servings: it.servings ?? null, quantity: it.quantity ?? null,
            unit: null, cost,
          })
        }
        planView = {
          id: plan.id, name: plan.name, kind: plan.kind, note: plan.note,
          items: planItems,
        }
      }
    }
    recommendations.push({
      meal_type: row.meal_type,
      recipe: staple || dishBriefs[0] || null,
      dishes: dishBriefs,
      source: row.source || 'rule',
      reason: row.reason || null,
      preference: row.preference || null,
      plan: planView,
      is_current_meal: row.meal_type === currentMeal,
    })
  }

  return {
    status: 'ready',
    date: today,
    recommendations,
    totals: {
      cost: round2(totals.cost),
      calories: round1(totals.calories),
      protein_g: round1(totals.protein_g),
      carbs_g: round1(totals.carbs_g),
      fat_g: round1(totals.fat_g),
      refresh_counts: refreshCounts,
    },
  }
}

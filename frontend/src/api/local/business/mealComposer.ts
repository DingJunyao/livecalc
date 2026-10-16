// 餐食组合器（本地模式，与后端 meal_composer.py 同契约）
// - 规则组合：主食 staple + 主菜 main（+汤/粥），分类池与后端一致
// - 校验器：与后端同规则（≥1 staple / id∈候选 / 1-4 道 / 无重复 / 排除集）
// - LLM 组合：浏览器直连 OpenAI 兼容 / Anthropic（读本地 AI 配置），失败降级规则

export type DishRole = 'staple' | 'main' | 'side' | 'soup' | 'drink'

export interface ComposerCandidate {
  id: number
  name: string
  category?: string
  cost_estimate?: number | null
  calories_per_serving?: number | null
  protein_per_serving?: number | null
  is_favorite?: boolean
}

export interface ComposedDish {
  recipe_id: number
  role: DishRole
  reason: string | null
}

export interface ComposedMeal {
  dishes: ComposedDish[]
  note: string
  source: 'rule' | 'system_ai' | 'user_ai'
}

export type MealType = 'breakfast' | 'lunch' | 'dinner'

/** 各餐候选分类（与后端 MEAL_POOL_CATEGORIES 一致） */
export const MEAL_POOL_CATEGORIES: Record<MealType, string[]> = {
  breakfast: ['早餐', '主食', '汤与粥'],
  lunch: ['主食', '荤菜', '素菜', '水产', '汤与粥'],
  dinner: ['主食', '荤菜', '素菜', '水产', '汤与粥'],
}

const ROLE_LABEL_ZH: Record<DishRole, string> = {
  staple: '主食',
  main: '主菜',
  side: '配菜',
  soup: '汤',
  drink: '饮品',
}

export function scoreCandidate(c: ComposerCandidate, pool: ComposerCandidate[]): number {
  let score = 50
  const maxCost = Math.max(...pool.map(x => x.cost_estimate ?? 0), 1)
  if (c.cost_estimate != null) {
    score += (1 - c.cost_estimate / maxCost) * 30
  }
  if (c.protein_per_serving != null) {
    score += Math.min(c.protein_per_serving / 20, 1) * 20
  }
  if (c.is_favorite) score += 10
  return Math.max(score, 0)
}

function bestOf(
  candidates: ComposerCandidate[],
  categories: string[],
  used: Set<number>,
): ComposerCandidate | null {
  const pool = candidates.filter(c => categories.includes(c.category || '') && !used.has(c.id))
  if (pool.length === 0) return null
  return pool.reduce((a, b) => (scoreCandidate(b, candidates) > scoreCandidate(a, candidates) ? b : a))
}

/** 规则组合：主食 + 主菜（+汤/粥）；staple 兜底与后端一致 */
export function composeByRule(
  candidates: ComposerCandidate[],
  mealType: MealType,
  excludeIds: number[] = [],
): ComposedMeal {
  const used = new Set<number>(excludeIds)
  const dishes: ComposedDish[] = []
  const take = (c: ComposerCandidate | null, role: DishRole) => {
    if (!c || used.has(c.id)) return
    used.add(c.id)
    dishes.push({ recipe_id: c.id, role, reason: null })
  }

  if (mealType === 'breakfast') {
    take(bestOf(candidates, ['主食'], used), 'staple')
    take(bestOf(candidates, ['早餐'], used), 'main')
  } else {
    take(bestOf(candidates, ['主食'], used), 'staple')
    take(bestOf(candidates, ['荤菜', '素菜', '水产'], used), 'main')
    take(bestOf(candidates, ['汤与粥'], used), 'soup')
  }

  if (!dishes.some(d => d.role === 'staple')) {
    const remaining = candidates.filter(c => !used.has(c.id))
    if (remaining.length > 0) {
      const pick = remaining.reduce((a, b) =>
        scoreCandidate(b, candidates) > scoreCandidate(a, candidates) ? b : a)
      used.add(pick.id)
      dishes.unshift({
        recipe_id: pick.id,
        role: 'staple',
        reason: '主食候选不足，以最接近者替代',
      })
    }
  }

  return { dishes, note: '按营养与成本目标挑选', source: 'rule' }
}

/** 校验 LLM 组合结果，返回错误清单（空 = 通过）。与后端 validate_composition 同规则。 */
export function validateComposition(
  raw: string | any,
  candidates: ComposerCandidate[],
  mealType: MealType,
  excludeIds: number[] = [],
  singleRole?: DishRole,
): string[] {
  const errors: string[] = []
  if (typeof raw === 'string') {
    try {
      raw = JSON.parse(raw)
    } catch {
      return ['输出不是合法 JSON']
    }
  }
  if (!raw || !Array.isArray(raw.dishes)) return ['缺少 dishes 数组']

  const byId = new Map(candidates.map(c => [c.id, c]))
  const dishes = raw.dishes as any[]
  if (singleRole) {
    if (dishes.length !== 1) errors.push('单道换模式下必须恰好 1 道')
  } else if (dishes.length < 1 || dishes.length > 4) {
    errors.push(`道数必须在 1-4 道，实际 ${dishes.length} 道`)
  }

  const seen = new Set<number>()
  let hasStaple = false
  for (const d of dishes) {
    const rid = d?.recipe_id
    if (!byId.has(rid)) {
      errors.push(`recipe_id ${rid} 不在短名单中`)
      continue
    }
    if (seen.has(rid)) {
      errors.push(`recipe_id ${rid} 重复`)
      continue
    }
    seen.add(rid)
    const role = d?.role
    if (!['staple', 'main', 'side', 'soup', 'drink'].includes(role)) {
      errors.push(`recipe_id ${rid} 的 role 非法：${role}`)
      continue
    }
    if (role === 'staple') {
      hasStaple = true
      if (mealType !== 'breakfast' && byId.get(rid)!.category !== '主食') {
        errors.push('午餐/晚餐的 staple 必须是「主食」分类的菜')
      }
    } else if (byId.get(rid)!.category === '主食') {
      errors.push(`recipe_id ${rid}（主食分类）必须标 role=staple`)
    }
  }
  if (singleRole) {
    for (const d of dishes) {
      if (d?.role !== singleRole) errors.push(`单道换的 role 必须是 ${singleRole}`)
    }
  } else if (!hasStaple) {
    errors.push('至少一道 role=staple（主食）')
  }
  if (excludeIds.some(id => seen.has(id))) {
    errors.push('结果命中排除清单')
  }
  return errors
}

/**
 * 首次输出未通过校验时追加的重试后缀（与提示词同属模型输入，非用户可见文案）。
 * 放在这里而不是调用方，是为了让「发给模型的文本」集中在本模块。
 */
export const RETRY_SUFFIX = '\n\n上一次输出未通过校验，请修正后重新只输出 JSON。'

export function buildComposePrompt(
  candidates: ComposerCandidate[],
  mealType: MealType,
  preference: string,
  excludedNames: string[],
  recentNames: string[],
  singleRole?: DishRole,
): { system: string; user: string } {
  const singleLine = singleRole
    ? `6. 本次是「单道替换」：只输出恰好 1 道菜，且 role 必须是 ${singleRole}。`
    : '6. 午餐/晚餐的 staple 必须是分类为「主食」的菜；分类为「主食」的菜必须标 staple。'
  const system = `你是营养搭配助手。给定候选菜谱短名单（JSON）与约束，组合一餐（1-4 道菜）。
硬性要求：
1. 至少一道 role="staple"（主食）；
2. 只能从短名单中选，不得编造 recipe_id；
3. 每道菜给 role（staple|main|side|soup|drink）与不超过 30 字的推荐理由；
4. 避开「排除菜谱」与「近 7 天已推荐」中的菜；优先满足用户偏好、营养目标与预算；
5. 理由用界面语言书写；菜系不限（不限于中餐），按短名单里实际有的菜搭配；
${singleLine}
只输出一个 JSON 对象，不要 markdown 代码块、不要解释：
{"dishes": [{"recipe_id": 123, "role": "staple", "reason": "…"}], "note": "整餐一句话理由"}`

  const mealName = { breakfast: '早餐', lunch: '午餐', dinner: '晚餐' }[mealType]
  const user = JSON.stringify({
    meal_type: mealName,
    user_preference: preference || '',
    excluded_recipes: excludedNames,
    recent_7d_recipes: recentNames,
    candidates: candidates.map(c => ({
      recipe_id: c.id,
      name: c.name,
      category: c.category,
      cost: c.cost_estimate,
      calories: c.calories_per_serving,
      is_favorite: !!c.is_favorite,
    })),
  })
  return { system, user }
}

/** 浏览器直连 AI（OpenAI 兼容 / Anthropic），返回首条文本；失败抛错。 */
export async function aiComplete(
  provider: 'openai' | 'anthropic',
  cfg: { apiKey: string; model: string; baseUrl?: string },
  system: string,
  user: string,
  timeoutMs = 120000,
): Promise<string> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    let res: Response
    if (provider === 'anthropic') {
      const base = String(cfg.baseUrl || 'https://api.anthropic.com').replace(/\/$/, '')
      res = await fetch(`${base}/v1/messages`, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': cfg.apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: JSON.stringify({
          model: cfg.model,
          max_tokens: 2048,
          system,
          messages: [{ role: 'user', content: user }],
        }),
      })
    } else {
      const base = String(cfg.baseUrl || 'https://api.openai.com/v1').replace(/\/$/, '')
      res = await fetch(`${base}/chat/completions`, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${cfg.apiKey}`,
        },
        body: JSON.stringify({
          model: cfg.model,
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user },
          ],
        }),
      })
    }
    if (!res.ok) {
      const text = await res.text().catch(() => '')
      throw new Error(`${provider} ${res.status}: ${text || res.statusText}`)
    }
    const j = await res.json()
    const content =
      provider === 'anthropic'
        ? (j?.content?.[0]?.text ?? '')
        : (j?.choices?.[0]?.message?.content ?? '')
    return String(content || '')
  } finally {
    clearTimeout(timer)
  }
}

export { ROLE_LABEL_ZH }

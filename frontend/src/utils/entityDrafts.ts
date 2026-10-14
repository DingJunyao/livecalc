// 新增商品/原料时的「自定义单位 / 营养信息」草稿落库。
//
// 实体创建成功（拿到 id）后一次性写入：
//   1. 自定义单位（按依赖分批创建，负数草稿 id 映射为真实 id）：POST /entities/{type}/{id}/units
//   2. 营养数据：POST /nutrition/{products|ingredients}/{id}/nutrition
//
// 失败**不抛出**、也不影响已经创建成功的实体：返回结构化的 issue 由调用方翻译成
// 提示，让用户看到「商品/原料已保存，但哪一项附加数据没保存」。

import { api } from '@/api'
import {
  planDraftUnitWrites,
  type EntityDraftNutrient,
  type EntityDraftUnit,
} from '@/utils/entityDraftPlan'

/** 支持草稿落库的实体类型。 */
export type DraftEntityType = 'product' | 'ingredient'

/** 一条附加数据的保存失败/跳过原因（由调用方翻译文案）。 */
export interface DraftPersistIssue {
  kind: 'cycle' | 'refMissing' | 'unit' | 'nutrition'
  names: string[]
  detail?: string
}

export interface PersistDraftsResult {
  unitsCreated: number
  unitsPending: number
  nutritionSaved: boolean
  nutritionPending: boolean
  nutrientsSaved: number
  issues: DraftPersistIssue[]
}

/** 一条给用户看的提示（含语义色）。 */
export interface DraftNotice {
  text: string
  color: 'success' | 'info' | 'warning' | 'error'
}

function errorDetail(error: any): string {
  return error?.response?.data?.detail || error?.message || ''
}

/** 营养端点的路径段：/nutrition/{products|ingredients}/{id}/nutrition。 */
function nutritionSegment(entityType: DraftEntityType): string {
  return entityType === 'ingredient' ? 'ingredients' : 'products'
}

/**
 * 落库草稿。[units] 里的负数 weight_unit_override_id 指向同批草稿，
 * 正数指向关联原料的自定义单位（仅商品有此来源）。
 */
export async function persistEntityDrafts(
  entityType: DraftEntityType,
  entityId: number,
  units: EntityDraftUnit[],
  nutrients: EntityDraftNutrient[],
): Promise<PersistDraftsResult> {
  const result: PersistDraftsResult = {
    unitsCreated: 0,
    unitsPending: 0,
    nutritionSaved: false,
    nutritionPending: false,
    nutrientsSaved: 0,
    issues: [],
  }

  const createdByDraftId = new Map<number, number>()
  const plan = planDraftUnitWrites(units || [])

  if (plan.cycles.length > 0) {
    result.issues.push({ kind: 'cycle', names: plan.cycles.map(unit => unit.unit_name) })
  }

  for (const batch of plan.batches) {
    for (const unit of batch) {
      const ref = unit.weight_unit_override_id
      const refIsDraft = ref != null && ref < 0
      if (refIsDraft && !createdByDraftId.has(ref as number)) {
        // 被引用的草稿单位没落库（失败或提交待审），引用它的单位无 id 可用
        result.unitsPending += 1
        result.issues.push({ kind: 'refMissing', names: [unit.unit_name] })
        continue
      }
      try {
        const response: any = await api.post(`/entities/${entityType}/${entityId}/units`, {
          unit_name: unit.unit_name,
          // 换算系数已从界面移除：语义由「量 + 单位」表达，固定写 1
          conversion_factor: 1,
          weight_per_unit: unit.weight_per_unit,
          weight_unit_id: ref != null ? null : unit.weight_unit_id,
          weight_unit_override_id: refIsDraft ? createdByDraftId.get(ref as number) ?? null : ref,
          is_default: unit.is_default,
        })
        const createdId = Number(response?.id ?? response?.unit?.id ?? 0)
        if (createdId > 0) {
          createdByDraftId.set(unit.id, createdId)
          result.unitsCreated += 1
        } else {
          // 普通用户提交待审：后端返回 id=0 的占位骨架
          result.unitsPending += 1
        }
      } catch (error: any) {
        result.issues.push({ kind: 'unit', names: [unit.unit_name], detail: errorDetail(error) })
      }
    }
  }

  const payloadNutrients = (nutrients || [])
    .filter(entry => entry.name.trim() && entry.value != null && Number(entry.value) > 0)
    .map(entry => ({
      name: entry.name,
      value: Number(entry.value),
      unit: entry.unit || 'g',
      key: entry.key || undefined,
    }))

  if (payloadNutrients.length > 0) {
    try {
      const response: any = await api.post(
        `/nutrition/${nutritionSegment(entityType)}/${entityId}/nutrition`,
        {
          base_quantity: 100,
          base_unit: 'g',
          nutrients: payloadNutrients,
          source: 'custom',
        },
      )
      if (response?.status === 'pending' || !!response?.proposal_id) result.nutritionPending = true
      else {
        result.nutritionSaved = true
        result.nutrientsSaved = payloadNutrients.length
      }
    } catch (error: any) {
      result.issues.push({ kind: 'nutrition', names: [], detail: errorDetail(error) })
    }
  }

  return result
}

/**
 * 把落库结果翻译成给用户看的提示（调用方逐条 notify）。
 * [target] 是实体名（商品/原料），用于拼「XX已保存…」这类文案。
 */
export function buildDraftNotices(
  t: (key: string, params?: Record<string, unknown>) => string,
  result: PersistDraftsResult,
  target: string,
): DraftNotice[] {
  const notices: DraftNotice[] = []

  for (const issue of result.issues) {
    if (issue.kind === 'cycle') {
      notices.push({
        text: t('products.draftUnitCycle', { names: issue.names.join(', ') }),
        color: 'error',
      })
    } else if (issue.kind === 'refMissing') {
      notices.push({
        text: t('products.draftUnitRefMissing', { names: issue.names.join(', ') }),
        color: 'warning',
      })
    } else if (issue.kind === 'unit') {
      notices.push({
        text: t('products.draftUnitFailed', { name: issue.names[0] ?? '', detail: issue.detail ?? '' }),
        color: 'error',
      })
    } else if (issue.kind === 'nutrition') {
      notices.push({
        text: t('products.draftNutritionFailed', { detail: issue.detail ?? '' }),
        color: 'error',
      })
    }
  }

  if (result.issues.length > 0) {
    if (result.unitsCreated > 0 || result.nutritionSaved) {
      notices.push({
        text: t('products.draftExtrasSaved', {
          target,
          units: result.unitsCreated,
          nutrients: result.nutrientsSaved,
        }),
        color: 'success',
      })
    }
    return notices
  }

  if (result.unitsPending > 0 || result.nutritionPending) {
    notices.push({ text: t('products.draftExtrasPending', { target }), color: 'info' })
    return notices
  }

  if (result.unitsCreated > 0 || result.nutrientsSaved > 0) {
    notices.push({
      text: t('products.draftExtrasSaved', {
        target,
        units: result.unitsCreated,
        nutrients: result.nutrientsSaved,
      }),
      color: 'success',
    })
  }
  return notices
}

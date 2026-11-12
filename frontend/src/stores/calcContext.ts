// stores/calcContext.ts
// 会话级临时覆盖（导航栏切换）：币种/地区/计算范围，仅当前会话有效，不修改用户配置。
// 持久化到 sessionStorage（浏览器会话），关闭标签页即失效。
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { api } from '@/api'

const STORAGE_KEY = 'calc-context'
const SCOPE_LEVEL: Record<string, number> = { '': -1, country: 0, province: 1, city: 2, county: 3 }

interface CalcContext {
  regionId: number | null
  scope: string | null
  currency: string | null
  effectiveRegionId: number | null
  // 自定义计算范围（scope 以 custom: 开头）解析出的地区 id 列表，X-Region 用逗号拼接
  effectiveRegionIds: number[] | null
}

function readSaved(): CalcContext {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY)
    if (raw) {
      const d = JSON.parse(raw)
      return {
        regionId: d.regionId ?? null,
        scope: d.scope ?? null,
        currency: d.currency ?? null,
        effectiveRegionId: d.effectiveRegionId ?? null,
        effectiveRegionIds: Array.isArray(d.effectiveRegionIds) ? d.effectiveRegionIds : null,
      }
    }
  } catch { /* ignore */ }
  return { regionId: null, scope: null, currency: null, effectiveRegionId: null, effectiveRegionIds: null }
}

export const useCalcContextStore = defineStore('calcContext', () => {
  const saved = readSaved()
  // 用户选择的地区（展示/编辑用）
  const regionId = ref<number | null>(saved.regionId)
  // 计算范围：'' 全部地区 / country / province / city / county / custom:<id> / null 跟随配置
  const scope = ref<string | null>(saved.scope)
  // 会话币种覆盖：null = 跟随用户配置
  const currency = ref<string | null>(saved.currency)
  // 已解析的生效地区节点（发给后端 X-Region，单节点）
  const effectiveRegionId = ref<number | null>(saved.effectiveRegionId)
  // 自定义计算范围的地区 id 列表（发给后端 X-Region，逗号分隔多 id）
  const effectiveRegionIds = ref<number[] | null>(saved.effectiveRegionIds)

  function persist() {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify({
        regionId: regionId.value,
        scope: scope.value,
        currency: currency.value,
        effectiveRegionId: effectiveRegionId.value,
        effectiveRegionIds: effectiveRegionIds.value,
      }))
    } catch { /* ignore */ }
  }

  /** 解析 地区 + 计算范围 -> 生效地区节点。chain 可传入级联选择器已有的祖先链，避免重复请求。 */
  async function resolveEffective(chain?: Array<{ id: number; level: number }>) {
    const id = regionId.value
    // 自定义范围：regionIds 由调用方直接给出（范围即地区列表，无需按层级截取）
    if (scope.value != null && scope.value.startsWith('custom:')) {
      effectiveRegionId.value = null
      persist()
      return
    }
    effectiveRegionIds.value = null
    if (id == null) { effectiveRegionId.value = null; persist(); return }
    const target = scope.value == null || scope.value === '' ? -1 : (SCOPE_LEVEL[scope.value] ?? 0)
    if (target < 0) { effectiveRegionId.value = null; persist(); return }
    let nodes = chain
    if (!nodes || !nodes.some(n => n.id === id)) {
      try {
        const detail: any = await api.get(`/regions/${id}`)
        nodes = [
          ...((detail?.ancestors || []) as any[]).map((a: any) => ({ id: a.id, level: a.level })),
          { id: detail.id, level: detail.level },
        ]
      } catch {
        effectiveRegionId.value = null
        persist()
        return
      }
    }
    const self = nodes.find(n => n.id === id)
    const level = Math.min(target, self?.level ?? 0)
    effectiveRegionId.value = nodes.find(n => n.level === level)?.id ?? id
    persist()
  }

  function apply(values: Partial<Pick<CalcContext, 'regionId' | 'scope' | 'currency'>> & { regionIds?: number[] | null }, chain?: Array<{ id: number; level: number }>) {
    if ('regionId' in values) regionId.value = values.regionId ?? null
    if ('scope' in values) scope.value = values.scope ?? null
    if ('currency' in values) currency.value = values.currency ?? null
    // 自定义范围直接携带地区列表；其余分支由 resolveEffective 清空
    effectiveRegionIds.value = Array.isArray(values.regionIds) && values.regionIds.length ? values.regionIds : null
    persist()
    void resolveEffective(chain)
  }

  /** 清空会话覆盖，回到用户配置。 */
  function clear() {
    regionId.value = null
    scope.value = null
    currency.value = null
    effectiveRegionId.value = null
    effectiveRegionIds.value = null
    persist()
  }

  // 恢复会话后补解析生效节点（老数据可能缺 effectiveRegionId）
  if (regionId.value != null && effectiveRegionId.value == null) {
    void resolveEffective()
  }

  return { regionId, scope, currency, effectiveRegionId, effectiveRegionIds, apply, clear }
})
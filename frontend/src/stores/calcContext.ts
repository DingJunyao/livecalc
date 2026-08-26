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
      }
    }
  } catch { /* ignore */ }
  return { regionId: null, scope: null, currency: null, effectiveRegionId: null }
}

export const useCalcContextStore = defineStore('calcContext', () => {
  const saved = readSaved()
  // 用户选择的地区（展示/编辑用）
  const regionId = ref<number | null>(saved.regionId)
  // 计算范围：'' 全部地区 / country / province / city / county / null 跟随配置
  const scope = ref<string | null>(saved.scope)
  // 会话币种覆盖：null = 跟随用户配置
  const currency = ref<string | null>(saved.currency)
  // 已解析的生效地区节点（发给后端 X-Region）
  const effectiveRegionId = ref<number | null>(saved.effectiveRegionId)

  function persist() {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify({
        regionId: regionId.value,
        scope: scope.value,
        currency: currency.value,
        effectiveRegionId: effectiveRegionId.value,
      }))
    } catch { /* ignore */ }
  }

  /** 解析 地区 + 计算范围 -> 生效地区节点。chain 可传入级联选择器已有的祖先链，避免重复请求。 */
  async function resolveEffective(chain?: Array<{ id: number; level: number }>) {
    const id = regionId.value
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

  function apply(values: Partial<Pick<CalcContext, 'regionId' | 'scope' | 'currency'>>, chain?: Array<{ id: number; level: number }>) {
    if ('regionId' in values) regionId.value = values.regionId ?? null
    if ('scope' in values) scope.value = values.scope ?? null
    if ('currency' in values) currency.value = values.currency ?? null
    persist()
    void resolveEffective(chain)
  }

  /** 清空会话覆盖，回到用户配置。 */
  function clear() {
    regionId.value = null
    scope.value = null
    currency.value = null
    effectiveRegionId.value = null
    persist()
  }

  // 恢复会话后补解析生效节点（老数据可能缺 effectiveRegionId）
  if (regionId.value != null && effectiveRegionId.value == null) {
    void resolveEffective()
  }

  return { regionId, scope, currency, effectiveRegionId, apply, clear }
})
import { ref } from 'vue'
import { api } from '@/api'

export type FavoriteEntityType = 'ingredient' | 'product' | 'recipe' | 'merchant'

function listPath(t: FavoriteEntityType) {
  return t === 'merchant' ? '/merchants/favorites' : `/favorites/${t}`
}

function itemPath(t: FavoriteEntityType, id: number) {
  return t === 'merchant' ? `/merchants/${id}/favorite` : `/favorites/${t}/${id}`
}

/** 收藏集合（乐观更新 + 失败回滚）。进页面调用 load()，切换调用 toggle()。 */
export function useFavorites(entityType: FavoriteEntityType) {
  const ids = ref<Set<number>>(new Set())
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      const rows: any[] = await api.get(listPath(entityType))
      ids.value = new Set((Array.isArray(rows) ? rows : []).map((r) => r.id))
    } catch (e: any) {
      console.error(`Failed to load ${entityType} favorites`, e)
    } finally {
      loading.value = false
    }
  }

  function isFavorite(id: number) {
    return ids.value.has(id)
  }

  /** 返回切换后的状态；失败时已回滚并抛出（调用方负责提示） */
  async function toggle(id: number): Promise<boolean> {
    const wasFav = ids.value.has(id)
    const next = new Set(ids.value)
    if (wasFav) next.delete(id)
    else next.add(id)
    ids.value = next
    try {
      if (wasFav) await api.delete(itemPath(entityType, id))
      else await api.post(itemPath(entityType, id))
      return !wasFav
    } catch (e) {
      const rollback = new Set(ids.value)
      if (wasFav) rollback.add(id)
      else rollback.delete(id)
      ids.value = rollback
      throw e
    }
  }

  return { ids, loading, load, isFavorite, toggle }
}

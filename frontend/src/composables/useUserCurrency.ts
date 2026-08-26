import { computed } from 'vue'
import { useUserStore } from '@/stores/user'
import { useCalcContextStore } from '@/stores/calcContext'

export function useUserCurrency() {
  const store = useUserStore()
  const calcContext = useCalcContextStore()
  const currency = computed(() => {
    // 会话级临时币种覆盖优先（导航栏切换，不修改用户配置）
    if (calcContext.currency) return calcContext.currency
    const c = store.user?.default_currency || store.user?.effective_currency
    return typeof c === 'string' && c ? c : 'CNY'
  })
  return { currency }
}
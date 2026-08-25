import { computed } from 'vue'
import { useUserStore } from '@/stores/user'

export function useUserCurrency() {
  const store = useUserStore()
  const currency = computed(() => {
    const c = store.user?.default_currency
    return typeof c === 'string' && c ? c : 'CNY'
  })
  return { currency }
}
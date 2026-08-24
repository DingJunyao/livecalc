import { computed } from 'vue'
import { useUserStore } from '@/stores/user'

export function useUserCurrency() {
  const store = useUserStore()
  const currency = computed(() => store.user?.default_currency || 'CNY')
  return { currency }
}
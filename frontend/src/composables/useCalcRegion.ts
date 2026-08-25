import { ref, computed } from 'vue'

// 页面级地区覆盖：null = 未临时选择 → 后端按用户默认计算范围（region + default_calc_scope）推导。
// 选择后仅对当前页面会话生效（不清除用户默认设置），可随时清除回退到默认。
export function useCalcRegion() {
  const regionId = ref<number | null>(null)
  const effective = computed(() => regionId.value ?? null)
  return { regionId, effective }
}

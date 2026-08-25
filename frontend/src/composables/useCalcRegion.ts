import { ref, computed } from 'vue'

export function useCalcRegion() {
  const regionId = ref<number | null>(null)
  const effective = computed(() => regionId.value ?? null)
  return { regionId, effective }
}

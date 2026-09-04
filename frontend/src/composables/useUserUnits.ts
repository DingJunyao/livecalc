// composables/useUserUnits.ts
// 用户级单位偏好读取 + 能量单位转换。NULL 字段由前端 fallback。
import { computed } from 'vue'
import { useUserStore } from '@/stores/user'
import { CHINESE_JIN_NAME, COMMON_SI_FACTORS_TO_KILOGRAMS } from '@/data/localValues'
import { localizedUnitLabel } from '@/utils/localDisplay'

export interface UnitPref {
  id: number
  name: string
  abbreviation: string
}

const FALLBACK_VOLUME_NAME = 'mL'

export function useUserUnits() {
  const userStore = useUserStore()
  const up = computed(() => (userStore.user as any)?.unit_preferences ?? null)

  const energyUnit = computed<'kcal' | 'kJ'>(() => up.value?.energy_unit ?? 'kcal')
  const massUnit = computed<UnitPref | null>(() => up.value?.mass_unit ?? null)
  const volumeUnit = computed<UnitPref | null>(() => up.value?.volume_unit ?? null)
  const priceUnit = computed<UnitPref | null>(() => up.value?.price_unit ?? null)

  const massUnitName = computed(() => massUnit.value?.abbreviation ?? CHINESE_JIN_NAME)
  const volumeUnitName = computed(() => volumeUnit.value?.name ?? FALLBACK_VOLUME_NAME)
  const priceUnitName = computed(() => priceUnit.value?.abbreviation ?? CHINESE_JIN_NAME)
  const massUnitLabel = computed(() => localizedUnitLabel(massUnitName.value))
  const priceUnitLabel = computed(() => localizedUnitLabel(priceUnitName.value))

  // 从「元/斤」折算到用户质量偏好单位（用于价格趋势/单价显示）。
  // si_factor：1 单位 = ? kg。元/X = 元/斤 × (si_factor_X / si_factor_斤)。
  // 只覆盖常见质量单位；未知单位不转（保持斤），避免误算。
  const JIN_SI_FACTOR = 0.5 // 1 斤 = 0.5 kg
  const convertFromJin = (valuePerJin: number | null | undefined): number | null => {
    if (valuePerJin === null || valuePerJin === undefined) return null
    const abbr = massUnit.value?.abbreviation
    const f = abbr ? COMMON_SI_FACTORS_TO_KILOGRAMS[abbr] : undefined
    if (f === undefined) return valuePerJin // 未知单位不转
    return valuePerJin * (f / JIN_SI_FACTOR)
  }

  // calorie 转换：库存 kcal，前端按 energyUnit 显示/输入
  const toDisplayCalorie = (kcal: number | null | undefined): number | null => {
    if (kcal === null || kcal === undefined) return null
    return energyUnit.value === 'kJ' ? +(kcal * 4.184).toFixed(0) : kcal
  }
  const fromDisplayCalorie = (v: number | null | undefined): number | null => {
    if (v === null || v === undefined) return null
    return energyUnit.value === 'kJ' ? +(v / 4.184).toFixed(0) : v
  }

  return {
    energyUnit,
    massUnit,
    volumeUnit,
    priceUnit,
    massUnitName,
    massUnitLabel,
    volumeUnitName,
    priceUnitName,
    priceUnitLabel,
    toDisplayCalorie,
    fromDisplayCalorie,
    convertFromJin,
  }
}

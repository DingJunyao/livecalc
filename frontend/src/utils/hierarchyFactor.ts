// 层级关系换算系数纯函数 — 与后端 _get_ingredient_fallback_impl 同口径。
// 语义：factor_parent_quantity [factor_parent_unit] 父 = factor_child_quantity [factor_child_unit] 子。
// 子缺价回退父时：ppg_子 = ppg_父 × factor，factor = (q父×g父) / (q子×g子)。
// 任一端字段缺失 / 克重解析失败 / 数值非法 → factor = 1（按 1:1）。

export interface HierarchyFactorFields {
  factor_parent_quantity: number | null
  factor_parent_unit: string | null
  factor_child_quantity: number | null
  factor_child_unit: string | null
}

/** 4 个 factor 字段是否「全填」（部分填由调用方在提交前校验） */
export function hasCompleteFactorFields(f: Partial<HierarchyFactorFields> | null | undefined): boolean {
  if (!f) return false
  return f.factor_parent_quantity != null
    && !!String(f.factor_parent_unit ?? '').trim()
    && f.factor_child_quantity != null
    && !!String(f.factor_child_unit ?? '').trim()
}

/** 4 个字段是否「全空」 */
export function hasEmptyFactorFields(f: Partial<HierarchyFactorFields> | null | undefined): boolean {
  if (!f) return true
  return f.factor_parent_quantity == null
    && !String(f.factor_parent_unit ?? '').trim()
    && f.factor_child_quantity == null
    && !String(f.factor_child_unit ?? '').trim()
}

/**
 * 由两端的数量与克重计算价格折算因子。
 * 方向语义：当前原料是子（child）、从父（parent）取价 → 子价 = 父价 × 本因子。
 * 例：1 kg 干(父) = 3 kg 鲜(子) → factor = (1×1000)/(3×1000) = 1/3。
 */
export function hierarchyPriceFactor(
  qParent: number | null | undefined,
  gramsParent: number | null,
  qChild: number | null | undefined,
  gramsChild: number | null,
): number {
  const qp = Number(qParent)
  const qc = Number(qChild)
  if (gramsParent == null || gramsChild == null) return 1
  if (!(qp > 0) || !(qc > 0) || !(gramsParent > 0) || !(gramsChild > 0)) return 1
  const factor = (qp * gramsParent) / (qc * gramsChild)
  return Number.isFinite(factor) && factor > 0 ? factor : 1
}

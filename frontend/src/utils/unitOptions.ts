/**
 * 单位下拉选项的纯函数（无网络依赖，可被 `node --test` 直接跑）。
 */

export interface NamedUnit {
  name?: string | null
  unit_name?: string | null
}

/** 行 → 单位名（`unit_name` 优先，其次 `name`；两侧空白去掉）。 */
function unitNameOf(row: NamedUnit | null | undefined): string {
  const raw = row?.unit_name ?? row?.name ?? ''
  return String(raw).trim()
}

/**
 * 全局单位里与**实体自定义单位同名**的项不再列出。
 *
 * 全局单位表里本来就有「颗 / 个 / 盒 / 把」这类计数单位，实体（商品、或商品的
 * 关联原料）又按自己的口径定义了同名单位（如「1 颗 = 500 克」）时，下拉里会出现
 * 两条同名项（「颗 (颗)」和「颗（继承自原料）」），用户无从分辨该选哪条。
 *
 * 按后端 `UnitConversionService.get_entity_override` 的优先级链
 * （实体覆盖 > 全局单位），同名的全局项让位给更具体的实体定义。
 */
export function withoutShadowedGlobals<T extends NamedUnit>(
  globals: T[],
  entityRows: NamedUnit[],
): T[] {
  const names = new Set<string>()
  for (const row of entityRows || []) {
    const name = unitNameOf(row)
    if (name) names.add(name)
  }
  if (names.size === 0) return [...(globals || [])]
  return (globals || []).filter(global => {
    const name = unitNameOf(global)
    return name === '' || !names.has(name)
  })
}

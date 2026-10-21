# FEATURE：原料趋势图显示「替代 / 回退 / 从属」折算价（逻辑同菜谱成本）

日期：2026-10-21
范围：后端新增折算价序列接口 + Web 原料详情趋势图；移动端未改动。

## 需求

原料价格趋势图此前只画「该原料自己关联商品」的价格记录。若原料没有直接商品价，
但存在 **回退 / 替代（substitutable）/ 半成品 / 从属（contains）** 关系，菜谱成本计算
会自动降级取价，而趋势图是空白。要求趋势图也显示这部分「计算后的结果」，
且逻辑与菜谱成本计算完全一致；并加开关（默认打开）。

## 后端

### 新服务 `calculate_ingredient_price_series()`（`services/recipe_service.py`）

逐日 as-of 跑与 `_ingredient_cost_range` **完全相同的降级链**：

```
direct（自身商品加权价）
  → fallback（_get_ingredient_fallback：fallback + substitutable 双向）
  → name_match（商品名包含匹配）
  → recipe（半成品制作菜谱递归）
  → contains（从属子食材按 strength 聚合）
```

- 返回 `[{date, source, chain, min_ppg, max_ppg, avg_ppg}]`（元/克，已按用户币种折算）。
- `source ∈ direct / fallback / name_match / recipe / contains_aggregation`；
  `chain` 为链路说明（如「酱油 → 生抽」）。
- `days` 上限 **366**：逐日跑降级链成本较高，前端「全部」区间也只取近一年。
- 单日异常只记录 debug 日志、跳过该日，不影响整条序列。

### 新接口

`GET /api/v1/nutrition/ingredients/{id}/price-series?days=30&offset_days=0&region_id=`

- `days` 1..366，`region_id` 走 `resolve_region_param`（默认用户计算范围），`tz` 取请求头时区。

## 前端

### `PriceTrendChart.vue`

- 新增 props：`computedSeries?: DataPoint[]`（带 `source` / `chain`）、`computedTitle?`。
- `computedSeries` 非空时，标题栏出现 **「含替代/从属」开关**（`v-switch`，内部状态默认 `true`）。
- 折算序列画成：紫色 `#7e57c2` **虚线** + 低透明度区间带（不受商家模式影响，商家模式不叠加）。
- tooltip 同时展示：直接价（平均/区间/商品数）与折算价（来源文案 + 链路），
  例如「替代/从属折算: ¥15.90/斤」+「回退/替代关系（酱油 → 生抽）」。
- 空态判定、y 轴范围、单点撑轴都同时考虑折算序列。

### `IngredientDetail.vue`

- 新增 `loadComputedPriceSeries()`：按当前图表区间取 `week=7 / month=30 / quarter=90 /
  year=365 / all=366` 天；进入页面、切换区间、价格记录变更后刷新都会重取。
- `computedChartSeries`：每克价 × 图表单位克数（`CHART_UNIT_FACTORS_TO_GRAMS`）换算成
  `/斤`（或用户质量偏好单位），并**过滤掉 source=direct 的日子**（避免与已有直接价曲线重复）。

### i18n（三语）

`charts.computedPrice` / `charts.includeComputed` / `charts.sourceDirect` /
`charts.sourceFallback` / `charts.sourceNameMatch` / `charts.sourceRecipe` / `charts.sourceContains`。

## 验证

- 只读查库实跑（真实 SQLite 数据）：
  - `酱油`（0 条直接记录）→ 30/30 天 `fallback`，chain「酱油 → 生抽」；
  - `干红椒` → 「干红椒 → 干辣椒」；`中筋面粉` → 「中筋面粉 → 面粉」；`糖` → 「糖 → 白糖」；
  - `猪肉` → 30/30 天 `name_match`（同名商品匹配，与菜谱链顺序一致）；
  - 有直接记录的原料（五花肉/青椒/牛奶等）→ 全部 `direct`，前端不重复绘制。
- 新增回归 `tests/services/test_ingredient_price_series.py`：无直接价时走 fallback
  并透传 chain/三档；有直接价时短路、不调用 fallback。2 passed。
- 前端 `pnpm run build` 通过；`check:i18n` 三语键一致；后端 `py_compile` 通过。

## 实机反馈修复（首版上线后发现）

用户在 `http://localhost:5173/data/ingredients/14`（猪肉）看到「图表、最新价格都是空的」。两个独立原因：

1. **图表空白（ECharts 从未初始化）**：图表容器由 `v-if="hasEverHadData || !displayEmpty"` 控制。
   首帧只有折算序列、没有直接价时 `displayEmpty` 为 true → 容器不存在 → `onMounted` 的
   `initChart()` 拿不到 `chartRef` 直接 return；之后折算数据到达、容器渲染出来，但所有 watch
   只调 `updateChart()`（`if (!chart) return`），于是永远没有实例。
   **修复**：抽出 `renderOrInit()`（无实例且有 ref → `initChart()`，否则 `updateChart()`），
   数据 / 折算序列 / loading / 语言 / 筛选 / 模式等所有 watch 统一走它。
2. **最新价格空白**：卡片条件是 `v-else-if="latestPrice"`，而 `latestPrice` 只来自直接商品价；
   猪肉 0 条直接记录（只有同名商品可折算）→ 整张卡片被隐藏。
   **修复**：卡片条件改为 `latestPrice || latestComputedPoint`；无直接价时展示最新折算价
   （大字 + `/斤`）、`charts.computedPrice` 标签、区间（min–max）、日期 + 来源链路
   （「2026/10/21 · 同名商品匹配」）；有直接价时行为不变。

实机复验（Edge，`/data/ingredients/14`）：最新价显示 `15.90 CNY / 斤` + 「替代/从属折算」+ 区间
`15.90 - 15.90` + 「同名商品匹配」；趋势图为紫色虚线，开关「含替代/从属」默认打开。

> 注意：HMR 只热替换模板时会出现 `Property "latestComputedPoint" was accessed during render but is
> not defined on instance` 的假报警，刷新页面即消失（脚本部分未热重载）。

## 已知限制

- 本地模式（IndexedDB）没有该接口，调用失败会静默隐藏折算序列（开关也不出现）。
- 「全部」区间折算最多近一年（逐日降级链的性能取舍）；更早区间的折算曲线不显示。

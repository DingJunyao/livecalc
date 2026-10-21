# FEATURE：商家价格趋势对比（详情页趋势图「综合 / 按商家」切换）

日期：2026-10-21
范围：仅 web 前端，无后端 / 数据库改动。

## 需求

用户想对比食材、商品在不同超市（商家）的价格趋势并显示在图表上。经确认：

- 方式选 **A：在已有图表上改**（不新建页面）：对比语境天然挂在原料/商品详情页，数据已在前端。
- 防乱策略选 **商家多选 chips，默认勾选记录数最多的前 3 家**。

## 实现

### `frontend/src/components/charts/PriceTrendChart.vue`
- 新增可选 prop `comparisonSeries: { merchantId, name, data: DataPoint[] }[]`；≥2 条时标题栏出现「综合 / 按商家」切换（i18n `charts.overall` / `charts.byMerchant`，三语已补）。
- 按商家模式：标题下渲染商家 chips（多选、带色点），默认勾选「记录数（Σ count）」最多的前 3 家；每个选中商家画一条均价线（固定色板 `MERCHANT_COLORS`，按序列索引取色，chips 色点与线同色）。
- 时间区间切片抽成 `sliceByFilter`，主序列与商家序列共用；商家序列区间口径与主序列一致。
- 商家模式 tooltip 列出各商家该日价格；`chart.setOption(option, true)`（notMerge）避免从商家模式切回综合时残留旧 series。
- **只有真实记录日画点**：`DataPoint.recorded` 标记该日是否有原始记录（商家分组内的原始价格点日期集合）；as-of 携带日 `symbolSize: 0` 只连线不画点（用户反馈：无记录日不要用点表示）。
- **切换时间区间保持商家选取**：区间切换会让父页面累积加载记录、`comparisonSeries` 引用变化；watch 以「商家 id 集合签名」判断——集合没变时只剔除已消失的 id、保留用户勾选，只有集合真变了（换实体/新商家到达）才重置为默认前 3 家。
- 空态判定改 `displayEmpty`（商家模式看选中序列是否为空）。

### `frontend/src/views/ingredients/IngredientDetail.vue`
- 原 `chartData` 内联的记录折算抽出为 `toChartPricePoint(record)`（含 exchange_rate 折算、standard_quantity / 实体单位回退折算，逻辑不变）。
- 新增 `merchantComparisonSeries`：`chartPriceRecords` 按 `merchant_id` 分组，每组用同一折算 + `buildWeightedAsOfDailySeries`（组内商品权重沿用 `productWeights`，startDay/backfillSparse 同主序列）。

### `frontend/src/views/products/ProductDetail.vue`
- 同理抽出 `toProductChartPoint`（normalizeRecordToJin + convertFromJin，逻辑不变）；`merchantComparisonSeries` 分组后权重恒 50、`bandFromRecords: true`，与该页主序列口径一致。

### i18n
- `charts.overall` / `charts.byMerchant`：zh-CN（综合/按商家）、en-US（Overall/By merchant）、ar（الإجمالي/حسب المتجر）。
- 商家名回退复用现有键：`prices.unknownMerchant`（无商家记录）、`recipes.merchantFallbackName`（有 id 无名字）。

## 注意点

- 不显示开关的条件：`comparisonSeries.length < 2`（单一商家不影响原展示）。
- 商家线只画均价、不画区间带——多商家叠加区间带会互相覆盖，视觉更乱。
- `chartPriceRecords` 是按区间累积加载的池子：切到「全部」区间前，商家序列也只含已加载区间的数据（与主序列行为一致）。
- 项目 `vue-tsc` 与 TS 版本不兼容（预先存在，`Search string not found` 崩溃），验证以 `pnpm run build`（vite build）+ `pnpm run check:i18n` 通过为准。

## 后续（未做）

- 移动端 app 同功能（遵循「各端体验一致性」，需在 feat/mobile-app 分支用 Flutter 图表实现同样交互）。
- 跨实体对比页（多食材/多商品横向比价）如需要再单独立项。

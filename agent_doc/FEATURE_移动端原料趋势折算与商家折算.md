# 移动端原料趋势折算价与各商家折算价

## 背景

Web 端在「原料趋势图 / 各商家价格」上补齐了替代/回退/从属折算口径后，
移动端（`feat/mobile-app`）仍是旧实现：

- 趋势图只有「直接价 as-of 序列」，没有折算虚线/区间带，也没有「含替代/从属」开关；
- 「各商家价格」只调 `latest-price-by-merchant` 不带任何参数 → 该商家没有直接价就整条缺失，
  直接价超期也不会改用折算价；
- `MerchantPrice` 模型没有 `source/chain/is_derived/区间/原直接价` 字段，卡片只会置灰。

## 后端接口（已有，无需改动）

- `GET /nutrition/ingredients/{id}/price-series?days=&prefer_relations_when_stale=true`
  逐日折算价，每克三档 + `source` / `chain` / `direct_ppg` / `direct_stale`。
- `GET /nutrition/ingredients/{id}/latest-price-by-merchant?include_relations=true&prefer_relations_when_stale=true`
  按商家给出直接价或折算价，行带 `source` / `chain` / `is_derived` / `min_price` / `max_price` /
  `direct_price` / `direct_stale`。

## 移动端实现

### 数据层

- 新增 `shared/models/computed_price_point.dart`：解析 price-series 每克价，**统一按 500g/斤
  换算成每斤**（与移动端 `buildPriceTrendPoints` 的 price-per-jin 口径一致）；
  保留 `source` / `chain` / `directStale` / `directAvg`。
- `MerchantPrice` 增加 `source` / `chain` / `isDerived` / `minPrice` / `maxPrice` /
  `directPrice` / `directStale`（默认 `direct`，旧接口无这些字段时安全降级）。
- `IngredientRepository`：
  - `getLatestPricesByMerchant(..., includeRelations, preferRelationsWhenStale)`；
  - 新增 `getPriceSeries(id, days, preferRelationsWhenStale)`。

### 状态层（`IngredientDetailPageNotifier`）

- `IngredientDetailPageState` 增加 `computedPoints` / `includeComputed`（默认 true）/
  `loadingComputed`。
- `_loadChart` 记住当前区间天数 `_chartDays`；`load()` 与 `reloadChart()` 同时拉折算序列，
  保证「切换周/月/季/年」时折算曲线与主曲线同区间。
- `setIncludeComputed(bool)`：与 Web 同一个开关语义（开 = 显示折算 + 超期优先；
  关 = 不请求、只看直接价），切换时**同时重取**折算序列与各商家价格。

### 图表（`CostTrendChart` 扩展，菜谱/试算复用不受影响）

- 新增可选 `computedPoints` / `includeComputed` / `showComputedSwitch` /
  `onIncludeComputedChange`；默认空/false，原有调用方零改动。
- 标题栏加一个小号 Switch（`key: include_computed_switch`），Tooltip 文案「含替代/从属」。
- 画布：折算点参与 Y 轴范围；≥2 点时画紫色浅色区间带 + 紫色虚线均价，单点时画一个点。
  日期对齐主序列下标，没有同日期主点的折算日跳过，避免错位。
- Tooltip 增加一行「替代/从属折算 均价（区间）」+ 来源文案。

### 各商家价格卡片

- 折算行：紫色浅底 + 紫色描边（不再套 `Opacity 0.5` 置灰），显示区间、紫色来源文字、
  被替换时红字「原直接价 X」；直接价行保持原灰底，超期仍置灰。
- 卡片高度 124 → 152，给多出来的区间/来源/原价行留空间，避免 `RenderFlex overflow`。
- 最低价角标对折算行同样生效（后端会给非陈旧的折算行标 `is_lowest`）。

### i18n

`app_zh/en/ar.arb` 新增：`includeComputed` / `computedPrice` / `computedSourceFallback` /
`computedSourceNameMatch` / `computedSourceRecipe` / `computedSourceContains` /
`originalDirectPrice`；`flutter gen-l10n` 重新生成 `app_localizations*.dart`。

## 追加：开关文字标签 + 「综合 / 按商家」对比

用户反馈两条：

1. **「含替代/从属」开关没有提示**：移动端没有 hover，之前只包了 `Tooltip`，界面上只有一个光秃秃的
   开关。改为「开关 + 可见文字标签」一行（整行可点切换，`key: include_computed_row`）。
2. **手机端没做「对比食材/商品在不同超市的价格趋势」**：这是本功能的核心诉求。

### 数据层

`features/prices/utils/price_trend.dart` 新增：

- `PriceMerchantSeries { merchantId, name, points, recordDays }`；
- `buildMerchantTrendSeries(records, {useStandardQuantity, startDay, staleDays, backfillSparse})`：
  按 `merchantId` 分组，每组各跑一遍 `buildPriceTrendPoints`（同一套逐日 as-of、区间切片、
  30 天陈旧上限），返回按「记录日数量」降序（默认选前 3 家）；
- `priceRecordDays(records)`：真实记录日本地日期集合（「有记录才画点」）。

`IngredientDetailPageState` / `ProductDetailPageState` 新增 `merchantSeries` 与 `chartRecordDays`，
由各自的 `_loadChart` 用同一批 `result.records` 构建（切区间时同步刷新）。

### 图表（`CostTrendChart`）

- 新增 `merchantSeries` / `recordDays`。
- `merchantSeries.length >= 2` 时标题下出现两个 ChoiceChip：**综合 / 按商家**；
  进入「按商家」后出现横向 `FilterChip` 列表（默认选中记录数最多的前 3 家，可用色点区分）；
  至少保留 1 家，避免空图；切换区间时只在「商家集合变化」时重置默认选择，手动勾选保持。
- 按商家模式绘制：每家一条固定色板（`kMerchantLineColors`，与 Web 同组色）的均价平滑线，
  **只在该商家真实有记录的日子画点**（as-of 携带日不画）；Y 轴按选中商家的均价范围缩放；
  tooltip 逐行列出各商家当日均价（含色点）。
- 综合模式也补了「只在记录日画点」（`recordDays`）。
- 折算叠加序列与「按商家」互斥（按商家模式不画紫色折算带，避免混淆）。

### 验证

- `flutter analyze`：No issues found。
- 新增 `test/features/prices/utils/merchant_trend_test.dart`（3 例：分组/排序/记录日、
  无商家记录被忽略、`priceRecordDays` 去重）+ 原有 4 例模型测试 → 7 passed；
  `test/features/ingredients + products + recipes/widgets` → 132 passed。



- `flutter analyze`：仅剩 1 条**既有**提示（`test/features/products/screens/product_list_stale_search_test.dart`
  的 `prefer_const_constructors`），本次改动无新增。
- 新增 `test/shared/models/computed_price_point_test.dart`（4 例）：每克→每斤折算（猪肉
  5.80–29.90 / direct 6.59）、缺字段降级、商家折算字段解析、直接价默认非折算行。
- `flutter test test/features/ingredients test/shared/models/computed_price_point_test.dart`
  → 31 passed。
- 未实机跑 App（需登录 + 后端重启加载新接口参数）；后端参数用真实库离线验证过
  （猪肉 6 家从属聚合、食用油 3 家超期替换）。

## 注意

- 移动端与 Web 共用后端折算口径；后端由 VS Code 调试进程启动（无 `--reload`），
  改 Python 后必须重启调试会话，否则移动端仍会拿到「无折算」的旧响应。
- 移动端折算价按「斤」展示（与移动端趋势图既有口径一致）；若后续要跟随用户质量单位偏好，
  需在 `ComputedPricePoint` 增加单位因子参数。

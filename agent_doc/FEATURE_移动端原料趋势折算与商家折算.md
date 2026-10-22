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

## 追加 2：开关只在真有关系时出现；「综合/按商家」改为下拉

用户反馈两条：

1. **胡萝卜（无任何替代/从属关系）也显示了「含替代/从属」开关**：之前原料详情页写死
   `showComputedSwitch: true`。改为 `_showComputedSwitch(state)`：
   - 层级关系（`parentRelations` / `childRelations` / `expandedRelations`）里出现
     `fallback` / `substitutable` / `contains` / `recipe` 才显示；
   - 兜底：已经拿到 `source != 'direct'` 的折算点（例如半成品/从属聚合命中）也显示。
     注：后端已移除「同名商品匹配」（见 FEATURE_原料趋势替代从属折算.md 第六轮），
     所以不会再出现 `name_match` 来源。
   胡萝卜没有这些 → 开关不出现。
2. **「综合/按商家」要和区间一样做成下拉**：两枚 ChoiceChip 换成标题栏里的
   `DropdownButton<TrendViewMode>`（`key: merchant_mode_dropdown`），与区间下拉同一形态、
   同一行（≥2 家商家时出现）；商家多选 FilterChip 行保留在「按商家」模式下。

验证：`flutter analyze` No issues found；商家序列 7 例 + 原料/商品 77 passed。

## 追加 3：无关系原料仍画折算线 / 下拉字号不一致

用户反馈两点：

1. **胡萝卜（无关系）图表里仍有「含替代/从属」的线和范围**。
   根因不在开关显隐，而在数据：`price-series` 会返回**每一天**的点，多数原料每天都是
   `source: direct`；移动端 provider 之前把整段都存进 `computedPoints`，图表又不过滤，
   于是把 direct 的 min/max 当成「折算区间」画成了紫色虚线与区间带。
   Web 端本来就有 `source !== 'direct'` 的过滤，移动端漏了。
   - 新增 `nonDirectComputedPoints(points)`（`shared/models/computed_price_point.dart`）；
   - provider 存折算序列时过滤；图表侧再过滤一次（双保险）；
   - 现在胡萝卜 `computedPoints` 为空 → 不画线/带，开关也不出现（两者一致）。
2. **「综合/按商家」下拉字号与时间区间下拉不一致**：模式下拉的 `DropdownMenuItem` 设了
   `labelMedium`，区间下拉用默认样式。去掉自定义 `style`，两个下拉统一走
   `DropdownButton` 默认字号。

验证：新增 1 例 `nonDirectComputedPoints` 过滤测试（共 8）→ passed；`flutter analyze` No issues found。

## 追加 4：商家选择从「单行 chips」改为下拉

用户反馈：按商家模式下的商家开关挤在一行，看不出能不能横向拖动，不建议单行标签，改下拉更好。

- 删除横向 `ListView` + `FilterChip` 行；
- 改为**下拉式触发器**（`key: merchant_selector`）：描边圆角框 + 当前选中摘要
  （≤2 家显示名字，>2 家显示「A、B 等 N 家」）+ 下拉箭头；
- 点开是**底部勾选面板**（`showModalBottomSheet` + `CheckboxListTile`，色点对应曲线颜色，
  右上角「完成」）：移动端比单行 chips 更好点，也避免了「拖动」暗示；
- 勾选实时生效、至少保留 1 家；点「完成」/点遮罩关闭后回写选中集合（遮罩取消不丢已勾选项）。

验证：`flutter analyze` No issues found；原料+商品+模型相关 **91 passed**。

## 追加 5：按商家显示价格区间带

用户反馈：移动端「按商家」只有均价线，没有区间。

- `buildPriceTrendPoints` 本来每天就有 `minCost/maxCost`（该商家当天各商品价的极值），
  之前按商家模式只用了 `avgCost`；
- 现在按商家模式：
  - Y 轴范围按选中商家的 `minCost/maxCost` 计算（区间不会画出画布）；
  - 每家在该商家「当天有区间跨度」的日子画同色低透明度区间带（≥2 个点才成带）；
  - tooltip 该商家行追加 `(min ~ max)`；
  - 仍只在真实记录日画点。

验证：`flutter analyze` No issues found；商家序列/折算模型 8 passed。

## 追加 6：仅折算序列也能画图（猪肉「暂无成本历史数据」）

用户反馈：猪肉（0 条直接商品记录）在移动端提示「暂无成本历史数据」，打开含替代/从属也没用。

根因：图表的「有数据」判定与 X 轴都只看直接价序列 `points`——
`_buildBody` 在 `points.isEmpty` 时直接渲染空态；画布的横坐标也只由 `points` 的日期构成，
即使把折算点传进去也没有可落笔的位置。Web 端是「直接价或折算任一存在就画」，移动端漏了。

改动（`CostTrendChart`）：

- 空态判定改为 `points.isEmpty && computed.isEmpty`（含替代/从属开着、有折算点 → 画图）；
- 新增 `dateAxis`：优先直接价日期，points 为空时用折算点日期兜底；`xAt`、商家/折算的
  日期对齐、触摸映射、X 轴首/中/尾标签全部改走 `dateAxis`；
- 主序列（区间带/虚线/均价线/记录日圆点/单点）仅在 `points` 非空时绘制；
  折算叠加与十字线、X 轴标签移出该守卫，仅折算时也执行；
- tooltip 触摸日期取轴日期；仅折算时只显示日期 + 折算行（无主序列 avg/range 行）。

验证：新增 widget 回归 2 例（仅折算→不显示「暂无成本历史数据」且开关在；两者皆无→仍显示空态）
→ 10 passed；`flutter analyze` No issues found。另：`test/features/ingredients+products` 里
7 个详情页测试 `pumpAndSettle` 超时**与本改动无关**（已用 stash 验证无本改动同样失败，
为另一会话「关联与换算」引入），未纳入本次提交。



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

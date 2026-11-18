# FEATURE_跨地区物价对比（一期）

> 分支：后端+Web master `350dc521` → 合入 feat/mobile-app（merge `49208ca1`）；移动端 feat/mobile-app `f1566862`。
> 一期范围：批量对比端点 + 对比页（概览 / 原料·商品）+ 详情页「商家｜地区」维度切换。菜谱·试算对比、热力图为二三期。

## 需求与设计原则

数据范围跨多个地区时，对比各地区原料/商品价格、菜谱与试算成本、商家物价热力图。痛点是功能多、两端不知如何展示。

**设计原则（用户定调）**：全部参照现有「按商家」比较的交互模式，新增能力一律以**维度切换**进入现有控件——**不新增卡片、不新增区块、控件数量不增加**。用户已经会「综合/按商家」，把维度换成地区即可。

## 口径（三端一致）

- **卡片价** = 每标准单位综合价口径（`get_weighted_ingredient_price` mode="recent" 等价实现：每商品「最近有记录日」每标准单位均价 → 30 天参与上限、全部超期放开 → 权重加权），与详情页综合价可对照。
- **趋势** = ¥/斤 前向携带加权（sparklines 同口径），跨商品可比。
- **物价指数** = 基准地区（region_ids 第一个）对「近一年有记录的共同商品篮子」的单价比率中位数 ×100（基准=100）。偶数个取中间两值均值（与后端 `statistics.median` 一致）。
- 取数窗口 365 天：卡片价/篮子只看近一年有记录的商品（趋势携带起点必然落在窗口内）。
- 未分配地区的商家计入所有地区（`apply_region_filter` 既有口径），矩阵/热力图 UI 需标注。
- 地区对比的每个 region_id 单独作为一棵子树过滤（与会话 X-Region 的「并集范围」语义不同，不复用会话头）。
- 所有价格经 `record_price_in_user_currency` 折算到用户/会话币种。

## 后端（master）

新 `backend/app/api/comparison.py` + `schemas/comparison.py`，`main.py` 挂 `/api/v1/comparison`（带会话币种依赖）：

- `GET /comparison/regions` — 有价格记录的地区候选（按记录数降序；无地区商家不产生候选）。
- `GET /comparison/summary?region_ids=&days=` — 每地区记录数/商品数/物价指数/篮子日均价趋势（每地区一次 365d 大查询 + 内存走查 `_basket_daily_series`，算法与 `_ingredients_sparklines_batched` 同构：前向携带 + 30 天参与上限 + 全超期放开）。
- `GET /comparison/entity-prices?entity_type=&entity_ids=&region_ids=&days=` — 实体×地区矩阵：每格卡片价（`_region_price_data` 一次取数 + `_entity_card_price` 复刻 mode="recent" 聚合）+ 趋势（复用 `api.sparklines._ingredients/_products_sparklines_batched`）+ `days_since_record` 陈旧标记。响应含 `regions` 元数据（名称/display_name）供列头与地区卡。
- 上限：region_ids≤6、entity_ids≤50、days≤90；`_parse_region_ids` 去重保序。
- **ProductRecordResponse 补 `merchant_region_id`**（纯列值，零额外查询；5 处序列化点同步）——前端「按地区」趋势靠它把记录分组，无需额外拉商家列表。
- 无表结构变更，不需要 alembic/SQL 脚本。

## Web（master）

- **路由 `/compare`** + 侧栏「物价对比」入口（桌面 + 移动抽屉，`mdi-compare`，在商家之后）。
- **`views/compare/CompareView.vue`**：v-tabs 两块（概览 / 原料·商品），tab/地区同步 URL query；首次进入自动带入候选地区前 3。
  - 概览：`RegionMultiSelect`（复用自定义计算范围的现成组件）+ 地区摘要卡（物价指数 + 记录/商品数 + SparklineBackground + 最低徽标）+ `SimpleBarChart` 物价指数条形（基准=100 高亮）+ `PriceTrendChart` 篮子均价趋势（多地区叠加，`compareLabel`「按地区」）。
  - 原料·商品：实体类型切换 + `v-autocomplete` 多选（`v-model:search` + 300ms 防抖 + `custom-filter=()=>true`，端点 `/ingredients` 与 `/products/entity`）+ `RegionPriceMatrix`（行=实体、列=地区、每行最低价绿色加粗、缺失「—」、超期灰色时钟图标）。
- **`composables/useRegionPrices.ts`**（详情页共用）：`fetchPricedRegions`（会话级模块缓存）、`loadEntityRegionPrices`（卡片数据 + 最低价标注）、`buildRegionSeriesFromRecords`（**与「按商家」同构**：同一批图表记录按 `merchant_region_id` 分组、同一 `buildWeightedAsOfDailySeries` 口径，保证综合/按商家/按地区三模式在同一张图上刻度一致）。
- **`PriceTrendChart.vue` 泛化**：`MerchantSeries.merchantId` 类型放宽为 `number|string|null`（语义=序列键），新增 `compareLabel` prop（默认仍「按商家」）。现有调用零改动。
- **原料/商品详情维度切换**：价格卡区「商家｜地区」二选一（`v-btn-toggle`，仅候选地区≥2 时出现）；地区卡 = 地区名 + 每标准单位加权价 + 30 天迷你图 + 最低徽标 + 超期「最近记录 N 天前」；切到地区首次才拉 `entity-prices`（懒加载）。趋势图 `comparisonSeries` 跟随维度。
- **本地模式**：`api/local/handlers/comparison.ts`（`regionSubtree` 子树过滤 + `priceNormalize.rawUnitPrice` 卡片价 + `buildWeightedAsOfDailySeries` 趋势；中位数与后端 `statistics.median` 对齐）+ proxy 注册；本地价格记录回填 `merchant_region_id`。
- i18n：`compare` 命名空间 27 键 + `charts.byRegion` + `nav/routes.compare` + `localErrors` 四键 + `ingredients/products.regionPrices`（`scripts/add-compare-i18n.py` 幂等脚本；本地 handler 报错走 `localError` 码）。

## 移动端（feat/mobile-app）

- **`features/comparison/`** 新模块：repository（三端点 + `searchEntities` 实体搜索）→ provider（StateNotifier + 请求序号防竞态）→ `CompareScreen`（TabBar 两块）。
- **路由 `/compare`**：宽屏 NavigationRail 第 10 项（`Icons.compare_arrows`）；窄屏进「更多」胶囊网格（`_moreMenuTabs`）。
  - **坑**：10 个 `labelType: all` 目的地在 800×600 视口纵向溢出 48px；rail 内部含 Expanded **不能套裸滚动容器**（unbounded height 报错）。修复：`LayoutBuilder` + `SizedBox(height: max(视口, 660))`——视口足够高时 rail 填满不滚动，矮视口时可滚。660 为 10 个目的地的固有高度 + 余量。
- **概览**：地区选择底部弹层（候选 checkbox 多选 2-6，`/comparison/regions` 候选 + 搜索框）；地区摘要卡横向滚动（指数 + 徽标）；物价指数条形（Row + FractionallySizedBox）；篮子均价趋势 = `CostTrendChart` + 地区序列包装成 `PriceMerchantSeries`（regionId 塞 merchantId 字段）+ `compareLabel`/`compareSuffixBuilder`。
- **原料·商品**：实体类型 DropdownButton + 搜索底部弹层多选 + `RegionPriceMatrix`（冻结首列 + 横向滚动，同商家比价矩阵布局）。
- **详情页维度切换**（原料 + 商品）：`_LatestPriceCard` 内 `SegmentedButton`（商家｜地区，≥2 个有数据地区才出现）+ `RegionPriceCardList`（116px 卡片，同 `MerchantPriceList` 布局：地区名 + 每标准单位价 + Sparkline + 最低奖杯图标 + 超期置灰）；趋势图序列跟随维度。provider 在 `_loadChart` 前 `_ensureRegionCandidates`（地区名图例），首次切地区才拉卡片数据。
- **`price_trend.dart`**：`PriceRecord.merchantRegionId` + `PriceRegionSeries` + `buildRegionTrendSeries`（与 `buildMerchantTrendSeries` 同构：分组 → 同一套 as-of + 30 天上限 + 回退全量判据）。
- **`CostTrendChart`** 加 `compareLabel` / `compareSuffixBuilder` 参数（默认路径字节不变）。
- l10n 三语 31 键（`scripts/add-compare-l10n.py` 追加）。
- **顺手修存量**：en/ar ARB 缺 `priceNoProductFoundCreate` 的占位符元数据导致 `catalog_integrity_test` 存量失败——补 `{"placeholders": {"name": {"type": "String"}}}`（**坑**：无 type 时 gen-l10n 按 Object 推断，与模板 String 不一致会告警）。

## 验证

- 后端：`tests/test_comparison.py` 6 例全过（候选/指数=1000 中位数口径/矩阵含无数据地区/超期放开/加权/region_ids 校验），根 .venv 有界子集；`test_products.py` 2 个登录前置失败为既有（memory 记录）。
- Web：`npm run build` ✓（53.9s）、`check:i18n` ✓、`check:i18n:sources` ✓、`test:utils` 73 ✓。
- 移动端：`flutter analyze` 0 issue；comparison 4 例 + prices utils + recipes widgets + router 28 例 + l10n 全过 = **135 例全过**；`app_bar_title_budget_test` 加 compare spec（本机缺字体按既有行为跳过测量）；`pubspec.lock` 未被 gen-l10n 改写（已 checkout 还原）。
- 本地模式：需要先在数据维护导入地区种子后手动验证（一期未自动 seed）。

## 已知边界与二三期

- 卡片价取数窗口 365 天：某地区 365 天前最后记录的实体显示「无数据」（趋势口径一致）；篮子定义同窗口。
- 本地模式地区候选显示名用 `region.name`（本地 regions store 无 display_name 计算，中文环境下与云端一致）。
- 二期：菜谱/试算成本对比（`EvaluateRequest`/`plan_cost_trend` 加显式 region_id 或对比端点直接循环调 service——service 层 `_item_cost_nutrition` 已带 region_id 参数）。
- 三期：热力图（`/comparison/heatmap`：单品模式复用 latest-price-by-merchant 聚合 + join 坐标；整体物价模式按共同商品集算商家指数）。

# 价格趋势图「区间内无记录」时空白

## 现象

原料 / 商品的价格趋势图默认选中「月」。若该实体近一个月没有任何新记录（数据整体陈旧），打开页面时图表为空，显示「暂无价格历史数据」；切到「季 / 年 / 全部」等有数据的区间后再切回「月」，图表又正常。移动端同样。

## 数据流与根因

- 取数：`frontend/src/views/ingredients/IngredientDetail.vue` / `frontend/src/views/products/ProductDetail.vue` 的 `loadChartPriceRecords(startDate)` 把记录累积进 `chartPriceRecords`，请求 `/products`（原料传 `ingredient_id`、商品传 `product_id`）时带 `start_date`。
- 计算：图表数据按 **as-of** 口径生成——每个商品取「最近有记录日」的当日均价，并一直有效到下一次记录（`frontend/src/utils/priceAsOf.ts` 的 `buildWeightedAsOfDailySeries`，含 30 天参与上限、当日全部超期时放开）。
- 渲染：`frontend/src/components/charts/PriceTrendChart.vue` 只按所选区间对 `props.data` 切片，自己不再取数。
- 根因：as-of 需要「区间之前最近一次记录」作为携带起点，而取数用 `start_date` 把区间外的记录全部挡掉了。区间内一条记录都没有时序列无从生成 → 空数组 → 显示「暂无价格历史数据」。切到更宽的区间后记录进入累积池，再切回窄区间由 `PriceTrendChart` 本地切片（携带价覆盖到区间末尾），于是「切回来就有了」。
- `ProductDetail.vue` 更严重：它原来的图表是「按自然日分桶、只画有记录的日子」，即使取到全量、所选区间没有记录日也仍然空白。

复现（真实库，2026-10-13，`start_date=2026-09-13`）：

| 实体 | 近 30 天窗口 | 全量 |
| --- | --- | --- |
| 原料 473（苹果） | 0 条 | 6 条 |
| 商品 142 | 0 条 | 12 条 |

## 修复

1. 新增共享判断 `shouldLoadFullPriceHistory({ windowStart, windowHits, loadedCount })`（`frontend/src/utils/priceAsOf.ts`）：区间命中 0 条且累积池为空 → 需要回退「全量」请求。
2. `IngredientDetail.vue` / `ProductDetail.vue`：请求与合并抽成 `fetchChartPriceRecords(start?)`；区间取数 0 命中且池为空时补发一次不带 `start_date` 的「全量」请求（沿用既有 30s 长超时），让 as-of 序列拿到携带起点。
3. `ProductDetail.vue`：图表口径改为逐日 as-of（与原料详情、后端迷你图同源）；价格卡片右侧的「区间 / 记录数」改由新的 `latestRecordStats`（最近一次记录日）提供，不再从图表尾点推导。
4. 移动端 `mobile/lib/features/prices/utils/price_trend.dart`：`buildPriceTrendPoints` 改为同口径 as-of（`startDay` / `endDay` / `staleDays` 可注入；本端暂无用户权重，各商品等权），`ingredient_provider.dart` / `product_provider.dart` 的 `_loadChart` 在区间取数为空时回退全量取数，并用 `startDay` 把序列截到所选区间起点。

## 验证

- 真实数据端到端（真实 DB + 运行中的后端取数，再用 `frontend/src/utils/priceAsOf.ts` 复算「月」视图切片）：修复前 0 点（即用户看到的空白），修复后 30 点，尾值 = 最近一次已知价（原料 473 avg 2.90；商品 142 avg 3.135）。
- `npm run test:utils`：16/16（新增 `shouldLoadFullPriceHistory` 真值表用例）。
- `npm run build`：通过。
- 移动端：`flutter analyze` 0 issue；`flutter test test/features/prices/utils/price_trend_test.dart` 6/6（新增「区间内没有新记录时补满区间」「startDay 截断」「陈旧商品在有新鲜商品时被排除」等）；全量 `flutter test` 576 项，6 项为存量失败（apple_map×3、locale_preferences×2、my_proposals×1）。

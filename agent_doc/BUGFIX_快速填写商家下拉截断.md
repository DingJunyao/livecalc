# BUGFIX：快速填写商家下拉缺少「美道家万达广场店」

日期：2026-10-21
范围：移动端快速填写（flutter）+ Web 快速填写（vue），无后端改动。

## 现象

用户反馈：移动端「快速填写」的商家下拉里没有「美道家万达广场店」。
要求同时检查 Web 端是否有同样问题。

## 根因（数据流逐层确认）

只读查询 `backend/data/livecalc.db`（sqlite，只 SELECT 未改库）：

- `merchants` 共 16 家，其中 `is_open=1` 14 家；
- `美道家万达广场店`：`id=4`、`is_open=1`、`region_id=1951`、`created_at=2026-03-15`；
- 后端 `GET /merchants` 默认 **`limit=10`**、按 `created_at DESC` 排序（`backend/app/api/merchants.py:794/853`）；
- 按该排序，`美道家万达广场店` 位于营业商家**第 12 位** → 默认 limit=10 时被截断。

各层请求参数：

| 端 | 请求 | 结果 |
|---|---|---|
| 移动端 `quick_fill_screen.dart` `_loadMerchants` | `GET /merchants`（**不带任何参数**） | 后端取默认 limit=10 → 只有最新 10 家，缺 id=4 |
| Web `QuickFillView.vue` `loadMerchants` | `GET /merchants?limit=100` | 14 家全拿到，本次未复现 |
| Web 其它商家下拉（价格页/商品详情/原料详情/记价对话框） | `limit: 100` | 同上，本次未复现 |

结论：移动端是**直接复现**；Web 端的同类隐患是「只取第一页、硬编码 100 上限」，商家超过 100 家时会同样漏店（并非本次现象的原因）。

## 修复

两端都把「只请求一页」改为**按 `total` 翻页取全**（单页用后端上限 100，最多 10 页兜底）：

- `mobile/lib/features/prices/screens/quick_fill_screen.dart`：新增 `_fetchAllMerchants()`，`_loadMerchants()` 在无测试注入时调用它。
- `frontend/src/views/prices/QuickFillView.vue`：`loadMerchants()` 改为 skip/limit 循环，累积全部 `items`。

筛选口径保持不变：仍为「营业中商家 + 用户计算范围内」（与 Web 其它下拉一致），不包含已关闭商家。

## 验证

- Web：`pnpm run build` 通过。
- 移动端：`flutter analyze lib/features/prices/screens/quick_fill_screen.dart` → No issues found；
  `flutter test test/features/prices/screens/quick_fill_screen_test.dart` → 3 tests passed。
- 数据库只读核对：营业商家 14 家，按创建时间倒序「美道家万达广场店」第 12 位，修复后 limit=100 一页即可覆盖。

## 遗留

- 其它商家下拉（Web 的 `PricesView` / `ProductDetail` / `IngredientDetail` / `QuickPriceRecordDialog` / `PriceRecordForm`，以及移动端 `merchantListProvider` 首屏 20 条）仍是「固定上限、不分页」的实现；商家规模超过各自上限时会同样漏店，建议后续统一改成翻页取全或服务端搜索。

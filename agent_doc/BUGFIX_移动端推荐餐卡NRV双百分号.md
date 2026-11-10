# BUGFIX: 移动端今日推荐餐卡 NRV 双百分号

## 现象

用户报告：移动端「今日推荐」的早/午/晚餐卡片中，四项营养素的 NRV 行显示成 `NRV 12.5%%`（百分号重复）。

## 根因

`mobile/lib/features/home/widgets/meal_card.dart` 的 `_nrvSuffix`：

```dart
'NRV ${formatPercentValue(pct, maximumFractionDigits: 2)}%'
```

`formatPercentValue`（`core/i18n/app_formatters.dart`）本身已经会在末尾拼一个 `%`，模板字符串又手动拼了一个 → `NRV xx%%`。web 侧的 `MealCard.vue#nrvText` 是 `` `NRV ${pct}%` ``（裸数字 + 一个 %），没有此问题——「与 web 餐卡同格式」只在 mobile 抄坏了一层。

## 修复

- `meal_card.dart`：去掉手动拼接的 `%`，只保留 `formatPercentValue` 自带的。
- 排查其余 `formatPercentValue` 调用点（nutrition_card / recipe_detail / nutrition_source_grid / cost_proportion_chart）均无重复拼接，仅此一处。

## 验证

- `meal_card_test.dart` 新增断言：`find.text('NRV 54.9%')` 精确匹配 + `find.textContaining('%%')` findsNothing。
- 受影响测试（meal_card / localized_home / planner / nutrition_display）22 例全过；`flutter analyze` 无新增。

分支：feat/mobile-app。无后端 / 迁移改动。

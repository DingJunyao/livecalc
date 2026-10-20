# BUGFIX：移动端试算详情配色一致

## 问题

移动端试算详情的「食材成本占比」与「营养贡献溯源」中，同一个条目可能使用不同颜色。

## 原因

- 后端 `/meal-plans/evaluate` 的 `nutrition.ingredient_details[].ingredient_id` 使用的是方案条目 `item_id`。
- 移动端成本占比却取 `recipe_id / ingredient_id / product_id`，两处配色标识不同，`getIngredientColor` 自然会得到不同颜色。
- Web 成本占比与营养溯源都使用 `item_id`，因此移动端与 Web 口径也不一致。

## 修复

移动端 `PlanDetailScreen._costBreakdown` 改为和营养溯源一样使用求值结果里的 `item_id` 配色。缺失 `item_id` 时两处都会落入灰色兜底，仍然保持一致。

## 验证

- 新增试算详情回归：成本条与营养贡献条同时使用 `item_id=77` 的颜色。
- `flutter test test/features/planner/plan_detail_screen_test.dart`：2 passed。
- `flutter analyze`：No issues found。

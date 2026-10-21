# 趋势图「只在真有记录的日子画点」

日期：2026-10-21
范围：Web 前端图表 + 后端两个趋势接口加 `has_record`；移动端图表不涉及（本来就不画逐点圆点）。

## 需求

商家对比模式已经做到「只有真实记录日画点」，用户要求其他价格/成本趋势图也统一：
**有价格记录的日子才画点，as-of 前向填充出来的日子只连线不画点。**

## 覆盖的图表

| 图表 | 位置 | 数据来源 |
|---|---|---|
| 原料价格趋势（综合） | `PriceTrendChart.vue` | `chartPriceRecords` → 前端 as-of |
| 商品价格趋势（综合） | `PriceTrendChart.vue` | 同上 |
| 菜谱成本趋势 | `PriceTrendChart.vue` | `/recipes/{id}/cost-history-range` |
| 菜谱成本分析 | `CostTrendAnalysis.vue`（回退折线分支） | 同上 |
| 方案成本走势 | `CostTrendAnalysis.vue` | `/meal-plans/{id}/cost-trend` |

移动端 `CostTrendChart`（原料/商品/菜谱/方案）只画线 + 选中日圆点，没有逐点圆点，无需改动。

## 实现

### 前端

- `PriceTrendChart.vue`：主均价线改为逐点对象
  `{ value: [ts, avg], symbolSize: d.recorded === false ? 0 : 6 }`；
  `DataPoint` 已有 `recorded?: boolean`（缺省 = 画点，兼容未标注的调用方）。
- `IngredientDetail.vue`：`chartData` 用 `chartPriceRecords` 的真实日期集合算 `recordDays`，逐日写 `recorded`。
- `ProductDetail.vue`：`recorded: recordCountByDay.has(d.date)`（count>0 即当天有记录）。
- `RecipeDetail.vue`：`chartData` 映射带 `recorded: !!record.has_record`（后端新字段）。
- `CostTrendAnalysis.vue` 回退折线：均价线逐点 `symbolSize: chartData[i]?.has_record === false ? 0 : 4`。

### 后端

- `schemas/recipe.py`：`RecipeCostRangeResponse` 新增 `has_record: bool = False`。
- `services/recipe_service.py`：
  - 新增 `_recipe_record_days(db, recipe_id, start_date, end_date, tz)`：一次查询取「菜谱直接食材对应商品」在区间内有价格记录的本地日期集合（`ProductRecord join Product join RecipeIngredient`，按用户时区换算本地日）。
  - `calculate_recipe_cost_range_trend` 在循环外算好集合，逐日写 `has_record`（查询失败降级为空集合，不影响曲线）。
- `services/meal_plan_service.py`：`plan_cost_trend`
  - 菜谱项：透传 `point["has_record"]`（OR 聚合到当天）。
  - 散项（ingredient/product）：一次查询其商品在窗口内的记录日期（`daily` 的 key 是 UTC 日期，标记也按 UTC 日期对齐），命中即 `has_record = True`。
  - 输出新增 `has_record` 字段。
- `api/recipes.py`：区间趋势响应透传 `has_record`。

口径说明：菜谱/方案的成本是聚合值，「有记录日」定义为「当天至少有一条相关价格记录」；
个别记录因权重/超期未真正参与计算时仍会画点，属于可接受的近似（已在代码注释标注）。

## 验证

- 只读实跑（真实 SQLite 数据）：
  - 菜谱 3「上汤娃娃菜」30 天 → 31 个点、8 个记录日（如 2026-09-21/24/26、10-10/13/14/16/18）；
  - 方案 1「黄焖鸡米饭」30 天 → 30 个点、10 个记录日。
- 后端：`py_compile` 通过；`tests/services/test_meal_plan_product_unit.py`、`tests/schemas/test_recipe_cost_range.py`、`tests/test_meal_plans_api.py`、`tests/test_recipe_pending_cost.py` 共 11 passed（新增 1 项 has_record 透传回归）。
- 顺手修掉两个**时间脆弱**的老测试：`plan_cost_trend` 的用例把日期写死成 `2026-10-17` 又传 `days=1`，daily key 是「今天」，时间一过必挂；改为按 `datetime.now(timezone.utc).date()` 生成。
- 前端 `pnpm run build` 通过。

## 注意

- 后端改动的是 Python 逻辑，开发服务需重载（自动 reload）后新接口才会返回 `has_record`；若图表仍全画点，先确认后端已重启、清掉 `__pycache__`。

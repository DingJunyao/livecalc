# BUGFIX: 试算原料条目营养为空（火腿肠脂肪未计入）

## 现象

用户报告（外部环境 https://livecalc.home.a4ding.com 复现）：一顿饭里选了「火腿肠」（**原料**条目，2 根），试算合计里没有它的脂肪。方案 3（方便面青菜火腿肠胡萝卜）求值结果：`fat_g = 1.18`，只有方便面/胡萝卜/青菜三项；火腿肠条目 `nutrition: null`，且「营养来源」明细里整个缺失。

同一条数据走**商品**条目（方案 2：奥乐齐火腿肠 60g*10，2 根）则正常（fat 10.2 g）——所以是原料路径的问题。

## 根因（数据流回溯）

`backend/app/services/meal_plan_service.py` `_item_cost_nutrition` 的 ingredient 分支是手写的旧口径：

1. 直读 `nutrition_data` **首行**（`db.query(NutritionData).filter(ingredient_id==…).first()`）；
2. 数量→克用 `UnitConversionService.convert(unit→g)` 手工换算。

两条链在火腿肠这个数据形态下都断了：

- **营养源**：原料自己**没有** nutrition_data 行（营养挂在关联商品的自定义营养上）。原料营养详情页早已是 `NutritionCalculator.calculate_ingredient_nutrition` 口径——`get_best_nutrition_data` + **缺项从关联商品自定义营养加权平均回填**（每 100 g 归一），所以详情页能看到脂肪 10.95 g/100 g；试算的旧手写路径没有回填 → `mapping is None` → 营养直接跳过。
- **数量换算**：原料按「根」计数，克重经 `EntityUnitOverride`（商品换算链）给出 1 根 = 60 g。旧路径只做了 `unit→g` 一次 convert，回填后也未必与详情页同链路。

外部环境用详情页接口验证：`GET /nutrition/ingredients/240/nutrition?quantity=2&unit=根` → base_quantity 120 g、fat 13.14 g（计算器路径正常），坐实两口径分叉。

## 修复

`meal_plan_service.py` ingredient 分支的营养计算整体换成与详情页同源：

```python
NutritionCalculator(db).calculate_ingredient_nutrition(ingredient.id, quantity, unit_abbr)
```

- 返回的 `nutrition.all_nutrients` 已按请求量缩放，键是显示名（附 `original_key` 英文键）；逐条取 `original_key or KEY_BY_NAME[显示名]` 汇成 `nutrient_values`（能量经 `energy_to_kcal` 归一）；
- `out["nutrition"]` 四项（calories/protein_g/carbs_g/fat_g）从同一份 values 取，保证条目合计、totals、营养来源明细三处同源；
- 成本计算（原料加权价）不变；`_build_plan_nutrition` / `_evaluate_stub_items` 不变。

清理：`NutritionData` import、旧 `_to_grams` 闭包删除；模块 docstring 的 ingredient 口径说明同步更新。product / recipe 分支不动（商品条目本就走 `calculate_product_nutrition`，未复现问题）。

## 回归测试

`backend/tests/services/test_meal_plan_product_unit.py` 新增 2 例（口径：原料无自有营养行 / 有自有营养行 × 数量用计数单位「根」）：

- `test_ingredient_nutrition_from_product_backfill_with_count_unit`：原料无 nutrition_data + 关联商品自定义营养（每 100 g fat 10）+ `EntityUnitOverride` 1 根=120 g → 2 根求值 fat_g=24、calories=480，且 `ingredient_details` 里火腿肠的 fat 贡献=24（旧实现此处为 null）。
- `test_ingredient_nutrition_uses_own_row_with_count_unit`：原料有自有营养行（每 100 g fat 25）+ 1 根=80 g → fat_g=20。

**测试环境坑**（两条都是既有经验，再次踩到）：

1. 手建质量单位必须设 `si_factor`（kg 口径，g=0.001），否则覆盖克重解析退化；
2. 内存测试库默认**没有 kg 单位**，`_get_piece_weight_kg` 需要 `get_unit_by_abbr("kg")` 才能把覆盖克重折成 kg——新增 `_ensure_kg_unit` get-or-create 助手（存在则不删，避免撞 `unit.abbreviation` 唯一约束）。

## 验证

- `tests/services/test_meal_plan_product_unit.py` 7/7 过（含 3 个存量用例）。
- 相关子集（meal_plans_api / meal_plans_models / meal_recommendation_items / ai_policy）与 stash 基线结果一致（`test_daily_recommendation_has_items_not_recipe_id` 在该批量组合下基线也挂，属共享内存库相互干扰的既有现象，单跑即过）。
- 外部环境待部署后复核：方案 3 求值火腿肠应计脂肪（2 根 ≈ 13.14 g，与详情页同口径）。

分支：master（后端），两端共用；合并入 feat/mobile-app。无迁移、无表结构变更。

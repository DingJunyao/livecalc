# FEATURE: 试算页（meal_plans，阶段 3）

- **日期**：2026-10-16
- **分支**：后端 + web（master 679567a0 / 85491731），移动端（feat 86a596f7）
- **关联**：设计 [docs/plans/2026-10-15-favorites-ai-meals-planner-design.md](../docs/plans/2026-10-15-favorites-ai-meals-planner-design.md) §5

## 功能

用户自己搭配一顿/一日（菜谱条目 + 原料/商品散项），实时看**成本与四营养素合计 vs 目标**；已保存方案可看**成本按历史价格 as-of 逐日折算的走势**；可一键**设为今日推荐**（推荐页渲染方案视图），换整餐后翻回 AI/规则来源。

## 数据模型

- `meal_plans`：user_id / name / kind('meal'|'day') / note + AuditMixin（软删）。
- `meal_plan_items`：plan_id / group(breakfast|lunch|dinner|other) / item_type('recipe'|'ingredient'|'product') 三选一 CheckConstraint / servings（菜谱项）/ quantity+unit_id（原料商品项）/ sort_order / note + AuditMixin。
- `daily_recommendations.plan_id`（FK meal_plans，nullable；source='plan' 回链）。
- 迁移 `20261015_0003`；SQLite 脚本注意 `"group"` 是保留字要加引号。

## 计算（`meal_plan_service.py`）

- **recipe 项**：`calculate_recipe_cost(servings_override=servings)`（成本随份量缩放）+ `calculate_recipe_nutrition` per_serving（与推荐 totals 同口径）。
- **ingredient 项**：`get_weighted_ingredient_price(target_unit_abbr=单位)` × 数量（单位不一致走 `UnitConversionService.convert` 实体覆盖换算）；营养 = `nutrition_data.nutrients.all_nutrients`（标准 key energy/protein/carbohydrate/fat）× 数量克数 / 基准克数（基准单位也走实体换算 + 密度兜底）。
- **product 项**：最新有效记录单价（price/standard_quantity）× 换算数量；无营养。
- **targets**：day=每日目标；meal=每日目标 × `MEAL_RATIOS[meal_type]`（budget 同缩放）。
- **cost_trend**：菜谱项 `calculate_recipe_cost_range_trend` avg 档 × servings；原料项逐日 `get_weighted_ingredient_price(as_of)`；商品项最新价前向填充。

## API

- `/meal-plans` CRUD（仅本人；items 全量替换保存；三选一/分组校验 400）
- `POST /meal-plans/evaluate`（草稿不落库求值）
- `GET /meal-plans/{id}/cost-trend?days&offset_days`
- `POST /meals/recommendations/set-plan` `{plan_id, meal_type?}`：meal 需 meal_type（缺省取当前餐）；day 设三餐；该餐无推荐时直接新建 plan 来源行。响应经 `_build_response_from_records`：source='plan' 的餐渲染 `plan` 视图（id/name/kind/items/totals，条目带 name 与单条 cost）并计入 totals；**换整餐刷新后 source 翻回 AI/规则、plan_id 清空**。

## 三端

- **web（85491731）**：`api/mealPlans.ts` + `views/plans/PlansView.vue`（列表卡片 + 编辑器：菜谱/原料/商品三类搜索添加、份量/数量编辑、一日分组、求值 vs 目标、echarts 趋势 30/90/365 天、保存/删除/设为今日）；侧栏导航 `/plans`；推荐卡「拿去试算」→ sessionStorage 草稿 → /plans 载入。**本地模式**：IndexedDB `meal_plans` 单 store（items 内嵌，DB v5）、handlers 同契约、`set-plan` 写 meal_recommendations 行、导出白名单加入。
- **移动端（86a596f7）**：`features/planner/`（repository + provider + 列表屏/编辑屏），路由 `/plans`、`/plans/edit`，桌面侧栏 + 「更多」菜单入口（Wrap 换行）。趋势用 CustomPainter 折线（无 fl_chart 依赖）。设为今日后提示回首页查看。

## ⚠️ 存量库迁移

`backend/scripts/sql/20261015_meal_plans_sqlite.sql`：两张新表 create_all 可自动建，但 **daily_recommendations.plan_id 列**必须手工执行脚本添加（可重复执行）。

## 测试

- `test_meal_plans_models.py`：CRUD/CheckConstraint/软删/plan_id 回链。
- `test_meal_plans_api.py`：CRUD + evaluate（目标=每日×0.35 校验）+ 三选一 400 + cost-trend 结构 + set-plan（plan 视图渲染）+ 换整餐翻回来源。
- 全量：相关回归 14 项全绿；web build/i18n/tsc 131；移动端 analyze 0 error / test 679 通过 6 存量失败。

## 经验

1. **python 批量改代码的锚点必须先验证唯一性**：`_plansTab` 以 `const _profileTab = _Tab(` 为锚插入，结果吃掉了 `_favoritesTab` 的定义（它同样以该行结尾）→ analyze 报 duplicate `_profileTab` + undefined `_favoritesTab`。
2. **set-plan 新建的方案来源行没有 items**，会撞上刷新守卫「无 items = 暂无推荐」——方案来源餐要放宽该守卫（允许从空 items 刷新）。
3. SQLite 脚本中 `group` 是保留字，列名要写 `"group"`。
4. 响应新增字段（`plan`）必须同步加进 pydantic 响应模型，否则被静默剥离（测试断言 KeyError: 'plan' 才发现）。

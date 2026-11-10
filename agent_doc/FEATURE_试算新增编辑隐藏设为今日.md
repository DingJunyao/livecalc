# FEATURE: 试算新增/编辑态隐藏「设为今日」

## 背景

用户报告：试算页的「设为今日」按钮（`verified_outlined` / `mdi-clipboard-check-outline` 图标）与「保存」按钮相邻，容易搞混。要求：**新增、编辑时不应显示「设为今日」按钮**。

## 改动口径

「设为今日」只保留在**非编辑入口**：

- 试算列表页：web `PlansView.vue`（行内按钮 + 一顿方案的餐次菜单）、移动端列表行，均不变。
- 移动端方案详情页（`/plans/:id`，浏览态）：保留在 ⋮ 菜单，不变。

## 改动点

### Web（master）

`frontend/src/views/plans/PlanDetailView.vue`：该页面始终是新增/编辑态（名称、条目、保存/取消都在页面上），按需求整块移除 app-bar 里的「设为今日」（一顿方案的餐次 v-menu + 一日的直按按钮），仅保留 ⋮ 计算菜单与删除按钮。连带清理死代码：`settingToday` ref、`mealTypeOptions` computed、`onSetToday`、`setPlanAsRecommendation` import（`PlansView.vue` 仍在用该 API，key `plans.setToday*` 不动）。

### 移动端（feat/mobile-app）

`mobile/lib/features/planner/screens/planner_screens.dart` 试算新建/编辑页：AppBar 移除「设为今日」IconButton（原来紧挨保存图标），连带删除该页私有的 `_setToday`（保存后跳详情，详情 ⋮ 里可设今日）。列表与详情的入口不变。

## 验证

- web `npm run build` ✓、`check:i18n` ✓。
- 移动端 `flutter analyze` 无新增；planner 相关测试全过。
- `app_bar_title_budget_test.dart` 的 `planner_form` spec 同步 icons 3→2（AGENTS.md 要求 actions 增删后同步该表；本机缺 simhei/arial，预算测量用例按既有环境失败跳过，stash 对照确认与本次无关）。

分支：web 部分 master；移动端 feat/mobile-app。

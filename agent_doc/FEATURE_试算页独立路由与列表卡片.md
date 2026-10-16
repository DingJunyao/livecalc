# 试算页独立路由（/plans/new、/plans/:id）与列表卡片增强

## 背景

用户反馈两点：

1. 二级页面（方案详情 / 新增）不是独立路由 —— 无法直接打开、刷新、从浏览器历史回到某个方案的详情；
   之前的「编辑」只是 `/plans` 路由内一个 `editing` 开关。
2. 试算列表页只有「名字 + 条目数」，看不到成本、营养素与趋势迷你图（原料列表/详情已有这套观感）。

## 独立路由

- 新增 `frontend/src/views/plans/PlanDetailView.vue`（二级页面），`PlansView.vue` 拆成纯列表页。
- 路由（`frontend/src/router/index.ts`）：
  - `plans/new`（name `plan-new`）**必须排在** `plans/:id`（name `plan-detail`）之前；
  - 两条路由共用 `PlanDetailView`，由 `route.params.id` 区分「新增」与「详情」（`planId` computed，非数字 → null）。
- 详情页：
  - AppBar 返回箭头 → `/plans`（真实路由跳转），标题 = 方案名 / 新建方案；
  - 标题右侧 `CalcContextMenu` + 「设为今日」+「删除」（仅已保存方案）；
  - 新建保存成功后 `router.replace('/plans/:id')` —— 刷新 / 分享都落在同一个方案上，不会重复新建；
  - 删除前弹确认（`useConfirmDialog` + 新 i18n 键 `plans.deleteConfirm`，三语）；
  - 路由 `fullPath` 变化时重新载入（列表点进另一个方案、新建后 replace 成 `:id` 都走这条）。
- 「拿去试算」草稿流：`views/meals/DailyMealsView.vue` 改为 `router.push('/plans/new')`；
  草稿由详情页在「无 id」时消费（读后即删 sessionStorage）。
- 列表页整卡可点进详情：`@click` + 动作按钮 `@click.stop`（**不要**用 `v-card :to`，见经验 2）。

## 列表卡片增强（对齐原料列表 / 详情的观感）

- 逐条并发拉取（方案数量少）：
  - `POST /meal-plans/evaluate`（`kind` + 按条目分组推导的 `meal_type` + `items`）→ 成本 / 热量 / 蛋白质 / 脂肪；
  - `GET /meal-plans/{id}/cost-trend?days=30` → 迷你图数据（数值数组）。
- 卡片：`SparklineBackground`（30 天成本，`color="tertiary"`，仅当存在非 0 值时渲染）+ 成本
  （`text-subtitle-1 font-weight-bold text-tertiary`）+ 一行营养素 + 原有的条目数 / 设为今日 / 删除。
- 单条失败静默（`try/catch` per plan + `Promise.all`），不影响其它卡片；`planStats` / `planTrends` 以方案 id 为键，
  删除方案时同步清理。

## 验证

- `npm run build` ✓（`PlanDetailView` 单独产出 chunk：`dist/assets/PlanDetailView-*.js`）
- `npm run check:i18n` ✓（3 份语料键树一致）/ `check:i18n:sources` ✓ 2167 键（新增 `plans.deleteConfirm`）
- `npm run test:utils` 66 ✓
- `npx tsc --noEmit` 137 条 = 旧基线 135 + **2 条新增路由的 `@/views/plans/*.vue` 模块解析盲区**
  （与其余 20+ 条同类：`tsc` 不认 `.vue`，每加一条 `.vue` 路由就会多一条）
- 模板 → 脚本标识符交叉核对：两个视图都无「调用了未定义函数」
- 未实机验证（`/plans` 需登录，浏览器会话 token 已失效）

## 已知缺口

移动端试算列表（`mobile/lib/features/planner/screens/planner_screens.dart` 的 `PlannerListScreen`）仍是
「名字 + 类型 + 条目数 + 设为今日」，没有成本 / 营养素 / 迷你图。仓库层已具备
（`PlannerRepository.evaluate` / `costTrend`），可用现成的 `_TrendPainter` 画迷你图 —— 待补，以符合
「各端体验一致性」。

## 经验

1. **模式式二级页面**（同一路由内 `editing` 开关）无法刷新、收藏、从历史直达。拆成 `xxx/new` + `xxx/:id`
   两条路由共用一个组件是成本最低的做法；注意 `new` 必须排在 `:id` 之前。
2. `v-card :to` 会渲染成 `<a>`：子按钮上的 `@click.stop` **拦不住锚点的默认跳转**（项目里已踩过一次）。
   整卡用 JS `@click` + 子按钮 `@click.stop` 才安全（JS 监听器能被 `stop` 拦住）。
3. 列表逐条拉取时用「每条约独立 `try/catch` + `Promise.all`」，一条坏数据不影响整页渲染，
   并让卡片在数据回来前显示占位（`…`）。

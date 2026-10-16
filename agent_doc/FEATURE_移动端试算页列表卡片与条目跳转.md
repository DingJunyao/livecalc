# 移动端试算页：列表卡片补成本/营养素/NRV/迷你图 + 条目可点进详情

## 背景

web 端试算页这一轮修完（四层连坑 → 独立路由 → 列表 NRV/营养/迷你图 → 详情全营养素与成本分析）后，
按「各端体验一致性」对照移动端逐条筛查，找到 4 处同类问题：

| web 的问题 | 移动端是否有 | 处理 |
| --- | --- | --- |
| 条目求值写死餐次（目标比例不对） | **有**：`_evaluate()` 里 `mealType: 'lunch'` 写死 | 已修：`_mealTypeOf(_items)`（breakfast/dinner 用各自比例，其它退回午餐，与 web 同口径） |
| 条目不能点进实体详情 | **有**：编辑页条目 `ListTile` 没有 `onTap` | 已修：`_openItem()` → `/recipes/:id`、`/ingredients/:id`、`/products/:id` |
| 列表无成本 / 营养素 / 迷你图 | **有**：列表卡片只有名称 + 类型 + 项数 | 已修（本轮） |
| 走势图无价格区间（min/max 带） | **有**：`_TrendPainter` 只画一条线 | **未做**（见下） |

另外移动端本来就没有 web 那几类「模板/运行时」问题（Flutter 是静态编译，模板调用不存在的函数根本过不了
`flutter analyze`；`_evaluate` 也是从选中项取 id，没有「把 id 当对象」的坑）。

## 本轮改动

- `mobile/lib/features/planner/providers/planner_provider.dart`
  - `PlannerListState` 增加 `totals`（plan.id → evaluate.totals）、`nutrients`（plan.id → evaluate.nutrition，含 NRV%）、
    `trends`（plan.id → 近 30 天成本数组）。
  - `load()` 拉完列表后逐条拉 `evaluate` + `costTrend(days: 30)`（数量少；**每条约独立 try/catch**，单条失败不影响其它卡片），
    并把餐次按条目分组推导（与 web 同口径）。
- `mobile/lib/features/planner/screens/planner_screens.dart`
  - 列表卡片抽成 `_planCard()`：成本大字（tertiary）+ 一行营养素（热量/蛋白质/脂肪，各自带 `NRV x%`）
    + 近 30 天成本迷你折线（新 `_MiniSparklinePainter`，只描线不画网格）+ 原有「设为今日 / 删除」。
  - 编辑页条目 `ListTile` 加 `onTap` → 对应实体详情。
  - `_evaluate()` 的 `mealType` 改成本条目的餐次。

## 验证

- `flutter analyze` → **No issues found**
- planner 相关没有单测目录（`mobile/test/features/planner` 不存在），本次未新增测试
- 未实机验证

## 未做（仍与 web 有差距）

1. 编辑页走势图还没有 min/max 价格区间带（后端 `/meal-plans/{id}/cost-trend` 已返回 `min_cost`/`max_cost`，
   只差 `_TrendPainter` 层面的绘制）。
2. 编辑页还没有「全部营养素 + NRV%」表与「各条目成本占比」图（web 复用了菜谱详情的组件，
   移动端需要各自实现）。

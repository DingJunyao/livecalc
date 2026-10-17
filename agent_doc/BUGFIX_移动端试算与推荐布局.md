# BUGFIX 移动端试算与推荐布局

## 修改

- 试算列表新增入口移到 `FloatingActionButton`，返回列表后自动刷新。
- 试算列表营养摘要拆成热量、蛋白质、脂肪三行，各自保留 NRV%。
- 试算详情删除导航栏下重复的方案名；模块顺序改为：食材项目、合计 vs 目标、成本走势、食材成本占比、营养贡献溯源。
- 试算编辑页新增菜谱 / 原料 / 商品三个入口，统一打开内嵌选择器；选择器带三类型 Tab、300ms 防抖搜索、请求序号防旧结果覆盖。原料/商品默认数量 100，与 web 一致。
- 首页“一句话偏好”的应用范围下拉改为输入框左侧，输入框保持可扩展宽度。

## 验证

- `dart analyze`（经 Flutter 工具执行）：No issues found。
- 定向 Flutter 测试：`app_localizations_test.dart` + `test/features/home` + `test/features/planner`，11 passed。
- 未实机验证网络态选择器和真实后端保存流程。

## 追加修复

- 新建方案保存按钮：`TextEditingController` 修改文本后没有触发 AppBar 重建，保存按钮一直保持禁用。现在监听名称变化后刷新按钮状态。
- 方案编辑页成本走势：按用户要求从编辑页移除；详情页仍保留成本走势。
- 条目数量：菜谱份数与原料/商品数量都改为可直接输入，并提供减/增快捷操作；菜谱最小 0.5，原料/商品最小 0，非配方条目步进 10。

### 追加验证

- 新增 `planner_edit_screen_test.dart`：先复现保存按钮禁用、编辑页仍包含成本走势、数量不可输入，再修复为 2 个测试全部通过。
- Flutter analyzer：No issues found。
- localization / home / planner 定向测试：13 passed。

## 二轮交互收敛

- 添加条目收敛为一个按钮；按钮打开既有「菜谱 / 原料 / 商品」三 Tab 抽屉，默认落在菜谱 Tab。
- 原料/商品数量保留直接输入和单位切换；移除所有条目的减/增按钮。
- 保存成功后用 `context.go` 进入 `/plans/:id`；新建与维护保存都会落到对应详情页。

### 二轮验证

- `planner_edit_screen_test.dart` 新增/扩展：只有一个添加入口、抽屉三 Tab；原料/商品各一个单位下拉且无减/增；新建保存跳转 `/plans/42`。
- Flutter analyzer：No issues found。
- localization / home / planner 定向测试：15 passed。

## 三轮单位与餐次

- 添加条目成功后不再弹「已添加，可在列表调整」，列表本身已即时可见。
- 新建方案此前不加载 `/units/`，所以原料/商品看不到单位下拉；现在新建时后台加载全局单位，维护方案仍在求值前加载。
- 「一日」方案每条项目新增餐次下拉（早餐 / 午餐 / 晚餐 / 其他），修改后会重新求值并与保存 payload 的 `group` 同步。

### 三轮验证

- `planner_edit_screen_test.dart` 新增：新建方案添加原料后显示单位下拉且无添加提示；一日方案三条项目各显示餐次下拉，切换第一条为早餐后下拉值同步。
- Flutter analyzer：No issues found。
- localization / home / planner 定向测试：17 passed。

## 四轮商品默认单位

- 现象：商品条目未选单位时，部分商品（如西兰花、双汇马可波罗特级火腿肠 60g）求值结果 `unit` 为空，移动端也没有可回填的单位。
- 数据核对：开发库中这些商品最新有效价格记录的标准单位都是 `g`；对应 `meal_plan_items.unit_id` 为空。
- 根因：后端商品求值只读 `MealPlanItem.unit`，`unit_id` 为空时直接返回 `None`，没有回退到最新价格记录的 `standard_unit`。这与“商品默认用价格记录标准单位”的预期不一致。
- 修复：`meal_plan_service` 先取商品最新有效价格记录；未显式选单位时返回记录标准单位缩写，并用该单位参与成本与营养折算。

### 四轮验证

- 新增后端回归：商品无单位 + 价格记录标准 500g + 数量 120 → 求值 `unit` 为记录单位、成本 2.4；修复前 `unit=None`。
- `pytest tests/services/test_meal_plan_product_unit.py tests/test_meal_plans_api.py`：5 passed。
- `py_compile app/services/meal_plan_service.py` 通过；Flutter analyzer No issues found；planner editor 6 tests passed。

## 五轮维护价默认单位

- 需求：试算条目单位要和维护价格一样带出实体默认单位；下拉也要有。
- 口径：`entity_unit_overrides.is_default` 优先商品自身，其次商品关联原料；再把默认单位名匹配到 `/units/` 的全局 `unit_id`。以“双汇马可波罗特级火腿肠 60g”为例，商品默认覆盖是“袋”，因此试算条目应选“袋”，而不是等后端求值后回退标准 `g`。
- 修复：新建方案后台加载全局单位；添加原料/商品时读取维护价默认单位并直接写入 `unit_id`；维护已有方案时也会在求值前为空单位条目应用该默认。选择抽屉返回结果现在携带真实实体类型，避免切 Tab 后仍按初始“菜谱”处理。

### 五轮验证

- 新增 planner 测试：添加带默认“袋”的商品后，单位下拉存在且选中对应全局单位 ID；先复现为 `null` 再修复通过。
- Flutter analyzer：No issues found；planner editor 7 tests passed。

## 六轮胡萝卜成本

- 现象：方案「12」（ID 6）里的胡萝卜条目成本是 0，成本占比图会过滤 0 元，因此看不到它。
- 数据核对：胡萝卜 ID 97 有 3 个 active 商品、最新价格记录标准单位为 `g`，也有 `nutrition_data`（每 100g USDA 数据）。
- 根因：原料加权价返回的是标准单位单价（克价），但试算直接乘“根”的数量；1 根约 0.0024 元，被 `_round2` 变成 0。成本走势同路径也会丢小额原料成本。
- 修复：`get_weighted_ingredient_price` 在指定目标单位时，把首个参与商品的标准单位价换算为目标单位价（例如克价 × 120g/根）；同时试算明细保留 4 位小数、总计保留 2 位展示，成本走势用原始 4 位小数聚合后再输出，避免逐项丢小额成本。

### 六轮验证

- 新增后端回归：500g 1.18 元、1 根=120g，目标“根”单价应为 0.2832；修复前仍为克价 0.00236。
- 只读实跑方案「12」：胡萝卜成本从 0 变为 0.24，营养为 49.2 kcal / 1.12g 蛋白 / 11.5g 碳水 / 0.29g 脂肪；方案总计 2.93 元，营养溯源包含胡萝卜。
- `pytest tests/services/test_meal_plan_product_unit.py tests/test_meal_plans_api.py`：6 passed；`py_compile` 通过。共享后端修复已提交 master 并合入 feat/mobile-app。

## 七轮走势标题与区间值

- 「成本走势（历史价格折算）」改为「成本走势」，三语同步。
- 当前选中日期下方改为平均 / 最低 / 最高三个独立指标，区间数值始终可见；原来只是一行小字“Range min–max”，容易漏看。

### 七轮验证

- `cost_trend_chart_test.dart` 改为断言标题为 `Cost trend`，并断言选中日期的平均、最低、最高数值。
- Flutter analyzer：No issues found；planner 相关 Flutter 测试 9 passed。

## 八轮方案 2 区间超平均

- 现象：`/plans/2` 成本走势里区间带远高于平均线；后端 90 天输出此前类似 `avg=0.816`、`min=20.58`、`max=28.04`。
- 根因：方案走势聚合里，菜谱 `avg_cost` 写入普通 `cost`，原料/商品后续又写入新的 `raw_cost`；输出 `avg_cost` 时优先取 `raw_cost`，导致菜谱平均被丢弃，只剩原料 + 商品约 0.816。但 `min/max` 仍包含菜谱区间（约 20–28），所以区间远超平均。
- 修复：`plan_cost_trend` 改为统一累加 `avg / min / max` 三档；菜谱按份数缩放，原料/商品贡献同时进三档。输出时统一保留 4 位小数，避免逐项二位小数舍入继续失真。

### 八轮验证

- 新增单元测试：菜谱份数缩放时 `avg/min/max` 均按份数缩放；菜谱 + 散项混合时 `avg` 不被散项覆盖。
- 只读实跑方案 2 修复后 90 天末点：`avg=22.8397`、`min=20.6987`、`max=25.2177`，90 天中 `min ≤ avg ≤ max` 全部成立。
- `pytest tests/services/test_meal_plan_product_unit.py tests/test_meal_plans_api.py`：8 passed；`py_compile` 通过。共享后端修复已提交 master 并合入 feat/mobile-app。

## 九轮走势加载态

- 现象：移动端方案详情先展示主体，成本走势仍在请求时直接显示「暂无营养数据」，没有转圈。
- 根因：`_load()` 拉到方案后立即关闭整页 loading；随后串行等待求值和走势请求，但 `CostTrendChart` 没有收到走势 loading 状态，且空态文案复用了营养文案。
- 修复：新增 `_trendLoading`，进入详情即保持走势卡 loading，直到 `/cost-trend` 完成；切换天数时同样转圈。成本走势空态改用「暂无成本历史数据」。

### 九轮验证

- 新增 `plan_detail_screen_test.dart`：方案与求值完成后挂起 cost-trend 请求，断言有 spinner 且不显示营养 / 成本空态；完成后 spinner 消失。
- Flutter analyzer：No issues found；planner 相关 Flutter 测试 10 passed。

## 十轮列表稳定高度与权限

- 列表卡片高度随逐条 evaluate / cost-trend 完成而变化，影响点击目标。
- 改为每张卡片固定 240 逻辑像素；名称、类型、项数、成本 / 热量 / 蛋白质 / 脂肪 / 成本走势标签从一开始就渲染，未加载值统一显示 `--`，加载后只填充对应数值和迷你图。
- 方案权限核对：列表、详情、更新、删除、成本走势和设为今日推荐均按 `user_id == current_user.id` 过滤；非创建者访问详情 / 更新 / 删除 / 走势 / 设为今日均 404，列表也不返回他人方案。

### 十轮验证

- 新增 `planner_list_screen_test.dart`：初始和 insights 加载完成后的卡片高度均为 240，固定标签存在，未加载时显示 5 个 `--`。
- 新增后端回归：非创建者访问 GET / PUT / DELETE / cost-trend / set-plan 均 404，且列表不含他人方案。
- Flutter analyzer：No issues found；planner 相关 Flutter 测试 11 passed。后端 `pytest tests/test_meal_plans_api.py` 5 passed；权限测试已提交 master 并合入 feat/mobile-app。

## 十一轮列表信息重排

- 去掉原来「左标签列 + 右对齐数值列」的重复结构，营养行改为单列左对齐文本：热量、蛋白质、脂肪、碳水均由同一段“标签 + 数值”组成。
- 右侧改为贯穿四条营养行的固定宽度成本列：成本迷你图在上、总成本在下；标题行保留类型、方案名和项数。
- 热量按用户能量单位偏好显示（kcal / kJ），碳水使用短标签「碳水 / Carbs」；加载前仍显示固定标签和 `--`。

### 十一轮验证

- `planner_list_screen_test.dart` 更新为检查无独立 Cost/Cost trend 标签、四条营养文本从一开始存在、右侧迷你图 key 存在，加载前后高度仍为 240。
- Flutter analyzer：No issues found；planner 相关测试 11 passed。

## 十二轮列表极简卡片

- 按用户最终选择，试算列表卡片收敛为一行：类型标签、方案名称、成本迷你图、成本，以及「设为今日 / 删除」图标按钮。
- 移除项数、热量、蛋白质、脂肪、碳水和额外标题行；卡片高度由 240 降为固定 88，加载前后不跳动。
- 「设为今日」从文字按钮改为 `verified_outlined` 图标按钮，保留 tooltip 与禁用态。

### 十二轮验证

- `planner_list_screen_test.dart` 断言卡片固定 88 高、仅保留标签/名称/迷你图/成本、无营养与项数文本、设为今日为图标 tooltip。
- Flutter analyzer：No issues found；planner 相关测试 11 passed。

## 十三轮列表对齐商品列表

- 卡片改为参照商品列表：左侧圆形类型图标、标题、标题下方完整类型标签与成本，右侧成本迷你图和操作图标。
- 圆形图标内使用短标签：中文「餐 / 顿」，英文 `Meal / Day`，阿拉伯语「وجبة / يوم」；标题下仍显示「一顿 / 一日」等完整标签。
- 成本不再放在固定宽度列中，改为标题下方剩余宽度内展示；卡片固定高度降为 76。
- 成本迷你图复用商品列表同一个 `Sparkline` 组件。

### 十三轮验证

- `planner_list_screen_test.dart` 断言：Card 固定 76 高；CircleAvatar 内为短标签；完整标签位于标题下方；成本完整显示；设为今日仍是图标按钮。
- Flutter analyzer：No issues found；planner 相关测试 11 passed。

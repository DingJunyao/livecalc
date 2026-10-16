# 试算页：列表 NRV、详情全营养素与成本分析（价格区间 / 条目多列 / 走势不显示）

## 需求（用户一次提 6 条）

1. 列表卡片三个营养素之间没有间距；2. 列表还要展示 NRV；3. 详情的成本走势图经常不显示（要切区间才出来），
且没有价格区间；4. 宽屏下条目一行一个太浪费，改多列 + 点击跳对应详情；5. 详情要展示计划的**全部**营养素
（像菜谱详情的营养成分）；6. 要像分析页一样展示各要素对成本、营养成分的贡献量及趋势。

## 后端（keystone：一次投入同时满足 2 / 5 / 6）

- 新增 `backend/app/services/nutrition_reference.py`：NRV 标准值（GB 28050-2011）+ 核心营养素表
  （中文名 ↔ 英文 key + 单位）+ `energy_to_kcal()`（kJ→kcal）+ `nrv_pct()`。
- `backend/app/services/meal_plan_service.py`：
  - `_item_cost_nutrition()` 额外产出 `nutrient_values`（英文 key，能量统一 kcal）：菜谱取
    `per_serving_nutrition.all_nutrients`（能量用已经换算过 kJ→kcal 的 `per_serving.calories`）；
    原料取 `all_nutrients × 折算系数`；商品暂无营养来源（保持原状）。
  - `_evaluate_stub_items()` 汇总成 `nutrition` 块：`per_serving_nutrition.{core_nutrients（含 nrp_pct / standard）,
    all_nutrients}` + `ingredient_details[].nutrition_contribution` —— **形状与 `calculate_recipe_nutrition`
    对齐**，前端可以直接复用菜谱详情/分析页的组件。逐条目原文 `nutrient_values` 不回传（响应体不膨胀）。
  - `plan_cost_trend()` 每天补 `min_cost` / `max_cost`（逐条目区间求和：菜谱用 range 趋势的 min/max，
    原料/商品 min = max），并同时给出 `avg_cost` 兼顾前端两种用法。
- 实测（开发库副本、只读）：16 项核心营养素 + NRV 全部产出（能量 36.84% / 蛋白质 34.23% / 脂肪 8.7% /
  碳水 45.42% / 钠 312.73%）；成本趋势 `min 101.11 / avg 104.44 / max 107.58`。

## 前端

- `frontend/src/views/plans/PlansView.vue`（列表卡片）
  - 营养素之间的间距改用 `style="gap: 4px 14px"` —— 原来的 `ga-x-3` 在本项目 Vuetify 版本里**不生效**，
    这就是「之间没有空白」的原因。
  - 每条营养素后附 ` · NRV x%`，取 `nutrition.per_serving_nutrition.all_nutrients[key].nrp_pct`；
    **模板里不能写中文常量**（否则 `check:i18n:sources` 报 `Han text`），所以传英文 key、在脚本里查表。
- `frontend/src/views/plans/PlanDetailView.vue`
  - **走势图经常不显示**的根因：`loadPlan()` 在 `finally` 里才把 `loading` 落下，而图表容器在 `v-else` 分支里
    —— `renderTrend()` 跑在 DOM 出现之前，`trendCanvas.value` 还是 `null` → 直接 return（静默）。
    切区间会触发 `watch(trendDays)`，那时 DOM 已就绪，所以表现成「切一下才出来」。
    改为：先 `loading=false` → `await nextTick()` → 再 `evaluateDraft()` / `renderTrend()`；
    `watch(editor.id)` 同样改成 `nextTick` 之后再画。
  - 趋势图改成「平均线 + 价格区间带」（min 走 stack 底层、max-min 填面积），tooltip 显示平均与区间。
  - 条目表 → 宽屏多列卡片（`cols=12 sm=6 md=4 lg=3`）：类型徽标 + 名称（真实 `<a href>` + `@click.prevent`
    走 SPA 路由，保留链接语义）→ `/recipes/:id`、`/data/ingredients/:id`、`/data/products/:id`；
    份数/数量输入与单条成本保留。
  - 复用菜谱详情/分析页的组件：`CostProportionChart`（各条目成本占比，输入 `{ingredient_id, ingredient_name, cost}`）、
    `NutritionSourceGrid`（全部营养素 + NRV + 营养来源，直接吃后端 `nutrition` 块）。
- 本地模式（`frontend/src/api/local/handlers/mealPlans.ts` + 新 `frontend/src/utils/nrv.ts`）：
  `evaluate` 也产出同形状 `nutrition`（每条目 4 个核心营养素 + NRV；`core_nutrients` 用英文 key + `key` 字段，
  组件按 `entry.key` 取 nrp_pct，避免 TS 里出现中文常量）；`cost-trend` 补 min/max（本地无逐日区间，min=max=avg）。

## 验证

- 后端：meal/plan 相关 13 例 → 12 passed + 1 条既有顺序性失败（与 HEAD 基线一致，非本次引入）；
  开发库副本只读实跑：全营养素 / NRV / min-max 均正常
- 前端：`build` ✓ / `check:i18n` ✓ / `check:i18n:sources` 2167 ✓ / `test:utils` 66 ✓ /
  `npx tsc --noEmit` 137（135 基线 + 2 条 `.vue` 路由模块解析盲区）/ 模板 → 脚本标识符核对 ✓
- 未实机验证（`/plans` 需登录）

## 已知取舍

- **商品条目的营养暂不计入**：后端原本就没取商品自建营养（`custom_nutrition_data`），要补需先定基准口径。
- 没做「营养素随时间的趋势」：营养素不随时间变化（变的只有价格），分析给的是各条目**贡献量** + 成本**趋势**。
- 复用组件里的标题仍是菜谱那套文案（`recipes.ingredientCostShare` 食材成本占比、`recipes.nutritionSources` 营养来源），
  没有为方案另加一套 i18n key。

## 经验

1. **`v-else` 里的图表容器**：`loading` 必须在画图**之前**落下，否则 `ref` 是 null、echarts 静默不画，
   表现就是「切一下才出来」。凡是「加载态 + 图表」的组合都要检查这个顺序。
2. 模板里传中文常量会被 `check:i18n:sources` 拦（`Han text`）；改用英文 key 传参、脚本里映射。
3. 复用组件的前提是**形状对齐**：让后端 `evaluate` 直接产出与 `calculate_recipe_nutrition` 同形的 `nutrition` 块，
   前端一行 `v-if` 就能用上菜谱详情/分析页的整套 UI —— 比新写图表便宜得多。
4. Vuetify 3（本项目 3.12）没有 `ga-x-*` 工具类，要精确间距直接写 `style="gap: …"`。

## 追加一轮（用户实机反馈五条）

1. **条目卡片样式**：原来的 `variant="outlined"` 小方框看着不对 —— 改成与原料详情一致的**扁平卡片**
   （`elevation="0"` + `v-card-title` + `v-divider` + `v-card-text`，见 `IngredientDetail.vue` 的 `.grid-item`），
   宽屏 `cols=12 sm=6 md=4 lg=3` 多列。
2. **标题不要做成链接**：条目名称改回普通标题（`text-body-2 font-weight-medium`），不再是 `<a>`；
   改由**整卡点击**进对应详情（卡片 `@click` + 份数/数量区 `@click.stop`），右侧加 chevron 提示可点。
3. **成本走势平均值一直贴底**：区间带用堆叠实现时，第二条系列必须是「**max - min**」的差值 ——
   之前放的是 max，堆叠后区间变成 `[min, min + max]`，平均值自然贴在底部。tooltip 里的区间也改成
   `min` 与 `min + 差值` 还原。
4. **宽屏左右分列**：`食材成本占比` 与 `成本走势` 放进 `<v-row no-gutters>` 的两个 `md=6` 列（与菜谱详情排布一致）。
5. **NRV 与营养素贡献图表**：新增「营养成分」表（全部营养素 + 含量 + NRV%，表头/文案复用 `recipes.nutrient`、
   `recipes.amount`、`recipes.nrvPercent`、`recipes.nrvExplanation`，标题用新增键 `plans.nutrition` 三语）；
   营养素贡献沿用 `NutritionSourceGrid`（每个营养素一个环形图 + 主要贡献条目）。
   顺带修结构：上一轮把「成本走势」卡塞进 `v-col` 时漏了 `</v-card>`，`vite` 直接报 `Element is missing end tag`。

### 验证（追加轮）

- `npm run build` ✓ / `check:i18n` ✓ / `check:i18n:sources` 2168 ✓（新增 `plans.nutrition`）/ `test:utils` 66 ✓
- `npx tsc --noEmit` 137（135 基线 + 2 条 `.vue` 路由盲区）/ 模板 → 脚本标识符核对 ✓
- 仍未实机验证（`/plans` 需登录）

## 再一轮（用户实机反馈四条）

1. **条目数量输入显示不全 + 没有单位下拉**：`v-number-input` 原来 `style="max-width: 120px"` 且带步进器，
   数字被挤掉 → 改 `control-variant="hidden"` + 固定 `width: 96/110px`；原料/商品条目补单位下拉
   （`value` 用 **unit_id**，与 `meal_plan_items.unit_id` 对齐；候选来自 `GET /units/?limit=500` 的启用项，
   拉不到就保持后端默认：原料按克 / 商品按记录标准单位），新增三语键 `plans.defaultUnit` 作占位文案。
2. **各食材营养占比图表看不到**：核查后确认**后端数据是全的**（开发库 plan 2：17 项核心营养素、6 个条目贡献、
   min 101.11 / max 107.58）。判断是**运行中的后端仍在旧代码上**（本轮做 git 迁移时还原过 `backend/**`，
   uvicorn 未必跟上）→ 需要重启后端；为避免以后再把「数据缺失」看成「图表没出来」，详情页在没有营养块时
   加了一条明确提示（复用 `recipes.noNutritionData`）。
3. **成本走势标题与「食材成本占比」不一致 + 区间又看不到**：自绘的 echarts 走势（含手写的 min/max 堆叠区间带）
   整个删掉，改为直接复用菜谱详情的 `CostTrendAnalysis` —— 卡片标题/结构天然一致，价格区间带、图例、
   周/月/季/年/全部 筛选都由它负责（`filter-change` 映射到 7/30/90/365/3650 天再拉数据）。
   少一份自绘图表 = 少一处「区间算错/不显示」的坑。
4. **列表 NRV**：NRV 取的是 `nutrition.per_serving_nutrition.all_nutrients[key].nrp_pct`（后端算好），
   数据没到就没有 —— 同 (2)，随后端重启即恢复；布局本身是 `flex-wrap`，空间不够会自动换行。

### 验证（再一轮）

- `npm run build` ✓ / `check:i18n` ✓ / `check:i18n:sources` 2167 ✓（少了一个只因模板不再用 `plans.days`）/ `tsc` 137 ✓
- 模板 → 脚本标识符核对 ✓；未实机验证

## 「一日方案设为今日」按分组拆三餐（用户反馈：三部分全写进每一餐）

- 根因：方案来源餐渲染时对三餐各自评估的是**整个方案**（`evaluate_plan` 不按条目分组过滤），
  所以早/午/晚三张卡都是同一份全部条目。
- 修复：`evaluate_plan` 增加 `group` 参数 —— `plan.kind == 'day'` 且传入 group 时只取 `item.group == group`
  的条目，并按该餐的目标比例（kind='meal' + meal_type=group）计算；`meal_recommender._build_response_from_records`
  渲染方案来源餐时传 `group=meal_type`。方案本身在 `/plans/:id` 仍按整天评估，不受影响。
- 「其它」分组的条目不会计入任何一餐（不映射到餐次）；商品条目营养已计入（上一轮）。
- 实测（开发库副本，一日方案 5 条目）：早 2 条 4.7/305kcal（目标 500）、午 2 条 7.46/431（800）、
  晚 1 条 7.11/279（700），合计 19.27/1015.08 与整方案一致。
- 回归：meal/plan 相关 13 例 → 12 passed + 1 条既有顺序性失败（同 HEAD 基线）。


# BUGFIX: 试算成本不随数据范围（计算范围）变化

## 现象

用户报告（外部环境 https://livecalc.home.a4ding.com 复现）：一直按城市级别记录三门峡的商品价格，最近把数据范围扩大到全部（去南京、杭州记录了当地商家），再把数据范围缩回「城市」后，**试算的成本根本没有随数据范围改变而改变**。

线上 API 复现（admin，`default_calc_scope=city`、`region_id=1951` 湖滨区，X-Region 会话头生效性已用菜谱成本端点对拍确认）：

| 端点 | X-Region: all | 三门峡市(1950) | 河南省(1824) |
|---|---|---|---|
| `GET /recipes/357/cost`（范围敏感，对照） | 15.53 | **13.81** | 13.81 |
| `POST /meal-plans/evaluate`（黄焖鸡米饭） | 16.97 | 16.97 | 16.97 |
| `GET /meal-plans/1/cost-trend` | 同上，三档完全一致 | | |

更直观的：方案 2「奥乐齐方便面青菜火腿肠」（商品条目，商家全在上海）在**三门峡市**范围下照样算出 5.22 元——范围过滤完全没进试算链路。

## 根因（数据流回溯）

后端 `meal_plan_service.py` 全文没有任何地区范围处理；`/meal-plans/evaluate` 与 `/{id}/cost-trend` 端点也不调 `resolve_region_param`（对照：`/recipes/*/cost` 等端点都会先 `resolve_region_param(db, user, region_id)` 再透传）。三条成本链路全部漏传 `region_id`：

1. **recipe 项**：`calculate_recipe_cost(...)` 支持 `region_id` 形参但没传 → 全量记录参与；
2. **ingredient 项**：`get_weighted_ingredient_price(...)` 支持 `region_id` 关键字但没传；
3. **product 项**：手写「最新有效记录」查询（`ProductRecord … order_by(recorded_at.desc())`），无任何商家地区过滤；
4. **plan_cost_trend** 同样四处漏：菜谱 `calculate_recipe_cost_range_trend`、原料加权价、商品最新记录、散项 `has_record` 记录日查询。

X-Region 会话覆盖机制本身完好：`client.ts`（web）与移动端 `api_client.dart` 拦截器对所有请求注入 `X-Region`，`meal-plans` 路由也挂了 `get_session_currency_override` 依赖（deps.py 里解析 X-Region 并 `set_session_region`）——只是试算服务从不读它。

## 修复

`backend/app/services/meal_plan_service.py`：

- `_evaluate_stub_items` 与 `plan_cost_trend` 入口各 `region_id = resolve_region_param(db, user, None)` 一次（会话 X-Region 覆盖优先，其次用户默认计算范围 `region_id + default_calc_scope`）；
- `_item_cost_nutrition(db, user, item, tz, region_id=None)`：recipe → `calculate_recipe_cost(region_id=…)`；ingredient → `get_weighted_ingredient_price(region_id=…)`；product → 最新记录查询套 `apply_region_filter(query, db, region_id)`；
- `plan_cost_trend`：菜谱趋势、原料加权价补传；商品最新记录与 `has_record` 记录日查询同样套 `apply_region_filter`；
- 范围解析放在 service 公共汇合点而非各端点：`meal_recommender` 复用 `evaluate_plan` 做推荐打分，由此一并按范围取价，无需 /meals 端点重复接线。

语义与全 app 一致：`apply_region_filter` 在 region_id=None 时原样放行（旧行为不变）；范围内未分配地区的商家照常计入（既有约定）；记录没挂商家则在范围内不可见（与其它范围敏感端点同口径）。

## 回归测试

`backend/tests/services/test_meal_plan_region_scope.py` 5 例（自建 国家→省→城市A/B/C 地区链 + 两地商家 + 同商品两条异地记录 10 元/500g（早）与 100 元/500g（晚））：

- 商品条目：城市A→10、城市B→100、会话「全部地区」→100（最新记录）；
- 无会话覆盖时走用户默认计算范围（user.region_id=城市A + `default_calc_scope=city` → 10）；
- 原料条目：城市A→10、城市B→100、全部→100（as-of 前向填充只取最近一天记录）；
- 菜谱条目：城市A→10、城市B→100（`calculate_recipe_cost` 透传生效）；
- 方案走势：城市A 整窗 10 且记录日 `has_record`；空子树（城市C）整窗 0 且无记录日。

验证：新测 5 过；`test_meal_plans_api/models` + `test_meal_plan_product_unit` + `test_meal_composer` 子集 29 过 / 1 失败（`test_llm_composer_uses_generic_complete`，stash 基线同批次同样失败 = 共享内存库的既有顺序干扰，单跑即过）；价格/地区/菜谱子集（`test_price_region`、`test_ingredient_price_service`、`test_recipe_service`、`test_product_detail_region_price`、`test_ingredient_latest_price_weighted`）32 全过。

**坑**：`tests/services/test_meal_recommendation_route.py` 与 `tests/api/test_meal_recommendation_route.py` 同名，放进同一 pytest 批次会让整批静默 collected 0 —— 两文件只能分开跑。

## 开发库只读复核

黄焖鸡米饭方案（两道菜谱项）：all=14.81 / 三门峡市=15.41 / 南京市=15.36；南京范围下「电饭煲蒸米饭」正确归 0（其记录不在南京子树）。

## 各端情况

- **web 服务端模式**：`client.ts` 全局注入 X-Region → 纯后端修复即覆盖，前端零改动。
- **移动端服务端模式**：`api_client.dart` 拦截器注入 X-Region + 同一套 `/meal-plans` 端点 → 同样纯后端覆盖。
- **本地模式（web + 移动端）**：本地 handler（`api/local/handlers/mealPlans.ts` 等）目前完全没有计算范围的输入通道——`proxy.ts` 分发不透传会话上下文，菜谱本地 handler 虽接受 `region_id` 参数但所有调用方都传 null（本地模式整体是全局聚合，不止试算）。属既有结构性缺口，与本次回归无关，未在本次处理。

## 分支与部署

- master `78a265cf`（后端 + 测试）→ 合入 feat/mobile-app；移动端无代码改动。
- 外部环境待部署后复核（线上 admin 账号切范围对比试算合计）。

# 商品加权价格机制

> 日期：2026-07-07
> 设计稿：[docs/superpowers/specs/2026-07-06-product-weighted-price-design.md](../docs/superpowers/specs/202607-06-product-weighted-price-design.md)
> 实现计划：[docs/superpowers/plans/2026-07-06-product-weighted-price.md](../docs/superpowers/plans/2026-07-06-product-weighted-price.md)

## 背景与问题

一个原料常挂多个商品，价格差别悬殊（有机 vs 普通、不同品牌）。原系统把「商品价」聚合为「原料价」时两套逻辑互相打架且各有偏置：

1. **原料最新价**（[nutrition.py:get_ingredient_latest_price](../backend/app/api/nutrition.py#L864)）：把原料下所有商品、最近一天的所有价格记录**按记录数简单平均** → 记录多的商品被无形放大。
2. **菜谱成本**（[recipe_service.py:calculate_recipe_cost](../backend/app/services/recipe_service.py#L719) 等 5 变体）：遍历商品**取第一个有记录的商品** → 选中哪个全看查询顺序，价格悬殊时成本飘忽。

## 方案：商品级两层加权平均

- **第一层（商品内）**：每个商品当日有效记录的均价 → 该商品代表单价
- **第二层（商品间）**：按商品权重加权平均 `Σ(pᵢ×wᵢ)/Σwᵢ`（仅 w>0 且当日有记录的商品）

记录数从此不再影响原料价，只有商品权重说了算。

## 决策摘要

| 维度 | 结论 |
|---|---|
| 权重作用域 | 全局默认 + 用户私有覆盖 |
| 数值表达 | 0-100 整数，默认 50（对齐 ingredient_hierarchy.strength） |
| 生效范围 | 价格计算链路：原料最新价、菜谱成本、sparkline |
| 全局权重写权限 | 仅管理员（普通用户连提议都不开） |
| 用户覆盖写权限 | 所有用户（个人偏好，不走审核） |
| 与 default_product_id | 统一为权重机制；字段保留不动（死字段，价格计算只认权重） |

## 数据模型

- [products.price_weight](../backend/app/models/product_entity.py)：`INTEGER NOT NULL DEFAULT 50`，CHECK 0-100（SQL 层）
- 新表 [user_product_weight_overrides](../backend/app/models/user_product_weight_override.py)：`(user_id, product_id, weight)` + AuditMixin 软删，`UNIQUE(user_id, product_id)`
- 权重读取优先级：用户覆盖(is_active) → Product.price_weight → 兜底 50（封装在 `_resolve_weight`）
- 迁移：[alembic 20260707_0001](../backend/alembic/versions/20260707_0001_product_price_weight.py) + 四套 SQL（[sqlite](../backend/scripts/sql/20260707_product_price_weight_sqlite.sql) / mysql / postgres，PostGIS 与普通 PG 同）+ 开发库直接补（备份 `livecalc.db.bak_20260707_weight`），现有商品回填 50

## 统一服务 [ingredient_price_service.py](../backend/app/services/ingredient_price_service.py)

- `_product_unit_price(records)`：商品内均价（standard_quantity 为 0/None 时按 price 兜底）
- `_aggregate_weighted(product_records)`：纯聚合（无 db），返回 `{unit_price, mode, participants, excluded}`，mode ∈ weighted/single/none
- `_resolve_weight(db, user_id, product)`：权重优先级
- `get_weighted_ingredient_price(db, ingredient_id, *, as_of_date, user_id, target_unit_abbr, mode)`：编排，mode ∈ as_of（成本语义，当天+前向填充）/ recent（最新价语义，最近有记录日）
- `resolve_direct_weighted_for_cost(...)`：成本场景 helper，返回 `(unit_price_decimal, participants, std_unit_id)`

## 改造点

| 场景 | 现状 | 改造 |
|---|---|---|
| [原料最新价](../backend/app/api/nutrition.py#L864) | 记录级简单平均 | 保留逐条折算到目标单位、聚合换 `_aggregate_weighted`，响应加 `participants/excluded/mode`（target 口径，方案 B） |
| [菜谱成本 calculate_recipe_cost](../backend/app/services/recipe_service.py#L719) | 取第一个有记录商品 | 调 `resolve_direct_weighted_for_cost`（standard 口径），加权无价走原回退链；878 单价重算段加 `unit_price is None` 防对占位记录重算 |
| 菜谱成本 as_of / range_as_of | 同上 | 同模式（as_of 加权优先+失败回退；range_as_of 加权分支算 min/max/avg 再 continue） |
| 菜谱成本 trend | 调 as_of 循环 | 自动受益（as_of 已改） |
| [sparklines 原料](../backend/app/api/sparklines.py) | 记录级日均 | `_daily_avg_for_product_ids` 加 `ingredient_id/user_id` 参数，商品级加权（用户覆盖优先于全局） |

**单位口径差异**（关键）：统一服务编排返回「元/standard_unit」（成本口径）；latest-price 要「元/目标单位（如斤）」。故 latest-price 不直接用编排，而是自己逐条折算到目标单位后调 `_aggregate_weighted`（target 口径，精确）。成本场景用编排（standard 口径，配合 recipe 用量转换段）。

## 权限固化

- 全局 `price_weight`：仅管理员可写。[update_product](../backend/app/api/products_entity.py#L369) 对普通用户 payload 的 `price_weight` 一律剔除（连审核提议都不开）。`ProductExecutor` 吃 CrudExecutorBase setattr，管理员 `apply_as_admin` 直写生效。
- 用户覆盖：仿 [user_preferences](../backend/app/api/user_preferences.py) 样板，独立端点 `GET/PUT/DELETE /products/{id}/my-weight`（[product_weight.py](../backend/app/api/product_weight.py)），不走审核。

## 前端

- [ProductDetail 基本信息](../frontend/src/views/products/ProductDetail.vue)：`basicEditForm` 加 `priceWeight/myWeight/globalWeightReadOnly`，管理员可改全局、普通用户只读全局、所有人可设「我的覆盖」；`saveBasicInfo` 分流写入
- [IngredientDetail 商品编辑对话框](../frontend/src/views/ingredients/IngredientDetail.vue)：`productForm` 同构，`openEditProductDialog` 拉取生效权重、`saveProduct` 编辑分支分流
- 原料详情最新价区：可折叠「加权明细」（参与商品/权重/当日单价/来源 + 被排除项及原因），透明追溯
- API client：[productWeight.ts](../frontend/src/api/productWeight.ts)（`getProductMyWeight/setProductMyWeight/deleteProductMyWeight`）

## 测试

[test_ingredient_price_service.py](../backend/tests/services/test_ingredient_price_service.py) **15 个全过**：
- 8 纯聚合（基础加权、比例加权、权重0排除、无记录排除+归一、单商品退化、全空 None、**记录数偏置修正**、0 数量兜底）
- 3 权重解析（覆盖>全局>50）
- 2 集成（as_of 加权、用户覆盖排除，in-memory SQLite 不碰开发库）
- 2 e2e（管理员全局权重 0 排除、不同用户不同加权价）

前端 `npm run build` 通过（ProductDetail 58.18 kB、IngredientDetail 90.61 kB）。

## 遗留与未覆盖

- **range_trend 批量趋势函数未改**（[calculate_recipe_cost_range_trend](../backend/app/services/recipe_service.py#L1166)）：它是性能优化批量版（单商品 `price_source_cache` + 二分查找逐天），改成多商品加权需重写整个批量算法、风险高。遗留影响：菜谱 sparkline（[sparklines.py:81](../backend/api/sparklines.py#L81) 调 range_trend）和菜谱成本区间趋势（[recipes.py:1417](../backend/app/api/recipes.py#L1417)）暂仍是「单商品」口径，与详情页（加权）不一致。建议后续单独设计批量加权算法。
- **菜谱成本 breakdown 的 `weighted_participants` 字段未加**：cost/as_of 改造时聚焦加权计算，cost_breakdown.append 未补 `weighted_participants` 字段，故菜谱成本明细 tooltip 暂不展示加权来源（原料详情最新价区的加权明细已展示）。
- `default_product_id` 字段保留不动（前后端均无业务消费，死字段），价格计算只认权重。

## 环境备注

- **subagent 不可用**：本环境 subagent 底层模型配置坏（两次「模型不存在」API 错误），subagent-driven-development 回退为 inline 执行。
- **venv 在项目根**（`d:\code\livecalc\.venv`，非 `backend/.venv` 后者是空壳）：后端命令在 backend 目录用 `../.venv\Scripts\python.exe`。
- 开发库走「直接补」惯例（不走 alembic，参见 CLAUDE.md），操作前已备份。

## 补遗（2026-10-12）：综合价口径统一为「每商品最近价 as-of 加权」

**问题**（用户反馈）：原料「胡萝卜」下三个商品（胡萝卜 / 泥胡萝卜 / 水果胡萝卜），综合最新价与价格趋势图只
反映最新被记录的那一个商品（泥胡萝卜 ¥0.79/斤），而菜谱成本对同一原料算的是 ¥2.52/斤（三商品加权），差 3.2 倍。

**根因**：`GET /nutrition/ingredients/{id}/latest-price` 仍保留最初实现的「先取全局最近 24 小时滚动窗口、
窗口为空才回退到全局最新一天」的记录挑选逻辑——只要有任一商品在窗口内被记录，其余商品整段不参与加权，
综合价退化成单品价。设计意图的实现（`ingredient_price_service._collect_recent_records` + `mode="recent"`：
每商品各自「最近有记录日」）当时已写好，但**全仓库零调用**（死代码）。前端趋势图同理：按自然日分桶、
只让「当天有记录的商品」参与加权，没有把其他商品的最近价向前携带。

**统一后的口径（三处一致）**：

1. 每个商品的价格 = 该商品「最近有记录日」的均价（同日多条取均价）；
2. 该价格一直有效到下一次记录（as-of 向前携带，价格在两次记录之间视为不变）；
3. 每日 / 每次综合价 = 各商品当日有效价按权重（用户覆盖 > price_weight > 50）加权，权重 0 排除。

| 消费点 | 改动 |
| --- | --- |
| `/nutrition/ingredients/{id}/latest-price` | 24h 窗口 → `_collect_recent_records`（每商品最近有记录日）；`participants/excluded/mode` 完整返回；`latest_date` 取参与者最新记录时间；商品查询补 `is_active` |
| `/sparklines/ingredients` | 逐日 as-of 加权；窗口前最近一次记录作为携带起点（新增 `_fetch_carry_forward_seeds`）；序列 = 窗口起点 → 今天，一格一天 |
| 原料详情趋势图 avg 线（`IngredientDetail.vue`） | 复用新增共享工具 `frontend/src/utils/priceAsOf.ts` 的 `buildWeightedAsOfDailySeries`；min/max/count 改为「参与加权的商品价区间 / 商品数」（`PriceTrendChart` 新增 `countLabel`，卡片「记录数」→「商品数」，l10n 三语 `charts.productCount`） |
| 本地模式 | `handlers/nutrition.getLatestPrice`（原「全部历史记录平均」→ 每商品最近价加权）、`handlers/sparklines.getIngredientSparklines`（as-of 加权） |

**顺带修复**：

- `_fetch_recent_records` 漏选 `standard_unit_id`（c55206a1 体积语义重构引入）：`_unit_price_per_jin → record_standard_grams`
  取该列时 AttributeError，被端点 try/except 吞成 500 → `/sparklines/products|ingredients` 整体不可用（前端静默无迷你图）。
- `_collect_recent_records`、`_price_timeline_index` 未过滤 `ProductRecord.is_active`：已软删的价格记录仍在参与成本 / 趋势的日聚合。

**移动端**：app 复用同一批端点（原料最新价 / 迷你图），零改动自动对齐；`Sparkline` painter 已处理等值（全平）序列。

**验证**：后端新增 [test_ingredient_latest_price_weighted.py](../backend/tests/test_ingredient_latest_price_weighted.py)
（三商品等权 2.00 / 60 天前记录仍参与 / 权重 0 排除）与
[test_ingredient_sparkline_asof.py](../backend/tests/test_ingredient_sparkline_asof.py)
（窗口前价格继续携带、序列长度 = days+1、商品 sparkline 500 回归）共 4 用例通过；前端新增
[priceAsOf.test.ts](../frontend/src/utils/priceAsOf.test.ts) 5 用例（`npm run test:utils` 13/13）；
vite build、check:i18n 通过；胡萝卜实测综合价 ¥0.79 → ¥2.52（与菜谱成本一致）。

### 补遗修订（2026-10-13）：参与上限 30 天，卡片与图表必须同集合

**用户反馈**：综合最新价显示 2.52（含 8 周前水果胡萝卜 5.58/斤），而趋势图加权平均 0.98、
区间 0.79~1.18（图表数据按区间加载，看不到区间外的水果胡萝卜），卡片上的平均值甚至落在
自己显示的区间之外——卡片与图表完全对不上。

**规则补充**：参与综合价（综合最新价 / 原料 sparkline / 趋势图 avg 线 / 本地模式）的商品，
其最近一次价格必须落在 `INGREDIENT_PRICE_STALE_DAYS = 30` 天内；超期商品进入
`excluded`（`reason="stale"`，前端文案「超期未更新（>30 天）」）。30 天与商家价
（`MERCHANT_PRICE_STALE_DAYS`）和菜谱价格提示的陈旧口径一致。

**配套改动**：

- 卡片右侧「区间 / 商品数」改为直接取接口 `participants`（原来从图表尾点推导，
  图表数据按区间加载时会与接口的参与者集合不一致，平均值可能落在区间外）。
- 前端图表取数窗口不足 30 天（周视图）时自动放宽到 30 天（`PRICE_STALE_DAYS`），
  显示范围仍由 `PriceTrendChart` 按所选区间切片。
- `buildWeightedAsOfDailySeries` 增加 `staleDays`（默认 30）：每个商品的携带价在
  「最近记录日 + 30 天」后过期。

**口径说明（保留差异）**：菜谱成本（`mode="as_of"`）仍按「每商品最近一次已知价」计算，
不做 30 天上限——即胡萝卜今天的菜谱成本仍含水果胡萝卜（≈2.52），原料页综合价是 0.98。
这是「成本 = 按已知信息计价」与「综合价 = 近 30 天在售商品代表价」的语义差异；若要成本
也套 30 天上限，另开任务。

**验证**：胡萝卜实测综合最新价 0.98（参与者：胡萝卜 1.18 + 泥胡萝卜 0.788；excluded：水果胡萝卜
stale），sparkline 尾值 0.98 与卡片一致；后端用例改为 3 个（60 天 → stale 排除 / 29 天仍参与 /
权重 0 排除）+ sparkline 过期用例，目标集 26/27（1 失败为存量 i18n 文案断言）；前端
`priceAsOf.test.ts` 6/6、vite build、check:i18n 通过。

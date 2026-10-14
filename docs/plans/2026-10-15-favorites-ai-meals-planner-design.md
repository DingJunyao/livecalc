# 收藏 / AI 一餐推荐 / 试算页 —— 设计文档

- **日期**：2026-10-15
- **状态**：待评审（评审通过后进入实现计划）
- **实施顺序**：① 收藏 → ② AI 一餐推荐 → ③ 试算页，每阶段独立可验收
- **分支策略**：每阶段先在 `master` 实现后端 + web（含本地离线模式），合并到 `feat/mobile-app` 后再实现移动端（遵循 AGENTS.md）

---

## 1. 背景与现状（已核实）

### 1.1 现有推荐（`backend/app/services/meal_recommender.py`）

- 每天为每位用户在本地日生成早 / 午 / 晚各 **1 道菜**，写入 `daily_recommendations`（唯一约束 `(user_id, date, meal_type)`）做当天缓存。
- 触发方式为「请求惰性触发 + 后台线程 + 前后端轮询」：`GET /meals/recommendations`（查状态）→ `POST .../generate` → 前端轮询至 `ready`；`POST .../refresh` 换一餐。
- 打分 = 0.5 × 营养偏差分 + 0.5 × 成本分；选择 = `random.choices(weight = score + 0.05)` 加权随机。
- 候选池：早餐 = `category == "早餐"`；**午/晚 = `category != "早餐"`** —— 调料（9 道）、半成品（7 道）、饮料（20 道）、甜品（25 道）都会进入午/晚候选；完全没有「主食 / 荤素 / 汤」概念。
- 开发库实测：362 道启用菜谱 —— 主食 55、汤与粥 27、荤菜 111、素菜 54、水产 32、早餐 22、甜品 25、饮料 20、调料 9、半成品 7。早餐池 22 道中大半是纯鸡蛋类（水煮蛋、溏心蛋、茶叶蛋……）。
- 响应中成本 / 营养为请求时实时重算，无快照。
- **现存 bug**：每餐每天 5 次刷新上限**从未生效** —— `_count_today_refreshes` 以 `COUNT(行数) − 1` 计数，而每（用户、日期、餐）恒 1 行、刷新走 UPDATE，计数恒为 0；响应里的 `refresh_counts` 也恒为 0。

### 1.2 收藏现状

- **商家已有完整实现**：`user_merchant_favorites` 纯链接表（`(user_id, merchant_id)` 唯一，无 audit 字段，取消即物理删）+ `GET /merchants/favorites`、`POST|DELETE /merchants/{id}/favorite`（登录直写、不走审批）+ 三端「心形 + 只看收藏筛选」。
- 原料 / 商品 / 菜谱**无收藏**。
- 云端导出（`backend/app/services/export/`）**不含**商家收藏；本地（IndexedDB）导出白名单含 `merchant_favorites`。
- 商家合并提议对收藏做快照 / 搬迁 / 回滚（`services/proposals/executors/merchant_merge.py`）。

### 1.3 AI 基建现状

- provider 配置存 DB `translation_configs` 单行 JSON（`services/translate/registry.py` 统一接口）。AI 类 provider 四个：`openai`（OpenAI 兼容）、`anthropic`、`claude_code`（本机 CLI，无需 key）、`codex`（本机 SDK，无需 key）。
- `services/agent/` 是面向「查库 + 写 SQL + 审批 + SSE」的会话体系（翻译 / 推断 / 黑名单匹配在用），**本设计的配餐调用不使用它**。
- 本地离线模式有浏览器端 agent（`frontend/src/api/local/agent/`：runner + 工具 + 本地 AI 配置解析，直连 anthropic / openai）。
- 移动端目前**没有任何 AI 界面**。
- 权限体系：多用户 + 邀请码；普通用户写共享数据的变更走 proposals 审批；收藏这类「个人私有数据」直写。

### 1.4 试算可复用能力

- 菜谱成本引擎带 `as_of_date` 参数（`services/recipe_service.py`），已有逐日 as-of 成本区间端点 `GET /recipes/{id}/cost-history-range?days&offset_days`（前向填充）与成本历史 `GET /recipes/{id}/cost-history`。
- 商品价格历史：`GET /products/history/{product_name}`；web 端 as-of 逐日序列工具 `frontend/src/utils/priceAsOf.ts`（12 例单测）、移动端 `mobile/lib/features/prices/utils/price_trend.dart`（10 例单测）。
- 菜谱份量缩放：web `RecipeDetail.vue`（displayServings / servingRatio）、移动端 `recipe_detail_screen.dart`（ratio + `_ServingsStepper`）。
- 单位换算服务 `services/unit_conversion_service.py`（含自定义单位嵌套 `resolve_override_amount`）。
- **试算 / 搭配 / 膳食计划功能目前不存在。**

### 1.5 用户诉求（原话要点）

1. 推荐不可用：一餐只推一道菜、绝大多数情况没有主食；希望借助 AI 推荐。
2. 要一个试算页：自己搭配菜谱，计算一顿 / 一日的营养、成本及其趋势。
3. 要收藏：原料、商品、菜谱，「和商家一样」。
4. 补充要求：管理员设置全局推荐方法 + 按用户选择推荐方法（为以后收益做结构）；BYOK 不限餐食推荐、将来别处也用；做了多用户就按「对外提供服务」的合规姿态设计；考虑 JEV 类决策模型是否适用。

---

## 2. 已确认决策清单

| # | 主题 | 决策 |
|---|---|---|
| 1 | 交付顺序 | 收藏 → AI 推荐 → 试算页 |
| 2 | AI 角色 | AI 从现有菜谱池组合挑选 + 给理由；无 AI / 失败时降级规则组合 |
| 3 | 一餐构成 | **不固定槽位**；硬约束「≥1 主食」；主食自足型（蛋炒饭、番茄鸡蛋面）可单独成餐；配菜 0..n 由 AI 判断 |
| 4 | 候选池 | 午/晚 = 主食 / 荤菜 / 素菜 / 水产 / 汤与粥；早餐 = 早餐 / 主食 / 汤与粥；甜品、饮料、调料、半成品不进正餐池 |
| 5 | 早餐保底主食 | AI 输出每道 `role`，校验器要求 ≥1 `staple`（午/晚叠加机械校验：staple 的 category 必须是「主食」） |
| 6 | 历史去重 | 同一菜谱最近 **7 天**不重复（跨餐次、按用户）；池不足时逐级放宽 7→3→0 |
| 7 | 一句话偏好 | 支持（随时输入，随生成 / 换菜提交；快照展示） |
| 8 | 换菜粒度 | 整餐重搭 + 单道换；共享每餐每天 5 次上限（并修复上限失效 bug） |
| 9 | 收藏形态 | 列表心形 + 只看收藏筛选 + 列表默认置顶收藏 + 「我的收藏」聚合页；覆盖原料 / 商品 / 菜谱 |
| 10 | 收藏用途 | 作为推荐的偏好信号（短名单加权） |
| 11 | 试算篮子 | 菜谱为主（每道可调份量）+ 可直接加原料 / 商品（数量 + 单位） |
| 12 | 试算保存 | 可命名保存方案；`meal`（一顿）或 `day`（一日，按早/午/晚分组） |
| 13 | 趋势口径 | 方案成本按**历史价格 as-of 逐日折算**的走势 |
| 14 | 推荐 ↔ 试算 | 双向：推荐「拿去试算」；方案可「设为今日一餐」并在推荐页显示 |
| 15 | 离线模式 | 也接 AI（浏览器端 agent）+ 规则降级；未配置 key / 调用失败时降级并提示 |
| 16 | 导出导入 | 云端导出**新增**收藏（原料/商品/菜谱）**并补上商家收藏**；导入按名字两遍法重映射 |
| 17 | AI 使用策略 | 管理员全局默认 + 用户级方法选择（管理员可指定、开启后用户可自选）；BYOK **通用化**（不限餐食推荐） |
| 18 | BYOK 默认 | **自定义端点地址默认关闭**（只能用管理员配置的端点 + 用户自己的 key）；公开分发时保持关 |
| 19 | 每日上限 | 现在就做：可配置每日 AI 次数上限（作用于 `system_ai` 调用，超限自动降级 rule） |
| 20 | 合规姿态 | 按「对外提供服务」设计：系统 AI 引导已备案境内模型、AI 内容标识默认开、密钥加密、外发数据告知 |
| 21 | 决策模型（JEV/Laya） | 部分适合（判断原语，不做组合器）；本次只做 provider 抽象（`chat / decision` + 能力声明）与决策 Composer 骨架，不接具体实现 |

---

## 3. 阶段 1：收藏

### 3.1 数据模型

新表 `user_favorites`（纯链接表，完全对齐 `user_merchant_favorites` 的模式）：

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | Integer PK | |
| `user_id` | Integer FK users，NOT NULL，index | |
| `entity_type` | String(20)，NOT NULL | `'ingredient' \| 'product' \| 'recipe'` |
| `entity_id` | Integer，NOT NULL，index | 按 entity_type 解释 |
| `created_at` | DateTime(timezone=True)，server_default now | |

- 唯一约束 `uq_user_favorites (user_id, entity_type, entity_id)`。
- **不继承 AuditMixin**：取消收藏 = 物理删除（对齐商家收藏）。
- 不加跨表外键（entity_id 是多态的）；实体存在性在应用层校验（对齐项目「软删 + 导入重排行 id，同表引用不加 DB 外键」的既有经验）。
- 商家收藏表**不动**（其合并快照 / 搬迁 / 本地链路都在工作）；聚合页读商家时直接查现有表。

**迁移产物**（每个建表迁移都要出；文件名中的日期为实现当日日期，此处为示意）：

- `backend/alembic/versions/<日期>_0001_add_user_favorites.py`
- `backend/scripts/sql/<日期>_user_favorites_sqlite.sql`
- `backend/scripts/sql/<日期>_user_favorites_mysql.sql`
- `backend/scripts/sql/<日期>_user_favorites_postgresql.sql`
- （与 PostGIS 无关，不提供 PostGIS 版）

### 3.2 后端 API

新路由 `backend/app/api/favorites.py`，挂载 `prefix="/api/v1/favorites"`，鉴权 = 登录即可（`get_current_user`），**不走 proposals 审批**（对齐商家收藏；收藏是个人私有数据）。

| 方法 | 路径 | 行为 |
|---|---|---|
| GET | `/api/v1/favorites` | 聚合四类：`{ingredients: [...], products: [...], recipes: [...], merchants: [...]}`（供聚合页；各全量、按 `created_at` 倒序、过滤 `is_active`） |
| GET | `/api/v1/favorites/{entity_type}` | 单类全量列表，`{entity_type} ∈ {ingredient, product, recipe}`（响应模型按类型复用现有 schema）；商家单类走既有 `GET /merchants/favorites`，不在此路由重复实现 |
| POST | `/api/v1/favorites/{entity_type}/{entity_id}` | 幂等加收藏；实体不存在（或已软删）返回 404；返回 `{"ok": true}` |
| DELETE | `/api/v1/favorites/{entity_type}/{entity_id}` | 幂等取消（物理删）；返回 `{"ok": true}` |

- **路由顺序**：`/favorites` 固定路径必须注册在 `/{entity_type}/...` 之前（merchants.py:203 注释里的教训）。
- 挂 `get_session_currency_override` 依赖（对齐其它业务路由）；聚合里的商家列表顺手补 `_attach_effective_currency`（修复现有商家收藏列表币种不生效的小坑）。

**列表端点新增参数**（参数化排序 / 过滤，**默认 false，不改动现有行为**）：

- `GET /api/v1/products/entity`、`GET /api/v1/ingredients`、`GET /api/v1/recipes` 各加：
  - `favorites_first: bool = False`：SQL 层 `LEFT JOIN user_favorites`，`ORDER BY CASE WHEN uf.id IS NULL THEN 1 ELSE 0 END, <原排序键>`（收藏组优先，组内保持原排序；分页正确性要求服务端实现）。
  - `favorites_only: bool = False`：服务端过滤（`IN` 子查询）。
- 只有主列表页传 `true`；快速填写、搜索自动补全等其它消费方不传，行为不变（沿用「共用端点排序必须参数化」的既有经验）。

### 3.3 生命周期联动

- **合并**（三处，参照 `merchant_merge.py` 的快照 / 搬迁 / 回滚模式）：
  - 商家合并：`services/proposals/executors/merchant_merge.py`（已有，不动）。
  - 商品合并：`services/proposals/executors/product_merge.py` 增加收藏处理（快照 `affected_favorites` 计数 → apply 时源商品收藏改挂目标并去重 → revert 逐行恢复）。
  - 原料合并：`services/ingredient_merger.py`（`IngredientMerger.merge_ingredients` + `IngredientMergeRecord` 回滚）同样处理。
- **软删**：收藏行保留，列表侧过滤 `is_active`（对齐商家收藏列表）。
- **导出 / 导入**（`services/export/packaging.py` + `services/importer/importers/export.py`）：
  - 新增 `user_favorites.json`（元素：`entity_type` + 实体 id + 实体名）与 **`user_merchant_favorites.json`（补上商家收藏）**；manifest `extended` 清单同步。
  - 导入两遍法（参照 `importers/export.py:308` 的 `weight_unit_override_name` 先例）：实体先导 → 收藏按「实体名 + 类型」解析成新 id 写入；解析不到的跳过并在导入报告中计数。
  - 归属 = 导入目标用户。

### 3.4 web（master 分支）

- 新组件 `frontend/src/components/common/FavoriteButton.vue`（心形图标按钮，`active` / `disabled` / `size` props，图标沿用 `mdi-heart` / `mdi-heart-outline` + `error` 色）+ 新 composable `frontend/src/composables/useFavorites.ts`（入参 `entityType` → 返回 `{ ids, load, isFavorite, toggle }`；乐观更新 + 失败回滚 + 全局提示）。用它们把 `MerchantsView.vue` 现有的三处内联实现替换掉（消除重复），新页面全部复用。
- 列表页加：行内心形、筛选栏「只看收藏」复选项（接入现有筛选框架）、请求带 `favorites_first=true`：
  - `views/data/ProductsView.vue`、`views/data/IngredientsView.vue`、`views/recipes/RecipesView.vue`
- 详情页加心形：`views/products/ProductDetail.vue`、`views/ingredients/IngredientDetail.vue`、`views/recipes/RecipeDetail.vue`。
- 新页面 `views/favorites/FavoritesView.vue`，路由 `/favorites`：四类 tabs（原料 / 商品 / 菜谱 / 商家），复用各列表的卡片样式，含空态；侧栏加导航入口。
- **本地离线模式**：新增 IndexedDB store `user_favorites`（`keyPath: 'id', autoIncrement`，索引 `by_type`（entity_type）、`by_entity`（entity_type + entity_id））+ handlers（`frontend/src/api/local/handlers/favorites.ts`）+ proxy 路由（`addRoute('/favorites', ...)`、`addRoute('/favorites/:type/:id', ...)`）+ 导出导入白名单（`EXPORT_STORES` / `FILE_STORE_MAP` 加 `user_favorites`，对齐 `merchant_favorites` 现状）；三个列表 handler 实现 `favorites_first` / `favorites_only`。

### 3.5 移动端（feat/mobile-app 分支，master 合并后）

- 三个列表屏 + 详情屏加心形：`features/products/screens/product_{list,detail}_screen.dart`、`features/ingredients/screens/ingredient_{list,detail}_screen.dart`、`features/recipes/screens/recipe_{list,detail}_screen.dart`；筛选底栏加「只看收藏」；provider 请求带参数。
- 新增「我的收藏」屏（`features/favorites/`：repository + provider + screen，四类 tabs），入口放「更多」页。
- **顺手修既有 bug**：`features/merchants/providers/merchant_provider.dart` 的 `toggleFavorite` catch 分支回滚无效（`copyWith(favoriteIds: state.favoriteIds)` 把乐观值赋回自己）—— 修成正确的旧值回滚；新代码不得复刻。

### 3.6 偏好信号（供阶段 2 消费）

- 后端短名单构建直接读 `user_favorites`（`entity_type='recipe'`）：收藏菜谱的打分 +0.1（封顶 1.0）；含收藏原料（`entity_type='ingredient'`）的菜谱在短名单条目上打标供 AI 参考。
- 不新增 API；web / 移动端无感。

### 3.7 测试与验收

- 后端：端点（幂等 / 404 / `favorites_only` / `favorites_first` 排序与分页）；商品合并与原料合并的收藏搬迁 + 回滚；迁移（建表 + 唯一约束）；导出导入往返（含名字重映射与跳过计数）。
- web：`npm run build`、`npm run check:i18n`、`npm run check:i18n:sources`（记录新键数）、`npx tsc --noEmit`（既有 137 条噪音不变）、`npm run test:utils`（composable 如有纯函数）；本地模式 handlers 测试。
- 移动端：`flutter analyze` 0 issue、`flutter test`（存量 6 项失败不新增）、新增 provider / widget 用例。
- 验收：三端可收藏 / 取消（列表 + 详情）、只看收藏筛选、置顶生效、聚合页四类可见、合并后收藏跟随。

---

## 4. 阶段 2：AI 一餐推荐

### 4.1 候选池口径（`_get_candidate_pool` 改造）

- 午 / 晚池：`category ∈ {主食, 荤菜, 素菜, 水产, 汤与粥}`。
- 早餐池：`category ∈ {早餐, 主食, 汤与粥}`。
- 硬过滤（沿用 + 新增）：`is_active`；黑名单原料关联菜谱（沿用 `_get_effective_blacklist_ids`）；**近 7 天已推荐过的菜谱**（新增，跨餐次、按用户；数据源 = 近 7 天 `daily_recommendation_items` ∪ 方案来源餐的 plan items）。
- 池不足（去重后 < 该餐最小可用数）：逐级放宽窗口 7 → 3 → 0 重试；仍不足则不排除历史（保证永远有解）。

### 4.2 短名单（确定性层）

- 打分：沿用 `_calc_nutrition_score`（per_serving 营养 vs 该餐目标）与 `_calc_cost_score`；`score = min(1.0, 0.5×n + 0.5×c + (0.1 if 收藏 else 0))`。
- 按分类取 top-K 组成短名单：主食 8 / 荤菜 6 / 素菜 6 / 水产 4 / 汤与粥 4；早餐模式：早餐 8 / 主食 6 / 汤与粥 4。
- 条目字段：`id / name / category / 每份成本 / 每份营养(calories, protein_g, carbs_g, fat_g) / total_time_minutes / is_favorite / has_favorite_ingredient / top_ingredients(前 5 个原料名)`。
- 短名单规模 ~20–30 条，提示词体积可控。

### 4.3 组合层

新服务 `backend/app/services/meal_composer.py`（`meal_recommender.py` 保留编排 / 落库 / 缓存 / 刷新，组合逻辑外移；纯函数可单测）：

- **协议**：`MealComposer.compose(shortlist, constraints, preference) -> ComposedMeal`；`constraints` = 餐次、营养目标、预算、黑名单原料名、近 7 天已推荐菜名、排除的 recipe_id（当前餐已有 / 单道换目标）。
- **`LLMMealComposer`**：走 Translator 通道 —— 调用形态为单条 prompt（餐次 / 约束 / 偏好 / 短名单全部内联在 user 内容里），`translate_batch([prompt], system_prompt=MEAL_PLANNER_SYSTEM_PROMPT)` 取首项返回；输出 JSON 契约：

```json
{"dishes": [{"recipe_id": 123, "role": "staple|main|side|soup|drink", "reason": "≤20 字"}],
 "note": "整餐一句话理由"}
```

- **校验器**（纯函数 `validate_composition(result, shortlist, meal_type) -> list[str]`）：
  1. JSON 可解析、结构正确；
  2. 所有 `recipe_id` ∈ 短名单；
  3. 1–4 道、无重复；
  4. **≥1 道 `role == "staple"`**；
  5. 午/晚：staple 的 `category` 必须是「主食」（机械兜底）；`category == "主食"` 的菜必须标 `staple`；
  6. 不含排除集 / 黑名单命中的菜。
- **重试与降级**：校验失败 → 把错误清单回灌重试 1 次 → 仍失败 / 超时 / 未配置 AI → `RuleMealComposer`。
- **`RuleMealComposer`**（也是本地模式与降级路径）：
  - 午 / 晚 = 主食最高分 + 主菜（荤 / 素 / 水产最高分）+（汤，`score ≥ 0.5` 才加）；
  - 早餐 = 主食最高分 + 早餐类最高分（+ 粥类 `score ≥ 0.5`）；
  - 理由用模板文案（三语）。
- **预留 `DecisionMealComposer`**：JEV / Laya 类决策模型（见 §4.9），本次只留接口与配置骨架。

### 4.4 一句话偏好

- 输入位置：推荐页顶部输入框（web + 移动端），可选；随 `generate` / `refresh` 提交。
- 存储：父行 `preference` 快照（生成 / 刷新时写入）；卡片脚注展示（如「按你的偏好：想吃面」）。
- 消费时机：只在生成 / 刷新时参与；改偏好后需点「换一餐」或重新生成。
- 语言：AI 输出理由 / 备注的语言按请求 `Accept-Language`（zh / en / ar）要求。

### 4.5 刷新语义

- `POST /meals/recommendations/refresh` body 扩展：`{meal_type, recipe_id?, preference?}`。
  - 无 `recipe_id` → **整餐重搭**：排除当前餐已有菜谱，重新走池 → 短名单 → 组合。
  - 带 `recipe_id` → **单道换**：保持其它菜不动，仅重选该道；换掉的是 staple 时新道必须也是 staple；短名单排除当前餐全部菜。
- 上限：整餐重搭与单道换**共享**每餐每天 5 次。
- **修复上限失效 bug**：父表加 `refresh_count INTEGER NOT NULL DEFAULT 0`，刷新时 +1；`_count_today_refreshes` 改读该列；响应 `refresh_counts` 语义随之恢复（前端展示不变，但真实生效）。

### 4.6 存储与迁移

`daily_recommendations`（父表）新增列：

| 列 | 类型 | 说明 |
|---|---|---|
| `reason` | Text NULL | 整餐一句话理由（AI 或模板） |
| `preference` | String(200) NULL | 生成时的一句话偏好快照 |
| `source` | String(20) NOT NULL DEFAULT 'rule' | `rule \| system_ai \| user_ai \| plan` |
| `refresh_count` | Integer NOT NULL DEFAULT 0 | 修复刷新计数 |
| `recipe_id` | （删除） | 由子表取代（alembic batch 模式兼容 SQLite） |

新表 `daily_recommendation_items`：`id / recommendation_id FK (index) / recipe_id FK (index) / sort_order / reason TEXT NULL`（每道一句）。

- 迁移文件 `20261015_0002_recommendation_items.py` + 三引擎 SQL；回填：旧行按 `recipe_id` 生成一条 item（`sort_order = 0`）、`source = 'rule'`。
- `plan_id` 列与方案来源的联动在阶段 3 迁移里追加（阶段 2 不引入对 `meal_plans` 的依赖）。

### 4.7 API 变更

`GET /api/v1/meals/recommendations` 响应（内部 API，三端同步改）：

```json
{
  "status": "ready", "date": "...", "refreshing_meals": [],
  "recommendations": [{
    "meal_type": "lunch", "is_current_meal": true,
    "source": "system_ai", "reason": "荤素搭配、有主食", "preference": "想吃面",
    "dishes": [{"id": 123, "name": "...", "category": "主食", "role": "staple",
                 "images": [], "image_urls": [], "servings": 1,
                 "cost_estimate": 3.5, "currency": "CNY",
                 "nutrition_per_serving": {"calories": 300, "protein_g": 8, "carbs_g": 55, "fat_g": 4},
                 "reason": "补充碳水"}]
  }],
  "totals": {"cost": 12.3, "currency": "CNY", "calories": 800, "protein_g": 40, "carbs_g": 90, "fat_g": 25, "refresh_counts": {"breakfast": 0, "lunch": 1, "dinner": 0}}
}
```

### 4.8 AI 使用策略层（通用，不限餐食推荐）

**全局配置**（`translation_configs` JSON 新增两个区块）：

- `meal_plan`：`{provider, timeout_seconds}`（默认 `claude_code`，超时默认 120s）。
- `ai_policy`：`{default_method, allow_user_choice, allow_byok, allow_custom_base_url, daily_ai_limit, show_ai_badge}`；默认值：`default_method='system_ai'`、`allow_user_choice=true`、`allow_byok=true`、`allow_custom_base_url=false`（决策 #18）、`daily_ai_limit=20`、`show_ai_badge=true`（决策 #20）。

**用户级**：新表 `user_ai_settings`（通用，不限餐食推荐）：

| 列 | 说明 |
|---|---|
| `id / user_id (FK, unique)` | 每用户一行 |
| `method` | `rule \| system_ai \| user_ai`，NULL = 跟随全局默认 |
| `provider` / `base_url` / `model` | BYOK 用（provider 限 `openai`（兼容端点）/ `anthropic`） |
| `api_key_enc` | Fernet 加密（key 由 `SECRET_KEY` 派生；`cryptography` 已是依赖）；接口只回显打码值（前 4 后 4），提供清除 |
| `daily_ai_limit_override` | 可空；管理员可对单用户改写 |

**解析顺序**：用户 `method`（在全局允许范围内）→ 全局 `default_method` → `rule`。解析器 `resolve_ai_credentials(user, scope='meal_plan') -> (method, provider_cfg)` 只写一次，后续其它 AI 功能复用。

**用量与上限**：新表 `ai_usage_events`（`id / user_id / scope / method / provider / status('ok'|'fallback'|'error') / created_at`）。`system_ai` 调用前计数（当天 + scope + method=system_ai + status ∈ {ok, fallback}）≥ 上限 → 直接走 `rule` 并在响应里给出提示文案；BYOK 不设限但同样记事件。

**合规默认值**（决策 #20）：系统 AI 的配置页默认引导选择已备案境内模型（OpenAI 兼容端点即可接 DeepSeek / 通义等，文案说明）；AI 生成的推荐卡片显示「AI 生成」小标（`show_ai_badge` 可关，公开分发应保持开）；偏好文本外发在设置页给隐私说明。

**管理入口**：AI 配置页（`views/admin/AiConfigView.vue` + 本地模式对应页）新增「餐食推荐」与「AI 使用策略」两个区块；用户管理页可为单用户指定方法与上限；个人设置页（web / 移动端）在允许范围内自选方法与填 BYOK。

### 4.9 Provider 抽象扩展与决策模型评估

- provider 能力声明（内置字典，`services/translate` 侧新增）：

```python
PROVIDER_CAPS = {
  'openai':      {'kind': 'chat', 'json_output': True,  'needs_key': True},
  'anthropic':   {'kind': 'chat', 'json_output': True,  'needs_key': True},
  'claude_code': {'kind': 'chat', 'json_output': True,  'needs_key': False, 'timeout_hint': 120},
  'codex':       {'kind': 'chat', 'json_output': True,  'needs_key': False, 'timeout_hint': 120},
  # 骨架（本次不接）：'jev'/'laya': {'kind': 'decision', ...}
}
```

- 配置页按 `kind` 显示字段；`MealComposer` 按 `kind` 选择实现（`chat` → LLM 组合；`decision` → 预留）。
- **JEV / Laya 评估结论**（决策 #21）：这类「System One」决策模型是**判断原语** —— 输入上下文 + 预定义问题（choice / score / noul），输出带校准概率的类型化答案，70–500ms，不能生成文本。适配结论：
  - 适合：偏好文本 → 类型化约束解析；候选逐道打分 / 相关性判断；置信度门控（低分转规则或重试）。
  - 不适合：单独做组合器 —— 全局约束（≥1 主食、预算、去重）与自然语言理由它给不出，需要「决策打分 + 确定性装配 +（可选）chat 模型补理由」的三段式。
  - 本次只落地抽象与骨架；将来接入 = 新增 `DecisionMealComposer` 一个实现 + 配置项，上层不动。Laya 是 Apache-2.0、可自托管（ModernBERT 系），若接入是合规压力最小的路径（本地非生成模型）。

### 4.10 三端实现

- **web（master）**：`views/meals/DailyMealsView.vue` + `components/meals/MealCard.vue` 改为多道菜卡片（每道一行：名称 / 分类 / 成本 / 热量 + 「换这道」按钮），卡片底部 AI 理由 + 偏好 chip + 「AI 生成」标，顶部偏好输入框，卡片底部「换整餐」；轮询机制不变（`stores/meals.ts`）。
- **本地离线模式**：`api/local/business/mealRecommender.ts` 升级 —— 短名单用本地数据（含本地收藏）、AI 走浏览器端 agent（`api/local/agent/`，anthropic / openai，读本地 AI 配置）、同一契约的 TS 校验器（与后端同规则、带单测）+ 规则降级；未配置 key / 调用失败 → 降级并在 UI 提示（文案区分「离线模式未配置 AI」）；刷新上限用本地存储实现同口径；claude_code / codex 为 CLI 专属，本地模式不可用（README / 设置页注明）。
- **移动端（feat/mobile-app）**：home 卡片展开多道菜、偏好输入、换菜菜单（整餐 / 单道）、「AI 生成」标；`HomeErrorCode` 与文案补充；provider / 轮询沿用。

### 4.11 测试与验收

- 后端：校验器纯函数（越界 id / 无主食 / 道数越界 / 坏 JSON / role 交叉）；短名单（池口径、7 天去重与放宽链、收藏加权）；`RuleMealComposer` 输出；刷新（整餐 / 单道 / 上限 / 并发互斥 / 方案来源餐被换掉）；`resolve_ai_credentials`（各允许组合 + 上限触发降级）；迁移回填；API 用假 provider 注入（不打真实网络）。
- web：`test:utils`（TS 校验器）、`build`、`check:i18n`、`check:i18n:sources`、`tsc --noEmit`（基线不变）。
- 移动端：`flutter analyze` 0 issue、`flutter test` 存量失败不新增、多道菜渲染 / 单道换 / 偏好输入用例。
- 验收：真实 provider（claude_code）手工各跑一次生成与换菜；构造池不足场景验证放宽链；验证 5 次上限真实生效。

---

## 5. 阶段 3：试算页

### 5.1 数据模型

`meal_plans`：`id / user_id FK (index) / name String(120) / kind String(10)('meal'|'day') / note String(200) NULL` + AuditMixin（软删）。

`meal_plan_items`：

| 列 | 说明 |
|---|---|
| `id / plan_id FK (index)` | |
| `group` | `'breakfast' \| 'lunch' \| 'dinner' \| 'other'`；一顿方案统一 `other`；一日模式三餐外可用 `other`（加餐 / 零食） |
| `item_type` | `'recipe' \| 'ingredient' \| 'product'` |
| `recipe_id / ingredient_id / product_id` | 三选一（CheckConstraint 对齐 `user_ingredient_preferences` 的写法） |
| `servings` | Numeric(6,2) NULL（菜谱项，默认 1） |
| `quantity` / `unit_id` | 原料 / 商品项（数量 + 单位，默认取该商品 / 原料的默认单位） |
| `sort_order` / `note` | |

迁移 `20261015_0003_meal_plans.py` + 三引擎 SQL；同日新增父表 `daily_recommendations.plan_id`（FK meal_plans，NULL）+ `source` 增加 `'plan'` 取值。

### 5.2 计算

- **`POST /api/v1/meal-plans/evaluate`**（草稿不落库也能量）：body = `{kind, items: [...]}` → `{items: [{cost, currency, nutrition}], totals: {cost, calories, protein_g, carbs_g, fat_g}, targets, deltas}`。
  - 菜谱项：`calculate_recipe_cost(..., servings_override=servings)` / `calculate_recipe_nutrition`。
  - 原料 / 商品项：数量 × 单位换算（`UnitConversionService`，自定义单位嵌套走 `resolve_override_amount`）× 现有加权价（每商品最近价 → 30 天参与上限 → 全放开 → 按权重加权）；营养以 `nutrition_data.reference_amount`（默认 100g）为基准、沿用 `calculate_recipe_nutrition` 内部对原料的处理口径（实现时以该函数为准）。
  - 目标对比：`kind='day'` → 用户每日目标；`kind='meal'` → 每日目标 × `MEAL_RATIOS`（复用 `meal_recommender.MEAL_RATIOS`，提出为共用常量）。
- **`GET /api/v1/meal-plans/{id}/cost-trend?days=90&offset_days=0`**：逐日 = Σ（各菜谱 as-of 成本 × servings + 散装项 as-of 成本）；复用后端 as-of 引擎（`calculate_recipe_cost_trend` 家族，前向填充；稀疏区间沿用「as-of 携带起点」判据）；返回 `[{date, total_cost, currency}]`。

### 5.3 与推荐联动

- **推荐 → 试算**：推荐卡片「拿去试算」→ 打开编辑器并载入**未保存草稿**（整餐 dishes，servings=1）。
- **试算 → 推荐**：`POST /api/v1/meals/recommendations/set-plan {meal_type?, plan_id}`：`kind='meal'` 需 `meal_type`；`kind='day'` 一次设三餐。写父行 `source='plan' + plan_id`；推荐页对该餐渲染方案视图（含散装原料 / 商品项与方案名）；对该餐点「换一餐」→ 回归 AI / 规则生成（`source` 随之翻转）。
- 去重窗口（阶段 2 §4.1）把方案来源餐的 items 计入。

### 5.4 三端实现

- **web（master）**：路由 `/plans`（方案列表 + 编辑器，详情含趋势图）；入口 = 侧栏一级 + 推荐卡片按钮；编辑器 = 统一搜索（菜谱 / 原料 / 商品）加篮子、逐项份量 / 数量与单位编辑、一日模式按早 / 午 / 晚分组、汇总区（成本 + 四营养素 vs 目标）、「保存」「设为今日一餐」；趋势图复用现有图表样式与筛选（区间 / 全部）。
- **本地离线模式**：IndexedDB `meal_plans` / `meal_plan_items` + handlers + 本地 evaluate（本地 `costCalculator` 口径）+ 本地趋势（本地价格数据 + `priceAsOf.ts`）。
- **移动端（feat/mobile-app）**：`features/planner/`（列表 / 编辑 / 详情 + 趋势），入口在「更多」+ 推荐页按钮；份量编辑复用 `_ServingsStepper`，趋势图复用 `CostTrendChart`。

### 5.5 测试与验收

- 后端：plan CRUD（含 CheckConstraint 违规 400）、evaluate 口径（混搭、份量缩放、目标对比）、cost-trend（as-of 正确性、稀疏区间、与单个菜谱成本趋势同口径）、set-plan（一顿 / 一日三餐 / 换一餐翻转 source）。
- web：`test:utils`（篮子合计纯函数如有）、`build`、i18n、`tsc --noEmit` 基线。
- 移动端：`flutter analyze`、`flutter test` 存量失败不新增、planner 相关 widget 用例。
- 验收：搭一顿（菜谱 + 散装项）→ 保存 → 看趋势 → 设为今日一餐 → 推荐页显示 → 换成 AI 推荐，全链路实机走通。

---

## 6. 跨阶段要求

- **分支**：每阶段「master（后端 + web + 本地模式）→ 合并 feat/mobile-app → 移动端」；提交信息遵循 Conventional Commits。
- **迁移产物**：所有表结构变动同时提供 alembic 迁移与 `backend/scripts/sql/YYYYMMDD_<topic>_{sqlite,mysql,postgresql}.sql`。
- **i18n**：web 三语 `zh-CN / en-US / ar`，跑 `check:i18n` 与 `check:i18n:sources`（键数变化记录进要点）；移动端三语 ARB + `flutter gen-l10n`；AI 产出的文案语言随 `Accept-Language`。
- **测试基线**：后端既有 pytest 失败集合、移动端 6 项存量失败（apple_map×3 / locale_preferences×2 / my_proposals×1）、web `tsc --noEmit` 137 条噪音，均**不得新增**；每阶段结束跑对应全量 + 定向用例。
- **记录要点**：每阶段完成后按 AGENTS.md 索引写 `agent_doc/` 记录（保留最近 10 条）。

## 7. 非目标（YAGNI）

- 阶段 1：收藏分组 / 备注 / 文件夹；收藏热度统计；商家收藏迁入新表；收藏影响快速填写等非主列表场景。
- 阶段 2：AI 生成 / 改写新菜谱；库存 / 剩菜联动；每周计划；甜品进正餐池；推荐历史详情页；口味画像学习；计费与套餐（仅留用量数据）；JEV / Laya 具体接入（仅抽象与骨架）。
- 阶段 3：方案分享 / 公共方案库；方案导出；购物清单派生；自动求解（「配到 2000 kcal」）；按方案生成采购任务。

## 8. 风险与缓解

| 风险 | 缓解 |
|---|---|
| AI 输出不合契约 / 质量波动 | 校验器 + 回灌重试 1 次 + 规则降级；reason 与 source 标注实际路径 |
| claude_code CLI 单次 10–60s | 沿用后台线程 + 轮询；超时 120s 可配；决策模型策略（预留）延迟 70–500ms 可显著改善 |
| 收藏置顶改变列表排序波及其它消费方 | 参数化（默认 false）；仅主列表页开启；本地模式同口径 |
| 公开分发合规 | 按对外服务姿态设计（备案模型引导 + 内容标识 + 密钥加密 + 告知）；正式分发前做专业合规咨询 |
| 迁移删父表 `recipe_id` 兼容性 | alembic batch 模式 + 回填测试（旧数据 → items） |
| 5 次上限修复后行为变化被当成回归 | 文档与要点记录注明「上限此前从未生效」；前端 `refresh_counts` 展示本就存在 |

## 9. 实现核对清单（实现阶段先核实的既有细节）

1. 原料 / 商品营养口径：以 `calculate_recipe_nutrition` 内部对原料的处理为准（`nutrition_data.reference_amount` 基准 + 单位换算）。
2. 三个列表端点的分页与排序实现点（`products_entity.py` / `ingredient_extended.py` / `recipes.py`），确认 `favorites_first` 的 JOIN 不破坏现有 `no_recent_price` 等特殊条件。
3. 合并三处的收藏处理：`ProductMergeExecutor`、`IngredientMerger`（+ `IngredientMergeRecord` 回滚）、`MerchantMergeExecutor`（已有，仅核对）。
4. 导入两遍法：参照 `services/importer/importers/export.py:308` 既有先例实现收藏解析。
5. `refresh_counts` 语义恢复后两端展示（web `DailySummaryBar` / mobile home）是否需文案调整。
6. 本地模式列表 handler 的排序 / 过滤实现点（`api/local/handlers/{products,ingredients,recipes}.ts`）。

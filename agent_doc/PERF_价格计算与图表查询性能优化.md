# 价格计算与图表查询性能优化（2026-10-04）

## 背景

用户反馈：菜谱价格计算、菜谱/原料/商品图表（sparkline、成本趋势）响应极慢、经常超时。

## 问题定位（实测）

用 SQL 计数探针在真实库上实测（3,232 条价格记录、363 个菜谱、用户带地区过滤）：

| 场景 | 改造前 | 改造后 |
|---|---|---|
| 30 原料菜谱单日成本（带 region） | 0.70s / 569 SQL | <0.01s（缓存热） |
| 单菜谱 90 天成本区间趋势（带 region） | ~30s / ~51,000 SQL | **0.46s / 194 SQL** |
| 14 菜谱 × 2 region 口径全量趋势（28 次） | **886.4s / 769,898 SQL** | **4.6s / 1,509 SQL** |
| 商品 sparkline（60 个） | 0.30s | 0.01s |

根因（按贡献排序）：
1. `calculate_recipe_cost_range_trend` / `calculate_recipe_cost_trend` 对 90 天**逐天全量重算**，每天每原料完整走 5 层降级链（direct→fallback→name_match→recipe→contains），相邻天结果几乎恒同。
2. `apply_region_filter` 每次调用查 2 次地区子树，被乘了数万次。
3. `UnitConversionService.convert` 无缓存，每条记录 3-10 次查询（单位×2 + entity_override 链 + 密度链）。
4. 同一数据单次计算内重复查询：`_direct_cost_range_ppg` 经 `resolve_direct_weighted_for_cost` 取记录后又对每个参与商品重取一遍；fallback 链命中后为拿 chain 再跑一遍；`Recipe`/`User`/币种每天重查。
5. sparkline 端点 N+1：`/sparklines/products` 逐商品查询、`/sparklines/ingredients` 逐原料查询。
6. `product_records` 表**无 `(product_id, recorded_at)` 索引**，所有取价全表扫描。

## 方案与实现（数值完全等价，见验证）

### 1. 请求级只读缓存 `app/services/lookup_cache.py`（新文件）

挂在 `db.info` 上（生命周期=Session=请求），模块内注册 `before_flush` 事件：flush 中出现 Unit / EntityUnitOverride / EntityDensity / AdministrativeRegion / Product / ProductIngredientLink / IngredientHierarchy / Recipe / Ingredient / ProductRecord 实例时自动清空——写端点与 importer 无需手工失效。

覆盖：`unit_by_id` / `unit_by_abbr` / `unit_si_base` / `entity_override_map`（一次取实体全部 active 覆盖，同名多行保留第一行=旧 `.first()` 语义）/ `entity_density` / `product_ingredient_id` / `active_products_for_ingredient` / `hierarchy_all` / `making_recipe_for_ingredient` / 通用 `memoize_result`。

### 2. 地区子树缓存（price_region.py）

`region_subtree_ids` 结果挂 `db.info`（key 与 lookup_cache.clear 联动失效）。

### 3. UnitConversionService 接入缓存

`get_unit_by_abbr` / `get_density` / `get_entity_override` / 体积质量互转的 kg/L 基准查询全部走缓存；优先级链（product→ingredient→link）不变。

### 4. 价格记录时间轴索引（recipe_service.py，核心）

`_price_timeline_index(db, product_id=…|product_name_contains=…, tz, region_id)`：每商品/每名称**一次**全量载入（`ORDER BY recorded_at` 升序，与逐次查询同源同序），按本地日分组；`_get_price_record_with_fallback`（单数）/`_get_price_records_with_fallback`（复数）改为内存锚点选择（`<= as_of` 最新，倒序扫描；无则最早日），语义与逐次 SQL 完全一致。附带修复：as_of 传 aware datetime 时规范化为 naive UTC（旧版把 aware 传给 SQLite 属未定义字符串比较）。

### 5. 与 as_of 无关的结果缓存

- `_get_ingredient_fallback`：顶层调用（visited=None）结果缓存（回退源选择永远取全局最新，不看 as_of）；实现体拆为 `_get_ingredient_fallback_impl`，递归不缓存。
- 层级边 `_hierarchy_edges(db, "fallback"|"rev_sub"|"contains", id)`：全表一次载入内存过滤 + strength 降序（None 排最后=SQLite DESC 的 NULL 语义）。
- `_serving_weight_to_grams`、权重覆盖（`get_weighted_ingredient_price`）、`std_unit_of_product`、用户默认币种（三处入口 memoize）。
- `Recipe` 查询统一 `db.get`（identity map）；merged 原料重定向 `db.get(Ingredient, …)`。

### 6. 消除重复查询

- `resolve_direct_weighted_for_cost` 返回 4 元组（增 `participant_records`），`_direct_cost_range_ppg` 复用已取记录。
- `_fallback_cost_range_ppg` 返回 `(min,max,avg,chain)`，调用方不再二次跑回退链。
- `_name_match_cost_range_ppg` 锚点日同名记录走名称时间轴缓存。
- `_get_ingredient_fallback` 内「全局最新一条」取时间轴末位（注意不是 `_get_price_record_with_fallback(as_of=None)`——那是前向填充语义返回最早一条）。

### 7. sparkline 批量化（api/sparklines.py）

`/sparklines/products`、`/sparklines/ingredients` 改一次 IN 查询 + 内存分组（`_fetch_recent_records` / `_weight_map` / `_products_sparklines_batched` / `_ingredients_sparklines_batched`），聚合公式与遍历顺序（浮点累加序）不变；`/sparklines/recipes` 未动（其成本来自趋势计算本身的加速）。

### 8. 索引

- `product_records` 复合索引 `(product_id, recorded_at)`：模型 `__table_args__` + alembic `20261004_0001` + `scripts/sql/20261004_product_records_perf_indexes_{sqlite,mysql,postgresql}.sql`（与 PostGIS 无关）。
- 启动幂等补齐：`main.py _ensure_price_query_indexes()`（MySQL 无 IF NOT EXISTS，捕获重复错误忽略）。
- `entity_unit_overrides` 已有 `(entity_type, entity_id, unit_name)` 索引（ix_entity_unit_active），无需新增。

## 等价性验证（关键）

方法：改造前先用旧代码对真实库跑「14 个代表性菜谱（原料最多 5 个 + 半成品链 + 分散 8 个）× {无 region, 用户 region} × 90 天 range 趋势」导出数值基线（含每日 min/max/avg 与逐原料 breakdown、cost_source，Decimal 转 str），改造后重跑对比：

- **28 次运行数值 JSON 的 sha256 与基线逐字节相同**（`57d3387e…`），零差异。
- 60 商品/40 原料 sparkline 批量版 vs 逐实体版：零差异。
- 中途多轮增量验证（P0 后、P1 后）同样零差异。

### 复核与数据漂移说明

提交后数小时复验时基线出现「差异」，经排查**并非代码不等价**：开发机的自动重载后端在每次重启时会执行 lifespan 启动逻辑（汇率快照对齐 `ensure_user_currency_snapshots` 等），期间**改写了数据库中的部分数据**，导致基线过时；且 90 天滚动窗口跨本地日后整体平移一天。判定方法：用 `git worktree` 检出优化前提交（c2041dd），在**同一份当前数据库**上对跑新旧代码——菜谱 175/30/163 × {1951, None} 共 6 组 90 天趋势**全部逐值相同**。即：任意时刻的同一数据状态下，新旧代码结果恒等。今后做此类等价性复验时，应以「同库对跑」为准，不要用跨时间的基线快照。

## 测试说明

全量 pytest：821 passed，30 failed 经 stash 对照与单测复跑确认全部为**与本改动无关的既有失败/运行方式敏感用例**（USDA/agent/storage/downloader/format_detector/export，其中 9 个在全量与单文件两种运行方式下结果不一致，旧代码同样如此）；价格/成本/sparkline/单位相关测试全部通过。

已知理论差异点（等价性论证过，实测未触发）：同 `recorded_at` 微秒级碰撞时 `ORDER BY … DESC LIMIT 1` 的 tie 选择、层级边同 strength 并列时的顺序——SQLite 排序器与内存 stable sort（同 rowid 加载序）行为一致的概率极高。

## 注意事项

- `lookup_cache` 的缓存依赖「GET 计算路径内无写入」；写路径由 before_flush 自动失效，无需手工干预。新增写入相关实体的端点无需改动。
- 请求内长事务（如基线探针那种一直不 commit 的 session）持有弱引用对象可能被 GC 导致重复加载——生产请求路径由 trend 外层 `recipe` 局部变量持住关键对象，无此问题。
- 前端/移动端零改动；API 响应结构未变。

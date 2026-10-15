# FEATURE: 收藏（原料 / 商品 / 菜谱）

- **日期**：2026-10-15
- **分支**：master（后端 + web + 本地离线模式）；移动端待 master 合并到 `feat/mobile-app` 后另做
- **关联**：设计 [docs/plans/2026-10-15-favorites-ai-meals-planner-design.md](../docs/plans/2026-10-15-favorites-ai-meals-planner-design.md)（§3 阶段 1）；实现计划 [docs/plans/2026-10-15-favorites-implementation.md](../docs/plans/2026-10-15-favorites-implementation.md)

## 需求

用户要求收藏**原料 / 商品 / 菜谱**（「和商家一样」），并明确收藏要作为后续 **AI 推荐的偏好信号**（设计文档阶段 2 消费）。

## 数据模型

- 新表 `user_favorites`：`id / user_id / entity_type('ingredient'|'product'|'recipe') / entity_id / created_at`；唯一约束 `uq_user_favorites(user_id, entity_type, entity_id)`。
- **纯链接表**：取消收藏 = 物理删除（对齐 `user_merchant_favorites` 的既有模式）；`entity_id` 多态、**不加跨表外键**（软删 + 导出导入重排行 id，项目既有约定），存在性由 API 层校验。
- 迁移：`backend/alembic/versions/20261015_0001_add_user_favorites.py` + `backend/scripts/sql/20261015_user_favorites_{sqlite,mysql,postgresql}.sql`。
- 商家收藏沿用 `user_merchant_favorites`（不动其链路）。
- 开发库由后端启动时的 `Base.metadata.create_all` 建表（无需手工迁移）。

## API（`backend/app/api/favorites.py`，登录直写、不走 proposals 审批）

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/v1/favorites` | 聚合四类：`{ingredients, products, recipes, merchants}`（商家读既有表并补 `effective_currency`；条目为轻量 `{id, name, subtitle, image}`，按收藏时间倒序、过滤 `is_active`） |
| GET | `/api/v1/favorites/{type}` | 单类（type ∈ ingredient/product/recipe；商家走既有 `/merchants/favorites`） |
| POST / DELETE | `/api/v1/favorites/{type}/{id}` | 幂等；实体不存在或已软删 → 404；不支持类型 → 400；返回 `{ok: true}` |

## 列表端点参数（参数化，默认 false 行为不变）

`/api/v1/products/entity`、`/api/v1/ingredients`、`/api/v1/recipes` 各新增：

- `favorites_first`：收藏项置顶（`case` 排序前缀；**组内保持原排序**，非收藏项相对顺序不变——翻页不重不漏）。
- `favorites_only`：服务端过滤（`IN` 子查询；`total` 与过滤后条数一致）。

实现：`select(UserFavorite.entity_id).where(user_id=..., entity_type=...)` 子查询（**不要**用 `db.query(...).subquery()` 传给 `in_()`，会触发 SAWarning）。仅主列表页传 `true`；快速填写 / 自动补全等消费方不传。

## 生命周期联动

- **合并（删除源收藏 + 快照回滚，口径对齐 merchant_merge：不搬迁，避免同一用户同时收藏源与目标撞唯一约束）**：
  - 商品：`services/proposals/executors/product_merge.py`（snapshot/preview 带 `affected_favorites`，apply 删除 + 快照，revert 恢复）。
  - 原料：`services/ingredient_merger.py`（`merge_ingredients` 内删除源收藏，任何调用方都生效）+ `services/proposals/executors/ingredient.py`（快照 + revert 恢复）。
- **软删实体**：收藏行保留，列表侧过滤；实体复活后收藏自动恢复可见。
- **导出导入**：云 ZIP 新增 `user_favorites.json`（`entity_type + entity_id + entity_name`）与 **`user_merchant_favorites.json`（商家收藏此前未导出，本次一并补上）**；manifest `extended`/`counts` 同步。导入（`_import_user_favorites`，两遍法）：mapping 为主 + **名字兜底**解析新 id，解析不到 `_skip` 计数不中断；**归属导入用户**；已存在跳过（幂等）。
- 本地模式导出导入：`EXPORT_STORES` 加 `user_favorites`；`FILE_STORE_MAP` 加 `'user_favorites.json' → user_favorites` 与 `'user_merchant_favorites.json' → merchant_favorites`；导入 `user_favorites` 行时补 `entity_key` 归一化（云端导出无该字段，本地 store 的索引依赖它）。

## 三端实现位置

- **web（master）**：`composables/useFavorites.ts`（进页面 load 全量 → Set；乐观更新 + 失败回滚，`toggle` 返回新状态并抛错给调用方提示）+ `components/common/FavoriteButton.vue`；`MerchantsView` 三处内联实现迁移到通用件（列表项菜单保留 `v-list-item` 形态）。
- 列表页 `ProductsView` / `IngredientsView` / `RecipesView`：筛选项 `favorites_only`（FilterBar toggle）+ 请求带 `favorites_first=true` + 行内心形（`@click.stop`/`.prevent` 防导航）。
- 详情页 `ProductDetail` / `IngredientDetail` / `RecipeDetail`：app-bar 桌面平铺按钮 + 移动端三点菜单项（提示用各页既有 `showMessage` / `notify`）。
- 聚合页 `/favorites`（`views/favorites/FavoritesView.vue`，四类 tabs、点击跳详情、取消收藏即移除）+ 侧栏与移动抽屉导航项。
- **本地离线模式**：`DB_VERSION 3→4`，新 store `user_favorites`（索引 `by_entity_key` = `` `${type}:${id}` ``）；`handlers/favorites.ts` + `proxy.ts` 路由；三个列表 handler 支持 `favorites_only/first`（注意 `recipes.ts` 的 `filtered` 是 `const`，用 `splice` 而非重新赋值）；`localErrors` 新增 `favoriteUnsupportedType` / `favoriteEntityNotFound`（三语）。
- **移动端（feat/mobile-app）**：待另做（列表/详情心形 + 只看收藏 + 聚合屏；顺手修 `merchant_provider.dart` 的无效回滚 bug）。

## i18n

- web 三语新增 `favorites.*`（14 键）+ `nav.favorites` + `routes.favorites`；`check:i18n:sources` 2066 → **2081**。
- 文案对齐既有商家收藏措辞（`onlyFavorites` 用「仅看我的收藏」）。

## 测试与验证（2026-10-15）

- 后端新增 **9 例全绿**：
  - `tests/test_user_favorites_api.py`：唯一约束 / 三类往返 + 幂等 / 未知实体 404 / 不支持类型 400 / 软删 404 且列表隐藏 / `favorites_only` 排除非收藏项且 total 一致 / `favorites_first` 置顶且非收藏项相对顺序不变 / 叠加 `no_recent_price` 仍正确。
  - `tests/services/test_favorites_lifecycle.py`：原料合并删源收藏（管理员直写端点）/ mine 导出含收藏 / full 导出 ZIP 结构 + 解包重导入全部跳过（幂等）。
- 导出模块回归：4 项**既有失败**（真实库 testuser 依赖，已 stash 对照确认）+ 1 项因**开发库 schema 滞后**（`user_favorites` 表待后端下次启动 `create_all` 创建；不是代码缺陷）。
- 前端：`npm run build` ✓ / `check:i18n` ✓ / `check:i18n:sources` ✓（2081）/ `test:utils` 52/52 / `npx tsc --noEmit` 与基线错误集**归一化后完全一致**（138 条，仅行号位移）。
- **实机 GUI 验证未做**（当时前端/后端服务都未运行），待用户启动服务后点验清单：三类列表与详情心形、只看收藏筛选、收藏置顶、聚合页四 tab、导出 ZIP 含两份收藏文件、本地模式同套。

## 经验（踩坑）

1. **测试假通过**：内存库每类只有 1 条数据时，「忽略参数」与「正确过滤」的结果相同 → `favorites_only` 的测试不实现也全绿。夹具必须建 2 条、只收藏 1 条。
2. **TestClient 不触发 lifespan**：提案执行器由 `main.py` lifespan 的 `register_all()` 注册，合并类端点测试需 autouse fixture 显式 `register_all()`（对齐 `tests/test_entity_unit_nesting_api.py` 既有写法）。
3. **`db.query(...).subquery()` 传给 `in_()` 触发 SAWarning**（"Coercing Subquery object into a select()"），改用 `select()` 构造。
4. 多态引用（`entity_type + entity_id`）需要四件套：API 存在性校验、列表软删过滤、合并搬迁（删除 + 回滚）、导入名字兜底重映射——缺一就会出现悬空或幽灵数据。
5. 共用列表端点的排序/过滤**必须参数化**（默认 false），只由主列表页开启；分页正确性要求**服务端**实现（客户端排序只能排当前页）。
6. 聚合端点若直出 ORM 对象（无 response_model）会踩序列化问题；用 `MerchantResponse.model_validate(m)` 转换后再返回，并补「收藏了商家」的测试覆盖（空列表时测不出来）。
7. 编辑 CRLF 混合行尾的 `.vue` 文件（本仓 `RecipesView.vue` / `RecipeDetail.vue`）会被工具统一为全 CRLF，diff 偏大但内容无损——提交时留意即可。

## 修复轮（2026-10-15，用户实机反馈）

用户反馈三条：①商品/原料列表点心形会连带跳进详情；②「我的收藏」页过于简陋；③移动端未实现三类收藏与统一收藏页。

**① 心形连带跳转（根因）**：商品/原料的卡片与列表项都是 `:to` 链接（Vuetify 渲染为 `<a>`），`FavoriteButton` 只写了 `@click.stop` —— `stopPropagation` 只拦 JS 冒泡，**拦不住锚点的默认导航**；本仓既有按钮（`mdi-tag-plus` 等）一律用 `@click.prevent` 正是这个原因。修复：`FavoriteButton` 改 `@click.stop.prevent`（一处修复覆盖三类列表与详情）。

**② 「我的收藏」页对齐列表页观感**：不再用精简的 `/favorites` 聚合数据直出文本列表，改为：
- 数据：复用三个列表端点的 `favorites_only=true`（payload 与列表页完全同型），商家用 `/merchants/favorites`；
- 富化（与列表页同源）：`useLatestPrices`（原料 `/nutrition/ingredients/{id}/latest-price`、商品 `/products/entity/{id}/latest-price`）、`/sparklines/{products|ingredients}`、`POST /recipes/batch-cost`；
- 渲染：新增 4 个按类型卡片组件 `frontend/src/components/favorites/Favorite{Product,Ingredient,Recipe,Merchant}Card.vue`，桌面网格 `cols=12 sm=6 md=4 lg=3 xl=2` + 移动端列表项（与各自列表页一致），含头像/图片、名称、品牌/分类/地址、最新价、迷你图、成本·热量、心形与跳转；
- 聚合 `/favorites` 端点保留（移动端与未来功能可用），web 不再消费。

**③ 移动端实现（feat/mobile-app）**：
- `mobile/lib/shared/repositories/favorites_repository.dart`：多态收藏仓库（`fetchIds(type)` / `add` / `remove`）。
- 三个 provider（ingredient/product/recipe）新增 `favoritesOnly`、`favoriteIds`、`loadFavorites()`、`toggleFavorite()`（乐观更新 + `previous` 回滚），列表请求固定带 `favorites_first=true`；recipe 的 `loadRecipes` 重建 state 时同步携带新字段。
- 三个 repository 的 `search`/`getRecipes` 增加 `favoritesOnly`/`favoritesFirst` 参数（透传 `favorites_only`/`favorites_first`）。
- 三个列表屏：条目卡片加心形按钮；筛选面板加「仅看我的收藏」开关（`SwitchListTile`，进入 `_hasActive`/清除逻辑）；`initState` 加载收藏集合。三个详情屏：app bar 加心形（本地 `_isFavorite` 状态 + 失败回滚 + 提示）。
- 新增 `features/favorites/screens/favorites_screen.dart`：四类 tab（原料/商品带最新价与迷你图、菜谱带成本·热量与缩略图、商家带地址），取消收藏即从列表移除，下拉刷新。
- `app_router.dart`：新增 `/favorites` 路由 + `_favoritesTab`（桌面侧栏与移动「更多」弹出菜单都加入）；「更多」菜单由单行 4 项 `Row(Expanded)` 改为每行 4 项的 `Wrap`（5 项时自动换行）。
- 顺手修复：`merchant_provider.toggleFavorite` 的无效回滚（`copyWith(favoriteIds: state.favoriteIds)` 把乐观值赋回自己）→ 改为保存 `previous` 回滚。
- i18n：ARB 三语各加 12 键（`navFavorites`、`favoritesAdd/Remove/Removed/AddFailed/RemoveFailed/OnlyFilter/Empty`、`favoritesTab*`）并 `flutter gen-l10n`。

**测试与验证**：
- web：`npm run build` ✓、`check:i18n` ✓、`check:i18n:sources` 2081、`npx tsc --noEmit` 与基线错误集归一化后完全一致；
- 移动端：`flutter analyze` 0 error（仅 1 条未触碰文件的 `onReorder` deprecation info）、`flutter test` **665 通过 / 6 存量失败**（apple_map×3、locale_preferences×2、my_proposals×1 = 基线）；11 处测试假仓库（`_Fake*Repository` / `_ListRepository`）签名随接口补参同步（`favoritesOnly`/`favoritesFirst`）。
- 实机 GUI 验证仍待服务启动后由用户点验（桌面心形不跳转、收藏页四 tab 观感、移动端更多菜单入口与三类心形）。

**补充（同日第二轮，用户实机两条）**：①移动端「我的收藏」改称「收藏」（zh ARB `navFavorites`，桌面侧栏/更多菜单/收藏页标题同源生效；en/ar 本就是 Favorites/مفضلاتي 不动，web 仍为「我的收藏」）；②收藏页商家 tab 补「已关闭」标注——`_FavoriteTile` 新增可选 `titleBadge`，商家 tab 用与商家列表屏同款橙色胶囊（`Colors.orange` + `merchantClosed`），已关闭商家照常显示但带标注。

**经验**：
1. `@click.stop` 防不住「链接型容器」（`v-card :to` / `v-list-item :to`）的默认导航 —— 子按钮必须 `.prevent`；
2. 聚合页要复用**列表端点**（完整字段）而不是另造精简接口，否则页面必然简陋；富化接口（最新价/迷你图/成本）与列表页保持同源；
3. 给 repository 方法加参数会让所有测试 fake 的 override 失效 —— 改签名时要同步搜 `test/` 下的假实现；
4. Dart `StateNotifier` 重建 state（`state = XxxState(...)`）时必须把新字段一并带上，否则会被静默重置。

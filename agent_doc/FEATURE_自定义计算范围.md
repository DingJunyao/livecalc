# FEATURE：用户自定义计算范围（多地区组合）

## 背景

住在行政区划边界附近的用户，价格数据横跨多个地区（如「灵宝市（县）+ 三门峡市（地级市）」）。原机制只能表达「单个所在地区（`users.region_id`）+ 层级档位（`users.default_calc_scope` ∈ ''/country/province/city/county）」，无法组合多个地区。

本次新增：用户可创建多个「自定义计算范围」（名称 + 多个地区，层级可混合），在「默认计算范围」选择器中选用；计算按所选范围的地区子树**并集**过滤。Web 与移动端的会话级切换器（顶栏「地区/计算范围/币种」）同步支持临时选择。

分支：后端+web master `c908484a`；移动端 feat/mobile-app `7f1c4161`（master 先合入 feat `bc1eabee`）。

## 语义设计

- **多地区过滤 = 子树并集去重**：每个所选地区按 `region_subtree_ids`（path 前缀 + is_active）展开后取并集——选了地级市又选其下辖县不重复计数。未分配地区（`merchant.region_id IS NULL`）的商家始终计入；`None`/`all` = 不过滤（全部地区）——既有约定全部保留。
- **内部多值表示用 `tuple[int, ...]`**：`recipe_service.py:45,267` 把 region_id 用作 lookup_cache 的 dict key，必须可哈希；list 不行。全链路（`resolve_region_param → apply_region_filter/region_subtree_ids → 各 service`）以 int | tuple | None 透传。
- **默认范围解析优先级**（`calc_scope.py`）：`users.default_calc_scope_id`（自定义，**不要求** users.region_id 已设置）> 既有 `region_id + default_calc_scope` 路径；范围被删或 region_ids 为空时回退既有路径。
- **互斥写入**：`PATCH /me` 设 `default_calc_scope_id` 时清 `default_calc_scope`，反之亦然（设层级档位含空串也清自定义）。
- **X-Region 头扩展**（`deps.py`）：`all` / 单 id（完全兼容）/ **逗号分隔多 id**（≤20 个，任一非法→400，沿用既有报错文案；单 id 存 int，多 id 存 tuple 进会话 ContextVar）。
- **显式 query 参数 > X-Region 会话覆盖（含 all 短路用户默认）> 用户默认**——优先级链不变。
- **限额**：每用户 ≤20 个范围、每范围去重后 ≤50 个地区；范围名同用户内唯一（400 已存在同名范围）。

## 后端（master）

- **模型**：`app/models/user_calc_scope.py` 新表 `user_calc_scopes`（id / user_id FK / name String(100) / `region_ids JSON` / 唯一 (user_id,name)）；`users.default_calc_scope_id` FK。导出于 `models/__init__.py`。
- **迁移**：`alembic/versions/20261112_0001_user_calc_scopes.py`（down_revision=`20261023_0001`，inspect 幂等）；SQL 脚本 ×3 `scripts/sql/20261112_user_calc_scopes_{sqlite,mysql,postgresql}.sql`（PostGIS 无关，不需第四份）。**开发库需手工执行 sqlite 脚本**（users 加列 create_all 不会补），表本身由启动 create_all 建。
- **核心链路**：`price_region.py` 的 `region_subtree_ids` 接受 int|tuple|list（多值逐子树合并去重，缓存键 tuple；单值缓存键仍是原 int）；`calc_scope.py` 的 `resolve_default_calc_region_id` 先查自定义范围（去重保序 tuple）再走旧档位推导，`resolve_region_param` 透传；`session_context.py` 注解放宽；`deps.py` X-Region 逗号解析。`merchants.py` 两处直查 `region_subtree_ids` 零改动即兼容。
- **CRUD**：`/api/v1/calc-scopes`（`app/api/calc_scopes.py`，风格照 places.py）：GET 列表（含 `regions` 明细 id/name/display_name/level + `is_default` 派生）/ POST / PUT / DELETE（非本人 404；删除时 `UPDATE users SET default_calc_scope_id=NULL`）。校验：名称 strip 非空、region_ids 去重保序非空 ≤50 且全部存在且活跃、每用户 ≤20。display_name 用 `region_display_name(region, request_locale)` 与 /regions 同口径。
- **用户资料**：`UserResponse`/`UserProfileUpdate` 增 `default_calc_scope_id`（`_user_to_response` 用 `getattr` 兜底——测试的 FakeUser 没有该属性）；`patch_me` 互斥 + 归属校验（400 自定义计算范围不存在）。

## Web（master）

- `types/index.ts`：`UserCalcScope`；`User.default_calc_scope_id`。
- 新组件 `components/common/RegionMultiSelect.vue`：四级级联浏览 + 每级可「添加当前地区」+ chips（文案带祖先前缀「河南 / 三门峡市」，编辑回填走 `/regions/{id}` ancestors）。
- 新组件 `components/profile/CalcScopeManagerDialog.vue`：范围列表（设为默认/编辑/删除 + 确认框）+ 新建/编辑表单；变更后 emit `changed` 由 ProfileView 刷新。
- `ProfileView.vue`：设置列表新增入口（`v-if="!isLocalMode"`）；`scopeDialog` 选项追加自定义（value=`custom:<id>`），保存按前缀分流 PATCH；`scopeLabel` 支持自定义名；挂载时拉 `/calc-scopes`。
- `calcContext` store：增 `effectiveRegionIds` 持久化到 sessionStorage；`apply` 接受 `regionIds`；`resolveEffective` 对 custom 分支跳过层级截取。
- `client.ts`：X-Region 注入优先级 `''→all` → `effectiveRegionIds.join(',')` → 单 id。
- `CalcContextMenu.vue`：打开时拉 `/calc-scopes`，范围下拉追加自定义项；选中自定义时地区级联禁用、保存传 `regionIds`。
- i18n：三文件 `profile.customCalcScopes*` / `profile.customScope.*`（zh/en/ar 同步）。
- 本地模式不在本次范围（无范围通道属既有缺口，维持现状）。

## 移动端（feat/mobile-app）

- 新模块 `lib/features/calc_scope/`：`models/calc_scope.dart`（含 `regionsSummary`）、`repositories/calc_scope_repository.dart`、`providers/calc_scope_provider.dart`（照 PlaceList 模式）、`screens/calc_scope_list_screen.dart`（FAB + PopupMenu 设为默认/编辑/删除；设为默认走 `AuthRepository.updateMe({'default_calc_scope_id'})` 后 `applyUser`）、`screens/calc_scope_form_screen.dart`（FormExitGuard + saveAppBarActions/saveBottomBar；`regionRepository` 可注入供测试）、`widgets/region_multi_select_field.dart`（级联 + 添加 + InputChip，display_name 优先）。
- 路由 `/profile/calc-scopes`、`/profile/calc-scopes/new`、`/profile/calc-scopes/:id/edit`；`_isFullScreenFormRoute` 加精确 `/profile/calc-scopes/new` + 新正则 `^/profile/calc-scopes/\d+/edit$`（原实体正则不含 /profile 前缀）。
- `profile_screen.dart`：设置区入口 ListTile；默认范围对话框加载 `/calc-scopes` 追加 radio（`custom:<id>`，subtitle 地区摘要）；`_saveLocaleSettings` 增 `defaultCalcScopeId` 参数；范围行 subtitle 在自定义默认时显示「自定义计算范围」。
- `calc_context_provider.dart`：`CalcContextState` 增 `effectiveRegionIds`（apply 时 `toSet()` 去重保序）；custom 分支不做祖先链解析、regionId 置 null。拦截器：`''→all` → 多 id join(',') → 单 id。
- `calc_context_menu_button.dart`：sheet 打开拉范围列表，下拉追加自定义项；选中时 RegionSelectField 用 `AbsorbPointer+Opacity` 禁用；保存传 `customRegionIds`。
- `User` 模型增 `defaultCalcScopeId`；`updateSettings` 增参数。
- l10n：三语 arb 新增 24 组 key（含 `calcScopeDeleteMessage` 的 {name} placeholder），`flutter gen-l10n` 重新生成（注意：gen 会触发 pub 改写 `pubspec.lock`，需还原）。

## 坑

1. **`recipe_service.py` 缓存键**：region_id 作 dict key，多值必须 tuple，否则运行时 TypeError——这也是全链路用 tuple 而非 list 的根因。
2. **`_user_to_response` / `_scope_to_response` 必须用 `getattr(user, 'default_calc_scope_id', None)`**：conftest 的 FakeUser 是普通类没有该属性，直接点号访问会让 GET /auth/me、calc-scopes 列表全 500。
3. **FakeUser 与 `GET /auth/me` 本就不兼容**（缺 `is_active` 等）——删除范围后验证默认引用清空要查 DB 或走 PATCH 响应，不能 GET /auth/me。
4. **移动端 widget 测试两坑**（profile_screen scope 对话框测试）：新增的 await `_fetchCalcScopes()` 让对话框打开依赖网络完成——必须像币种用例一样 ①mock secure storage 平台通道（`AuthInterceptor` 会挂起）②给 dio 换受控 adapter（默认 HTTP 在 FakeAsync 永不返回）。
5. **表单屏标题与保存按钮同文案会撞 `find.text`**：新建态标题与按钮都用「新建范围」时 widget 测试双匹配；按 places 惯例按钮用 `commonAdd`。
6. `flutter gen-l10n` / 任何 pub 操作会改写 `pubspec.lock`——提交前还原。
7. `app_bar_title_budget_test` 需同步 `_specs`：新页面 calc_scope_list（back,0 icon）/ calc_scope_form（back,0 icon,button commonSave）。

## 验证

- 后端（根 .venv）：`tests/api/test_calc_scopes.py`（10 例：CRUD/归属 404/校验 400/互斥/删除清引用/X-Region 多 id 端到端）+ `tests/services/test_calc_scope.py`（+5 例：自定义优先/无 region_id 可用/被删回退/空组合回退/去重保序）+ `tests/services/test_price_region.py`（+4 例：并集去重/多地区过滤/空元组 filter False/会话 tuple）24 例全过；价格/菜谱/地区回归子集 41 过（`test_latest_price_batch_rejects_invalid_ids` 失败为既有，stash 对照确认）。
- Web：`npm run build` ✓、`check:i18n` ✓、`test:utils` 73 ✓。
- 移动端：新增 17 例（模型 3/仓库 4/Provider 3/表单屏 2/拦截器 2/预算 2 spec + profile 对话框 1 扩展）全过；`flutter analyze` 0 issue；路由 + plan_detail 子集过。
- 待办：外部环境部署复核；开发库执行 `scripts/sql/20261112_user_calc_scopes_sqlite.sql` 后重启后端。

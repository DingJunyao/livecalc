# BUGFIX 关联弹层带出单位：商品默认单位优先于原料默认单位

## 现象（用户报告）

「关联其他商品/原料」弹层里，在各种浓汤宝商品之间建关联时，带出的是**原料的「块」**而不是**商品的「盒」**。用户规则：**不管在哪，商品的默认单位都优先于原料的默认单位**。

## 数据（只读实查）

- 原料 729「浓汤宝」：`entity_unit_overrides` = [块（is_default=1，32g）]；
- 浓汤宝商品（759/1096/1097/1120–1124）：自身单位 = [块（is_default=0）、盒（is_default=1，4块或2块/盒）]。

## 根因

关联弹层带出默认单位时取的是**单位列表第一项**（Web `currentUnitOptions.value[0]`、移动端 `options.first`）。单位下拉的顺序是「商品自身单位（按 id/创建序）→ 原料单位 → 全局单位」，商品自身列表里「块」恰好排在「盒」前面 → 带出块。

项目里已有正确实现「**商品自身默认 > 商品关联原料默认**」的函数——Web `fetchEntityDefaultUnitName`（entityUnits.ts）+ 移动端 `loadEntityDefaultUnitName`（entity_unit_names.dart）——但只接了记价表单，**关联弹层没用它**。

## 全量排查结果（两端所有「为商品带出默认单位」的场合）

**✗ 有此问题、已修复（2 处 4 个点）：**

| 端 | 文件 | 位置 |
|---|---|---|
| Web | `EntityQuantityLinksSection.vue` | `openAdd` 当前侧、`onTargetChange` 目标侧 |
| 移动端 | `entity_quantity_link_edit_page.dart` | `_loadCurrentUnits` 当前侧、`_loadTargetUnits` 目标侧 |

**✓ 本来就正确（无需改）：**
- Web `PricesView.vue`（记价页选中商品 → `fetchEntityDefaultUnitName('product', …)`）；
- Web `QuickPriceRecordDialog.vue`（快速记价同上）；
- 移动端 `price_record_form_screen.dart`（`_applyEntityDefaultUnit`）；
- 移动端 `planner_screens.dart`（试算条目默认单位 ×2，商品/原料各走对应实体的默认）。

**○ 排除（不属于「商品默认 vs 原料默认」语义）：** 记价编辑/再次记录的预填分支保留记录原单位（Web `applyEntityDefaultUnitOnSelect=false`）；营养基准单位（按可折算量纲，另有一套口径）；快速填写/粘贴导入（无默认单位带出）；`PriceRecordForm`/详情页 unit 赋值均为复制既有记录或用户点选。

## 修复

取值逻辑统一为：**实体默认单位（is_default）在候选列表里 → 用它；没有默认单位 / 读取失败 / 不在候选里 → 回退列表第一项（原行为兜底）**。

- Web：组件内新增 `pickUnitFor(entityType, entityId, ingredientId, options)`（内部走 `fetchEntityDefaultUnitName`），`openAdd` 与 `onTargetChange` 改用；`openEdit` 仍保留关联原单位。
- 移动端：页面新增 `defaultUnitLoader` 测试注入缝（缺省走 `loadEntityDefaultUnitName`），`_loadCurrentUnits` / `_loadTargetUnits` 在无已选单位时先取默认单位再交给 `_pickUnit`（有已选单位——编辑态——不取，保持原值）。

## 验证

- Web（master worktree）：`npm run build` ✓、`test:utils` 73 passed ✓（vue-tsc 因环境 TS 补丁问题无法运行，与本次无关）；提交 `44147bf1`，合并到 feat/mobile-app（merge `62b4be6a`）。
- 移动端：`flutter analyze` No issues found；`entity_quantity_link_edit_page_test.dart` 3 项全过——新增「浓汤宝盒优先于块（两侧均带出盒）」「无默认单位回退第一项」2 例。
- **注意**：原整页测试未注入 `defaultUnitLoader` 时会走真实 API，`pumpAndSettle` 因加载圈永不停止而超时——新测试必须带注入缝。

## 复盘

「商品默认 > 原料默认」的取值函数此前只在记价链路接入；新写的关联功能（弹层）复制了「取第一项」的旧习惯而没复用它。新增任何「为商品预选单位」的场合都应走 `fetchEntityDefaultUnitName` / `loadEntityDefaultUnitName`，而不是猜列表顺序。

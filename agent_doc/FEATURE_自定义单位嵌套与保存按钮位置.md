# FEATURE：自定义单位嵌套（1箱=12盒）+ 价格记录单位下拉 + 保存按钮位置

> 2026-10-13。用户反馈五件事（web + 移动端）：
> 1. 移动端自定义单位（如食用油「桶」）后，回到价格记录页下拉里选不到；
> 2. 给商品改名后，价格记录里的商品名不跟着改；
> 3. 移动端自定义单位/密度界面是「先跳到一个列表页」，右上角却是「完成」会直接退出，
>    期望：详情页直接显示列表 + 列表右上方新增按钮 + 行内编辑/删除，密度同理（一个实体至多一条）；
> 4. 自定义单位要填「换算系数 + 单个重量」，希望换算系数不填默认 1、单个重量拆成「数值 + 单位」
>    以便嵌套（一盒奶 220 mL、一箱奶 12 盒）；
> 5. 保存按钮统一挪到右上角后用不惯：移动端希望可以选「右上角 / 页面下方」（本地设置）；
>    Web 对话框现在上下各有一个保存按钮，应改为只保留下方、右上角放关闭。

## 1. 数据模型：单位链

`entity_unit_overrides` 新增可空列 **`weight_unit_override_id`**（指向**同一实体**的另一条自定义单位），
语义统一为：

```
1 个自定义单位 = conversion_factor(默认 1) × weight_per_unit × weight_unit
weight_unit = weight_unit_override_id（递归解析）| weight_unit_id（全局质量/体积单位）| 缺省 → 克
```

- 「盒 = 220 mL」「箱 = 12 盒」→ 1 箱 = 12 × 220 mL = 2640 mL，改「盒」时「箱」自动跟随。
- `weight_unit_id` 与 `weight_unit_override_id` **互斥**（同时传 400）。
- 不加 DB 级自引用外键：软删 + 导出导入会重排行 id，引用完整性由应用层保证（三引擎 DDL 一致）。
- 迁移：`alembic/versions/20261013_0001_add_weight_unit_override_id.py`；
  SQL 脚本 `scripts/sql/20261013_entity_unit_weight_override_{sqlite,mysql,postgresql}.sql`。

### 换算链解析（唯一入口）

`UnitConversionService.resolve_override_amount()`：返回 `(单个自定义单位对应的数量, 全局单位)`。
- 每跳都乘该跳的 `conversion_factor ?? 1` 与 `weight_per_unit ?? 1`；
- 循环引用（visited 集合）、深度 > 8、引用悬空**不臆估**：本行另有 `weight_per_unit` 时退化为全局单位路径，
  否则返回 `None`；
- 消费方全部改走该入口：`convert()`、`_get_piece_weight_kg()`（count 兜底）、
  `recipe_service` 菜谱营养 count 分支（保持「无覆盖 → ratio=0」不落回 1个=100g 的老口径）。

## 2. 商品改名 / 合并同步价格记录名

`product_records.product_name` 是写入时快照列（NOT NULL），价格列表/详情/历史/商家价格都直接读它，
改名不改它就会一直显示旧名（开发库实测 136/3410 行已不一致）。

- `ProductExecutor`（改名走提议执行器，管理员与普通用户同路径）在 update 且 payload 含 `name` 时，
  把该商品价格记录的 `product_name` 一并更新；`revert_payload.record_name_restore` 记录**逐行旧值**
  （只记录确实变化的行），回滚时按行还原，历史脏数据不会被"顺带抹平"。
- `ProductMergeExecutor` 合并商品时同步把迁移记录的名字改成目标商品名，revert 时还原源名。
- 存量数据回填脚本（三引擎，幂等）：
  `scripts/sql/20261013_backfill_product_record_names_{sqlite,mysql,postgresql}.sql`。
  MySQL 用 `UPDATE ... JOIN`（避免 1093），PG/SQLite 用 `UPDATE ... FROM` / 关联子查询。

## 3. Web

- **价格记录单位下拉**：新增 `src/utils/entityUnits.ts`，与后端 `get_entity_override` 的
  「商品 > 关联原料 > 全局」链一致；下拉每次从全局单位基准**重建**（原来只追加，切商品会残留），
  并带请求序号防竞态。`PricesView` / `QuickPriceRecordDialog` / `PriceRecordForm` 接入。
- **自定义单位表单**：去掉「质量/体积」开关，改为「单个重量 = 数值 + 单位」；
  单位可选全局质量/体积单位或**同一实体的其他自定义单位**（编码 `u:<id>` / `o:<id>`）；
  换算系数留空或 0 一律发 `null`（后端按 1）；列表按层级显示 `1箱 = 12 盒` /
  `1盒 = 220 mL（≈227 g）`，链上单位改动后自动跟随。
- **对话框**：25 个对话框统一为「底部保存 + 标题行右上角关闭(X)」。此前
  `34c1fa30` 把确认按钮搬到标题行又给底部加 `d-none d-md-flex`，导致桌面端一屏两个保存按钮。
- **本地（离线）模式**：`unitConverter.ts` 新增 `resolveOverrideAmount` 跟随嵌套链，
  `priceNormalize` / `costCalculator` 传入同实体覆盖表；`weight_unit_id` 缺失时按克兜底（与后端一致）；
  顺带修 `units.ts` 的 `deleteOne` 未导入（本地删单位/密度直接 ReferenceError）与
  `getEntityDensity` 返回对象而非数组（本地密度永远不显示）。
- `check-i18n.mjs sources` 忽略 `*.test/*.spec`：测试用例名不是用户可见文案（此前
  `197314ba` 的中文用例名让该检查变红）。

## 4. 移动端

- **价格记录单位下拉**：新增 `shared/utils/entity_unit_names.dart`
  （`loadEntityUnitNames` 合并商品 + 关联原料的自定义单位；`mergePriceUnitOptions` 保证当前值在列表内，
  否则 DropdownButton 会因值不在 items 里断言失败），新增/编辑两个价格页接入。
- **详情页直接管单位与密度**：`EntityUnitsCard` 改为可交互列表——区块右上方「添加」，
  行内编辑/删除（待审行只显示「待审」）；密度一个实体至多一条，展示该条并提供编辑/删除；
  新增/编辑改为对话框（自带底部保存），不再跳 `EntityUnitsScreen`（页面与路由已删除）。
- **单位表单**：与 web 同构（换算系数可空、单个重量 = 数值 + 单位、单位可选全局单位或同实体自定义单位、
  自引用/成环前端拦截）；列表展示 `1箱 = 12 盒` / `1盒 = 220 mL（≈ 227 g）`。
- **保存按钮位置本地设置**：`features/profile/providers/save_button_position_provider.dart`
  （SharedPreferences `mobile.save_button_position`，默认右上角）+ `shared/widgets/save_action_button.dart`
  （`saveAppBarActions` / `saveBottomBar` 一对 helper，位置决定谁生效、busy 时显示转圈）；
  设置入口在「我的」页，作用于**所有全屏表单**（商品/原料/商家/地点/菜谱/账号/价格新增与编辑/
  营养编辑/单位偏好/营养目标）。对话框保持各自底部保存，不跟随该设置。

## 5. 验证

- 后端：新增 `tests/services/test_nested_unit_override.py`（嵌套链、换算系数默认 1、密度折克、
  count 兜底、循环引用、悬空/跨实体引用、菜谱营养 1468.4 kcal）、
  `tests/test_entity_unit_nesting_api.py`（互斥/同实体/自引用/成环/悬空 400）、
  `tests/test_product_rename_syncs_records.py`（改名同步 + 逐行回滚 + 非改名不动）；
  `tests/services + tests/api + test_products.py` 全量：改前基线 9 failed/293 passed，
  改后 9 failed/302 passed（失败集合与基线完全一致，均为沙箱临时目录/网络/登录夹具存量问题）。
- Web：`npm run build`、`check:i18n`、`check:i18n:sources`、`test:utils`(18/18) 通过。
- 移动端：`flutter analyze` 0 issue；`flutter test` 全量见下方"验证记录"。

## 6. 经验

1. 「换算系数 × 单个重量」这套语义一旦要支持嵌套，就必须有**唯一的解析入口**——原来
   `convert` / `_get_piece_weight_kg` / 菜谱营养 / 前端本地模式各写一遍，加一层链就要改四处，
   漏一处就是静默错数。本次统一到 `resolve_override_amount`。
2. 引用型字段（指向同表另一行）在「软删 + 导出导入重排行 id」的项目里，**不要加 DB 级外键**，
   否则导入顺序、软删都会咬人；改成应用层校验 + 名字冗余（导出带 `weight_unit_override_name`，
   导入二次回填）更稳。
3. 快照列（`product_records.product_name`）的维护必须挂在**唯一的写入口**上：商品改名走提议执行器，
   管理员直写与普通用户待审同路径，改在端点里就会漏掉一半。
4. 「切换对象后重填选项」要用**基准重建**而不是追加：原来价格单位下拉只 append，
   切商品后上一个商品的自定义单位一直留着，清空商品也不消失。
5. Web 对话框「标题行保存 + 底部保存」是 `d-none d-md-flex`（只在 md 以下隐藏底部）造成的
   桌面端双按钮；移动端则相反——把「完成/保存」放右上角会被当成"改完就走"，让用户丢输入。
   两端对同一个按钮的默认预期不同，所以移动端做成用户可选（存本地），Web 固定底部。
6. `flutter gen-l10n` 后生成的 `app_localizations*.dart` 是入库文件，ARB 改动必须连带重新生成
   （本次 39/40/41 行纯新增，无重排）。

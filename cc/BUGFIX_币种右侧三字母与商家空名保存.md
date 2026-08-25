# BUGFIX_币种右侧三字母与商家空名保存.md

## 用户反馈

- 网页端和 app 上，币种相对于价格的位置不一致。统一放在右边，显示为三字母（下拉显示全称和字母）
- 新增、修改商家，只填写国家/地区时不会保存，需要也能保存

## 根因

### 币种位置/显示不一致

- Web 六处价格表单（PriceRecordForm / QuickPriceRecordDialog / PricesView / ProductDetail / IngredientDetail / QuickFillView）币种按钮在**价格左侧**，显示**符号**（¥），下拉项「符号 全称」
- App 价格新增/编辑页币种下拉已在价格**右侧**，但收起显示「¥ CNY」；快速填写页显示「¥ CNY」容器
- 两端位置相反、显示形态各异 → 用户要求统一：右侧 + 三字母

### 商家只填国家/地区无法保存

- 后端 `MerchantCreate.name` 为**必填**（Pydantic `Field(...)`）→ 缺 name 直接 422
- Web 两处表单（MerchantsView / MerchantDetail）：name 字段 `required` + 保存前 `if (!name.trim()) return` 双重拦截
- App 商家表单：`_save()` 空名直接 SnackBar 拦截
- DB 列 `name NOT NULL`（可存空串，无需迁移）

## 修复

### Web（master，提交 650eb60）

- 六处价格表单统一：币种菜单移到**价格右侧**，按钮显示**三字母代码**（`recordCurrency`），下拉项显示「全称 代码」（`${c.name} ${c.code}`）；移除仅用于按钮的 `currencySymbolText` 状态与 `currencySymbol`/`symbolFromIntl` 导入（QuickFillView 保留 `currencySymbolText` 用于价格输入 placeholder）
- 商家：MerchantsView / MerchantDetail 去掉 name `required` 与空名拦截，标签改「商家名称（可留空）」；列表/详情显示回退「未命名商家」

### 后端（master，提交 650eb60）

- `MerchantCreate.name` 改 `Optional[str] = Field(None, max_length=200)`，创建端点 `name=merchant.name or ""`（DB NOT NULL 不变，存空串）
- 新增 `tests/test_merchant_empty_name.py` 3 例（空串/缺字段/正常名）

### App（feat/mobile-app，提交 1ff7ad8）

- 价格新增/编辑页币种下拉：`selectedItemBuilder` 实现**收起只显示三字母**（CNY），展开列表「全称 代码」（人民币 CNY）；快速填写页币种按钮只显示代码、列表全称+代码
- 商家表单去掉空名拦截，标签「商家名称（可留空）」；商家列表/详情空名回退「未命名商家」

## 验证

- 后端：空名商家测试 3/3 + 汇率相关 12/12（master 与 feat/mobile-app 均通过）
- Web：master worktree 与主 worktree 前端构建通过
- 移动端：`flutter analyze` 0 issue；全量 `flutter test` 418/418（新增 1 例商家空名保存）

## 经验

- `DropdownButtonFormField` 收起/展开显示不同文案：`items` 用完整文案，`selectedItemBuilder` 用精简文案（两列表需同序同长）
- mocktail `when` 未注册的具名参数视为任意匹配（createMerchant 的 regionId 等无需显式注册）
- 商家 name 可空但 DB NOT NULL：用空串而非 NULL，避免迁移

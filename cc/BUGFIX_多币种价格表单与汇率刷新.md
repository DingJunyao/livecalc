# BUGFIX_多币种价格表单与汇率刷新.md

## 用户反馈

- 价格新增/修改：网页、app 均未把商家放在最前面；网页无选择币种的下拉，输入价格仍显示「价格（元）」；app 币种下拉样式与其他控件不符，且新增与修改不一致
- 刷新汇率报错：`POST /api/v1/admin/exchange-rates/refresh` → 502，`汇率拉取失败: list indices must be integers or slices, not str`

## 根因

### 后端汇率解析（master）

frankfurter v2 API（`https://api.frankfurter.dev/v2/rates?base=EUR`）返回**按币种平铺的数组**：

```json
[{"date":"2026-08-25","base":"EUR","quote":"AED","rate":4.2903}, ...]
```

而 `FrankfurterProvider.fetch` 按 v1 dict 结构解析（`data["base"]/data["date"]/data["rates"]`），对 list 做字符串键索引 → `TypeError: list indices must be integers or slices, not str`。HTTP 请求本身 200 正常，解析层崩。

### Web 价格对话框（master）

- `PricesView.vue`：价格字段在前、标签「价格 (元)」、商家在底部、无币种
- `ProductDetail.vue`：价格历史区新增/编辑对话框同样问题（标签「价格（元）」）
- `IngredientDetail.vue`：编辑价格对话框同样问题
- （`PriceRecordForm.vue` / `QuickPriceRecordDialog.vue` 已是商家在前 + 币种下拉，无需改）

### 移动端价格表单（feat/mobile-app）

- 新增页 `price_record_form_screen.dart`：币种用自定义 `PopupMenuButton`+带边框 `Container`，与单位 `DropdownButtonFormField` 风格不一致；商家字段排第 4 位
- 编辑页 `price_record_edit_screen.dart`：**完全没有币种选择**；字段用 `_label()` 包行的旧样式，与新增页不一致（新增/修改不一致的根源）

## 修复

### 后端（master，提交 7543254）

`backend/app/services/exchange_rate_providers.py`：`FrankfurterProvider.fetch` 兼容两种响应结构——list 时按 `quote→rate` 建映射、取 `max(row["date"])` 为快照日期；dict 时走原 v1 分支。新增 `backend/tests/services/test_exchange_rate_providers.py`（mock httpx，v1/v2/尾斜杠 3 用例）。调度器走同一 `fetch_and_store_daily`，一并修复。

### Web（master，提交 7543254）

三个旧对话框统一为：**商家 autocomplete 置于最前**（联动商家默认币种）、价格旁加**币种下拉**（复用 PriceRecordForm 的符号按钮 + compact list 模式）、标签改为「价格 *」；新增/编辑保存均携带 `currency`，编辑时按记录原币种预填。全前端已无「价格（元）/价格 (元)」残留。

### 移动端（feat/mobile-app，提交 802750b）

- 新增页：商家 `Autocomplete<Merchant>` 移到最前；币种改为 `DropdownButtonFormField<String>`（与单位下拉同款 OutlineInputBorder 12 圆角），行内 `SizedBox(width: 132)` 解决 InputDecorator 无界宽度断言；`key: ValueKey(_currency)` 保证商家默认币种程序化变更时下拉同步显示
- 编辑页：整体重写对齐新增页——商家在前、inline label 样式、价格带 `prefixText` 币种符号 + 币种下拉；`PriceRecordFormResult`/`PriceRecordFormArguments` 增加 `currency`/`initialCurrency`；币种优先级：记录原币种 > 商家默认 > CNY
- 调用链：价格列表/商品详情/原料详情三处编辑入口 + 三个 notifier（`price_provider`/`product_provider`/`ingredient_provider`）透传 `currency`，编辑后列表局部更新同步币种

### 测试

- 新增/编辑页测试适配字段顺序与标签（价格定位改 `find.widgetWithText(TextField, '价格')`）
- 补齐测试 fake 的 `createRecord`/`updateRecord` `currency` 参数
- 顺手修复 region 提交（9337a66）引入的预存失败：`/cost`、`/merchant-costs` 现带 `queryParameters`，recipe 三处 mock 补 `any(named: 'queryParameters')`；比价矩阵 ¥ 前缀断言更新

## 验证

- 后端：汇率相关测试 16/16（provider 3 + service 4 + API 9），master 与 feat/mobile-app 均通过
- Web：master worktree 与主 worktree 前端构建均通过（vite build）
- 移动端：`flutter analyze` 0 issue；全量 `flutter test` 417/417 通过

## 经验

- frankfurter v2 `/rates` 是数组结构，v1 `/latest` 才是 dict——接第三方 API 先实弹一次看响应形状
- `DropdownButtonFormField` 放进 `Row` 必须有界宽（`Expanded`/`SizedBox`），否则 InputDecorator 断言
- `DropdownButtonFormField` 的 `initialValue` 只生效一次，程序化改值需 `key: ValueKey(value)` 重建
- region 提交给 recipe 仓库接口统一加了 `queryParameters`（含空 map），mocktail 全参数严格匹配，stub 必须补 `any(named: 'queryParameters')`

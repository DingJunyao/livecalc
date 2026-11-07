# FEATURE：快速填写价格改系统数字键盘 + 币种跟随商家地区

日期：2026-11-07
范围：移动端快速填写（flutter，feat/mobile-app）+ Web 快速填写（vue，master），无后端改动、无迁移。

## 用户要求

1. 快速填写录价格时用**系统数字键盘**，不要自绘的数字键盘；并检查其他地方是否有同样情况。
2. 快速填写的**币种按商家的地点自动选**，不用显式定义。

## 排查结论

- `NumericKeypad`（`mobile/lib/shared/widgets/numeric_keypad.dart`）全 App **只有快速填写页在用**；其余所有数字输入（记价表单、记价编辑、试算、营养目标、菜谱分量、关联换算等）早已是系统键盘 `keyboardType: TextInputType.numberWithOptions(decimal: true)`，记价表单还用 `prefixText` 显示币种符号。→ 快速填写是唯一例外，无其他地方需要改。
- 后端商家接口本就返回推导币种 `effective_currency`（`GET /merchants` 由 `_attach_effective_currency` 附加；链路 `get_merchant_default_currency`：商家显式 `default_currency` → `region_id` 地区国家币种 → `DEFAULT_CURRENCY`），「按商家地点选币种」后端已实现，前端没用上。
- 原有 bug（顺带发现）：移动端 `_selectMerchant` 只读 `default_currency`，商家未显式设置时**沿用上一个商家选中的币种**（换商家不换币种）；web 端则是 `default_currency || effective_currency` 且带显式选择器。

## 改动

### 移动端（feat/mobile-app `39e219df`）

`mobile/lib/features/prices/screens/quick_fill_screen.dart`：

- 价格输入由「`GestureDetector` 只读展示 → `_showKeypad` 弹 `_PriceInputSheet`（`NumericKeypad` 计算器键盘）」改为**行内 `TextField`**：`numberWithOptions(decimal: true)` + 新增 `_PriceInputFormatter`（白名单 `^\d*\.?\d*$`，拦第二个小数点；个别输入法在数字键盘上仍可能给出多余字符）+ `prefixText: _currencySymbol` + hint `0.00`（空态即显示币种，对齐 web placeholder）+ 右对齐固定宽 96，`Directionality(ltr)` 包裹保持数字方向。
- 删除 `_showKeypad` / `_PriceInputSheet` / `onShowKeypad` 回调；**删除 `shared/widgets/numeric_keypad.dart`**（无其他使用方）。
- 币种：删 `_currencies` / `_loadCurrencies()`（`/currencies` 拉取）与 `PopupMenuButton` 选择器；`_selectMerchant` 改读 `merchant['effective_currency'] ?? merchant['default_currency']`（测试注入的商家可能缺字段，逐级回退）；原选择器位置改为**只读展示**当前推导币种。
- 表头「单价」列右侧预留 `SizedBox(96→140)`（价格列由「最小 56 可撑开」变为固定 96 + 单位 chip）。
- `_saveAll` 逻辑不变（`priceController.text` → `double.tryParse` > 0 才保存），输入方式变化不影响保存口径。

### Web（master `30f700e0`）

`frontend/src/views/prices/QuickFillView.vue`：

- 移除历史商品行 / 新增商品行两处**币种 `v-menu` 选择器**；删 `currencies` ref 与 `loadCurrencies` 调用（import 同步清理）。
- `onMerchantChange` 改用新抽取的 `applyMerchantCurrency(m)`：`recordCurrency = m?.effective_currency || m?.default_currency || 'CNY'`（`effective_currency` 优先——它本就是含显式覆盖的推导值），币种符号仍走 `currencySymbol()` 异步取、`symbolFromIntl` 兜底。
- **草稿恢复补币种同步**：`restoreDraft()` 直接写 `selectedMerchantId` 不触发 `onMerchantChange`，币种会停留在默认 CNY；`loadMerchants()` 拿到商家列表后若已有选中商家则补调 `applyMerchantCurrency`，避免恢复草稿后按 CNY 保存。

## 测试

- 移动端：重写 `quick_fill_compact_layout_test.dart` 键盘用例为「系统键盘 TextField 输入 + 行内回显（prefix `¥` + 文本）+ 拦截第二个小数点」；`quick_fill_screen_test.dart` 新增「币种跟随商家地区（`effective_currency: 'IDR'` → 标签 IDR + 价格前缀 Rp，无 ¥）」，`pumpQuickFill` 支持注入自定义商家列表；快速填写 6 例 + `localized_prices_test` 21 例 + `price_list_screen_test` 3 例全过（币种标签「币种」保留故 localized 断言不受影响）；`flutter analyze` 无新增 issue（仅 1 条既有 product_form 提示）。
- Web：`npm run build` ✓（29.9s）、`check:i18n` + `check:i18n:sources` ✓（`prices.selectCurrency` 键保留，记价表单/快速记价对话框仍在用）。
- 无后端、无迁移、无需重启。

## 行为变化

- 价格录入从「点一下弹计算器键盘 → ✓ 确认」变为**直接行内输入**（系统数字键盘，实输实显）。
- 快速填写不再提供手动换币种；记价币种完全由商家（显式 `default_currency` 或地区）决定。web 记价表单 `PriceRecordForm` / 快速记价对话框 `QuickPriceRecordDialog` 的币种选择**保留**——那里商家可选可不选，显式币种仍是需求。
- 分支：master `30f700e0` → 合入 feat/mobile-app（merge `6345eccb`，`.gitignore` 冲突取 feat 侧：`mobile/` 在 feat 是被跟踪源码目录不能加入忽略）。

## 同日追加：保存按钮右上角 + 不显示币种

- 「保存所有价格」从底部 `SafeArea > FilledButton` 改为 **AppBar 右上角保存图标**（`Icons.save`，与 planner 页一致；tooltip 复用 `quickFillSaveAll`）；未选商家/加载中禁用——此前按钮在商家未选时整段不渲染，移到常驻的 AppBar 后需显式 guard（与粘贴按钮同条件 `_selectedMerchantId == null || _loading`）。
- 删除「币种: XXX」只读展示行；**价格输入前缀（¥/Rp）成为唯一币种提示**。`priceCurrencyLabel` 仍被记价表单/记价编辑使用，l10n 键保留。
- 底部按钮删除后无需补 SafeArea：`ListView` 默认用 `MediaQuery.padding` 做滚动 padding，末行（添加商品按钮）可滚出底部导航条区域。
- 测试：币种用例改断言 `find.text('IDR') findsNothing` + Rp 前缀；`localized_prices_test` 移除币种标签断言；quick fill/compact/localized/price_list 4 套件 30 例全过，analyze 无新增。

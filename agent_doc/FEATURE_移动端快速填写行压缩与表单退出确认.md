# FEATURE: 移动端快速填写行压缩 + 表单退出二次确认

日期：2026-11-07 ｜ 分支：feat/mobile-app（仅移动端，无 master 同步需求）

## 背景（用户报告两点）

1. 移动端「价格快速填写」各行高度过高、特别松散；很多商品名称显示不完全。
2. 新增商品写了信息后退出无任何确认，直接丢失；新增原料、菜谱、商家、试算同样。

## 问题 1：快速填写行（quick_fill_screen.dart）

**实测定位**（临时 widget 测试量过）：360dp 窄屏下，`Card`（默认 margin 4）+ 外层
padding 4 + 卡片内 padding 8 + 名称 `Padding(vertical:10)` + 16px `bodyLarge`
字体 + 价格 TextField 固定 100 宽 → 名称列只剩 **~164px、单行卡片高达
116px**，长名换行 3-4 行，观感即「松散 + 显示不全」。

**改法**（对齐 web QuickFillView 的紧凑单行 flex）：

- 去掉 Card，改扁平行 + 行间细分隔线（`Divider(indent:16, thickness:0.5)`）。
- 名称：`bodyMedium`(14px)、不限行数换行（完整可见）；新增行用 `isCollapsed`
  紧凑 TextField（去掉 labelText，留 hint）。
- 价格：TextField（AbsorbPointer）改为纯文本展示（空显 `—`，有值显
  `¥xx`，Directionality.ltr）；点按仍弹数字键盘。因不再有 TextField 自带
  controller 监听，`_showKeypad` 改为 `await` 弹层后手动 `setState` 刷新行。
- 单位 chip：`labelMedium`(12px) + `outlineVariant` 边框 + 圆角 6。
- 效果：单行 ~40px（旧 116px），长名 2 行 ~60px；断言进
  `quick_fill_compact_layout_test.dart`（行高 <56、文本所需宽 ≤ 可用宽）。

## 问题 2：表单退出二次确认（仅新增态）

新组件 `shared/widgets/form_exit_guard.dart`：

- `FormExitGuard` 包裹 Scaffold：`PopScope(canPop:false)` +
  `onPopInvokedWithResult` → 脏检查（`isDirty` 闭包，弹出时实时求值）→
  `confirmDiscardUnsavedChanges()` 对话框（新增 l10n 键
  `formExitUnsavedTitle/Body/Discard` + 复用 `commonCancel`；放弃按钮用
  error 色）。`_confirming` 防连按叠层。
- 关键机制（go_router 14.8.1 实测源码）：系统返回/默认 AppBar BackButton /
  `maybePop()` **会**被 PopScope 拦截（doNotPop → maybePop 返回 true 且回调
  `onPopInvokedWithResult(false)`）；而 go_router `context.pop()` 走
  `Navigator.pop()` **强制退出、绕过 PopScope**；保存成功后的
  `Navigator.pop(result)` 同为强制退出——正是「保存后免确认直接关」的通路。
- `AppBackButton` 相应从 `context.pop()` 改为 `maybePop` 优先：`maybePop`
  返回 false（仅 bubble=无路可退时）且 `context.canPop()` 为假才
  `go('/home')`；guard 拦截时返回 true，不会误跳首页。其余 8 处使用点
  （列表/详情/收藏）无 PopScope，行为不变。

5 个表单接线（全部**仅新增态** `enabled: !_isEdit && !_saving`）：

| 表单 | isDirty 判定 |
|---|---|
| 商家 | 名称/地址非空、营业开关≠true、地区/币种/坐标任一设置（initState 快照比对） |
| 原料 | 名称/别名非空、分类非空、单位/营养草稿非空 |
| 商品 | 名称/品牌/条码与 initState 快照（含扫码 prefill）比对、别名/新增对应原料/新原料名非空、关联原料 ≠ `fixedIngredient`、草稿非空 |
| 菜谱 | 自有 PopScope 改 `_handleBack()`：复用既有基线，`_changedBasicPayload` 非空 + 步骤/小贴士/原料 payload 与基线 jsonEncode 比对（`_tipPayload` 是 `List<String>`，不能走 `_listJsonEquals`） |
| 试算 | 方案名非空或条目非空（`_planId == null` 时启用） |

编辑态不启用（用户只要求新增态；菜谱编辑态分区保存有自己的 PopScope 语义）。

## 顺带修：NumericKeypad debug 断言崩溃

`_KeyButton` 内部自带 `Expanded`，`_buildBottomRow` 又在外面包
`Expanded(flex:2)` → 同一 RenderObject 两个 ParentData，debug 模式抛
"Incorrect use of ParentDataWidget"（release 无断言所以线上没炸，但任何
widget 测试打开键盘即崩）。改法：`_KeyButton` 不再包 Expanded，弹性行由
Row 外层统一给（比例不变 0=flex2）。

## 测试坑（复用价值高）

- `tester.pageBack()` 按 tooltip **'Back'** 找按钮；zh locale 下
  `backButtonTooltip` 是 **「返回」**，pageBack 直接 `expectSync` 失败。
  zh 测试用 `find.byTooltip('返回')` 或 `tester.binding.handlePopRoute()`
  （系统返回 → maybePop，正是要测的路径）。
- 试算新增态 AppBar 标题就是 `plansNewPlan`('New plan')，与输入的方案名
  `find.text('New plan')` 撞 2 个匹配 → 断言改「对话框已关」。
- `RecipeFormScreen`/`MerchantFormScreen` 都 `ref.watch(saveButtonPositionProvider)`
  → 测试必须套 `ProviderScope`。

## 验证

- `flutter analyze`：0 新增 issue（唯一 info 为 product_form 既有行）。
- 新增测试：form_exit_guard_test 4 例、quick_fill_compact_layout_test 2 例、
  merchant_form_exit_test 3 例、recipe_form_exit_test 2 例、planner 编辑
  +1 例、product_form +2 例（prefill 不算脏 / 写名弹窗）；既有
  quick_fill_screen_test 3 例、localized_prices_test 14 例不回归
  （quick fill 断言从 labelText 改 hint，对齐新紧凑行）。
- 全量 `flutter test`：**759 通过 / 7 失败**，失败全部为存量
  （apple_map×3、locale_preferences×2、my_proposals×1、home_summary×1 ——
  home_summary 已 stash 在 HEAD 复跑定责，此前不在存量清单里）。
- `flutter build apk --release`：本机无 Android SDK 无法构建（历史 APK
  在用户另一台机器构建），编译验证以 analyze + 全量测试覆盖。

## 关联

- 记价默认单位/快速填写历史商品：`FEATURE_PWA快捷方式图标.md` 无关；
  商家下拉取全见 `BUGFIX_快速填写商家下拉截断.md`。

# FEATURE_移动端五项问题修复

> 日期：2026-08-11
> 分支：feat/mobile-app（仅移动端）
> 流程：用户 5 项反馈 → 澄清 → 计划 → Subagent-Driven（①⑤②③④ 逐项，每项 spec 合规 + 代码质量双审 + 修复循环 + 最终整轮审查）

## 需求（用户 5 项 + 澄清）

1. **①推荐页去掉「快捷入口」**
2. **②价格记录新增/编辑表单，商家改文本框筛选**（Autocomplete，两处表单：底部 sheet + 全屏页）
3. **③计价页支持编辑已有价格记录**（澄清：卡片加**三点菜单**编辑/删除入口，整卡点击仍跳商品详情）
4. **④快速填写加复制粘贴记录**（澄清：移植 web 端已有功能，做成**独立全屏页**而非 bottom sheet）
5. **⑤「更多」菜单改网格**（澄清：仅底栏 tab 的「更多」二级菜单，横排胶囊样式同底栏；桌面 NavigationRail 不受影响）

## 关键设计

### ① 删除快捷入口
[home_screen.dart](mobile/lib/features/home/screens/home_screen.dart) 删 QuickEntryGrid 引用；[quick_entry_grid.dart](mobile/lib/features/home/widgets/quick_entry_grid.dart) 整文件删除（全项目仅此一处引用，grep 确认）。底部留白由 SingleChildScrollView padding 提供。

### ② 商家 Autocomplete 文本筛选
两处 `DropdownButtonFormField<int?>` → `Autocomplete<Merchant>`：
- [price_record_form_sheet.dart](mobile/lib/shared/widgets/price_record_form_sheet.dart)（底部表单）+ [price_record_form_screen.dart](mobile/lib/features/prices/screens/price_record_form_screen.dart)（全屏页）
- `optionsBuilder`：空文本→全部商家；非空→name.contains 过滤；`displayStringForOption: (m)=>m.name`
- `fieldViewBuilder` 用 `addPostFrameCallback` 同步外部 `_merchantController` 与 Autocomplete 内部 controller（避免预填值被内部 controller 覆盖，对齐 quick_fill_screen 模式）
- initState 预填：initialMerchantId → 在 merchants 找 name 填 controller + 设 _merchantId（**M-1**：不在列表则 _merchantId=null）
- **I-1 stale id 修复**：onChanged 从「value.isEmpty 才清 id」改为「_merchantId != null 就清 id」——文本一改即失效，必须重新点选。关键：onSelected 里程序化 `controller.text = m.name` **不触发** onChanged，故选中流程不受影响

### ③ 三点菜单编辑/删除
[price_list_screen.dart](mobile/lib/features/prices/screens/price_list_screen.dart) 卡片尾 `chevron_right` → `PopupMenuButton<String>`（edit/delete，Icons.more_vert）：
- `_openEditRecord`：复用 `showPriceRecordFormSheet` 预填（fixedProductId/fixedProductName + 各 initial 字段）→ `notifier.updateRecord` **局部更新**对应记录（不 loadRecords，保滚动位置）
- merchantName 由**屏幕层反查** `merchantListProvider.items.firstWhere(id)` 传入（notifier 不持有商家列表）
- `_confirmDelete`：AlertDialog 二次确认（含商品名+金额），删除按钮 error 色
- [price_provider.dart](mobile/lib/features/prices/providers/price_provider.dart) 加 `updateRecord`（本地重建 PriceRecord）/`deleteRecord`（total 修正：`removed = length diff; total: state.total>0 ? state.total-removed : 0`）

### ④ 粘贴导入全屏页（移植 web）
照搬 web [pastePriceParser.ts](frontend/src/utils/pastePriceParser.ts) + [PasteImportDialog.vue](frontend/src/components/prices/PasteImportDialog.vue) + [QuickFillView.vue](frontend/src/views/prices/QuickFillView.vue) 流程：
- **parser** [paste_price_parser.dart](mobile/lib/features/prices/utils/paste_price_parser.dart)：正则 `r'^(.+?)\s+(\d+(?:\.\d+)?)(?:/(\d*\.?\d*)\s*([A-Za-z一-龥]+))?\s*$'`（中文范围一-龥等价一-龥）；单位别名{克:g,公斤:kg,千克:kg}（斤保留）；边界顺序 空行→注释→格式不匹配→名空→价无效；四种格式
- **状态机** [paste_import_screen.dart](mobile/lib/features/prices/screens/paste_import_screen.dart)：
  - 复制模板（每行「名+空格」join）→ 粘贴文本 → parsePasteText → 自动匹配 → unmatched 行可展开手动处理 → 导入
  - **四级自动匹配**（对齐 web tryAutoMatch）：商品主名(name)→原料主名(ingredient_name)→商品别名(alias)→原料别名(ingredient_alias)；原料命中经 `_resolveIngredientProduct`（唯一>同名>第一个）解析最佳商品；并发 5（`_concurrency`，分批 Future.wait）
  - **手动三分支**：existing（搜索选商品）/new_same（创建同名）；**new_attach UI 简化**（自动匹配已覆盖原料路径，保留枚举+doImport 逻辑备扩展）
  - **doImport**：`recordType:'price'` 显式传（默认 purchase）；existing→productId、new_same→productName；别名策略 existing/new_attach 成功后 addImportAlias、new_same 不加；并发 5 + Future.wait 逐条 try-catch 模拟 allSettled + 进度条；全成功才 pop(savedIds)
- **product-orders 排序**（spec MISSING，补）：[quick_fill_screen.dart](mobile/lib/features/prices/screens/quick_fill_screen.dart) `_saveProductOrders` → `POST /merchants/{id}/product-orders` body `{product_ids, session_date}`（对齐 web onPasteImported，try/catch 静默失败）
- repository 契约：[product_repository.dart](mobile/lib/features/products/repositories/product_repository.dart) `autocomplete(q,{limit})`（兼容 List/{items:[]}）、[price_repository.dart](mobile/lib/features/prices/repositories/price_repository.dart) `addImportAlias(productId,name)`
- 路由：[app_router.dart](mobile/lib/core/router/app_router.dart) `/prices/paste-import`（ShellRoute 内，state.extra 取 merchantId/historyProductNames）

### ⑤ 「更多」横排胶囊网格
[app_router.dart](mobile/lib/core/router/app_router.dart) `_showMoreMenu`：`Column>ListTile` → `Row>Expanded(_NavItem)`，复用同文件私有类 `_NavItem`（secondaryContainer 圆角16 胶囊，与底栏完全同款）；builder **外**取 `GoRouterState.of(context).matchedLocation`（builder 内 ctx 在 Overlay 下拿不到）+ `_tabIndexFor` 做选中态；标题行（「更多」+关闭按钮 tooltip「关闭」）；`itemKey: ValueKey('more-${label}')`。桌面 _moreTab 仅在 _mobileTabs，走 NavigationRail 不触发此 modal。

## 审查抓到的真问题（全部修复）

### ②
- **I-1 stale id**（Important）：选中商家后编辑非空文本不清 _merchantId，保存带过时 id → 改「_merchantId!=null 即清」（程序化 controller.text 不触发 onChanged 是安全基础）
- **M-1**：预填 initialMerchantId 不在商家列表 → _merchantId=null

### ③
- PopupMenuItem.leadingIcon 本 SDK 版本不支持（编译错）→ 纯 Text（对齐项目 merchant_list/product_detail 一致性）
- merchantName 编辑后过时 null → updateRecord 加 merchantName 参数 + 屏幕反查传入
- 「不触发 getRecords」测试假绿（records.length==1 回退无法捕获错误 loadRecords）→ FakeRepo 加 `getRecordsCalls` 计数器断言 0 增量
- deleteRecord total 误算（删不存在 id 仍 total-1）→ `removed = length diff`

### ④
- **product-orders MISSING**（spec，controller 补）：plan L119 明确要求对齐 web onPasteImported，实现只刷新未记录排序 → 补 `_saveProductOrders`
- **C1 每次 build new TextEditingController**（Critical）：光标强制跳末尾（中间编辑不可用）+ 内存泄漏 → `_ImportRow` 持久 `searchController`，`_releaseEditor` 集中 dispose（_cancelEdit/_chooseExisting/_chooseNewSame 关闭时调）+ dispose 兜底
- **I1 搜索竞态**（Important）：旧请求晚回覆盖新结果 → `searchSeq` 序号守卫（成功+异常双分支，复用项目 _searchSeq 模式）
- **I2/I3 裸 `as int` 类型转换**（Important）：raw Map 字段若返回 double（如 9.0）抛 TypeError，而 TypeError 是 Error **不被 `on Exception` 接住**，经 Future.wait 直接崩 _parse 红屏 → `_toInt(dynamic v) => (v as num?)?.toInt()` 助手替换 9 处
- M1 进度逐条 setState → 批末一次性；M2 测试 `find.text().last` 脆弱 → ListTile Key + find.byKey；M5 quick_fill 注释乱码恢复

## 测试

- TDD 全流程，每项先写失败测试。**全量 296/296 全绿**（①home 调整 + ②sheet 5/screen 5 + ③provider 9/list 5 + ④parser 24/repo 4/screen 10 + ⑤router 4，含修复轮新增竞态/持久/double-id 3 条）
- `flutter analyze` 0 新增（剩 5 个预先存在：api_client print、颜色常量、recipe_provider_test 3 const）
- `flutter build windows --debug` 通过（40.1s，先 taskkill livecalc_mobile.exe 防 MSB3073 文件占用——本仓库已知坑）
- 最终整轮审查 READY：五项逐项确认 ✅ + app_router(④⑤)/price_record_form_sheet(②③)/merchantListProvider(②③)/quick_fill(④)/移动端↔web 对齐 5 项交叉影响核查全无冲突；遗留仅「再次记录」入口预先缺口 + new_attach/recordedAt 已接受 spec 简化

## 经验

- **Autocomplete 程序化 controller.text 不触发 onChanged**——I-1 stale id 修复的安全基础；手动 controller 同步须 addPostFrameCallback
- **TypeError 是 Error 不被 `on Exception` 接住**——raw Map（未经 fromJson）类型转换必须 `(as num?)?.toInt()`，否则后端字段类型微调（int→double）直接崩且无提示
- **build 路径里 new TextEditingController 是 Flutter 反模式**——光标强制跳末尾 + 泄漏；状态对象应持有持久 controller，集中 dispose + 兜底
- **Dart 无 Promise.allSettled**——`Future.wait + 逐条 try-catch` 模拟
- **searchSeq 序号守卫**防异步竞态（项目 price_record_form/ingredient_detail 已有模式，复用）
- **quick_fill 直接 dio 模式**（_loadMerchants 先例）——product-orders 走同模式，YAGNI 不为非关键路径加 repository 抽象
- 国产瓦片/后端字段类型假设不可靠，接新数据源先核类型与编码

## 涉及文件

- **新增**：`paste_price_parser.dart`、`paste_import_screen.dart`、`price_record_form_sheet_test.dart`、`price_provider_test.dart`、`paste_price_parser_test.dart`、`paste_repositories_test.dart`、`paste_import_screen_test.dart`
- **修改**：`home_screen.dart`、`price_record_form_sheet.dart`、`price_record_form_screen.dart`、`price_list_screen.dart`、`price_provider.dart`、`product_repository.dart`、`price_repository.dart`、`app_router.dart`、`route_names.dart`、`quick_fill_screen.dart`
- **删除**：`quick_entry_grid.dart`

## 不做的事

- 不动 web 前端/后端（后端接口齐备，移动端直接复用）
- ④ new_attach 手动 UI（自动匹配已覆盖原料路径）、recordedAt 输入框（粘贴快记默认当前时间更合理）
- ④ `_resolveIngredientProduct` 不依 created_at 排序、手动搜索无 debounce（Minor，后续迭代）
- quick_fill `_saveAll` 的 product-orders（预先缺失，④范围外，后续单独处理）
- ②③⑤ 各自范围外的一致性改造

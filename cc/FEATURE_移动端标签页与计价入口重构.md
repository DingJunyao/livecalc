# FEATURE_移动端标签页与计价入口重构

> 日期：2026-08-10 ~ 2026-08-11
> 分支：feat/mobile-app（仅移动端）
> 流程：brainstorming → 设计 → 计划 → Subagent-Driven（7 任务 + 每任务双审 + 最终整体审查）

## 需求（用户 3 项）

1. **底栏改版**：7 个功能项放不下 → 手机 4 项（推荐/计价/菜谱/更多），更多（汉堡）弹底部菜单：原料/商品/商家/我的；桌面 ≥600px 用 NavigationRail 7 项全展示
2. **「我的」加「启动时起始页」配置**（推荐/计价/菜谱三选一，SharedPreferences 纯本地不上云端）
3. **长按「计价」直达新增价格记录**；顺带发现并修复计价页加号错误指向快速填写的 bug（加号应为普通新增价格记录，快速填写移入 AppBar bolt 入口，对齐 web `mdi-lightning-bolt`）

## 关键设计

- **自绘底栏**（方案 A 自绘）：原生 NavigationBar 不支持 per-destination 长按，方案 B（Overlay hack）否决。`_NavItem`（Row + InkWell + Semantics(selected/button/label + excludeSemantics)）外观对齐 M3（选中 secondaryContainer 胶囊 + 填充图标 + w600 标签）
- **选中态按路由前缀分组**：`_tabIndexFor` 前缀匹配（`location == p || startsWith('$p/')`）——旧实现精确全等，进详情页（/recipes/123）后选中态丢失；前缀匹配后详情页也高亮所属 tab，/merchants/map、/profile/settings/* 等 19 个 shell 子路由全覆盖
- **`_Tab` 单一模型**：桌面 rail 与手机底栏共享 `_desktopTabs`/`_mobileTabs`/`_moreMenuTabs` 常量，无两套逻辑漂移
- **起始页生效链路**：`StartupPageNotifier`（prefs 键 `startup_page`，值 home/prices/recipes，load 校验非法值、值域 kStartupPages 密封）→ `app.dart` `_bootstrap()` **load 先于 checkAuth**（redirect 只在状态离开 initial/loading 才离开 /splash → 无「读到默认值」竞态窗口）→ `app_router.dart` redirect 认证分支 `'/${ref.read(startupPageProvider)}'` → **三条路径统一**（自动登录 redirect / 手动登录 / 注册成功均读配置，Task 3A 用户决策追加）
- **新增价格记录全屏页** `/prices/record`（Shell 内）：字段对齐 web 对话框——商品名称（`ProductRepository.search` 可输新名直接创建）、价格必填>0、数量+单位（priceRecordUnits 默认斤）、商家下拉（merchantListProvider，initState 须 load）、计入支出 Switch（purchase/price）、记录时间（日期+时间选择默认现在）、备注；repository 构造注入支持测试（对齐 MerchantListScreen 模式）；保存校验 → `createRecord` → `pop(true)`
- **FAB 与长按共用同一 push/pop 契约**：`push<bool>('/prices/record')` + `saved == true` 才 `loadRecords()`（取消不刷新）

## 审查抓到的真问题（全部修复）

- Task 4 双 Important：**stale `_selectedProduct`**（选商品后改名，保存仍带旧 productId → 非空搜索分支按名字不匹配清空，+ 防回归测试）；**merchant 列表未 load**（initState 直接 load() 抛 "Tried to modify a provider while the widget tree was building" → `Future.microtask` 延后，对齐 price_list_screen.dart:28-34 惯例）
- Task 4 Minor：搜索竞态（`_searchSeq` 序号守卫，空 query 分支也递增使在途搜索失效）、timePicker 后 mounted 守卫、`catch (_)` → `on Exception`、RouteNames.priceRecord 常量、测试脆弱断言修复（`find.widgetWithText(ListTile, '番茄')`）+ 负分支（pop null 不刷新）
- Task 6 Minor：4 处注释被工具链转义成 `\uXXXX`（perl 修复时 shell 引号导致正则退化、误伤 10 处标识符 Scaffold→S쫿old，Python 纯 ASCII 脚本 + 先审计后修复，TDD 式核对）；`_NavItem` Semantics 补 `excludeSemantics: true`（防读屏念两遍「推荐\n推荐」）
- 最终审查 Minor：保存按钮在途守卫（`_saving`，双击不重复 createRecord，失败恢复可重试）

## 测试

- TDD 全流程：每任务先写失败测试。全量 **231/231**（原 ~200 + 新增 ~30）+ `flutter analyze` 0 新增（剩 5 个预先存在 info）+ `flutter build windows --debug` 78s 通过
- 测试模式要点：`_FormHost` push 包装（pop(true) 契约必须经 push）；stub GoRouter 隔离 shell；`skipOffstage: false` 断言被覆盖的底栏；flagsCollection + Tristate（3.32+ 非弃用）代替 matchesSemantics 全量匹配（合并节点带 InkWell 动作 flag 过严）

## 经验

- 计划自审要核对**测试 key 与实现 key 的生成方式一致**（`'tab-${route}'` 会带 `/` 前缀 → 改 label 方案 `'tab-计价'`）
- `const Scaffold(appBar: AppBar(), ...)` 编译错（AppBar 无 const 构造）
- 长按测试里 stub 路由 pop(null)（pageBack）→ saved 为 null → 不会触发真实 provider 网络请求，测试天然安全
- Windows Git Bash 下 perl 的 `\\u` 引号传递不可靠（正则静默退化）——文件字符级修复用 Python 纯 ASCII 脚本 + 先审计非 ASCII 行清单
- Semantics 测试：find.bySemanticsLabel 匹配合并后 label（「推荐\n推荐」）不可靠；getSemantics + flagsCollection 断言 flags 更稳

## 涉及文件

- 新增：`startup_page_provider.dart`、`price_record_form_screen.dart` + 6 个测试文件
- 修改：`app_router.dart`（redirect + /prices/record 路由 + 底栏重构）、`app.dart`（bootstrap）、`profile_screen.dart`、`login_screen.dart`、`register_screen.dart`、`price_list_screen.dart`、`route_names.dart`

## 不做的事

- 不动 web 前端/后端；不动 6 处既有 `showPriceRecordFormSheet` 调用；不做价格记录编辑模式（YAGNI）；桌面 rail 无长按；起始页配置仅影响启动落点

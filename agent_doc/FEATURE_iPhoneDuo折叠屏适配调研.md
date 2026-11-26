# FEATURE_iPhoneDuo折叠屏适配调研

> 状态：调研完成，**尚未实施**。全部建议落在 feat/mobile-app 分支（纯移动端，无后端/web 改动）。

## 背景

用户报告 iOS 端尚未适配 iPhone Duo（苹果 2026 秋发布的折叠屏 iPhone，Xcode 设备类型 `iPhone Duo` / modelIdentifier `iPhone19,4` / productClass V68）。本调研基于本机 Xcode 27.2 设备描述文件实证 + Flutter 生态现状（2026-11-22）+ 对 feat/mobile-app 布局体系的全面勘察，给出适配建议。

## 设备规格（Xcode 27.2 设备描述文件实证，非传闻）

描述文件位置：`/Library/Developer/CoreSimulator/Profiles/DeviceTypes/iPhone Duo.simdevicetype/Contents/Resources/capabilities.plist`

- **外屏（合上）**：1398×2034 px @ **3.0x** = **466×678 pt** 竖屏；460 PPI；挖孔前摄。比现有 iPhone **更宽更矮**（iPhone 18 Pro Max 为 440×956），纵向空间 ≈ SE3（667）档。
- **内屏（展开）**：2007×2853 px @3x = **669×951 pt** 竖屏 / **951×669 pt** 横屏（开书自然方向为横屏）；约 1.42:1，iPad mini 观感；屏下摄像头。
  - 注意：与早期传闻（2713×1920）不同，以引擎实测为准——Flutter PR #195199 修复「内屏误报外屏尺寸」（旧引擎 `UIScreen.mainScreen` 恒指外屏），该 PR 2026-10-28 合入，3.50.1（2026-11-18 build）已含。
- **半开姿态**：内屏被折痕分为两 pane（竖半开上下分、横半开左右分 = laptop pose）。折痕是连续屏的 **fold**（不遮挡）而非 Android 式 hinge（遮挡）。
- **系统行为**：内屏**忽略 `UISupportedInterfaceOrientations`**（无论怎么声明都会旋转）；横屏时系统状态栏/控件堆到**一侧竖条 strip**（viewPadding 的一侧出现大 inset）。
- **App Store**：2027 年 4 月起要求 iPhone Duo 截图。

## Flutter 生态现状（2026-11-22）

- Flutter ≥3.41 自带 UIScene lifecycle 自动迁移；本项目 **Flutter 3.50.1 ✓**。
- **displayFeatures 空缺**：flutter/flutter#192515（iOS 填充 `MediaQuery.displayFeatures`）仍 open，PR #193025 未合 → **Flutter 3.50.1 在 iOS 上 displayFeatures 恒为空**，拿不到折痕/姿态。临时方案：
  - pub.dev **`foldable`** 包：platform channel 桥接 iOS 27 `reservedRegions(kind:)`，含 hinge angle/posture；非折叠设备安全降级。
  - **`duo_kit`** v0.1：FoldScaffold（导航入条）/ FoldSplitView（折痕两侧双 pane）/ FoldAnchor（弹层锚到折痕上/下方）；需 Flutter ≥3.41。
- 工程要求：**Xcode 27.1+ SDK**（≤26 = 兼容模式缩窗；27.0 = 只到状态栏；27.1 = 全屏）、UIScene lifecycle、部署目标 **≥15.0**、**不要锁方向**。

## 本项目现状盘点（feat/mobile-app）

### 已就位（无需改动）

| 项 | 现状 |
|---|---|
| UIScene lifecycle | AppDelegate `FlutterImplicitEngineDelegate` + SceneDelegate `FlutterSceneDelegate`，Info.plist 有 `UIApplicationSceneManifest` ✓ |
| 部署目标 | `IPHONEOS_DEPLOYMENT_TARGET = 15.0`（pbxproj 三处）✓（Xcode 27 拒绝更低） |
| 设备家族 | `TARGETED_DEVICE_FAMILY = "1,2"` ✓ |
| 方向 | iPhone 已声明 Portrait+LandscapeLeft/Right；Dart 无 `setPreferredOrientations` ✓（内屏反正忽略声明） |
| Xcode | 27.2 ≥ 27.1 要求 ✓ |
| 壳层断点 | `width >= 600`（app_router.dart:792）：外屏 466→底栏、内屏竖 669/横 951→rail，**恰好全覆盖** ✓ |
| rail 矮视口 | minRailHeight 660 + SingleChildScrollView 滚动兜底（app_router.dart:806-814）✓ |
| 菜谱网格 | 669 宽 → 2 列（recipe_list_screen.dart:350-355 的 960/1280/1920 阈值）✓ |

### 缺口/风险

1. **断点裸数字**：600（app_router.dart:792）与网格 960/1280/1920（recipe_list_screen.dart:350-355）无共享常量/工具层；全 lib 无 responsive 封装。
2. **切内外屏穿越 600 断点 → State 丢失**：ScaffoldWithNavBar 的 body 在 `Row[NavigationRail, Expanded(child)]`（宽）↔ 裸 `child`（窄）间切换，子树 element 深度变化 → 重建（滚动位置/输入内容丢失）。内屏半开再展开宽度不变不触发；触发点在 466↔669 切屏。
3. **displayFeatures 空** → 半开姿态下 dialog/sheet 居中渲染，横跨折痕；Flutter 的 DisplayFeatureSubScreen 避让与 `anchorPoint` 都依赖 displayFeatures 有值。
4. **外屏 678 pt 高（近年最矮档）**：
   - compare 5 个 picker sheet 固定 `SizedBox(height: 420)`（compare_screen.dart 581/831/1182/1470）+ 键盘弹出易超屏（普通 iPhone 上已存在的债，Duo 外屏更常见）；
   - planner 条目 sheet `height: .88*屏高`（planner_screens.dart:951）、entity_quantity_link_edit_page.dart:698（.78）、barcode_scanner_sheet.dart:47（.8）均无 maxHeight 约束；唯一有约束的是 calc_context_menu_button.dart:27-33（可作范本）。
5. **横屏 951×669**：图表固定高（planner cost_trend 170、recipes 200、cost_proportion 140、nutrition grid 120、heatmap 420）在 669 高视口占比过半；compare_screen.dart:186 `EdgeInsets.only(bottom: 24)` 顶掉自动 inset，横屏 strip 侧 inset 大时有 home-indicator 压内容风险；22 页 body 无显式 SafeArea（靠 Scaffold 自动消耗，基本 OK）。
6. **内屏内容单列**：除菜谱网格外全部单列 ListView，669/951 宽利用率低；无 master-detail（「试算详情宽屏多列」是 web 端特性，移动端 plan_detail 条目单列 plan_detail_screen.dart:453-502）。
7. **外屏合上横屏（678×466）**：宽 678 ≥ 600 → 命中 rail，且高 466 < 660 触发滚动兜底；系统是否允许外屏横屏需在模拟器验证（若体验差，可考虑 rail 断点加高度条件）。
8. **测试**：app_bar_title_budget_test 实为 360dp 文本宽度预算（非视口测量，Mac 缺字体全 skip）；rail 组用 900×1200、窄屏 400×800；**无 600±1 边界测试**；无 Duo 三视口（466×678 / 669×951 / 951×669）测试。

## 适配建议（优先级）

### P0（正确性）

1. **壳层树形恒定**：窄屏也保持 `Row[导航(零宽/隐藏), Expanded(child)]` 结构（或 GlobalKey 迁移 State），避免断点穿越整树重建丢 State。LeanCode 博客定调：不要按 fold/断点直接切换 widget 树。
2. **foldable 包桥接 displayFeatures**：等 PR #193025 合入 Flutter stable 后移除；随后给 dialog/sheet 补 `anchorPoint`，让 DisplayFeatureSubScreen 把弹层放进折痕单侧 pane（阅读内容放 fold 上方、控件放下方）。
3. **模拟器实测回归**：本机已有 `iPhone Duo` 模拟器（iOS 27.2，Xcode 27.2 DeviceHub）。跑 App 读真实 MediaQuery（size/dpr/displayFeatures）验证 669×951@3x 与折痕时序（模拟器坑：半开静止后 fold 数据延迟 ~1s；`UIRequiresFullScreen` + 方向锁会导致缩窗且不报 fold——本项目未锁 ✓）。widget 测试补三视口 + 600±1 边界。

### P1（体验）

4. **断点抽共享常量**：`core/layout/breakpoints.dart`（600/960/1280，对齐 web Vuetify sm/md/lg），600 与网格阈值统一引用，新增 `isWide` 封装。
5. **sheet 高度收敛**：固定值/纯屏高百分比 → maxHeight 约束（参照 calc_context_menu_button.dart 写法）；compare picker 420 固定高改 ConstrainedBox。
6. **横屏验证清单**：侧条 strip 的单侧大 inset 下各列表/表单边距；图表固定高在 669 高视口的占比；自定义 bottom padding 顶掉自动 inset 的位置。

### P2（增强）

7. **内屏内容级适配**：列表/详情 master-detail（fold 两侧双 pane）、表单 maxWidth 居中（~720）、网格阈值接共享常量。
8. **laptop pose**：内容上 pane / 操作下 pane（菜谱步骤场景最自然）；键盘只 resize fold 以下 pane（`removeDisplayFeatures` + `resizeToAvoidBottomInset: false`）；建议依赖 duo_kit 或自行封装。
9. **App Store 2027-04 Duo 截图**备忘。

## 设计稿 v2（2026-11-22，用户反馈四条后重制）

初版四条不成立：①状态栏画成了普通横排（应为**环形状态栏**，围绕摄像头、位于右上）②展开图未标铰链 ③缺半折 UI ④菜谱卡缺图、样式偏离原版。v2 重制为五形态（`原型/iPhoneDuo适配设计稿.html`）：

1. **外屏·折叠态 466×678**：环形状态栏（时间+信号+环形电量，右上）；底栏 4 tab 维持。
2. **内屏·展开竖屏 669×951**：右缘竖条（状态环右上 + 10 目的地**图标导航沉右下**，替代左侧 rail）；铰链 y≈475 细虚线，内容上下分区留白跨过折痕，交互控件不落折痕。
3. **内屏·展开横屏 951×669**：菜谱卡**一行四项 + 图片固定高 104**（真实卡结构：图 + 名称心形 + ¥成本/份·kcal/份；无图用图标占位，对应 `recipe_list_screen.dart:252` 两种状态）；铰链 x≈475 恰走第 2/3 列间距，卡片不跨折痕。
4. **内屏·半开竖屏**：铰链梁硬分隔上下 pane——上阅读（列表）/下操作（快速记价表单），右缘竖条被铰链截断后按 pane 续排。
5. **内屏·半开横屏 laptop**：内容上 pane / 操作下 pane（菜谱阅读 + 加入试算/收藏/记成本按钮）。

系统行为依据：iOS 27 Duo 采用环形状态栏（环形电量、围绕摄像头、右上）；展开/半开姿态系统状态栏与控件收进一侧竖条（Apple HIG "Designing for iPhone Duo"），适配示例普遍把 app 导航放右下角；"图标无文字"是 Duo 侧栏惯例（目的地取舍实施时定）。壳层含义：展开态导航从左侧 NavigationRail 改为右缘图标竖条（P1），`ScaffoldWithNavBar` 需姿态分支；600 断点逻辑不变。

## 设计稿 v3（2026-11-23，用户实测反馈后修订）

v2 四条修正 + 新增 web 同构页面版块（现共 8 版块，`原型/iPhoneDuo适配设计稿.html`）：

**姿态修正**：系统只有 折叠/展开竖屏/展开横屏/半开竖屏 **四种姿态——无半开横屏（laptop）**，v2 的 laptop 版块系虚构已删除，相关 P2（laptop 分栏/键盘只 resize 下 pane）作废。

**壳层定调（用户反馈）**：
- **Duo 全形态导航恒在右缘**——折叠态（外屏 466×678）也用右缘图标竖条，底部 4 tab 在 Duo 上不出现；常规 iPhone（<600 窄屏）仍用底栏，属设备分支（`ScaffoldWithNavBar` 需设备形态判断）。
- 展开竖屏：列表内容**自然跨过折痕滚动**（不强制分区），铰链仅虚线位置标注；半折态经用户定调（2026-11-23）同样连续屏处理，不硬分隔。
- rail 目的地顺序对齐 web（`AppLayout.vue:46-65`）：**商品→原料**（移动端 `app_router.dart` 现为原料→商品，需调）；卡片口径对齐（成本/份 · 每份热量）。

**新增页面版块（web 同构，依据 Explore 勘察）**：
- 04 原料四列 / 05 商品四列：与 web 同骨架（搜索+筛选 → 四列卡 → 分页 → FAB）；卡 = 30 天走势铺底 + 首字母头像（原料 secondary 色/商品 primary 色）+ 分类/品牌 chip + 最新价 + 收藏/记价入口；排序 = 价格记录数 + 收藏置顶；折痕走 2/3 列间距。
- 06 商家双栏：左 350 列表（搜索/筛选按钮/两行制列表/分页/FAB）+ 右弹性地图（地图内容可跨折痕）；地图引擎 Leaflet+五引擎适配不变；地图禁用模式退回四列卡。
- 07 试算详情：web 区块顺序同构（编辑行 → 三搜索 → 条目四列 → 合计四块超目标红/正常绿 → 图表 1:1 双栏 → 营养成分｜来源双栏折叠线下）；条目卡 gutter 与折痕对齐。
- 08 半开竖屏：**与展开竖屏同构**——连续屏、内容自然跨过折痕、不做 pane 分区（用户定调 2026-11-23，v2 的铰链梁双 pane 方案作废）；foldable 桥接与 anchorPoint 相应暂缓。

## 实施进展（2026-11-23，Phase 1/2/6 已落地，feat/mobile-app 工作区未提交）

用户确认按设计稿实施。已完成：

1. **Phase 1 壳层（`core/layout/device_form.dart` 新建 + `core/router/app_router.dart` 重构）**
   - `shellModeFor(size, displayFeatures)`：折叠屏（Android 由 hinge/fold 特征判定；iOS Duo 走外屏宽矮特征：竖屏 440≤宽<600 且高宽比≤1.5）→ 尾缘竖条；内屏竖屏（竖屏宽≥600）→ 标准横条；平板（shortestSide≥700）→ 左 rail；常规 iPhone → 底栏。
   - 壳层结构改为 **Stack 树形恒定**：内容槽固定首位、模式切换只改 padding 与叠加导航层——外屏↔内屏切换滚动/输入 State 不丢（widget 测试以 TextField 元素 identical 断言验证）。尾缘竖条物理固定 trailing（HIG：RTL 不翻转）；平板左 rail 保持 leading 翻转。
   - `_EdgeRail`：宽 64，SafeArea 消化系统状态/摄像头保留区（顶部）与 home indicator（底部），tab 目的地沉底、图标无文字（Semantics 保留标签），M3 胶囊选中态；工具栏区留位（页面操作 Phase 2+ 按页接入）。
   - rail 顺序对齐 web：`_desktopTabs`/`_moreMenuTabs` 商品→原料。
   - 测试：`device_form_test.dart` 14 例（Duo 三视口/常规 iPhone/平板/Android 折叠屏/cutout/边界）+ scaffold 测试 6 例（三模式断言、竖条点按导航、树形恒定）+ router 用例视口调整（800×600 → 尾缘竖条为图标形态，「我的」标签断言移到 900×1200）。
2. **Phase 2 菜谱卡（`recipe_list_screen.dart`）**：`_columnCountFor` 补 Duo 档（≥800 → 4 列，其余 2 列，对齐 web sm/xl）；图片 AspectRatio 4:3 → 固定高 104；卡片口径对齐 web 改「成本/份」（新 l10n 键 `recipeCostPerServing` 三语：/ 份、/ serving、/ حصة，风格对齐 web "{amount} / 份"）。
3. **Phase 6 弹层高度收敛（`compare_screen.dart`）**：4 处固定 `SizedBox(height: 420)` → `ConstrainedBox(maxHeight: 屏高 × 0.5)`——Duo 外屏 678 高叠加键盘不再顶出屏幕。

**验证**：`flutter analyze` 非 deprecated 0 问题；`flutter test` 全量 855+40 通过/4 失败均为既有基线（app_bar 字体缺失、home_summary、apple_map ×2——stash 对照确认与本改动无关）。

**模拟器实测**：iPhone Duo 模拟器（iOS 27.2）构建/安装/启动成功；**系统状态栏竖排在右上角实测确认**（HIG 尾缘行为真实存在），右上角可见摄像头保留区；simctl 截图需 `--display=1` 指定活动屏（两个 display：外屏+内屏）。shell 视觉验证受登录挡（本机 8000 端口被 enroute 项目占用、livecalc 后端未运行、idb 未装无法 UI 自动化），由 widget 测试覆盖。

**待办**：Phase 3 原料/商品卡对齐（走势铺底需数据层评估：移动端列表当前无逐卡 sparkline 数据源）、Phase 4 试算详情分栏、Phase 5 商家双栏；改动未提交（feat/mobile-app 工作区：device_form.dart 新建、app_router/recipe_list/compare_screen/三语 arb/测试）。

## 首轮实测修正（2026-11-23，用户反馈「导航按钮移位/无响应」「今日推荐应三栏」）

**① 竖条图标移位 + 点按无响应（真 bug，已修）**
- 根因：`_EdgeRail` 内部 `SafeArea` 会再次消费 `viewPadding.right`（Duo 内屏横屏实测 **84pt**），而竖条宽度当时仅 64 → 内容宽度被压成 0：图标被挤到竖条左缘（距右缘 64..108pt，而系统图标列在 42pt 处 → 视觉「严重移位」），命中区塌陷 → tap 全部落空。
- 修复：竖条内 `SafeArea(left: false, right: false)`（竖条本身已在系统保留条内，绝不能再内缩一次）；竖条宽度改为**取系统保留条宽度**（`MediaQuery.viewPaddingOf(context).right`，≥44 用实测值，否则兜底 56）→ 图标自然居中于系统图标列；图标尺寸 22 → **20**（与系统 WiFi 图标一致）；命中区 44×38 → 44×44。页面内容的右内边距同步取竖条宽度，内容不再钻到系统条下。
- 回归测试：`scaffold_with_nav_bar_test` 新增「内屏横屏真实几何（951×669、右保留条 84pt）」——断言竖条宽 84、图标中心距右缘 42（±1.5）、图标 size 20、点按可切页。**已用回退修复验证该测试确实会失败**（错误态图标中心 868 vs 正确 909，偏 41pt）。
- 真机探针（Duo 模拟器）：`size=951×669, padding=(0,0,84,34), viewPadding 同, dpr=3, displayFeatures=[]` —— iOS Duo 的保留条以 safe-area 形式给出，Flutter 侧据此定位即可。

**② 展开态「今日推荐」三栏（已实现）**
- `home_screen.dart` 新增 `_buildMealsArea`：可用宽 ≥780 → 3 栏（Duo 内屏横屏 951−84=867 命中）、≥560 → 2 栏（内屏竖屏 669）、否则单列（外屏/手机）。卡片等宽 `(宽 − 32 − 12×(列−1))/列`，`Wrap` 承载。
- 测试：`home_columns_test` 三例（951×669 三栏同行且 x 递增 / 669×951 两栏 / 390×844 单列）。

**③ 竖条目的地收敛为 4 项 + 图标列精确对齐（2026-11-23 第二轮反馈）**
- 用户定调：竖条与底栏同构——**底部只放 4 个目的地，最后一个是「更多」**，点开底部弹层展示其余目的地（不再把 10 项全塞进竖条）。实现：壳层竖条的 `tabs` 改用 `_mobileTabs`，选中索引按 4 项计算；`_moreTab.prefixes` 补 `/favorites`、`/plans`（此前在这两页底栏无高亮）。
- 图标列对齐：像素测量 `duo-sim-d1.png`（外屏 466×678@3x）——系统状态图标（时间行 `y150-320`、环形电量行 `y320-470`）中心距右缘 **48.0pt**，两行完全一致；84pt 保留条的几何中心是 42pt，因此**按条居中会偏内 6pt**。实现：`iconColumnCenter = strip>=84 ? 48 : strip/2`，竖条内 `Padding(end: 2*center - strip)`（84 条 → 12）把图标中心钉在 48pt。图标 20pt（与系统 WiFi 图标同尺寸）。回归测试断言图标中心 = 951-48（±1.0）。
- 设计稿同步：`.edge-rail` 64→**84** 宽、`padding: 12px 26px 14px 14px`（内容 44 → 中心距右缘 48）、每版块竖条只留 4 项（折叠态/菜谱页 = 对应项高亮，原料/商品/商家/试算 = 「更多」高亮），内容右内边距 84。

**④ 分屏左右侧 + 竖向导航动效（2026-11-23 第三轮反馈）**
- **分屏左窗竖条未跟到左缘**：Split View 中系统保留条只出现在本窗口靠外的一侧（左窗 `viewPadding.left`、右窗 `right`）。竖条侧别改为读取该侧：`stripOnLeft = viewPadding.left > viewPadding.right`，竖条 `Positioned(left/right)`、内容 padding 与图标列中心（48pt）同步镜像；分隔线放在靠内容一侧。HIG：「每个 app 把控件放在自己靠外的边缘，左边的 app 控件在左」。
- **分屏侧别的权威信号（第二轮修复）**：首版用 `viewPadding.left > right` 判断，用户实测分屏左窗竖条仍在右——`viewPadding` 在分屏场景不可靠。改用 UIKit 官方 trait：`UITraitCollection.verticalBarEdge`（iOS 27.1+，返回 leading/trailing/unspecified，看 `UIKit/UIVerticalBarEdge.h`；文档明确「reflects the system's preferred edge regardless of whether a vertical bar is currently visible」）。新增原生桥接 `DuoLayoutPlugin`（`ios/Runner/AppDelegate.swift`，通道 `com.a4ding.livecalc/duo_layout`，`registrar.viewController.traitCollection.verticalBarEdge` → 0/1/2）+ Dart `core/layout/vertical_bar_edge.dart`；壳层 `WidgetsBindingObserver.didChangeMetrics` 时重查（旋转/进出分屏/拖分隔条都会触发）。优先级：trait → padding 比较 → 默认 trailing。模拟器实测：全屏横屏 trait=`trailing` + 右 84，与实况一致；分屏左窗预期 `leading`。调试日志 `DUO verticalBarEdge=… viewPaddingLeft/right=…`（仅 debug）。测试：mock 通道返回 1/2 两例——leading 时即使 padding 在右，竖条也贴左缘（图标中心距左缘 48）；trailing 时贴右缘。
- **折叠态摄像头在左下/右下（第三轮补充）**：摄像头是物理器件，随持握方向可能落在竖条的**底部**，此时系统簇（摄像头+状态）占竖条下半段，导航项若仍贴底部会压住它。改用 `UIView.reservedRegions(kind: .occlusion)`（iOS 27.1+，Swift 名为 `reservedRegions(kind:)`，见 UIKit.swiftinterface）取遮挡区矩形：`DuoLayoutPlugin` 的 `layoutInfo` 返回 `{edge, width, height, occlusions[]}`；Dart 侧 `clusterAtBottom`（任一遮挡区中心 y > 高度 55%）为真时把导航项翻到竖条**顶部**（`_EdgeRail.itemsAtTop`），顶部簇时保持底部。真机径测（折叠态 466×678）：`occlusions=[Rect(399.7,29.3,436.7,66.3) 摄像头 37×37, Rect(382,0,466,174) 状态列 84×174]`——摄像头中心距右缘 48pt，与图标对齐基准自洽；`edge=trailing`。测试：mock 遮挡区在下半段 → 导航项 dy < 屏高/2。
- **竖向导航应上下滑动**：壳层页面过渡原来恒为左右滑动。新增 `shellRailSlideBegin` / `shellPageSlideBegin(mode, toEarlierTab, isRtl)`：`ShellMode.edgeRail` 时沿竖条方向上下滑动（切到更靠下的目的地 → 从下方滑入 `Offset(0,1)`；反向 `Offset(0,-1)`，RTL 不镜像），其余模式保持左右滑动（RTL 镜像）。`_shellTransitionPage` 在 transitionsBuilder 里按当时的 `shellModeFor` 选择方向。
- 测试：`scaffold_with_nav_bar_test` 新增「分屏左窗（left 84）：竖条贴左缘、图标中心距左缘 48、内容从 84 起」；新增 `shell_transition_direction_test` 6 例（edgeRail 上下 + RTL 不镜像；bottomBar/sideRail 左右 + RTL 镜像）。金图核对左窗形态通过。

**⑥ 标题栏图标入竖条 + 详情/列表分栏（2026-11-23 第四轮反馈）**
- **竖条工具栏机制**（新 `core/layout/shell_chrome.dart`）：页面在 build 中 `context.publishShellActions(primary:, actions:)`，壳层 `_EdgeRail` 在系统状态簇下方渲染——`primary` = 原 FAB（右上区域的新增按钮，44×44 primaryContainer 圆角），`actions` = 图标动作（20pt）或自定义控件（如 `CalcContextMenuButton`、⋮ 菜单）。页面同时按 `context.shellRailMode` 隐藏自己的 AppBar actions 与 FAB（`actions: rail ? const [] : [...]`、`floatingActionButton: rail ? null : ...`）→ 标题栏右侧不再空一块。路由切换时壳层 `clear()` 防动作残留；`publish` 走 post-frame notify，避免 build 期 setState。适用条件 = `ShellMode.edgeRail`（折叠竖屏 / 内屏横屏 / 分屏）；内屏竖屏、平板、常规 iPhone 仍在标题栏右侧。
- **接入页面**：首页（范围 + 刷新）、计价（新增 primary + 范围 + 快捷填写）、菜谱（新增 primary + 范围）、商品（新增 primary + 范围）、原料（新增 primary + 范围）、商家（新增 primary + 范围 + 地图开关）、试算详情（范围 + ⋮ 菜单）。**未接入**：菜谱/原料/商品/商家**详情页**（各自 AppBar 动作较多，待下一轮）。
- **实体详情分栏**（新 `shared/widgets/detail_two_column.dart`）：≥820 双栏、窄屏按左→右堆叠。菜谱详情：左 = 头部/成本/原料，右 = 步骤/营养/小贴士；原料详情：左 = 基本信息/最新价/走势，右 = 关联商品/价格记录/关联菜谱/营养/单位/层级；商品详情：左 = 基本信息/最新价/价格记录，右 = 营养/单位。
- **列表页分列**：计价列表与试算列表 ≥620 两列、≥1100 三列（行内 `Row + Expanded`，保留加载更多）；菜谱网格新增 669/678 三列档（`≥1920:6 / ≥1280:5 / ≥800:4 / ≥620:3 / else 2`）。
- **验证**：新增测试——竖条模式动作进竖条且无 FAB、横条模式动作留在标题栏、669/678 一行三列、详情/列表既有测试全绿；`flutter analyze` 非 deprecated 0；`flutter test` 除既有基线外全过（本轮新踩：`no_unlocalized_user_text_test` 拦截硬编码「计算范围」→ 改用 `l10n.calcContextTooltip`）。

**㉕ 真机 iPhone 13 Pro 标题栏仍顶进刘海：加屏幕比例闸门（2026-11-26 第二十二轮）**

用户实测：「iPhone 13 Pro，模拟器上没问题，但是真机就不行，标题栏还是会跑到刘海那块。」

**分析**：模拟器（iPhone 18 Pro）上报的是整条状态栏 `Rect(0,0,402,54)`，被第二十轮的「角落簇」过滤挡掉了；但真机的 `reservedRegions` 形态与模拟器不同（可能上报刘海/摄像头区，甚至带侧别），矩形过滤不足以保证。**结论：光靠遮挡区形状判 Duo 不可靠，要加一道与设备形态无关的闸门。**

**修法**：
- 新增 `isFoldableScreenShape(size)`：短边/长边 ≥ **0.6** 才算折叠屏。Duo 各姿态（466×678 / 669×951 / 951×669 / 469×669）比值都 ≥0.687；普通 iPhone（13 Pro 390×844、18 Pro 402×874、SE 375×667）≤0.56。
- 所有 Duo 决策都过这道闸门：`_isDuo(size)`、`_seenDuo` 赋值、`_barInsets`、`OrientationPolicy`（普通比例的手机即使上报「像 Duo 的侧别/遮挡区」也不会解锁旋转）。
- 顺手修 `DuoLayoutInfo.clusters`：`width/height` 未知时返回**空**（此前返回原始 occlusions，等于跳过校验）。
- 调试日志补齐判据：`DUO edge=… size=… occlusions=[…] clusters=N mq=Size(…) shape=bool`——真机有问题时让用户回传这一行即可定位。

**验证**：`flutter analyze` 非 deprecated 0；新增测试——`isFoldableScreenShape` 各姿态（Duo 5 种通过 / 普通 4 种不过）、`duo_poses_test`「普通手机比例 + 上报像 Duo 的角落簇与侧别 → 标题栏仍在状态栏下方、动作不被推走、返回键可用」、方向策略「普通比例 + 像 Duo 的信号仍锁竖屏」；全量 `flutter test` **950 通过、14 失败**（同一批既有基线）。

**㉔ iOS 普通手机锁定竖屏（2026-11-26 第二十一轮）**

用户：「iPhone 18 横屏时，未避让灵动岛。建议 iOS 下，一般的手机端不要做旋转，旋转仅适用于平板和折叠屏设备。」

普通 iPhone 横屏时灵动岛在侧边，标题栏没有（也不打算）为普通手机做横屏避让——按建议直接禁旋转。新 `core/layout/orientation_policy.dart`：

- `allowedOrientations(isIOS, size, duo)`：非 iOS 保持原样（Android 折叠屏走 `displayFeatures`，不动）；**iOS 普通手机（最短边 <600 且无 Duo 簇）→ 仅 `portraitUp`**；平板（最短边 ≥600）与折叠屏（`hasDuoCluster` 或竖条侧别已知）→ `portraitUp + 两个横屏`。
- 应用时机：冷启动 `_bootstrap` 末尾 **发后即忘**（`applyForCurrentView` 不 await、不加超时——原生通道在测试 / 冷启动瞬间可能永不回包，挂一个 Timer 会让测试的 pending-timer 断言失败，`await` 还会卡住后面的启动步骤）；壳层拿到 Duo 信息变化后再跑一次（折叠屏展开出系统簇即解锁旋转）。策略结果有缓存，重复调用不重复设。
- 实测：iPhone 18 Pro 启动（窗口遗留横屏 874×402）→ `ORIENT apply=portraitUp` 且窗口转回竖屏；Duo（内屏横屏 951×669 + 簇）→ `apply=portraitUp,landscapeLeft,landscapeRight` 旋转保持可用。

**验证**：`flutter analyze` 非 deprecated 0；新增 `orientation_policy_test` 5 例（普通手机竖屏锁定含横屏尺寸、平板旋转、Duo 旋转、折叠态旋转、Android 不受限）；全量 `flutter test` **945 通过、14 失败**（同一批既有基线）；已构建并同时安装到 iPhone 18 Pro 与 Duo 模拟器。

**㉓ 回归：普通 iPhone 的整条状态栏被误判成 Duo 簇（2026-11-26 第二十轮）**

用户：「改 duo 的布局不要影响其他机型。现在其他机型的标题栏跑到了刘海、灵动岛上面，根本无法操作按钮；原先该有的后退按钮也没了。」

**排查（在 iPhone 18 Pro 模拟器上取证）**：app 的 `DUO edge=…` 日志显示普通 iPhone 也会上报 occlusion：

```
DUO edge=VerticalBarEdge.unspecified size=402.0x874.0
    occlusions=[Rect.fromLTRB(0.0, 0.0, 402.0, 54.0)]
```

也就是 **`UIView.reservedRegions(.occlusion)` 在全机型上都会返回「整条状态栏」**。壳层此前用「有遮挡区 = Duo」判断，于是普通 iPhone 命中：

- `_wrapPageMediaQuery` 走 Duo 分支 → 顶部内边距清零 → 标题栏内容画到状态栏/灵动岛下方（跑到它上面）；
- `DuoBarInsets.of` 把整条状态栏当成「在右侧的簇」→ `trailingInset = 402` → 动作按钮被推到屏幕外，点不到；
- 后退键同样被挤出可视区（不是被隐藏，而是整条栏错位）。

**修法**：`DuoLayoutInfo.clusters` 只保留「侧边簇」——同时满足①贴左/右边缘、②靠近上/下边缘（容差 40pt，覆盖 home indicator 区）、③不占满整宽、④不占满整高。`DuoBarInsets`、`topClusterInset`、`bottomClusterInset`、`clusterAtBottom`、`_isDuo()`、`_seenDuo`、个人中心的 Duo 提示全部改用 `clusters` / `hasDuoCluster`；`foldX` 的折痕带识别仍用原始遮挡区（折痕带不贴侧边）。普通 iPhone / iPad 的整条状态栏因此被过滤，Duo 的角落簇（669 竖屏 144×82、内屏横屏 84×124、折叠态 174×84 / 84×82 等）不受影响。

**验证**：iPhone 18 Pro 模拟器实测（重新安装后截图）——状态栏下方是正常标题栏，右侧两个动作在屏内，底部 4 项 + 更多；新增测试：`duo_bar_insets_test` 3 例（整宽状态栏 / 横屏居中刘海 → 非 Duo；Duo 角落簇保留）、`duo_poses_test`「普通 iPhone：标题栏留在状态栏下方、动作不被推走、返回键可点」、个人中心「非 Duo」用例改用真实状态栏遮挡区；全量 `flutter test` **940 通过、14 失败**（同一批既有基线）。

**㉒ 左侧竖条（分屏左窗）上部分按钮贴边（2026-11-25 第十九轮）**

用户：「侧边栏在左边的情况时，上部分按钮太靠边，显示不完全。请参照下部分按钮距离屏幕的距离。」

- **左右对称的只有横向，纵向不对称**：竖条内工具与 tab 同列居中（实测都在距外缘 48），但纵向——下方 tab 让了 home indicator（34），上方工具在**没有上报遮挡区**时只让 12（`topClusterInset == 0 → top: 0`，加上 SafeArea 的 0）。分屏左窗正是这种姿态（`edge=leading, occlusions=[]`），于是工具贴着窗口上沿、被圆角/系统状态区压住。
- 修法：竖条内容 `padding.top` 在无顶部簇时取 `max(12, viewPadding.bottom)`——直接照「下部分按钮距屏幕的距离」对齐；有顶部簇时仍是 `topClusterInset + 12`（内屏横屏 124 → 136 不变）。
- 回归：`duo_poses_test` 新增「分屏左窗」用例——竖条贴左缘且宽 84、工具横向中心 48、首个工具 top ≥ 34、末个 tab 底边 = 屏高 − 34 − 2（每项 2pt 内边距）、两者横向同列。

**验证**：`flutter analyze` 非 deprecated 0；全量 `flutter test` **936 通过、14 失败**（同一批既有基线）；已构建并覆盖安装到 Duo 模拟器。

**㉑ 保存按钮位置设置里的 Duo 说明（2026-11-25 第十八轮）**

用户要求：个人中心的「保存按钮位置」里，对 iPhone Duo 加一句「如果显示了侧边栏，则无论选哪项，保存按钮都固定在侧边栏上部分」。

- 文案走 l10n（三语）：`saveButtonPositionDuoRailNote`（zh / en / ar），`flutter gen-l10n` 重新生成。
- 只在 **Duo** 上显示：弹层挂在根导航上，拿不到壳层的 `DuoLayoutScope`，所以在打开对话框前用页面的 context 判一次（`DuoLayoutScope.infoOf` 的遮挡区非空或竖条侧别已知 → Duo），再把布尔值传进对话框；非 Duo（手机 / 平板）不显示，避免出现「侧边栏」这个不存在的概念。
- 测试：`profile_screen_test` 两例（Duo 有提示 / 非 Duo 无提示），注意设置项在长列表里，需要 `ensureVisible` 再点。

**验证**：`flutter analyze` 非 deprecated 0；全量 `flutter test` **935 通过、14 失败**（同一批既有基线）；已构建并覆盖安装到 Duo 模拟器。

**⑳ 详情页分栏改回 820 / 标题栏按钮继续给状态簇让位（2026-11-25 第十七轮）**

用户验收第十六轮后两条修正：

1. **详情页在折叠横屏 / 展开竖屏不分栏**（撤回 ⑲ 的 820→600）：`DetailTwoColumn` 默认断点与试算详情 `LayoutBuilder` 都回到 **820**，只有展开横屏（867）分栏；折叠横屏（646）、展开竖屏（637）保持单列。⑲ 里为窄栏做的「卡头标题可收缩」保留（宽屏下无视觉变化，窄栏防溢出）。测试同步反转：637/646 断言单列、899 断言双列；商品/原料详情的 669×951 用例改为「单列且不溢出」。
2. **标题栏不再下坠，但按钮没给状态簇让位**：⑲ 的 `_seenDuo` 只保住了「移除 top padding」，而标题栏高度/让位仍取自 live 的 `_duoLayoutInfo`——切换瞬间原生返回空遮挡区时 `DuoBarInsets.of` 变成 none（栏高 56、按钮贴边）。修法三重：①**同尺寸空结果沿用上一帧遮挡区**（原生没就绪不代表几何变了）；②空结果触发**补查**（400ms，最多 5 次，拿到非空即清零）；③壳层统一走新的 `_barInsets(context)`：完全拿不到遮挡区、但已确认是 Duo 且是展开竖屏尺寸（≥600×800）时，按实测几何兜底（右上簇 144×82、光轴 48），保证按钮不压在状态簇底下；拿到真实数据自动覆盖。底栏/浮层/页面 MediaQuery 三处也统一改用该 helper。

**验证**：`flutter analyze` 非 deprecated 0；`duo_poses_test` 的「某一帧返回空信息」用例扩展为断言栏高 82、末项按钮距右缘 152、文本中心 48；全量 `flutter test` **933 通过、14 失败**（同一批既有基线）；已构建并覆盖安装到 Duo 模拟器。

**⑲ 展开瞬间标题栏下坠 / 详情页 600 分栏 / 粘贴页操作行（2026-11-25 第十六轮）**

用户验收三项：

1. **折叠横屏展开成展开竖屏时，标题栏有概率掉到状态簇下面**。根因：切换瞬间原生 `reservedRegions` 可能返回空（`edge=unspecified`、`occlusions=[]`），壳层据此判为非 Duo → 页面不再 `removePadding(top)`，系统 top padding 把标题栏整条推下去；而 `_refreshVerticalBarEdge` 的相等判断只比 `edge` 与 `occlusions`，尺寸变化也不触发更新，状态会一直错到下次姿态变化。修法：①新增 `_seenDuo`——见过一次 Duo（有竖条侧别或遮挡区）就长期按 Duo 处理；②相等判断补上 `width/height`（rect 只在自己的坐标空间里有效）；③尺寸兜底：底栏模式且 `≥600×800`（Duo 展开竖屏特征）一律当 Duo，即使这一帧还没拿到布局信息。
2. **详情页在折叠横屏（646）与展开竖屏（637）也分栏**：`DetailTwoColumn` 默认断点 820 → **600**，试算详情的 `LayoutBuilder` 同步 820 → 600；手机（约 358）仍单列。为了在约 300 宽的单栏里不溢出，把详情卡片标题行改成可收缩（`Expanded` + `Flexible` + ellipsis）：商品/原料详情的 6 处卡头、试算详情 1 处、营养卡（标题 + 基准）、原料「关联商品」卡（标题 + 计数 chip）、`EntityQuantityLinksSection` 卡头。此前这些行在 336 宽时溢出 6.5~103px（英/阿语更长），现已由 800 宽与 669 宽两个尺寸的测试钉住。
3. **粘贴导入页：「复制模板」与「解析并匹配」放同一行，模板靠左、解析靠右**（用户澄清这里的「粘贴导入」是笔误，指复制模板）。移动端把原来右对齐的模板按钮从上移到解析行、概要移到自己一行；web `PasteImportDialog.vue` 同步（模板左、summary 中、解析右），两端结构一致。`npm run build` ✓、`check:i18n` ✓。

**验证**：`flutter analyze` 非 deprecated 0；新增测试——`duo_poses_test`「展开时某一帧原生返回空信息，标题栏仍贴顶」、`detail_two_column_fold_test` 默认断点 637/646 双列 + 390 单列、原料/商品详情「669×951 双列不溢出且左右并排」；全量 `flutter test` **933 通过、14 失败**（同一批既有基线）；已构建并覆盖安装到 Duo 模拟器。

**⑱ 宽底栏 tab 根页去返回键 / 后退统一「带尾巴」箭头 / 后退无响应（2026-11-25 第十五轮）**

用户验收：商品、原料、商家、试算、收藏、物价对比六个列表页在**展开竖屏 / 折叠横屏**时左上角还有返回键（这两个姿态底栏已直接列出全部目的地，列表页本身就是一级 tab，不该有「返回上一页」）；且展开竖屏下这些后退键按了没反应；后退图标样式不统一（框架 `BackButton` 在 iOS 上是 chevron / 无尾巴，`AppBackButton` 是 `arrow_back` / 带尾巴），以带尾巴的为准。

1. **`ShellChromeScope.tabRoot`**：壳层在 `bottomBar && 宽度 ≥600`（= 展开竖屏 669 / 折叠横屏 678，底栏 10 项）且当前地址**恰好**是 10 个目的地前缀之一时置真；`context.shellTabRoot` 为真时六个列表页 `leading` 传 null，返回键消失。手机竖屏（底栏 4 项 + 更多）保持原有返回键。
2. **返回键统一**：`ShellAppBar` / `ShellSliverAppBar` 接管 AppBar 的自动返回键（`leading == null && automaticallyImplyLeading` 且路由可退出），统一合成 `AppBackButton`（`Icons.arrow_back`，带尾巴，RTL 由图标自身镜像）；`DrawerButton` / 全屏对话框的 `CloseButton` 保留。所有表单页的后退也一并统一。
3. **后退无响应**：`AppBackButton` 改为——`PopScope`（`popDisposition == doNotPop`，如 FormExitGuard）→ 交给 `Navigator.maybePop` 由守卫弹确认；否则 `GoRouter.canPop()` → `GoRouter.pop()`（ShellRoute 下 `Navigator.maybePop` 不可靠，会吞掉这次点击）；`canPop` 为假（tab 根页）→ 先试 `maybePop`，再 `go('/home')`。**没有 GoRouter 的独立页面（组件测试）**退回纯 Navigator，否则会抛 `No GoRouter found in context`（本轮 16 个表单测试因此失败，已修）。

**验证**：`flutter analyze` 非 deprecated 0；`duo_poses_test` 新增「展开竖屏 / 折叠横屏的 tab 根页无返回键」「手机竖屏保留返回键」「展开竖屏详情页返回键可点并回到上一页」三例；全量 `flutter test` **927 通过、14 失败**（同一批既有基线）；已构建并覆盖安装到 Duo 模拟器。

**⑰ 竖条动作按路由隔离 / 「更多」4 列 / 展开竖屏对齐与四项一行 / 菜谱分析分栏（2026-11-24 第十四轮）**

用户第七轮验收反馈（全部为「有侧栏时」的场景）：

1. **竖条残留上一页的按钮**（个人中心出现「新增」、单位偏好返回后变成「保存」对勾、自定义计算范围同时有侧栏新增与 FAB、菜谱分析页出现菜谱详情的收藏/分析/⋮）。根因有**两层**：
   - **ShellRoute 的 builder 在 `push` 子页面时不重建**，`GoRouterState.of(context).matchedLocation` 一直停在 tab 根路径；`_lastChromeLocation` 的清空逻辑因此没被触发，且命令式 push 的页面地址也读不到。
     修法：壳层在 `didChangeDependencies` 里监听 `GoRouter.routerDelegate`，用 `currentConfiguration.matches.last` **一路走进 `ShellRouteMatch`**（push 出来的页面嵌在它内部）取真实地址；变化时同步给 `ShellChrome` 并 `setState`（顺带修好 push 子页面时的 tab 高亮/表单判定）。
   - **动作只有一个槽位**：转场期间上一页仍挂着并会重建（于是再次 publish），把新页面的动作覆盖掉。修法：`ShellChrome` 改为**按发布者路由各存一份**（`Map<location, (actions, primary)>`，最多 12 条），只渲染与当前路由一致的那份；切回旧页时它的动作还在，不必等重建。`publishShellActions` 用 `GoRouterState.of(context).matchedLocation` 作为归属键。比较只看「结构 + 是否禁用」，**不能比闭包/子控件身份**——页面依赖 `ShellChromeScope`，notify 会让它重建再 publish，形成重建循环（本轮踩过，四个竖条测试直接超时）。
2. **自定义计算范围页**：补 `publishShellActions(primary: 新增)`，竖条模式下隐藏 FAB（此前两个新增入口并存）。
3. **「更多」菜单窄屏每行 4 项**：可用宽 <600 固定 4 列（手机 / 分屏 / 折叠态），宽屏仍按 72pt 最小宽多排。
4. **展开竖屏标题栏对齐（`DuoBarInsets.contentCenterY`）**：单行状态簇（高 ≤100）里系统状态图标与摄像头共用**实测 48pt 的光轴**（与竖条图标列同一基准），而簇矩形几何中心是 41 → 标题/返回/动作整体下移 7pt（给槽位加 `2Δ` 顶部内边距，AppBar 居中后正好下移 Δ）；簇更高（过渡态 124）取簇中心。标题栏高度仍是簇底边（82），不改高度。
5. **今日预估四项一行**：`NutrientGrid.wideBreakpoint` 760 → **560**（展开竖屏卡片内实际可用宽只有 605：页面 16 + 卡内 16 两层内边距，760 当年按内容宽估会漏；手机 358 仍 2×2）。
6. **菜谱分析页分栏**：① 食材成本占比 + ② 成本趋势 用 `DetailTwoColumn(breakpoint: 600)` 两卡一行（展开竖屏内容宽 637、展开横屏 835 都命中，手机 358 单列，对齐 web `v-col cols=12 md=6`）；营养贡献溯源在卡内宽 ≥560 时**一行两个条形图**（每行 `IntrinsicHeight + Expanded` 等高）。

**验证**：`flutter analyze` 非 deprecated 0；新增/更新测试——`shell_chrome_route_scope_test`（5 例：按路由隔离、旧页迟到发布不影响新页、返回旧页动作仍在、clear、条目上限）、`duo_poses_test` 新增「下钻不发布动作的子页面，竖条不残留上一页按钮」与标题栏垂直中心 48 断言、`app_router_test` 新增「窄屏更多菜单每行 4 项」、`nutrient_grid_test` 新增 605 宽一行、`nutrition_source_grid_test` 新增宽屏两栏、`detail_two_column_fold_test` 新增 600 断点；全量 `flutter test` **923 通过、14 失败**（与改动前同一批既有基线）；已构建并覆盖安装到 Duo 模拟器。

**⑯ 系统实测几何定稿 / ShellAppBar 统一标题栏 / 浮层安全区统一接管（2026-11-24 第十三轮）**

用户逐项验收后的问题：展开竖屏标题栏按钮被状态簇挡住、菜谱详情标题栏不够高；折叠横屏曲边在下时标题栏按钮不靠边、底栏「我的」被摄像头挡住；十余个页面有侧栏时标题栏仍残留返回键；有侧栏时所有底部弹层右侧一大片空白；展开横屏今日预估四项应排一行；物价对比 / 收藏的标签右侧空白。**这轮的转折点是从模拟器日志里拿到了各姿态系统真实上报的遮挡区**（`xcrun simctl spawn booted log show --predicate 'eventMessage CONTAINS "DUO edge"'`），让位逻辑全部改成按矩形推导，不再靠猜。

**几何基准（系统上报的 occlusions，单位 pt）**

| 姿态 | size | edge | occlusions |
|---|---|---|---|
| 内屏竖屏 | 669×951 | unspecified | `Rect(525,0,669,82)`：右上状态簇 144×82 |
| 折叠横屏·曲边在下 | 678×466 | trailing | 摄像头 `(611.7,399.7,648.7,436.7)` + 系统簇 `Rect(594,384,678,466)` |
| 折叠横屏·曲边在上 | 678×466 | leading | 摄像头 `(29.3,29.3,66.3,66.3)` + 系统簇 `Rect(0,0,174,84)`（紧凑态 84×82） |
| 内屏横屏 | 951×669 | trailing | `Rect(867,0,951,124)`（另有 `Rect(807,0,951,82)` 变体） |
| 分屏左窗 | 469×669 | leading | `[]` |

要点：**系统安全区是整条侧边内缩（摄像头侧 84pt），但系统 UI 只占摄像头所在的那个角**。照搬安全区会让标题栏 / 正文 / 弹层空出一整条；旋转瞬间还会上报过渡态（如 82×200 的细高条），不能当稳态用。

**旋转后的上报规律（装包后盯着日志看到的）**：刚转到一个姿态时，系统会先上报**上一姿态稳态的形状**，再切到本姿态的稳态——内屏竖屏稳态是 `Rect(525,0,669,82)`（144×82），刚从横屏转来时先报 `Rect(585,0,669,124)`（84×124）1~10 秒；内屏横屏稳态是 `Rect(867,0,951,124)`，刚转来时先报 `Rect(807,0,951,82)`。所以让位数值不能瞬切：页面主题用 `AnimatedTheme`、底栏 / 竖条的让位用 `AnimatedPadding`（200ms）过渡。

1. **标题栏 / 底栏让位（`DuoBarInsets`，`vertical_bar_edge.dart`，ThemeExtension）**：从遮挡区推导。簇在**顶部**：`toolbarHeight` = 簇底边（上限 96，过渡态超出部分改由侧向让位）、按钮排到簇旁边（`leadingInset` / `trailingInset`）、底栏全宽；簇在**底部**：标题栏不内缩（按钮距边 8）、底栏在该侧让开（`barTrailingInset` = 84）、无底栏的整页表单与浮层抬到簇之上（`bottomInset` = 82）。展开竖屏 = 标题栏高 82、右侧动作整体让到 x=525 左边；曲边在下 = 动作贴边、底栏右让 84（「我的」不再被摄像头挡）；曲边在上 = 标题栏高 84、返回键排到 174 的右边，底栏保持全宽（用户确认该姿态底栏位置正确）。
2. **页面子树 MediaQuery（`_wrapPageMediaQuery`）**：横条模式去掉左右内边距、标题栏贴顶，底栏存在时底部只让 home indicator，否则取 `max(home indicator, 底部簇)`；竖条模式去掉竖条所在侧的内边距。此前 AppBar 自带的 SafeArea 又吃了一次 84（主题里再叠一层 → 折叠横屏右侧空白 178pt；竖条模式标题偏左 42pt）。
3. **返回键位置**：AppBar 把 leading 在 `leadingWidth` 里**居中**，`leadingWidth = 64 + 簇宽` 会正好压在系统簇上。`ShellAppBar` 在系统簇位于 leading 侧时显式给出返回键（含复刻 Flutter 的自动返回逻辑）并用 `Align(centerEnd)` 排到簇右边。
4. **统一标题栏 `ShellAppBar` / `ShellSliverAppBar`（新 `core/layout/shell_app_bar.dart`）**：应用内 53 处 `AppBar(` 全部改用它。竖条模式下**不渲染 leading 与 actions**（返回由竖条置顶，动作由页面 `publishShellActions` 发布），非竖条形态与 `AppBar` 完全一致。残留返回键的根因：商品 / 原料 / 商家列表与试算详情的 `leading: const AppBackButton()` 根本没按竖条模式判断，其余页面靠 AppBar 自动返回，没有统一入口。**硬约束**：`test/core/layout/shell_app_bar_guard_test.dart` 源码守卫——`lib/` 内出现裸 `AppBar(` / `SliverAppBar(` 即失败；带 `actions` 的 `ShellAppBar` 所在文件必须调用 `publishShellActions` / `saveAppBarActions`（两种违例都做过变异验证，确实会失败）。debug 下动作未发布时 `ShellAppBar` 还会打印提示。页面里原有的 42 处 `automaticallyImplyLeading: !rail` / `leading: rail ? …` / `actions: rail ? const [] : …` 全部删掉。补发布 3 个漏网页面：自定义单位草稿（新增 → 主操作）、原料关联关系（完成 → 对勾主操作）、快速填写（保存 → 对勾主操作 + 粘贴导入）。
5. **浮层安全区统一接管（`ShellOverlayInsets` + `ShellOverlayInsetsScope`，`shell_chrome.dart`）**：弹层挂在 Navigator 上，拿不到壳层给页面准备的 MediaQuery，逐个弹层改必漏。现在壳层在 build 里声明该去掉 / 抬高什么，`MaterialApp.router` 的 `builder` 在 Navigator 之上套一层 MediaQuery：竖条模式去掉竖条所在侧的 84；Duo 横条模式两侧铺满、底部抬到底部簇之上。构建期不能通知（会抛 markNeedsBuild during build）→ 帧末应用，浮层晚一帧无感。注意：弹层挂在**壳层导航**上，范围 = 内容区 / 底栏之上；Flutter 的 modal sheet 只让顶部与左右，底部由弹层内容自己的 SafeArea 决定。
6. **今日预估四项一行**：`NutrientGrid(wideColumns: 4)`，可用宽 ≥760 时排一行（首页传入；餐卡不传，仍 2×2）。
7. **标签铺满**：新 `shared/widgets/adaptive_tab_bar.dart`（`AdaptiveTabBar`）：宽 ≥600 时 `isScrollable: false + TabAlignment.fill` 等分整行，窄屏按内容排可滚动。物价对比、收藏、原料关联关系、试算添加条目弹层四处接入。

**这轮踩到的 Flutter 框架细节**

- `SliverAppBar.toolbarHeight` 默认值是 **56 而不是 null**，会盖掉主题里的标题栏高度——只有菜谱详情用 SliverAppBar，正好对上「菜谱详情标题栏不够高」；包装层按「参数 → 主题 → 默认」解析。
- `Scaffold` 只对 Flutter 自己的 `AppBar.preferredSize` 类型套用主题高度（`AppBar.preferredHeightFor`），包装层自己拼一个 `Size` 会被夹回 56 → `preferredSize` 直接委托给内部 `AppBar`。
- 原生通道名是 `com.a4ding.livecalc/duo_layout`（**点**，不是下划线）：测试里 mock 错通道名时调用不报错而是一直挂着，表现为「查询没生效」。
- 测试里要用 `AppTheme.lightTheme`：默认测试主题下 AppBar 标题不居中。

**验证**：`flutter analyze` 非 deprecated 0；新增 `duo_bar_insets_test`（7 例）+ `duo_poses_test`（10 例，按上表真实几何逐姿态断言标题栏高度、按钮位置、底栏让位、弹层范围，含状态簇形状变化的平滑过渡）+ `shell_app_bar_guard_test`（3 例）+ `nutrient_grid_test`（3 例）+ `adaptive_tab_bar_test`（2 例）；全量 `flutter test` **912 通过、14 失败**（与改动前同一批既有基线）；已构建并覆盖安装到 Duo 模拟器。

**⑮ 折叠横屏改底栏 / 三页接入竖条 / 收藏与个人中心（2026-11-24 第十二轮）**
- **折叠横屏（矮，h<620）改回「全宽底栏」**：竖条只放 4 个 tab 也会留出一条 84pt 的空带（内容缩进 → 箭头偏左、右侧空白）。`shellModeFor`：有竖条信息时，内屏竖屏（h≥800）与矮横屏（h<620）都走 `bottomBar`，只有内屏横屏（669 高）走竖条。
- **横条模式的标题栏让位**（`_wrapDuoPageChrome`）：按**遮挡区**（而非 viewPadding）判断系统簇位置——簇在顶部时 `toolbarHeight` = 簇底边（标题与系统图标平齐）、`leadingWidth`/`actionsPadding` 按簇所在侧让位（返回键与动作不被时间/电量遮挡）；簇在底部时只留 8pt 边距。
- **底栏横跨全宽**：`_buildBottomNav` 外层 `MediaQuery.removePadding(removeLeft/removeRight)`——折叠态（系统条在左/右）不再出现一截空白。
- **物价对比 / 收藏 / 试算列表接入竖条**：动作（地区选择、范围菜单、新建）发布到竖条；有侧栏时隐藏 AppBar 的返回与动作；试算列表 FAB 在竖条模式下隐藏、改为竖条主操作。
- **收藏列表**：去掉尾部箭头（`forwardChevron`）。
- **个人中心**：默认币种 / 默认计算范围 / 自定义范围三行补上尾部箭头，与其余设置项一致。
- **验证**：`flutter analyze` 非 deprecated 0；全量 887 通过、14 失败仍为既有基线；已构建并安装到 Duo 模拟器供实测。

**⑭ 残留工具 / 更多菜单空白 / 商家 1:1 / 展开竖屏标题栏（2026-11-24 第十一轮）**
- **短竖条仍有页面工具**：页面在 `isRailMode=false` 后停止 publish，但 `ShellChrome` 里的旧动作不会被清 → 竖条继续渲染上一页工具。修：壳层在「竖条不接管工具」时每帧 `clear()`；自动后退也只在接管工具的竖条（高 ≥620）中渲染。
- **更多菜单左/右大片空白**：`showModalBottomSheet` 内的 `SafeArea` 会吃到系统竖条的 84pt 水平内边距（外屏左、内屏右各一侧）→ 菜单项整体偏移。修：菜单内容 `MediaQuery.removePadding(removeLeft/removeRight)`。
- **商家列表比例**：1:3 → **1:1**（列表 : 地图）。
- **竖条主操作（原 FAB）**：恢复 `primaryContainer` 圆角底（44×44、图标 22），不再是与普通图标无差别的幽灵按钮。
- **展开竖屏标题栏**：Duo 横条模式下给页面套 `AppBarTheme`——`toolbarHeight` = 系统状态簇高度（>56 时）、`actionsPadding.end` = 系统条宽度 + 8（动作不再被时间/电量遮住）、`leadingWidth: 64`（返回键离边远一点）。
- **加载态闪返回键**：各详情页 loading/error 分支的临时 AppBar 也按 `context.shellRailMode` 隐藏自动返回。
- **未决**：折叠横屏导航形态（底部全宽 vs 左侧 4-tab 竖条）与「五页待改」的具体范围，已向用户提问，等答复后处理。
- **验证**：`flutter analyze` 非 deprecated 0；全量 887 通过、14 失败仍为既有基线。

**⑬ 矮竖条只留 tab / 列表卡清理 / 菜谱顶部栅格 / 展开竖屏贴顶（2026-11-24 第十轮）**
- **矮竖条放不下**：折叠横屏（466 高）竖条里「工具 + tab」会溢出（用户截图 `BOTTOM OVERFLOWED BY 46 PIXELS`）。改为按高度分流：**竖条高 < 620 时只渲染 4 个 tab，页面动作/返回仍留在标题栏**（`isRailMode` 增加高度条件；页面无需改动，`context.shellRailMode` 自动为 false）。
- **列表卡精简**（所有设备）：原料、商品列表移除「记价」按钮（`add_chart`）与尾部箭头；商家列表移除尾部箭头。
- **菜谱详情顶部栅格**：对齐 web `.recipe-top-grid`——**左 = 图片灯箱 + 基本信息，右 = 成本（含走势）**；下面仍是「原料｜步骤」「营养｜小贴士」。待审横幅保持「图片 → 横幅 → 基本信息」顺序（单列与双列都成立）。
- **展开竖屏标题栏贴顶**：条件从「trait 明确 + 顶部无簇」放宽为「Duo（有竖条信息或保留区）且（底栏模式或顶部无簇）」，展开竖屏不再被多余 top padding 推下。
- **验证**：`flutter analyze` 非 deprecated 0；全量 887 通过、14 失败仍为既有基线；内屏横屏 951×669 金图核对（右竖条 4 tab + 菜谱左图/基本信息、右成本）。

**⑫ 折叠横屏（曲边朝上）竖条化（2026-11-24 第九轮）**
- 真机数据（折叠横屏 678×466）：`edge=leading`、`occlusions=[摄像头 37×37 @(29,29), 状态列 84×82 @左上]`、`viewPadding=(84,0,0,0)`——系统竖条在**左缘**，但此前判定为「底栏模式」，导致标题栏压住摄像头、底栏被 SafeArea 左边距顶出一大片空白。
- 修法：`shellModeFor` 增加 `edge` 入参——**系统明确有竖条时**，除「高瘦竖屏（h≥800，如内屏竖屏 669×951）」保留底栏外，一律走竖条；壳层把 `_duoLayoutInfo.edge` 传进去。竖条所在侧同时给摄像头让位（内容整体缩进 84），标题栏自然对齐摄像头列。
- 竖条内部排列定稿：**工具在系统簇下方、tab 贴底**（HIG：tab bar 在竖条末端），底部若有系统簇（摄像头朝下）用 `bottomClusterInset` 让位；移除上一轮的 `itemsAtTop` 翻转。
- 测试：新增「折叠横屏 678×466 摄像头左上 → 竖条、tab 贴底」「系统竖条存在 + 矮横屏 → 竖条」「高瘦竖屏 → 底栏」等用例。
- **注意**：调试时 `simctl uninstall` 会清掉模拟器里 app 的登录态/本地数据（本次已发生，需重新登录）。

**⑪ 后退键 / 全按展开处理 / 列表全量分列 / 标题栏贴顶（2026-11-24 第八轮）**
- **竖条后退无响应**：`Navigator.of(context).maybePop()` 在 ShellRoute 下无效 → 改 `GoRouter.of(context).pop()`。
- **一律按完全展开**（折叠区不可靠）：删除 `DetailTwoColumn` 的半折叠分支（等宽双栏 + 16 间距，不再按 foldX 拉大中缝）；商家列表恒 **1:2**；侧别只信 `verticalBarEdge` trait，未上报时默认 trailing（不再用 padding 猜测，避免误判左侧而留大片空白）。
- **列表页全量分列**：原料、商品、商家（无地图/窄栏）、收藏、计价、试算 —— ≥620 两列、≥1100 三列；菜谱网格沿用 3/4/6 档。单列与多列共用 `_buildItem` / `_buildMerchantItem`。
- **展开竖屏标题栏贴顶**：Duo 检测到侧边竖条且顶部无系统簇（`topClusterInset == 0`）时，对页面子树 `MediaQuery.removePadding(removeTop: true)`——标题栏顶到屏幕最上方，不再被多余 top padding 推下来。
- **验证**：`flutter analyze` 非 deprecated 0；全量 883 通过、14 失败仍为既有基线。

**⑩ 单列顺序 / 后退键 / 更多菜单 / 列宽（2026-11-24 第七轮）**
- **单列保持原顺序**：`DetailTwoColumn.rows(single: [...])` 新增 `single` ——单列（窄屏）按页面原有移动端顺序渲染，双列分组（web 桌面 Grid 顺序）只在宽屏生效。原料/商品详情显式给出 single 顺序（原料：单位在层级之前；商品：价格记录→营养→单位），菜谱/商家用分组展平即原顺序。
- **后退键找不到**：`ModalRoute.of(context)?.canPop` 在 ShellRoute 下不可靠 → 改用 `GoRouter.of(context).canPop()`；竖条第一条渲染后退。
- **「更多」弹层间距**：列数按可用宽度自适应（每项最小 72pt，上限 8 列），宽屏一行排满，右侧不再大片空白。
- **商家详情「商品价格」卡**：条目在卡内 ≥620 宽时两列（`_row` 提取 + LayoutBuilder 网格），窄屏单列。
- **详情分栏观感**：同排两侧**等高**（`IntrinsicHeight` + `CrossAxisAlignment.stretch`；直接 stretch 在 ListView 内会拿到无限高约束而崩溃，已修一处导致商家详情崩溃的回归）；列宽严格 1:1（试算详情由 3:2 改为 1:1）。
- **验证**：`flutter analyze` 非 deprecated 0；全量 881 通过、14 失败仍为既有基线。

**⑨ 表单页工具栏 / 半折避让 / 详情严格对齐 web Grid（2026-11-24 第六轮）**
- **表单页（新增价格记录等）**：壳层在**竖条模式**下不再隐藏导航（`showNav = railNav ? true : !fullScreenForm`），表单页照常显示竖条但**隐藏 4 个 tab**（`_EdgeRail.showTabs=false`）；`saveAppBarActions` 改为 rail-aware——竖条模式下把「保存」发布为竖条**主操作**（`Icons.check`，44×44/20pt）并返回空列表，底部保存条同时隐藏；返回键由壳层置顶。6 个表单页补 `automaticallyImplyLeading: !context.shellRailMode`（标题栏不再重复返回键）。全部保存按钮调用点（14 处）统一传 `context`。
- **详情页严格对齐 web 桌面 CSS Grid**（读 `ProductDetail.vue`/`IngredientDetail.vue`/`MerchantDetail.vue` 的 `@media (min-width:960px)` 规则，不再简单对半）：
  - 菜谱：基本信息/成本/走势整行 → **[原料｜步骤] [营养｜小贴士]**
  - 原料：**[基本信息｜最新价格] [关联商品｜价格趋势] [相关菜谱｜价格记录] [营养｜（层级+单位与密度）]**
  - 商品：**[基本信息｜最新价格] [单位与密度｜价格趋势] [营养成分｜价格记录]**
  - 商家：**[基本信息｜位置] [价格整行]**
  - 实现：`DetailTwoColumn.rows` 逐行配对（每行左右独立高度，与 web flex 行同语义）。
- **半折避让**：`foldX` 增加兜底——`.division` 为空时，用「细高遮挡带」（宽度 ≤80pt 且高度 ≥屏高 55%）识别折痕；原生 divisions 查询并上 `includeInactive`。`DetailTwoColumn` 与商家列表按 `foldX` 断开分栏。
- **商家比例**：完全展开时列表 : 地图 = 1 : 2（列表宽 = 内容宽/3），半折按 foldX。
- **验证**：新增半折测试 5 例（foldX 三例 + 半折/全开几何两例）；`flutter analyze` 非 deprecated 0；全量 881 通过、14 失败仍为既有基线。

**⑧ 工具栏规格 / 半折不跨铰链 / 详情顺序对齐 web（2026-11-24 第五轮）**
- **竖条工具栏规格**：所有页面动作（含原 FAB）统一为**44×44 命中区 + 20pt 图标**，与导航项同尺寸同列；顺序 = **后退（可返回时，壳层自动置顶）→ 主操作（原 FAB）→ 其余动作**。自定义控件（范围菜单、⋮ 菜单）以 `IconTheme(size:20)` + `IconButtonTheme(minimumSize 44, padding 0)` 归一。**避让系统簇**：`DuoLayoutInfo.topClusterInset`（遮挡区底边）作为竖条内容 `padding.top`——之前位置被系统状态图标挡住。竖条在左时工具栏同样从左上开始（内容列随侧别镜像）。
- **半折不跨铰链**：原生 `layoutInfo` 增加 `reservedRegions(kind: .division)`（折叠区），Dart 侧 `DuoLayoutInfo.foldX`；新增 `DuoLayoutScope`（layout + railWidth）由壳层注入，`DuoLayoutScope.foldXOf` 把折叠区坐标换算到内容坐标（左竖条时减 rail）。`DetailTwoColumn` 在有折叠区时**在折叠位置断开分栏**（左栏宽度 = 折叠 x，右栏占其余），窄屏/无折叠行为不变。
- **商家页地图 2/3**：完全展开（无折叠区）时列表 : 地图 = **1 : 2**（列表宽 = 内容宽/3）；半折时列表宽度 = 折叠位置，地图在右侧 pane，不跨铰链；窄屏保持 260 高堆叠。
- **详情页顺序对齐 web**：菜谱 = 头部/成本整行 + 「原料｜步骤」「营养｜小贴士」两行（`DetailTwoColumn.rows`）；原料 = 基本信息/最新价/走势 ｜ 关联商品/价格记录/关联菜谱/营养/**层级/单位**（层级提到单位前，与 web 一致）；商品 = 基本信息/最新价/**单位与密度**/价格记录/营养（单位卡移到价格记录前）；商家详情 = 基本信息/位置/价格，动作（编辑）进竖条。
- **详情页动作入竖条**：菜谱（收藏/分析/⋮）、原料（收藏/记价/⋮）、商品（收藏/记价/⋮）、商家（编辑）——竖条模式下隐藏 AppBar actions 与 leading（后退由壳层提供）。
- **验证**：`flutter analyze` 非 deprecated 0；全量 `flutter test` 876 通过、14 失败仍为既有基线；商家双栏测试改为断言「列表 ≤1/3、地图 ≥55% 宽」。

**⑦ 商家页例外规则（2026-11-23）**：展开横屏（内容宽 ≥820 且地图就绪）时**右侧始终展示地图**、左侧保持**单列**列表（不参与「列表多列」规则）；宽屏下不再渲染地图开关（右侧恒有地图），窄屏仍保留开关与 260 高堆叠。补充：上一轮商家页的竖条工具栏接入实际未落盘（脚本断言中断），本轮补上——新增（primary）+ 范围菜单进竖条，FAB 在竖条模式隐藏。测试：宽屏左列表单列堆叠、宽屏不出现地图开关图标、窄屏地图仍 260。

**⑤ 展开态分栏收尾（Phase 3/4/5，2026-11-23）**
- **Phase 4 试算详情（`plan_detail_screen.dart`）**：body 改 `LayoutBuilder`——可用宽 ≥820（Duo 内屏横屏 867）时按 web 信息架构分栏：左 3/5 = 条目卡（内部再按 2 列 Wrap 排条目）+ 右 2/5 = 合计卡 + 成本占比卡；成本走势、营养来源整行在下。窄屏保持原单列。抽出 `_buildItemsCard` / `_buildTotalsCard` 复用（原逻辑含口径切换与地区表，行为不变）。测试：宽屏下 `Items` 与 `Totals vs targets` 同 dy、合计在右（新增 1 例）。
- **Phase 5 商家列表（`merchant_list_screen.dart`）**：body 改 LayoutBuilder——≥820 且开启地图时「左 350 列表（搜索在上）+ 右全高地图」（与 web 桌面同构，地图圆角裁切 + VerticalDivider）；窄屏保持「搜索 + 260 高地图 + 列表」堆叠。测试：宽屏搜索右缘 ≤350、地图 left >340 且高度 >600（全高）；窄屏地图仍为 260（新增 2 例）。
- **Phase 3 原料/商品卡**：核对后原料卡已含首字母头像 + 分类 chip + 最新价 + 走势 + 收藏/记价，商品卡已含品牌（无品牌兜底）+ 关联原料 + 最新价 + 走势——仅补 web 有而移动端缺的**别名 chips**（`product.aliases` 前 2 个 + `+n`，secondaryContainer 底），与 web 商品卡字段对齐。
- **验证**：`flutter analyze` 非 deprecated 0 问题；全量 `flutter test` 872 通过、14 失败经 stash 基线对照确认**全部为既有基线**（app_bar 字体缺失 / home_summary / apple_map×3 / price_record_form_sheet×6 / locale_preferences×2 / my_proposals，与本次改动无关）。

**已知待办**：页面自身 AppBar 的操作按钮（扫码/筛选等）目前在页面内容区内（距右缘 84pt），尚未移入竖条工具栏区——HIG 期望「工具栏在竖条内、导航控件置顶」，需要页面级 toolbar 注册机制（Phase 2 后续）。

## HIG 官方定调（2026-11-23，用户提供官方链接；全文经 `designing-for-iphone-duo.md` 源抓取）

官方 HIG《Designing for iPhone Duo》（2026-09-09 发布）要点与设计稿响应（设计稿已按此全面修订）：

1. **竖排控件（Vertical controls）**：外屏与内屏横屏上，Dynamic Island + 状态栏 + 工具栏（含导航按钮）+ tab bar 全部收进**尾缘竖条**（LTR=右缘，RTL 同侧跟随硬件）；**内屏竖屏例外保留标准横条**。设计稿响应：01 外屏/03-07 内屏横屏 = 尾缘竖条（含页面操作按钮）；02/08 内屏竖屏恢复顶部导航栏 + 底部 tab bar。
2. **工具栏顺序**：竖条顶部留给主导航控件（Back/Close）→ 主要操作（Done/Compose）→ 其余保持原分组；溢出自底向顶；空间不足时按体验保留工具栏或 tab bar（压缩行为）。设计稿响应：试算详情 Back 置竖条顶、删除随其后；扫码/筛选入竖条；保存留在编辑行（「控件靠近其作用的内容」）。
3. **Reserved regions（安全区域之上）**：外屏前摄常驻（对齐竖条、Live Activities 时扩为 Dynamic Island）；内屏前摄仅激活时出现；**折叠区**半折时条件性把中心从可用区排除——alerts/sheets/菜单系统自动避让，grid **双数列优先**（内容对折干净）。设计稿响应：外屏竖条顶部画摄像头区；网格 gutter 对齐折痕；内容连续屏（用户定调）与「系统组件自动避让」并存不冲突。
4. **分屏（Split views / 分栏）**：内屏展开双栏、外屏单 pane；Mail/Notes 模式 = **列表/主导航在 leading 左侧、详情在 trailing 右侧**；分屏多任务时各 app 控件靠自身外缘（左 app 控件在左）。设计稿响应：商家页列表 pane 在左 ✓；后续 master-detail 一律列表在左。
5. **其余**：勿覆盖默认控件位置；控件靠近其作用的内容；用系统 overflow 菜单；工具栏项 title+symbol 双给；可用全宽的界面（如 Calculator）不必强加 bars。

## web 端与 Android 折叠屏扩展（2026-11-23，设计稿 Plate 09）

用户指出：这套折叠屏模式同样适用于其他折叠屏 Android 端；web 端也应检测折叠屏及状态，把详情自动分两列——目前 web 在 Duo 上仍单列。

**根因（勘察确认）**：Vuetify thresholds md=960（`src/plugins/vuetify.ts:117`），Duo 横屏逻辑宽 951 **差 9pt 跌落 sm 档** → 详情页 `cols="12" md="6"` 全部堆叠单列；壳层桌面判定 `isDesktop = mdAndUp`（`src/composables/useMobileDrawer.ts:12`）与 `MobileAppBar` 的 matchMedia 960（`MobileAppBar.vue:30`）同样跌落 → 整站退到移动抽屉壳。

**三层策略（Plate 09）**：
- **L1 断点层（全浏览器立即生效）**：详情页列档 md=6 → sm=6（`RecipeDetail.vue:301/311/321/375` 等四处；原料/商品/商家详情同查）——Duo 竖屏 669 与横屏 951 都吃两列，手机 <600 不变；壳层桌面判定 960 → 900 或「折叠屏已知」标记。两列对小平板同样受益，不依赖检测。
- **L2 姿态层（半折双 pane）**：`@media (horizontal/vertical-viewport-segments: 2)` + `env(viewport-segment-*)` → 列表/详情各占一段、折痕留 gutter。兼容性：**Chrome 125+ 正式支持**（2025-06 GA）、Samsung Internet 真机可用；**Safari 27.1（2026-10 WebKit 博客）已带 Device Posture + Viewport Segments API，处 Feature Flags 阶段**（设置 > Safari > 高级 > 功能标志），正式版随 iOS 27.x 后续。
- **L3 检测边界（诚实声明）**：device-posture 只有 continuous/folded——**全展开与直板机同值**，纯 API 判不出「折叠屏全展开」；以半折时缓存 isFoldable + 宽度档近似即可。

**Android 折叠屏**：Flutter 的 `MediaQuery.displayFeatures`/hinge posture 在 Android **原生可用**（foldable 桥接包只是 iOS 缺口）——本稿 02-08 的 pane 布局可直接复用于 Galaxy Z Fold 等；web 端 Chrome on Android 的 segments API 原生支持，同一套 L2 CSS 生效。

**分支注意**：web 前端改动按项目规则提交 **master**，再合 feat/mobile-app。

**设计稿**：Plate 09 = Web · Duo 展开横屏 · 详情两列（浏览器框 + 桌面侧栏壳 + 菜谱详情两列）。

## 参考

- Flutter issue：flutter/flutter#192515（iOS displayFeatures，open）；PR #193025（未合）；PR #195199（内屏尺寸修复，已合）
- LeanCode 博客《How to Prepare Your Flutter App for iPhone Duo》（2026-10）
- pub.dev：`foldable`、`duo_kit`
- 本机实证：Xcode 27.2 设备描述文件 + 已自动创建的 iPhone Duo 模拟器

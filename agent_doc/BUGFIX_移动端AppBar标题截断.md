# BUGFIX 移动端 AppBar 标题截断

- 日期：2026-11-07
- 分支：feat/mobile-app
- 类型：移动端 UI / 布局预算
- 关联页面：商品/原料/商家详情、试算方案详情、营养编辑、各列表页、关联原料关系、菜谱编辑

## 现象

移动端 AppBar 标题经常显示不全。360dp 小屏 + 阿拉伯语/英文下更严重。

## 根因（预算公式）

Flutter 3.47 `AppBar` 对标题强制单行省略（`app_bar.dart` 中 `DefaultTextStyle(softWrap: false, overflow: TextOverflow.ellipsis)`），所以问题都是**预算不足**：

```
标题可用宽度 = 屏宽(最小 360) − 返回键 56 − Σ actions
IconButton（含 PopupMenuButton）= 48/个；TextButton = max(64, 24 + labelLarge 文本宽)
```

主要杀手：

1. **商品/原料/商家详情**：4 个 actions（收藏/记价/⋮/刷新）→ 标题只剩 **112px**，再被标题里的类型 chip 挤掉 ~46px → 名称只能显示 **约 3 个汉字**。
2. **试算方案详情**：4 个 actions（🌐/✏️/设为今日/🗑）→ 112px ≈ 5 个汉字（方案名是动态标题）。
3. **营养编辑**：AppBar 上「清空自定义」TextButton 英文文案 184px + 保存 → en 下标题只剩 ~56px；标题还带动态 `{name}`（`nutritionEditTitleWithName`）。
4. **en/ar 静态文案过长**：`ingredientManageRelations` en 309px / ar 252px（预算 240）；`recipeEditBasicInfo` ar 275px。
5. 所有列表页 AppBar 有刷新按钮，而 body 已有 RefreshIndicator（纯冗余占位）。
6. 系统字体缩放最多放大标题 1.34×（预算不变），大字体用户加剧。

## 对策（本次实施）

- **删冗余刷新按钮 8 处**：原料/商品/商家/价格列表、收藏、商品/原料/商家详情（均已有下拉刷新，刷新逻辑不变）。首页的刷新按钮 tooltip 是 `homeSwapAll`（一键换菜），是功能动作，**保留**。
- **详情页标题去 chip**（3 处）：`title: Row[名称+chip]` → `title: Text(名称)`；类型信息在 body 基本信息卡已有，纯冗余。商品/原料详情保留 收藏+记价+⋮（记价是核心动作）；商家详情本就只有编辑+刷新，删刷新后仅剩编辑。
- **试算详情**：✏️编辑 / ✓设为今日 / 🗑删除 三个 IconButton 合并进一个 ⋮ PopupMenuButton（带图标与 enabled 态）；保留 🌐 计算上下文。
- **营养编辑**（`shared/screens/nutrition_edit_screen.dart`）：标题固定「编辑营养成分」；实体名移到 body 顶部（titleMedium 加粗、单行省略）；「清空自定义」移到手动编辑表单底部（错误色 TextButton.icon，危险操作区），USDA 模式不显示（与原逻辑一致）。
- **文案缩短**：`ingredientManageRelations` en→`Manage relations`、ar→`إدارة العلاقات`；`recipeEditBasicInfo` en→`Edit basic info`、ar→`تعديل المعلومات`。
- **删除无引用的 l10n key**：`nutritionEditTitleWithName`、`ingredientChip`、`productChip`、`merchantChip`（三语 arb 同步删除 + gen-l10n）。`recipeAnalysisChip` 仍在用（菜谱分析标题预算充足，不动）。

### 改后标题预算（360dp）

| 页面 | actions | 标题可用 | 容量（汉字） |
|---|---|---|---|
| 商品/原料详情 | 收藏+记价+⋮ = 3×48 | 160px | ≈7 |
| 商家详情 | 编辑 = 1×48 | 256px | ≈11 |
| 试算详情 | 🌐+⋮ = 2×48 | 208px | ≈9 |
| 菜谱详情（维持） | ♥+📊+⋮ = 3×48 | 160px | ≈7 |
| 营养编辑 | 保存按钮 | ~284px | en/ar 静态标题全过 |
| 关联原料关系 | 完成按钮 | 240px | en 172 / ar 149 全过 |
| 菜谱编辑·基本信息 | 保存按钮 | 240px | en 172 / ar 172 全过 |
| 其余列表/表单 | ≤2 icons | ≥208px | 全过 |

## 回归测试

新增 `test/app_bar_title_budget_test.dart`（38 例）：

- 按「屏 → (返回键, 图标数, 保存按钮文案)」清单（每行注明源文件）计算预算，用 TextPainter 以**宿主机真实字体**（zh 用 `C:\Windows\Fonts\simhei.ttf`、en/ar 用 `arial.ttf`）测量三语标题宽度，断言 ≤ 预算；缺字体时 skip。
- 动态实体名标题页断言最少汉字容量（详情页 ≥7、试算 ≥9 等）；菜谱分析页断言扣除 chip 后容量 ≥10 汉字。
- **维护要求**：给某页增删 AppBar actions、改长标题文案后，必须同步更新测试里的 `_specs` 表（按钮数是从源码抄的清单）。
- 测试坑：测试环境默认 Ahem 字体（所有字形 1em 等宽，英文比真实宽一倍），必须加载宿主字体测量才准；`FontLoader` 在 `package:flutter/services.dart`（不在 `dart:ui` 的可见导出里）。

## 验证

- `flutter analyze`：无新增（仅存续 1 条 product_form_screen 既有 info）。
- 新增预算测试 38 例全过。
- 受影响页面既有测试：plan_detail / price_list / quick_fill×2 / merchant_list+detail / product_list+detail / ingredient_detail / nutrition_edit 共 43 例全过。
- localized 三语测试 8 处断言更新（详情页 chip 断言改为断言 AppBar 标题显示 mock 实体名；两处改名文案同步）后全过。
- 无后端 / 迁移改动；分支 feat/mobile-app。

## 同日追加：原料/商品详情标题恢复类型标签

用户确认：原料和商品详情的标题**需要**带上类型标签（商家详情未要求，维持纯名称）。

- `ingredientChip` / `productChip` key 三语加回（zh 原料/商品、en Ingredient/Product、ar مكوّن/منتج）+ gen-l10n。
- 标题恢复为 `Row[Flexible(名称, 单行省略) + chip]`——名称必须包 Flexible，否则长名会把 chip 挤出工具栏。
- 恢复后的名称容量（预算 160px = 360 − 56 − 3×48）：zh ≈114px ≈ **5 汉字**、en ≈91px ≈ 15 字符、ar ≈106px；比治理前（4 actions 时代 66px ≈ 3 汉字）仍多 2 字。
- 预算测试同步：`_specs` 中 product/ingredient_detail 加 chip；chip 后容量断言从硬编码 220px 改为**按语言字宽折算**（汉字 22px/字、拉丁/阿拉伯 ≈11.5px/字），避免阿语 chip 偏宽造成误报。
- 如需进一步加长名称容量，下一档杠杆是把「收藏」移进 ⋮ 菜单（2 icons → 预算 208px，zh ≈7 汉字），本次未做。

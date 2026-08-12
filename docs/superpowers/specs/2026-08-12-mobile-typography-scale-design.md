# 移动端统一字号规范（Typography Scale）

- 日期：2026-08-12
- 范围：`mobile/lib/` 全量
- 目标：消除菜谱详情页及全 app 的字号不统一问题，建立唯一字号来源，并全量落地

## 背景与问题

当前 app 的主题 `app_theme.dart` **从未声明任何字号**，仅给默认 Material 3 字体加了中文回退链。全 app 的字号由两种来源混合而成：

1. M3 默认语义刻度（`textTheme.*`，约 229 处调用）
2. 散落在 11 个文件中的 23 处硬编码 `fontSize:` 魔数，用到 {9, 10, 11, 12, 13, 14, 18}，其中 9、10、13、18 在 M3 标准刻度里无对应档位

这导致三层问题：

- **基线不显式**：字号基准是隐式 M3 默认值，从未被声明，不可调、不可约束
- **同类正文语义错配**：菜谱详情页里做法步骤用 `bodyLarge`(16)、小贴士用 `bodyMedium`(14)，同为阅读型正文却差两号；`bodyLarge` 同时被当作「原料名称」和「正文」
- **脱离刻度的魔数**：图表轴标签 9sp、餐品名称 18sp、原料详情 13sp 等，与 M3 刻度对不上

## 设计决策

以下三项已确认：

1. **范围：全量落地**——规范文档 + 主题令牌 + 23 处魔数和语义错配全部对齐
2. **阅读型正文统一到 `bodyLarge`(16)**——做法步骤、小贴士、原料备注、卡片描述统一到 16sp，保证主内容可读性
3. **刻度保持纯 M3，不新增特例档**——图表轴标签（现 9sp）归入已有最小档 `labelSmall`(11)，不引入 `micro`(10) 等额外档位

## 字号刻度

沿用 Material 3 默认数值作为基准，不发明新数字。现有 229 处 `textTheme.*` 调用的数值不受影响，仅修正语义错配和魔数。

| 令牌（M3 语义） | sp | App 文本角色 |
|---|---|---|
| `displaySmall` | 36 | （保留，未使用） |
| `headlineMedium` | 28 | 成本大金额（hero 数字） |
| `headlineSmall` | 24 | 页面/详情大标题 |
| `titleLarge` | 22 | （保留） |
| `titleMedium` | 16 | 卡片分区标题（原料/做法/营养/小贴士） |
| `bodyLarge` | 16 | **阅读型正文**（步骤/小贴士/原料备注/描述） |
| `bodyMedium` | 14 | 元数据/辅助文本（用量、空状态） |
| `bodySmall` | 12 | 次要说明（原料 note、营养表注脚） |
| `labelLarge` | 14 | 按钮 |
| `labelMedium` | 12 | 紧凑标签（份数、徽章） |
| `labelSmall` | 11 | 徽章/角标/图片计数/图表轴标签/地图标注 |

最小可用档为 `labelSmall`(11)。**全 app 不存在 11 以下的字号**。

## 主题令牌（`app_theme.dart`）

在 `app_theme.dart` 中做两件事：

1. 显式声明字号常量，作为全 app 唯一字号来源：

```dart
abstract final class AppFontSizes {
  static const double display = 36;
  static const double headline = 28;
  static const double headlineSmall = 24;
  static const double title = 16;
  static const double body = 16;
  static const double bodySecondary = 14;
  static const double caption = 12;
  static const double label = 14;
  static const double labelMedium = 12;
  static const double micro = 11; // labelSmall，全 app 最小字号
}
```

2. 在 `_buildTheme` 中给 `textTheme` 逐档 `.copyWith(fontSize:)` 锁死数值，使刻度从「隐式 M3 默认」变为「显式可调、可约束」：

```dart
textTheme: base.textTheme
    .apply(fontFamilyFallback: _cjkFontFallback)
    .copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontSize: AppFontSizes.headline),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontSize: AppFontSizes.headlineSmall),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: AppFontSizes.title),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: AppFontSizes.body),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: AppFontSizes.bodySecondary),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: AppFontSizes.caption),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: AppFontSizes.label),
      labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: AppFontSizes.labelMedium),
      labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: AppFontSizes.micro),
    ),
```

`primaryTextTheme` 同样处理。`apply(fontFamilyFallback:)` 仍在，中文回退链不受影响。

锁死后即使 Flutter 升级改动 M3 默认值，app 视觉也不漂移；将来需要全局调字号（如做大字版），只改 `AppFontSizes` 一处。

## 语义错配修复

| 位置 | 当前 | 改为 | 原因 |
|---|---|---|---|
| 菜谱详情 - 小贴士正文 [:803](D:/code/live_calc/mobile/lib/features/recipes/screens/recipe_detail_screen.dart:803) | `bodyMedium`(14) | `bodyLarge`(16) | 与做法步骤统一为阅读型正文（核心修复） |
| 菜谱详情 - 步骤正文 [:559](D:/code/live_calc/mobile/lib/features/recipes/screens/recipe_detail_screen.dart:559) | `bodyLarge`(16) | 不变 | 已是目标值 |
| 菜谱详情 - 步骤内嵌 tips 子块 | `labelSmall`(11) | 不变 | 行内提示，保持与正文层级区分 |
| 菜谱详情 - 原料名称 [:414](D:/code/live_calc/mobile/lib/features/recipes/screens/recipe_detail_screen.dart:414) | `bodyLarge`(16) | 不变 | 名称本就比正文略重，合理 |

核心改动只有一处：小贴士正文从 `bodyMedium` 提到 `bodyLarge`。

## 魔数归位

23 处硬编码 `fontSize:` 全部替换为 `textTheme` 语义令牌，按当前值归位如下：

| 现值 | 数量 | 目标值 | 目标签 | 典型位置 |
|---|---|---|---|---|
| 9 | 5 | 11 | `labelSmall` | 成本趋势堆叠图轴标签、商家价签 |
| 10 | 2 | 11 | `labelSmall` | 「可选」徽章、商家成本卡 |
| 11 | 2 | 11 | `labelSmall` | 地图标注、商家成本卡（替换为令牌引用） |
| 12 | 8 | 12 | `bodySmall`/`labelMedium` | 计数角标、辅助文本 |
| 13 | 4 | 14 | `labelLarge` | 原料详情小标题、价格矩阵、菜谱计数 |
| 14 | 1 | 14 | `labelLarge` | 步骤序号圆圈（替换为令牌引用） |
| 18 | 1 | 16 | `titleMedium` | 餐品卡名称 |

替换原则：去掉 `TextStyle(fontSize: N, ...)`，改用 `theme.textTheme.<role>?.copyWith(保留 color/fontWeight 等)`。涉及文件清单见附录。

## 验证

- `flutter analyze` 无新增告警
- 逐文件确认无残留硬编码 `fontSize:`：`rg "fontSize:\s*\d+" lib/` 应仅命中主题令牌定义处（如有）或返回空
- 视觉验证：菜谱详情页做法步骤与小贴士字号一致；图表轴标签、徽章、角标在各机型上清晰可读
- 回归确认：229 处既有 `textTheme.*` 调用的视觉不变（令牌数值与 M3 默认一致）

## 非目标

- 不调整字重（fontWeight）、行高（height）、字间距（letterSpacing）——本次只统一字号
- 不改动 Web/前端（`frontend/`）——本规范仅限移动端
- 不重构非字号相关的样式

## 附录：受影响文件清单

主题：
- `mobile/lib/core/theme/app_theme.dart`

语义错配修复：
- `mobile/lib/features/recipes/screens/recipe_detail_screen.dart`

魔数替换（10 文件 23 处）：
- `mobile/lib/features/recipes/screens/recipe_detail_screen.dart`（4 处：12, 10, 14, 13）
- `mobile/lib/features/recipes/widgets/cost_trend_stacked_chart.dart`（4 处：9x4）
- `mobile/lib/features/recipes/widgets/merchant_cost_cards.dart`（4 处：10, 12, 12, 11）
- `mobile/lib/features/recipes/widgets/merchant_price_matrix.dart`（2 处：12, 13）
- `mobile/lib/shared/widgets/merchant_price_list.dart`（1 处：9）
- `mobile/lib/features/home/widgets/meal_card.dart`（2 处：12, 18）
- `mobile/lib/features/ingredients/screens/ingredient_detail_screen.dart`（2 处：13x2）
- `mobile/lib/features/merchants/widgets/merchant_map_view.dart`（1 处：11）
- `mobile/lib/features/profile/screens/my_proposals_screen.dart`（2 处：12x2）
- `mobile/lib/features/auth/screens/server_config_screen.dart`（1 处：12）

备注：`cost_trend_chart.dart` 使用参数化 `fontSize: size`（非硬编码字面量），不在魔数清单内，其调用方传入的 size 值应来自主题令牌。

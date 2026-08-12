# 移动端统一字号规范 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在移动端建立唯一字号来源（主题令牌），消除全部 23 处硬编码 fontSize 魔数，统一菜谱详情页等页面的正文/标签字号语义。

**Architecture:** 在 `app_theme.dart` 中显式声明 `AppFontSizes` 常量类并锁死 `textTheme` 逐档数值（与 M3 默认一致），使字号基线从隐式默认变为显式可调。随后将 11 个文件中的 23 处硬编码 `fontSize:` 替换为 `theme.textTheme.<role>` 语义引用，并将菜谱详情页小贴士正文从 `bodyMedium` 提升到 `bodyLarge`。

**Tech Stack:** Flutter / Dart / Material 3 / flutter_test

**Spec:** `docs/superpowers/specs/2026-08-12-mobile-typography-scale-design.md`

**测试策略：** Task 1（主题令牌）与 Task 2（菜谱详情页核心修复）采用完整 TDD（先写字号断言测试再实现）。Task 3-6 为机械替换，验证手段为 `flutter analyze` + `rg` 魔数清零扫描 + 跑全量既有测试。

**替换约定（所有 Task 通用）：**
- 去掉 `TextStyle(fontSize: N, ...)` 中的 `fontSize: N`，改用 `theme.textTheme.<role>?.copyWith(保留 color/fontWeight 等其它属性)`。
- `const TextStyle(...)` 改为 `theme.textTheme.*.copyWith(...)` 后会丢失 `const`（theme 是运行时值），这是预期行为。若调用点无 BuildContext（如地图 marker const），则改用 `AppFontSizes.<const>` 编译期常量保留 const。
- 文件顶部如未 import theme，需补 `import '../../../core/theme/app_theme.dart';`（路径按文件实际层级调整）。
- 仅改字号，不动字重、颜色、行高。

**字号映射速查表：**

| 现值 | 目标签 | 数值 |
|---|---|---|
| 9 | `labelSmall` | 11 |
| 10 | `labelSmall` | 11 |
| 11 | `labelSmall` | 11 |
| 12 | `bodySmall`（辅助说明）或 `labelMedium`（徽章/标签） | 12 |
| 13 | `labelLarge` | 14 |
| 14 | `labelLarge` | 14 |
| 18 | `titleMedium` | 16 |

---

### Task 1: 主题令牌 — AppFontSizes + 锁死 textTheme

**Files:**
- Modify: `mobile/lib/core/theme/app_theme.dart`
- Create: `mobile/test/core/theme/app_theme_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `mobile/test/core/theme/app_theme_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/theme/app_theme.dart';

void main() {
  group('AppFontSizes 刻度', () {
    test('提供全 app 唯一字号常量', () {
      expect(AppFontSizes.display, 36);
      expect(AppFontSizes.headline, 28);
      expect(AppFontSizes.headlineSmall, 24);
      expect(AppFontSizes.title, 16);
      expect(AppFontSizes.body, 16);
      expect(AppFontSizes.bodySecondary, 14);
      expect(AppFontSizes.caption, 12);
      expect(AppFontSizes.label, 14);
      expect(AppFontSizes.labelMedium, 12);
      expect(AppFontSizes.micro, 11);
    });
  });

  group('lightTheme textTheme 锁死字号', () {
    final theme = AppTheme.lightTheme;

    test('headlineMedium 锁死为 28', () {
      expect(theme.textTheme.headlineMedium!.fontSize, 28);
    });
    test('headlineSmall 锁死为 24', () {
      expect(theme.textTheme.headlineSmall!.fontSize, 24);
    });
    test('titleMedium 锁死为 16', () {
      expect(theme.textTheme.titleMedium!.fontSize, 16);
    });
    test('bodyLarge 锁死为 16', () {
      expect(theme.textTheme.bodyLarge!.fontSize, 16);
    });
    test('bodyMedium 锁死为 14', () {
      expect(theme.textTheme.bodyMedium!.fontSize, 14);
    });
    test('bodySmall 锁死为 12', () {
      expect(theme.textTheme.bodySmall!.fontSize, 12);
    });
    test('labelLarge 锁死为 14', () {
      expect(theme.textTheme.labelLarge!.fontSize, 14);
    });
    test('labelMedium 锁死为 12', () {
      expect(theme.textTheme.labelMedium!.fontSize, 12);
    });
    test('labelSmall 锁死为 11', () {
      expect(theme.textTheme.labelSmall!.fontSize, 11);
    });
  });

  group('darkTheme textTheme 同样锁死', () {
    final theme = AppTheme.darkTheme;

    test('bodyLarge / labelSmall 在暗色模式也锁死', () {
      expect(theme.textTheme.bodyLarge!.fontSize, 16);
      expect(theme.textTheme.labelSmall!.fontSize, 11);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd mobile && flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL (AppFontSizes 未定义 / fontSize 为 null)

- [ ] **Step 3: 实现 AppFontSizes + 锁死 textTheme**

在 `app_theme.dart` 中 `AppTheme` 类之前添加常量类：

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
  static const double micro = 11;
}
```

将 `_buildTheme` 末尾的 `return base.copyWith(...)` 替换为：

```dart
   return base.copyWith(
     textTheme: _withLockedFontSizes(
         base.textTheme.apply(fontFamilyFallback: _cjkFontFallback)),
     primaryTextTheme: _withLockedFontSizes(
         base.primaryTextTheme.apply(fontFamilyFallback: _cjkFontFallback)),
   );
```

在 `AppTheme` 类中添加静态辅助方法（`_buildTheme` 之后）：

```dart
  static TextTheme _withLockedFontSizes(TextTheme t) {
    return t.copyWith(
      headlineMedium:
          t.headlineMedium?.copyWith(fontSize: AppFontSizes.headline),
      headlineSmall:
          t.headlineSmall?.copyWith(fontSize: AppFontSizes.headlineSmall),
      titleMedium: t.titleMedium?.copyWith(fontSize: AppFontSizes.title),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: AppFontSizes.body),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: AppFontSizes.bodySecondary),
      bodySmall: t.bodySmall?.copyWith(fontSize: AppFontSizes.caption),
      labelLarge: t.labelLarge?.copyWith(fontSize: AppFontSizes.label),
      labelMedium: t.labelMedium?.copyWith(fontSize: AppFontSizes.labelMedium),
      labelSmall: t.labelSmall?.copyWith(fontSize: AppFontSizes.micro),
    );
  }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd mobile && flutter test test/core/theme/app_theme_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
cd mobile
git add lib/core/theme/app_theme.dart test/core/theme/app_theme_test.dart
git commit -m "feat(theme): AppFontSizes 字号令牌 + 锁死 textTheme 刻度"
```

---

### Task 2: 菜谱详情页 — 核心修复 + 4 处魔数

**Files:**
- Modify: `mobile/lib/features/recipes/screens/recipe_detail_screen.dart`
- Create: `mobile/test/features/recipes/screens/recipe_detail_typography_test.dart`

本文件含 1 处语义错配（小贴士正文 bodyMedium -> bodyLarge）+ 4 处魔数：L102(12)、L434(10)、L551(14)、L978(13)。

- [ ] **Step 1: 写失败测试**

创建 `mobile/test/features/recipes/screens/recipe_detail_typography_test.dart`，遵循 `recipe_analysis_screen_test.dart` 的 mocktail + ApiClient/Dio 模式：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/core/theme/app_theme.dart';
import 'package:com_a4ding_livecalc/features/recipes/providers/recipe_provider.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_detail_screen.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);

    when(() => mockDio.get('/recipes/1')).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'id': 1,
            'name': '番茄炒蛋',
            'servings': 2,
            'ingredients': [],
            'cooking_steps': [
              {'step': 1, 'content': '这是做法步骤正文', 'duration_minutes': 5},
            ],
            'tips': ['这是小贴士正文内容'],
          },
        ));
    when(() => mockDio.get('/recipes/1/cost'))
        .thenAnswer((_) async => throw Exception('boom'));
    when(() => mockDio.get('/recipes/1/nutrition'))
        .thenAnswer((_) async => throw Exception('boom'));
    when(() => mockDio.get('/recipes/1/cost-history-range',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => throw Exception('boom'));
  });

  testWidgets('小贴士正文与做法步骤同为 bodyLarge(16)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recipeDetailPageProvider(1).overrideWith(
            (ref) => RecipeDetailPageNotifier(
                RecipeRepository(client: mockClient), 1)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RecipeDetailScreen(id: 1),
      ),
    ));
    await tester.pumpAndSettle();

    final stepText = tester.widget<Text>(find.text('这是做法步骤正文'));
    final tipText = tester.widget<Text>(find.text('这是小贴士正文内容'));
    expect(stepText.style!.fontSize, 16);
    expect(tipText.style!.fontSize, 16,
        reason: '小贴士应与步骤同为 bodyLarge');
  });
}
```

注意：`RecipeDetailPageNotifier` 与 `RecipeRepository(client:)` 的构造签名以 `recipe_analysis_screen_test.dart` 为权威对齐。

- [ ] **Step 2: 运行测试确认失败**

Run: `cd mobile && flutter test test/features/recipes/screens/recipe_detail_typography_test.dart`
Expected: FAIL (小贴士 fontSize 为 14)

- [ ] **Step 3: 修复小贴士语义错配**

`recipe_detail_screen.dart` `_buildTipsCard` 中（L803 附近）：

```dart
// 改前
child: Text(tip, style: theme.textTheme.bodyMedium)),
// 改后
child: Text(tip, style: theme.textTheme.bodyLarge)),
```

- [ ] **Step 4: 替换 L102**（图片计数角标，12 -> labelSmall）
```dart
// 改前
style: const TextStyle(color: Colors.white, fontSize: 12),
// 改后
style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
```

- [ ] **Step 5: 替换 L434**（可选徽章，10 -> labelSmall，删 fontSize: 10）
```dart
// 改前
style: theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSecondaryContainer,
    fontSize: 10)),
// 改后
style: theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSecondaryContainer)),
```

- [ ] **Step 6: 替换 L551**（步骤序号圆圈，14 -> labelLarge）
```dart
// 改前
style: TextStyle(
    color: theme.colorScheme.onPrimary,
    fontWeight: FontWeight.bold,
    fontSize: 14))),
// 改后
style: theme.textTheme.labelLarge?.copyWith(
    color: theme.colorScheme.onPrimary,
    fontWeight: FontWeight.bold))),
```

- [ ] **Step 7: 替换 L978**（灯箱计数，13 -> labelLarge）

该行在 `_RecipeLightboxState.build` 中。确认 build 内有 `final theme = Theme.of(context);`，若无则添加。
```dart
// 改前
style: const TextStyle(color: Colors.white, fontSize: 13),
// 改后
style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
```

- [ ] **Step 8: 运行测试确认通过**

Run: `cd mobile && flutter test test/features/recipes/screens/recipe_detail_typography_test.dart`
Expected: PASS

- [ ] **Step 9: 提交**

```bash
cd mobile
git add lib/features/recipes/screens/recipe_detail_screen.dart test/features/recipes/screens/recipe_detail_typography_test.dart
git commit -m "fix(recipe-detail): 小贴士正文统一为 bodyLarge + 消除 4 处字号魔数"
```

---

### Task 3: 成本趋势堆叠图 — 4 处 9sp 魔数

**Files:**
- Modify: `mobile/lib/features/recipes/widgets/cost_trend_stacked_chart.dart`

4 处均为 `fontSize: 9`（Y/X 轴标签），全部归 `labelSmall`。`theme` 已在 build 作用域内。

- [ ] **Step 1: 替换 L395**
```dart
// 改前
style: TextStyle(fontSize: 9, color: theme.colorScheme.outline)),
// 改后
style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
```

- [ ] **Step 2: 替换 L414**
```dart
// 改前
style: TextStyle(fontSize: 9, color: theme.colorScheme.outline)),
// 改后
style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
```

- [ ] **Step 3: 替换 L506**（结构同 L395）
```dart
// 改前
style: TextStyle(fontSize: 9, color: theme.colorScheme.outline)),
// 改后
style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
```

- [ ] **Step 4: 替换 L524**（结构同 L414）
```dart
// 改前
style: TextStyle(fontSize: 9, color: theme.colorScheme.outline)),
// 改后
style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
```

- [ ] **Step 5: 验证**

Run: `cd mobile && flutter analyze lib/features/recipes/widgets/cost_trend_stacked_chart.dart`
Expected: No issues found

Run: `cd mobile && flutter test test/features/recipes/widgets/cost_trend_stacked_chart_test.dart`
Expected: All tests pass

- [ ] **Step 6: 提交**

```bash
cd mobile
git add lib/features/recipes/widgets/cost_trend_stacked_chart.dart
git commit -m "style(chart): 堆叠图轴标签 9sp 归入 labelSmall 令牌"
```

---

### Task 4: 商家成本卡片 — 4 处魔数

**Files:**
- Modify: `mobile/lib/features/recipes/widgets/merchant_cost_cards.dart`

4 处：L123(10)、L160(12)、L166(12)、L172(11)。确认 build 内有 `final theme = Theme.of(context);`。

- [ ] **Step 1: 替换 L123**（最实惠徽章，10 -> labelSmall）
```dart
// 改前
style: TextStyle(
    fontSize: 10,
    color: Colors.white,
    fontWeight: FontWeight.bold),
// 改后
style: theme.textTheme.labelSmall?.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.bold),
```
注意：去掉外层多余的 `const`（若编译器报错）。

- [ ] **Step 2: 替换 L160**（TextSpan 本店，12 -> bodySmall）
```dart
// 改前
style: const TextStyle(
    fontSize: 12,
    color: Color(0xFF2E7D32),
    fontWeight: FontWeight.w600),
// 改后
style: theme.textTheme.bodySmall?.copyWith(
    color: const Color(0xFF2E7D32),
    fontWeight: FontWeight.w600),
```

- [ ] **Step 3: 替换 L166**（TextSpan 外部，12 -> bodySmall）
```dart
// 改前
style: const TextStyle(fontSize: 12, color: Color(0xFFEF6C00)),
// 改后
style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFEF6C00)),
```

- [ ] **Step 4: 替换 L172**（需外购提示，11 -> labelSmall）
```dart
// 改前
style: const TextStyle(fontSize: 11, color: Color(0xFFF9A825)),
// 改后
style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFFF9A825)),
```

- [ ] **Step 5: 验证**

Run: `cd mobile && flutter analyze lib/features/recipes/widgets/merchant_cost_cards.dart`
Expected: No issues found

Run: `cd mobile && flutter test test/features/recipes/widgets/merchant_cost_cards_test.dart`
Expected: All tests pass

- [ ] **Step 6: 提交**

```bash
cd mobile
git add lib/features/recipes/widgets/merchant_cost_cards.dart
git commit -m "style(merchant-cards): 消除 4 处字号魔数，归入语义令牌"
```

---

### Task 5: 商家价格矩阵 + 价签列表 — 3 处魔数

**Files:**
- Modify: `mobile/lib/features/recipes/widgets/merchant_price_matrix.dart`
- Modify: `mobile/lib/shared/widgets/merchant_price_list.dart`

`merchant_price_matrix.dart` 2 处：L257(12)、L340(13)。
`merchant_price_list.dart` 1 处：L132(9)。

- [ ] **Step 1: 替换 merchant_price_matrix.dart L257**（用量 badge，12 -> bodySmall）
```dart
// 改前
style: TextStyle(
    fontSize: 12,
    color: theme.colorScheme.outline)),
// 改后
style: theme.textTheme.bodySmall
    ?.copyWith(color: theme.colorScheme.outline)),
```

- [ ] **Step 2: 替换 merchant_price_matrix.dart L340**（价格单元格，13 -> labelLarge）
```dart
// 改前
style: TextStyle(
  fontSize: 13,
  color: !row.cells[n]!.hasPrice
      ? theme.colorScheme.outlineVariant
      : row.cells[n]!.isLowest
          ? const Color(0xFFE65100)
          : null,
  fontWeight: row.cells[n]!.isLowest
      ? FontWeight.bold
      : null,
),
// 改后
style: theme.textTheme.labelLarge?.copyWith(
  color: !row.cells[n]!.hasPrice
      ? theme.colorScheme.outlineVariant
      : row.cells[n]!.isLowest
          ? const Color(0xFFE65100)
          : null,
  fontWeight: row.cells[n]!.isLowest
      ? FontWeight.bold
      : null,
),
```

- [ ] **Step 3: 替换 merchant_price_list.dart L132**（最低角标，9 -> labelSmall，删 fontSize: 9）
```dart
// 改前
style: theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onPrimary, fontSize: 9)),
// 改后
style: theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onPrimary)),
```

- [ ] **Step 4: 验证**

Run: `cd mobile && flutter analyze lib/features/recipes/widgets/merchant_price_matrix.dart lib/shared/widgets/merchant_price_list.dart`
Expected: No issues found

Run: `cd mobile && flutter test test/features/recipes/widgets/merchant_price_matrix_test.dart`
Expected: All tests pass

- [ ] **Step 5: 提交**

```bash
cd mobile
git add lib/features/recipes/widgets/merchant_price_matrix.dart lib/shared/widgets/merchant_price_list.dart
git commit -m "style(prices): 价格矩阵与价签列表消除 3 处字号魔数"
```

---

### Task 6: 其余页面 — 8 处魔数

**Files:**
- Modify: `mobile/lib/features/home/widgets/meal_card.dart`（L201:12, L208:18）
- Modify: `mobile/lib/features/ingredients/screens/ingredient_detail_screen.dart`（L1002:13, L1453:13）
- Modify: `mobile/lib/features/merchants/widgets/merchant_map_view.dart`（L546:11）
- Modify: `mobile/lib/features/profile/screens/my_proposals_screen.dart`（L104:12, L235:12）
- Modify: `mobile/lib/features/auth/screens/server_config_screen.dart`（L123:12）

- [ ] **Step 1: meal_card.dart L201**（餐次标签，12 -> bodySmall）

确认 build 内有 `theme`。
```dart
// 改前
style: const TextStyle(color: Colors.white70, fontSize: 12),
// 改后
style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
```

- [ ] **Step 2: meal_card.dart L208**（餐品名称，18 -> titleMedium）
```dart
// 改前
style: const TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.w600,
// 改后
style: theme.textTheme.titleMedium?.copyWith(
  color: Colors.white,
  fontWeight: FontWeight.w600,
```
注意保留原 TextStyle 的闭合括号结构。

- [ ] **Step 3: ingredient_detail_screen.dart L1002**（头像首字，13 -> labelLarge）

确认该方法/build 内 `theme` 可用；若无则加 `final theme = Theme.of(context);`。
```dart
// 改前
style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
// 改后
style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
```

- [ ] **Step 4: ingredient_detail_screen.dart L1453**（同上结构，13 -> labelLarge）
```dart
// 改前
style: const TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600),
// 改后
style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
```

- [ ] **Step 5: merchant_map_view.dart L546**（地图标注，11 -> labelSmall，用编译期常量保留 const）

此处是 `const TextStyle`（地图 marker）。保留 `const`，将字面量 `11` 替换为 `AppFontSizes.micro`：
```dart
// 改前
style: const TextStyle(
  color: Colors.white,
  fontSize: 11,
  fontWeight: FontWeight.w500,
),
// 改后
style: const TextStyle(
  color: Colors.white,
  fontSize: AppFontSizes.micro,
  fontWeight: FontWeight.w500,
),
```
文件顶部补 import：`import '../../../core/theme/app_theme.dart';`

- [ ] **Step 6: my_proposals_screen.dart L104**（状态标签，12 -> labelMedium）

确认 build 内有 `theme`。
```dart
// 改前
style: TextStyle(
    color: _statusColor(p.status),
    fontSize: 12,
    fontWeight: FontWeight.bold),
// 改后
style: theme.textTheme.labelMedium?.copyWith(
    color: _statusColor(p.status),
    fontWeight: FontWeight.bold),
```

- [ ] **Step 7: my_proposals_screen.dart L235**（同上结构，12 -> labelMedium）
```dart
// 改前
style: TextStyle(
    color: _statusColor(p.status),
    fontSize: 12,
    fontWeight: FontWeight.bold),
// 改后
style: theme.textTheme.labelMedium?.copyWith(
    color: _statusColor(p.status),
    fontWeight: FontWeight.bold),
```

- [ ] **Step 8: server_config_screen.dart L123**（错误提示，12 -> bodySmall）
```dart
// 改前
style: TextStyle(
    color: theme.colorScheme.error, fontSize: 12))
// 改后
style: theme.textTheme.bodySmall
    ?.copyWith(color: theme.colorScheme.error))
```

- [ ] **Step 9: 验证全部**

Run: `cd mobile && flutter analyze lib/`
Expected: No issues found

Run: `cd mobile && flutter test`
Expected: All tests pass

- [ ] **Step 10: 提交**

```bash
cd mobile
git add lib/features/home/widgets/meal_card.dart lib/features/ingredients/screens/ingredient_detail_screen.dart lib/features/merchants/widgets/merchant_map_view.dart lib/features/profile/screens/my_proposals_screen.dart lib/features/auth/screens/server_config_screen.dart
git commit -m "style(app): 其余页面消除 8 处字号魔数，统一语义令牌"
```

---

### Task 7: 全量验证 — 魔数清零 + 回归

**Files:** 无（仅验证）

- [ ] **Step 1: 魔数清零扫描**

Run: `rg "fontSize:\s*\d+" lib/`（在 mobile 目录下执行）
Expected: 返回空（0 匹配）。例外：引用 `AppFontSizes.micro` 等常量的行不含字面量数字，不会被命中，符合预期。

- [ ] **Step 2: 全量 analyze**

Run: `cd mobile && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 全量测试**

Run: `cd mobile && flutter test`
Expected: All tests pass

- [ ] **Step 4: 提交（如有遗漏修复）**

若 Step 1-3 发现遗漏，修复后提交；若全部通过无需额外提交，本 Task 仅作验证记录。

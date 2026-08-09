# 移动端菜谱列表不足一行时整网格居中修复

## 现象

菜谱列表页（移动端 App）当列表项少于页面每行能容纳的最大列数时（如筛出 1~2 个菜谱），整个网格**居中**显示而非靠左。Web 端 Vuetify 栅格最后一行靠左，移动端与之不一致。

## 根因（系统性调试）

**不是 Wrap 的对齐问题，是外层 SingleChildScrollView 的 shrink-wrap 收缩。**

证据链（Flutter 测试用 `tester.getRect` 逐层打点，800px 宽单卡片）：

| 层级 | 修复前 | 修复后 |
|---|---|---|
| SingleChildScrollView | (197..603) 只占 406px，**被居中** | (0..800) 撑满 |
| Column | (209..591) 收缩到卡片宽 | (12..788) |
| 卡片 dx | **209**（屏幕中央 400 附近） | **12**（= 页面 padding，靠左） |

链条：

1. `RefreshIndicator → LayoutBuilder` 给 `SingleChildScrollView` 的约束是 **loose**（0..360），SCSV 在水平方向默认 shrink-wrap
2. 菜谱不够一行时，Column 收缩到内容宽度，SCSV 跟着收缩（174px）
3. 上层 `RefreshIndicator` 把收缩后的 SCSV **居中**摆放在 body 内 → 单卡片显示在屏幕正中
4. 2+ 卡片时内容 ≥ 可用宽度，SCSV 被迫撑满 → 看不出问题

**旧测试假绿原因**：`单个结果靠左而不是居中` 断言 `dx < centerX - 100`（800px 下 < 300），居中时 dx=209 也通过。

## 修复

[recipe_list_screen.dart](mobile/lib/features/recipes/screens/recipe_list_screen.dart) `_buildContent` 里 SCSV 外包一层：

```dart
return SizedBox(
  // 撑满横向可用宽度：否则内容不满一行时 SCSV 收缩到内容宽度，
  // 被上层居中显示（列表项不足一行时整个网格居中）
  width: double.infinity,
  child: SingleChildScrollView(...),
);
```

一行改动，`WrapAlignment.start` 本来就正确，无需动。

## TDD

- 失败测试（修复前）：单卡片 dx = 209/532/807（360/800/1400/1920px 全复现，越宽越明显）
- 断言改为**精确**：卡片左缘 dx == 12（= padding），替代宽松的 `dx < centerX - 100`
- 新增用例：第二行不满时新行卡片仍靠左（2 列 3 个）、超宽屏 6 列单卡片靠左
- [recipe_list_layout_test.dart](mobile/test/recipe_list_layout_test.dart) 6/6 全绿

## 经验

- **SCSV 是 shrink-wrap 的**：内容不满可用宽度时收缩到内容宽度，外层若给宽松约束会被居中——滚动容器横向要撑满时，包 `SizedBox(width: double.infinity)` 或给 tight 约束
- 布局断言不要用「远离中心」这类宽松阈值，直接断言**精确期望值**（dx == padding），否则居中 bug 会假绿
- `tester.getRect(finder)` 逐层打点（SCSV→Column→Wrap→Card）是定位「哪一层居中」的高效手段
- 本次改动文件 2 个（screen + test），`flutter analyze` 5 个 issue 均为预先存在（avoid_print、constant_identifier_names、recipe_provider_test const 提示），0 新增

## 附带发现（已修复）：3 个测试断言过时

同批发现的 3 个预先失败测试，根因 = **7338ff6「统一价格/数量/单位展示格式」改了实现没同步测试**：

- 7338ff6（2026-08-09 14:17）把移动端数字单位从无空格 `100g` 改为带空格 `100 g`，**对齐 Web 端**（[MerchantPriceMatrix.vue:130-137](frontend/src/components/recipes/MerchantPriceMatrix.vue#L130-L137)、[RecipeAnalysisView.vue:189-199](frontend/src/views/recipes/RecipeAnalysisView.vue#L189-L199) 均是 `` `${qty}${unit ? ` ${unit}` : ''}` `` 带空格）
- 实现是对的（符合「各端体验一致性」），**测试期望没跟上**，且测试注释还写着过时的「web qty-badge 100g」
- 修复：更新 3 处断言对齐新格式——[merchant_price_matrix_test.dart](mobile/test/features/recipes/widgets/merchant_price_matrix_test.dart) `'100-200g'`→`'100-200 g'`、`find.text('100g')`→`find.text('100 g')`（注释一并修正）、[nutrition_source_grid_test.dart](mobile/test/features/recipes/widgets/nutrition_source_grid_test.dart) `'6g'`→`'6 g'`
- 全量 98/98 全绿，analyze 5 个预存 issue 不变

**经验**：统一展示格式的提交必须同步搜索测试断言里的旧格式（`rg "100g|6g|'...g'"` 测试目录），注释里的「web 行为」引用也要核对真实代码，测试注释可能记录的是当时（错的）假设。

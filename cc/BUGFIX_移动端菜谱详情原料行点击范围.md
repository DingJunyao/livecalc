# 移动端菜谱详情原料行点击范围修复

## 现象

菜谱详情页原料列表，有特殊计算方式（fallbackChain）的原料在价格前有 info tooltip 图标。桌面鼠标悬停有提示，但实机上点击价格/用量/图标任意位置都会跳转原料详情，用户看不到提示。

## 修复（对齐 Web [RecipeIngredientCard.vue:91-136](frontend/src/components/recipes/RecipeIngredientCard.vue#L91-L136)）

[recipe_detail_screen.dart](mobile/lib/features/recipes/screens/recipe_detail_screen.dart) `_buildIngredientRow`：

1. **跳转仅限名称列**：用量列、价格列原包 `InkWell(onTap: onTap)` 三列全可跳转 → 用量列、价格列改裸 `Padding`（移除 onTap）。Tooltip 保留（移动端默认 triggerMode=longPress，长按图标看提示，不再被 tap 跳转抢走）
2. **chevron 位置**：`Icons.chevron_right` 从名称**前**移到名称**后**（对齐 Web `mdi-chevron-right` 在名称文本后面）

## 验证

- analyze 0 issue + recipes 目录测试 68/68 全绿

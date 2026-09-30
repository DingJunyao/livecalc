# 移动端原料详情相关菜谱用量显示 0 修复

## 现象

原料详情页「相关菜谱」列表，菜谱用量显示为 0（如「0 g」）。绝大多数带区间的菜谱都中招；模糊量（适量/少许）菜谱也受影响。

## 根因（系统性调试）

[ingredient_recipe.dart](mobile/lib/shared/models/ingredient_recipe.dart) 的 `RecipeUsage` 模型有两个缺陷：

1. **没解析 `quantity_range`**：后端 `/nutrition/ingredients/{id}/recipes` 每个 usage 返回 `{quantity, quantity_range, unit, original_quantity}`（[nutrition.py:857-862](backend/app/api/nutrition.py#L857-L862)），但 `RecipeUsage.fromJson` 只解析了 quantity/unit/original_quantity，**漏了 quantity_range**。带区间菜谱 quantity 为 null → 0 → display 显示「0」
2. **`originalQuantity` 类型错误**：后端 `original_quantity` 是字符串（「适量」「少许」「100克」），移动端却用 `_toDouble` 解析成 `double?` → 「适量」解析失败成 null → 同样 fallback 到 0。模糊量菜谱也显示 0

## 修复（对齐 Web [IngredientDetail.vue formatUsageText:3387-3402](frontend/src/views/ingredients/IngredientDetail.vue#L3387-L3402)）

1. [ingredient_recipe.dart](mobile/lib/shared/models/ingredient_recipe.dart)：
   - 加 `quantityRange` 字段（复用 recipe_detail.dart 的 `QuantityRange`）
   - `originalQuantity` 改 `String?`，原样保留字符串
   - `display` getter 按 Web 规则：
     - 精确+区间 → `100~200 g（推荐 150 g）`
     - 仅精确 → `150 g`
     - 仅区间 → `100~200 g`
     - 模糊量 → 原样
     - 无 → `-`
   - 精确值判断用 `quantity > 0`（对齐 Web truthy：0 不算精确值）
2. [ingredient_detail_screen.dart](mobile/lib/features/ingredients/screens/ingredient_detail_screen.dart) `_RelatedRecipesCard` 加 `_usageText` helper，对齐 Web formatUsages：数值类（精确或区间）加「/ N 份」（servings 兜底 1），多条用分号「；」合并（原来用「、」无份数）

## TDD

- 新增 [ingredient_recipe_test.dart](mobile/test/shared/models/ingredient_recipe_test.dart) 9 个用例：display 六场景（区间+推荐/仅区间/仅精确/模糊量/空/无单位）+ fromJson 三场景（quantity_range Map 解析、quantity=0 不显示 0、original_quantity 字符串保留）
- 全量 107/107 全绿 + analyze 5 个预存 issue 0 新增 + build windows 通过（34.9s）

## 经验

- 模型解析漏字段的经典症状：**显示为默认值（0）**而不是缺失——quantity null → 0，无法区分「没填」和「真的是 0」。解析时字段类型必须与后端契约一致（字符串就是 String?，别强转 double 丢「适量」）
- 对齐 Web 端逻辑时，注意 Web 的 **truthy 判断**（`u.quantity ? ... : ...` 中 0 是 falsy）→ 移动端对应 `quantity > 0`
- 区间分隔符：相关菜谱用「~」（Web formatUsageText），比价矩阵用「-」（_qtyText）——两处规则不同，别互相套用

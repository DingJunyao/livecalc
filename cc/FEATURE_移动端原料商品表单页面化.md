# FEATURE_移动端原料商品表单页面化

> 日期：2026-08-16
> 分支：feat/mobile-app（仅移动端）
> 背景：用户反馈移动端原料/商品表单的别名输入、分类加载、新增商品报错，以及对话框不适合作为复杂表单载体。

## 需求

1. 别名不能把逗号、空格当作分隔符，交互应与网页端标签输入一致。
2. 原料表单的分类下拉必须能加载分类数据。
3. 新增商品必须是可打开的独立页面，避开原对话框路径触发的指针/`MouseTracker` 断言。
4. 原料/商品新增与编辑改成独立页面，保存后返回来源页并刷新对应数据。

## 实现

### 标签输入

- 新增 [alias_tags_field.dart](mobile/lib/shared/widgets/alias_tags_field.dart)。
- 输入后点击 `+` 生成一个完整标签（键盘完成/回车同样会提交）；逗号、空格保留在标签原文内。
- Helper 文案为「输入后点击 + 添加」，避免在 Android/iOS 上使用桌面键盘专属说法。
- 标签用 `Chip` 展示，点关闭图标删除；重复标签不追加。
- 原料别名、商品别名、商品编辑标签均复用该控件。

### 原料表单

- 新增 [ingredient_form_screen.dart](mobile/lib/features/ingredients/screens/ingredient_form_screen.dart)。
- 路由：`/ingredients/new`、`/ingredients/:id/edit`。
- 页面内部 `watch(ingredientCategoriesProvider)`，从路由直接进入也会触发分类加载；加载中禁用下拉，失败显示错误。
- 编辑页优先使用路由 `extra` 中的原料，缺失时按 id 拉取详情。
- 保存成功 `pop(true)`，来源页按需刷新。
- [ingredient_repository.dart](mobile/lib/features/ingredients/repositories/ingredient_repository.dart) 更新时始终提交 `category_id`，表单选择“未分类”时提交 `null`。

### 商品表单

- 新增 [product_form_screen.dart](mobile/lib/features/products/screens/product_form_screen.dart)。
- 路由：`/products/new`、`/products/:id/edit`；`new` 放在 `:id` 前避免误匹配。
- 商品列表新增商品时支持搜索并选择关联原料；原料详情新增商品时固定当前原料。
- 编辑页拉取商品详情，回填名称、品牌、条码、关联原料、别名和标签。
- 保存成功 `pop(true)`；商品列表刷新列表，商品详情刷新详情，原料详情刷新关联商品。

### 入口替换

- 原料列表 FAB、原料详情基本信息编辑、原料详情关联商品新增/编辑、商品列表 FAB、商品详情编辑全部改为路由页面。
- 删除旧的原料新增对话框、原料详情商品表单对话框、商品列表新增对话框、商品详情编辑对话框及死代码。

## 测试

- 新增 [alias_tags_field_test.dart](mobile/test/shared/widgets/alias_tags_field_test.dart)：跨平台 helper 文案、分隔符保留、重复去重、预填删除。
- 新增 [ingredient_form_screen_test.dart](mobile/test/features/ingredients/screens/ingredient_form_screen_test.dart)：分类异步加载、标签别名、保存返回。
- 新增 [product_form_screen_test.dart](mobile/test/features/products/screens/product_form_screen_test.dart)：新增独立页面、编辑回填、别名保留空格、标签保存。
- 新增 [ingredient_repository_test.dart](mobile/test/features/ingredients/repositories/ingredient_repository_test.dart)：清空分类时请求体包含 `category_id: null`（先红后绿）。
- 扩展 [app_router_test.dart](mobile/test/core/router/app_router_test.dart)：新增商品入口是独立路由页面且无 `AlertDialog`。

## 验证

- `flutter test`：全量通过。
- `flutter analyze`：新增代码无提示，仅剩 3 条既有 info（`api_client.dart` 的 `avoid_print`、颜色常量命名、既有测试 `unnecessary_const`）。
- `git diff --check`：通过。
- 用户日志中的 `MouseTracker._deviceUpdatePhase` 断言未在本地稳定复现；本次移除了新增/编辑商品的对话框交互面，入口改为普通路由页面后不再经过该 Overlay/对话框路径。

## 边界说明

- 后端当前 `PUT /ingredients/{id}` 对 `category_id is None` 的处理与“字段未提交”不可区分，因此显式 `null` 清空分类还需要后端在 master 分支补齐语义；本分支只修正移动端请求体，不越分支改后端。
- 层级关系、商家等其他对话框不属于本次原料/商品表单范围，保持原状。

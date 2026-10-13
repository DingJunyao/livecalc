# 移动端搜索下拉 IME 防抖与请求序号

## 现象

移动端新增商品时，在“搜索并选择关联原料”输入完整词“牛奶”，等待转圈结束后下拉为空；删掉“奶”只保留“牛”后，下拉又能显示“牛奶”。用户要求同时排查其他下拉及 web 端是否存在同类问题。

## 数据流与根因

- 页面：`mobile/lib/features/products/screens/product_form_screen.dart` 的 `Autocomplete<Ingredient>`。
- 请求：`IngredientRepository.search(q)` -> `GET /ingredients`。
- 后端：`backend/app/api/ingredient_extended.py` 按原料名、原料别名、商品名、商品别名匹配，`/ingredients?q=牛奶` 实测返回“牛奶”“全脂牛奶”，查询、序列化和下拉渲染本身正常。
- 根因在客户端请求时序：`Autocomplete.optionsBuilder` 对中文 IME 的每个组合态文本都会立即发请求（`n/ni/niu/...` 与最终中文各一次）。`caab0c95` 移除防抖后，请求风暴放大了网络与认证抖动；快速变化期间最新请求失败或被旧响应干扰时，界面表现为空下拉。
- `ProductFormScreen` 旧实现已有请求序号，但缺少防抖；黑名单原料、价格新增商品、粘贴导入商品/原料、原料合并、菜谱原料等下拉也存在不同程度的“无防抖”“无序号”或两者都缺。

## 修复

- 商品关联原料：300ms 防抖 + `Completer` 归并 + 请求序号 last-wins + `dispose` 取消，新增 IME 组合态回归测试，断言中间拼音不逐键请求服务端。
- 黑名单原料：新增防抖、Completer 与序号，`dispose` 取消。
- 价格新增商品：新增 300ms 防抖，序号保留 last-wins，清空文本立即失效在途结果。
- 粘贴导入：商品与原料两路均新增每行 Timer 防抖，保留序号守卫，释放编辑器与页面销毁时取消 Timer/Controller。
- 原料合并对话框：新增 300ms 防抖、序号与关闭对话框后的取消逻辑。
- 菜谱原料搜索：保留原有 300ms 防抖，补请求序号，丢弃过期响应。
- 顺带修复移动端编译阻塞：`ReorderableListView.builder` 使用不存在的 `onReorderItem` 参数，改为 `onReorder`；并按 Flutter 回调契约在向右移动时先 `newIndex--`。

## Web 端复核

新增商品、商品详情、菜谱原料、黑名单、管理端黑名单、粘贴导入等路径已有 300ms debounce + sequence + Vuetify `custom-filter` 保护（见 `34c1fa30`），未发现与本次相同的“完整词为空、短词有结果”问题。

## 验证

- `flutter analyze`：0 issue。
- 相关测试：`product_form_autocomplete_repro_test`、`formal_search_repro_test`、`price_record_form_screen_test`、`paste_import_screen_test`、`recipe_form_screen_test`、`ingredient_detail_screen_test` 通过。
- 全量 `flutter test`：566 项，6 项失败为存量（apple_map×3、locale_preferences×2、my_proposals×1）。
- `npm run build`：通过。

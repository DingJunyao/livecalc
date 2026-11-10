# FEATURE: 新增原料名称带入 / 表单页隐藏底栏 / 商家下拉收起 / 营养默认单位 mg

四项体验修复（用户报告）：

1. 新增商品开启「新增对应原料」时，关联原料里已输入但**未匹配到已有原料**的文字，自动带入「新原料名称」；已匹配到已有原料时不复制。
2. 新增/编辑原料、商品、菜谱、商家、方案等表单页隐藏底栏（宽屏隐藏侧栏）tab，避免误触切走丢失未保存内容（返回键仍有 FormExitGuard 二次确认）。
3. 移动端新增价格记录：选中商家后释放输入框焦点，扫码/选日期等操作回来后商家下拉不再重新弹出常驻。
4. 填写营养信息时，除能量、蛋白质、脂肪、饱和脂肪、反式脂肪、碳水化合物、糖、膳食纤维外的营养素，默认单位统一为 mg。

## 1. 新增对应原料自动带入名称

- Web `frontend/src/views/data/ProductsView.vue`：`watch(createNewIngredient)` 开启时先读取 `ingredientSearch`；
  `selectedIngredient` 为空（未匹配到已有原料）且新原料名称仍为空 → 写入 `newIngredient.name`，
  随后再清空 `selectedIngredient`（原有防挂旧原料逻辑不变）。
- 移动端 `mobile/lib/features/products/screens/product_form_screen.dart#_setCreateNewIngredient`：
  切换前记录 `_ingredientSearchController` 文本与 `_selectedIngredient`；仅当未匹配原料、文本非空、
  新原料名称仍为空时写入 `_newIngredientNameController`，再清空搜索框与已选原料。
- 已匹配场景（用户点选下拉项）继续走原有逻辑：不复制已有原料名，关掉开关还能恢复原选择。

## 2. 表单页隐藏 tab 栏

`mobile/lib/core/router/app_router.dart` 新增 `_isFullScreenFormRoute(location)`：

- 精确路径：`/ingredients/new`、`/products/new`、`/recipes/new`、`/merchants/new`、`/plans/edit`；
- 编辑态：`^/(ingredients|products|recipes|merchants|plans)/\d+/edit(/.*)?$`（含菜谱分节编辑）。

`ScaffoldWithNavBar` 命中时 `bottomNavigationBar = null`，宽屏下也不渲染 `NavigationRail`；
返回列表页后底栏自动恢复。没有新增 i18n 文案。

## 3. 商家下拉选中后释放焦点

`Autocomplete` 选中只收起选项面板，输入框仍保留焦点；随后点扫码（`IconButton` 不抢焦点）、
选日期等操作，模态路由关闭后焦点回到输入框，`RawAutocomplete` 随焦点恢复重新弹出选项 →
表现为「商家下拉一直显示」。

修复：以下三处 `onSelected` / 选商家回调在更新状态后调用
`FocusManager.instance.primaryFocus?.unfocus()`：

- `mobile/lib/features/prices/screens/price_record_form_screen.dart`
- `mobile/lib/shared/screens/price_record_edit_screen.dart`
- `mobile/lib/features/prices/screens/quick_fill_screen.dart#_selectMerchant`

## 4. 营养默认单位

规则：能量跟随用户能量单位偏好（kcal | kJ）；蛋白质、脂肪、饱和脂肪、反式脂肪、碳水化合物、
糖、膳食纤维默认 g；其余营养素（钠/钾/钙/铁/锌/磷/镁/铜/锰/硒/各类维生素/叶酸/烟酸/胆固醇/
单不饱和脂肪/多不饱和脂肪等）默认 mg。

- Web `frontend/src/composables/nutrientDefinitions.ts`：
  - `BASE_DEFS` 各单位候选把 mg 排到最前，维生素 D 补 mg；
  - 删除逐项 `DEFAULT_UNIT_BY_KEY`，改为 `defaultUnitForNutrientKey()`：能量随偏好、
    宏量营养素（含常见英文别名）g、其余 mg；
  - `ProductDetail.vue` / `IngredientDetail.vue` 的动态定义（USDA 扩展键）复用该函数，
    单位候选同样 mg 优先；
  - 行内营养素下拉：空行首次选择时套用 `def.defaultUnit`（已有行换营养素且旧单位仍可用则保留，
    避免静默改变已填数值的量纲）。
- 移动端 `mobile/lib/shared/utils/nutrition_basis.dart#defaultNutrientUnit`：
  兜底由 `g` 改为 `mg`，并把反式脂肪、膳食纤维补进 g 例外表；
  `nutrition_edit_screen.dart` 的 `_nutrientOptions` 单位候选 mg 优先/补 mg，
  新行选择营养素时套用默认单位（能量仍读用户偏好 `_energyUnit`）。

## 验证

- Web：`npm run build` ✓；`npm run test:utils` 73 ✓。
- 移动端：`flutter analyze` 0 issue。
- 新增/更新测试：
  - `product_form_new_ingredient_test.dart`：未匹配文字自动带入、已匹配不复制 2 例；
  - `scaffold_with_nav_bar_test.dart`：表单页隐藏底栏 / 宽屏隐藏侧栏 2 例；
  - `price_record_form_screen_test.dart`：选中商家后焦点释放 1 例；
  - `nutrition_basis_test.dart`：8 项例外 + 其余 mg 全覆盖 1 例；
  - `nutrition_edit_screen_test.dart`：新行选「钾」默认单位 mg 1 例。
- 相关子集 61 例全过；全量 774 通过 / 14 失败均为存量（stash 对照确认：
  `price_record_form_sheet_test` 6、apple_map 3、locale 2、my_proposals 1、
  home_summary 1、app_bar_title_budget 缺字体 1）。

分支：Web 部分 master；移动端 feat/mobile-app（master 改动再合入 feat）。

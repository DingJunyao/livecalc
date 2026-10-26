# FEATURE：新增商品页「新增对应原料」

> 2026-10-26。用户要求：新增商品时原来只有「新建同名原料」一个选项，但实际经常遇到
> 「商品名 ≠ 想要的原料名」（例如新增「某牌子松茸鲜」商品，而原料库里还没有「松茸鲜」），
> 只能退出 → 新建原料 → 再回来新建商品。希望把复选框改为「新增对应原料」：
> 选中后直接在该页填写原料的名称、分类等信息；名称留空 / 与商品同名时仍按商品名创建，
> 名称不同时按填写的名称创建对应原料，商品挂到它下面。Web 与移动端都要支持。

## 1. 行为口径

| 场景 | 结果 |
| --- | --- |
| 不勾选「新增对应原料」 | 从下拉里选已有原料（原行为，商品挂到所选原料） |
| 勾选，原料名称为空 | 以**商品名称**创建原料；分类/别名按填写内容写入（可留空） |
| 勾选，原料名称与商品名称相同（trim 后比较） | 同上，以商品名称创建原料 |
| 勾选，原料名称非空且与商品名称不同 | 以**填写的名称**创建原料（带分类/别名），商品挂到该原料下；**不再额外创建商品同名原料** |
| 勾选的原料名已存在 | 后端 `reuse_existing=true` 直接复用该原料（分类/别名不覆盖），商品挂到它下面 |
| 商品的自定义单位 / 营养信息草稿 | 始终写**商品层级**，与原料无关 |

补充：
- 开启开关后会隐藏「关联原料」下拉，并清空已选原料，避免商品仍挂到旧原料。
- 创建原料后会按同名规则调和草稿单位里对旧原料自定义单位的引用（与手动换原料同口径）。

## 2. 后端（master）

`POST /api/v1/ingredients`（`backend/app/api/ingredient_extended.py`，前端实际调用的路由；
`nutrition.py` 里的是 `/api/v1/nutrition/ingredients` 旧版，未改）新增两个可选 body 字段：

- `reuse_existing`（默认 `false`）：同名激活原料已存在时不报 400，直接返回 `{id, name,
  category_id, aliases, created_at, reused: true}`；分类/别名不覆盖已有记录。
- `create_same_name_product`（默认 `true`）：原料创建成功后是否自动创建同名商品。原料页
  新增原料仍保持原行为；**商品表单传 `false`**，因为商品紧接着由 `POST /products/entity`
  自己创建，否则会多出一个同名重复商品（同名场景尤其明显）。
- 另外：名称先 `strip()` 再判重/落库；`category_id` 传入时校验分类存在，否则 400；
  正常创建响应也带 `reused: false`，便于客户端识别。
- 无表结构变更，无迁移 / SQL 脚本。

测试：`backend/tests/test_ingredient_create_attrs.py` 4 例
（名称/分类/别名落库 + 默认仍自动建同名商品、`create_same_name_product=false` 不建商品、
`reuse_existing` 复用且默认仍 400、未知分类 400）。

## 3. Web（master）

`frontend/src/views/data/ProductsView.vue`（「添加商品」对话框）：

- 开关文案改为「新增对应原料」，提示改为「开启后可在下方填写原料名称、分类与别名；名称留空则与商品同名」。
- 新增 `newIngredient` 状态（名称 / 分类 / 别名），开启时用 `v-expand-transition` 展开三个输入项：
  名称（label 复用 `ingredients.ingredientName`，placeholder 显示当前商品名，hint
  「留空则使用商品名称」）、分类（复用已加载的 `categoryOptions`）、别名（v-combobox）。
- `saveItem()`：
  1. 解析 `ingredientName = newIngredient.name.trim() || productName`；
  2. `POST /ingredients`，带 `reuse_existing: true`、`create_same_name_product: false`、
     可选的 `category_id` / `aliases`；
  3. 拿到原料 id 写入 `form.ingredient_id`，按旧原料 id 调和草稿单位，再照常
     `POST /products/entity` 创建商品、落库商品层级草稿；
  4. 保存成功后重置 `newIngredient`。
- 开关从关 → 开时清空 `selectedIngredient`（同时 `form.ingredient_id=null`），避免旧选中原料
  让商品挂错；保存时不再依赖「未选原料」来触发创建。
- i18n：`products.newSameIngredient` / `newSameIngredientHint` / `selectIngredientOrCreate`
  三语改文案，新增 `products.newIngredientNameHint`；`IngredientDetail.vue` 里过时注释同步清理。

## 4. 移动端（feat/mobile-app）

`mobile/lib/features/products/screens/product_form_screen.dart`（新增商品整页表单）：

- 开关只在**新增态**显示（编辑态换绑原料走关联原料搜索下拉，开关没有意义）；开启时记住并清空
  `_selectedIngredient`、清空搜索框并取消 pending 搜索，隐藏关联原料下拉；关闭时恢复开启前的
  关联原料（固定原料进入新增页时尤其需要，否则界面显示固定原料但保存被判为未选）。
- 新增独立状态 `_newIngredientNameController` / `_newIngredientCategoryId` /
  `_newIngredientAliases`（不复用商品自身的 brand/aliases）；开启后展示：
  - 原料名称（label `ingredientName`，hint「留空则使用商品名称」）；
  - 分类 `DropdownButtonFormField`（`ingredientCategoriesProvider`，含「未分类」/加载/失败三态，
    与原料表单一致）；
  - 别名 `AliasTagsField`。
- `_save()`：新增态 + 开关开 → `targetName = 填写名.trim() || 商品名`，调用
  `createIngredient(name: targetName, categoryId, aliases, reuseExisting: true,
  createSameNameProduct: false)`，赋给 `_selectedIngredient` 后走原商品创建；随后按旧原料 id
  调和草稿单位（与手动换原料同口径）。失败仍提示 `productCreateIngredientFailed`。
- `IngredientRepository.createIngredient` 新增 `reuseExisting`（默认 false）/
  `createSameNameProduct`（默认 true）参数并写入 payload，默认值与后端一致，原料表单等旧调用方
  行为不变。
- l10n：`productCreateSameName` / `productCreateSameNameHint` / `productSelectIngredientOrCreate`
  三语改文案，新增 `productNewIngredientNameHint`，`flutter gen-l10n` 产物一并提交。
- 测试：新增 `product_form_new_ingredient_test.dart` 4 例（不同名+分类+别名、留空→商品名、
  开关关→提示且不创建原料、开关关掉后恢复固定原料）；适配 4 个既有测试的 Fake 签名/英文文案/
  懒构建滚动。

## 5. 验证

- Web：`npm run build` ✓、`npm run check:i18n` ✓（3 语料 key 树一致）、
  `npm run check:i18n:sources` ✓、`npm run test:utils` 73 ✓。
- 后端：`compileall` ✓；新增 4 例 ✓；相关 `test_permissions_p0` 中 1 例既有失败
  （USDA 权限用例先返回 404，与本次无关）。
- 移动端：`flutter analyze` No issues found；新增 4 例通过；
  `flutter test test/features/products test/features/ingredients` 81 passed / 0 failed（第 4 例与
  开关恢复修复后重跑）。
  其中既有「扫码命中已建档商品」用例因表单变长（新开关说明多一行）在
  `ensureVisible(条码按钮)` 后商品名称被 ListView 回收而找不到：已改为先滚回顶部再断言
  （断言内容不变），修复后全绿。

## 6. 分支与提交

- Web + 后端：master `e474ac3`，合并到 feat/mobile-app `84bbbd0c`。
- 移动端：feat/mobile-app `eb44a0f9` + `917aeb7a`（关闭开关恢复原关联原料）。
- 本地模式补充（web `createIngredient` 支持 `reuse_existing` 同名复用、剥离协议字段）与本文档：
  master 后续提交，再合入 feat/mobile-app。

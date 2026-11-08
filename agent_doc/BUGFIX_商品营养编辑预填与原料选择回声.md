# BUGFIX：移动端商品营养编辑带出原料值 + 新增商品选原料保存失败（有概率）与提示样式

> 用户报告（两个问题）：
> 1. 移动端编辑「原先没填写营养信息的商品」的营养信息时，带出来的是**原料**的营养数据。
> 2. 新增商品时，有概率出现「已选择关联原料」但保存时提示没有保存的情况；且此时提示信息是页面底部的内联文字，而不是像其他页面一样的底部弹出提示（SnackBar）。

两个问题都在移动端（feat/mobile-app），后端零改动。

---

## A. 商品营养编辑带出原料值（数据源错层）

### 根因（分层追踪）

| 层 | 行为 | 是否正确 |
|---|---|---|
| 后端 `GET /nutrition/products/{id}/nutrition` | `NutritionCalculator.calculate_product_nutrition` 按设计返回「商品自定义 → 原料 fallback 链」的**合并**数据（`nutrition.all_nutrients`），同时携带商品自身的 `custom_nutrition_data` | ✅ 展示口径正确（详情卡显示继承值是设计行为） |
| web `ProductDetail.vue` 编辑 | `startEditNutrition` 只读 `custom_nutrition_data.all_nutrients`，注释明确「mixin 模式：不显示从原料继承的」；没填则预填默认项 | ✅ 基准参照 |
| 移动端 | 详情页把合并后的 `state.nutrition` 整个传进 `NutritionCard` → `NutritionEditArguments.nutrition` → `NutritionEditScreen.initState` 用它预填行 | ❌ 编辑器预填用了合并值；商品没填时带出原料值，保存还会把原料值写成商品自身数据（语义污染） |

### 修复（对齐 web 口径）

1. **模型**（`shared/models/nutrition.dart`）：`NutritionInfo` 新增 `ownNutrients` 字段，`fromJson` 里从 `custom_nutrition_data`（回退 `nutrients` 键，与基准读取同回退）解析出商品自身的 `core/all_nutrients`。原料响应对此字段不消费，行为不变。
2. **provider**（`features/products/providers/product_provider.dart`）：`ProductDetailPageState` 新增 `nutritionForEdit`；`_loadNutrition` 里由**原始响应** `info.ownNutrients` 构造（不混入 `mergedWithPending` 的待审草案，也不含 USDA 待审——与 web 一致：编辑器预填官方商品自定义数据）；商品没填时为 null。基准沿用响应的 reference 字段（后端：商品自定义 → 原料 → 100g；web 编辑器同样接受这一继承）。
3. **组件**（`shared/widgets/nutrition_card.dart`）：新增可选参数 `editorNutrition`，`_openEditor` 传 `editorNutrition ?? nutrition`（缺省行为不变，原料详情不受影响）。
4. **详情页**（`features/products/screens/product_detail_screen.dart`）：`NutritionCard(editorNutrition: state.nutritionForEdit)`。

效果：商品自身有数据 → 预填自身数据；没填 → `NutritionEditScreen` 既有逻辑落到「默认七项」空行（`_hadNutritionData=false`，空保存不记录）。

---

## B. 新增商品「有概率保存失败」与提示样式

### B1. 提示样式：页底内联红字 → SnackBar

商品表单的 `_error` 渲染在 ListView 底部（内联红字），而商家表单、记价表单失败都走 `ScaffoldMessenger.showSnackBar`。用户期望 SnackBar。修复：

- 删除 `_error` 字段与页底内联块，新增 `_showError(message)` 统一走 SnackBar；
- 覆盖全部 5 个报错点：加载失败 / 名称必填 / 请选原料 / 新增对应原料失败 / 保存失败。

### B2. 保存失败透出后端 detail

原 catch-all 把后端原因（如「条码已存在」——扫码 prefill 流程里条码属于已有商品时）吞成笼统的「保存失败，请重试」。新增 `_serverErrorDetail(error)`：`DioException` 且 `response.data` 为 Map 时取 `detail` 字符串直接展示，取不到再落回 `commonSaveFailedRetry`。

### B3. 「有概率」的竞态：输入法回声静默清空已选原料

- 原料 Autocomplete 的 `onChanged` 有「文本与所选原料名不一致 → 清空 `_selectedIngredient`」的防误绑定逻辑；
- 查 Flutter 源码（`editable_text.dart`）确认：`TextField.onChanged` **只由平台/IME 的 `updateEditingValue` 触发**，程序化赋值（`onSelected` 里设文本）不触发——这正是商家下拉注释里的既有认知；
- 但真机上**点选下拉项后**，输入法可能补发滞留的组合态/上屏回声（时序相关 → 概率性），文本与所选原料名不一致 → 选择被静默清空 → 保存时校验报「请选择关联的原料，或开启新增对应原料」（正是 B1 说的页底文字）。用户视角：「我明明选了原料，保存却说没保存」。

修复（`product_form_screen.dart`）：

1. **保护窗口**：`onSelected` 里 `_armIngredientSelectionGuard()`——300ms 内 `onChanged` 不做清空判定（IME 回声在点选后数十毫秒内到达）；
2. **组合态跳过**：`onChanged` 里 `_ingredientSearchController.value.composing != TextRange.empty` 时直接 return（未上屏文本不动选择，上屏提交后自然走到正常判定）；
3. `dispose` 取消保护计时器。

对照组件行为不变：保护窗口过期后的正常编辑仍清空选择（有测试）。

### 顺带

- `_ensureDraftUnitReference` 的单行 `if (...) return;` 补花括号（analyze 的 `curly_braces_in_flow_control_structures`，存量问题）。

---

## 测试

- `test/shared/models/nutrition_test.dart`：+2（ownNutrients 只含商品自定义数据；没填时为空）。
- `test/shared/widgets/nutrition_card_editor_test.dart`（新）：3 例——编辑器预填 `editorNutrition` 且合并值（88/9）不出现；不传 `editorNutrition` 时回退 `nutrition`（原料路径行为不变）；空 `editorNutrition` 落到默认行。用最小 GoRouter 挂 `/entities/:type/:id/nutrition` 路由。
- `test/features/products/screens/product_form_autocomplete_repro_test.dart`：+2——点选后输入法回声（组合态 `牛奶n` + 上屏提交 `牛奶牛`）不清空选择、保存成功（`ingredient_id=81` 落库断言）；保护窗口过期后正常编辑仍清空（对照，SnackBar 断言）。新增 `_RecordingProductRepository` 与 `pumpLauncherApp`（表单挂在导航栈上，pop 才有上一页可回）。
- `test/features/products/screens/product_form_screen_test.dart`：+2——保存失败透出后端 detail（SnackBar 显示「条码已存在」，通用文案不出现）；无 detail 落回 `Save failed. Try again.`。新增 `_FailingProductRepository`（抛 `DioException`）。

验证：`flutter analyze` 0 issue；`test/shared/ + test/features/products/` 210 passed；`test/features/nutrition/ + ingredients/screens/` 66 passed。

## 测试坑

- 下拉选项必须先输入搜索词才会出现（optionsBuilder 空文本返回空），tap 选项前先 `enterText` + pump 过防抖。
- `find.widgetWithText(TextField, '100')` 会同时命中营养基准量输入框（默认 100）与能量行——断言用 `findsNWidgets(2)`。
- 保护窗口用 `Timer` 实现，`pumpAndSettle` 会把它泵过期；点选与回声之间用小步 `pump(50ms)`。

## 遗留 / 观察

- 原料表单、菜谱表单仍是「页底内联错误」样式（`_error` 字段），用户未点名，本次未改；如需统一可复用本篇的 SnackBar 化做法。
- 「有概率保存失败」若并非回声竞态而是网络/条码重复等真实失败，现在会透出后端 detail，用户截图可直接定位。
- 商品详情卡展示继承自原料的营养（合并值）是设计行为（web 一致），未加「来源提示」标记；如需提示可参照 `fromProducts` 的 Tooltip 做法。

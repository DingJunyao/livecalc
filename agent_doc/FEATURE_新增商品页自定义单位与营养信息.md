# FEATURE：新增商品页内置「自定义单位 / 营养信息」（填写后随商品一并保存）

> 2026-10-14。用户要求：新增商品时，在同一个页面（移动端是整页表单，Web 是对话框）应有
> 「添加自定义单位」「营养信息」两个按钮，点击进入对应编辑界面，填好后**保存商品时才一并保存**，
> 不需要先建商品再回头补录。

## 1. 为什么不能直接复用现有编辑器

- 单位覆盖挂在商品 id 上：`POST /entities/product/{id}/units`、`PUT/DELETE .../units/{unitId}`；
  营养同理 `POST /nutrition/products/{id}/nutrition`（清空 `PUT /products/entity/{id}/nutrition`）。
- 新增商品时商品**还不存在**（`ProductDetail` 里的编辑器全部依赖 `route.params.id`），
  且 `POST /products/entity` 的 `ProductCreate` 不接受 units/nutrition 字段。
- 结论：编辑器必须在**草稿模式**下工作（只维护本地数组），商品 `POST /products/entity` 成功
  拿到 id 后再落库。两端各自抽出了「草稿 + 落库」两层。

### 草稿单位用负数 id

```
产品内的草稿单位 id 恒为负数（真实 id 都是正数）
weight_unit_override_id：
  < 0  → 同一批草稿里的另一条（嵌套：1箱 = 12 盒）
  > 0  → 关联原料（商品 → 其关联原料）已存在的自定义单位，落库时原样发送
  null → 全局单位（weight_unit_id）或按克
```

落库前用**分批拓扑排序**（`planDraftUnitWrites`）保证被引用的单位先创建，
再把负数 id 映射成真实 id；引用成环的行单独报出来（不创建、不丢行）。
被引用单位落库失败或变成待审提议（普通用户，后端返回 `id=0` 占位）时，
依赖它的单位无法解析引用 → 跳过并提示（`refMissing`）。

## 2. Web（master）

新增/改动：

| 文件 | 作用 |
| --- | --- |
| `frontend/src/utils/productDraftPlan.ts` | 纯函数：`nextDraftUnitId` / `planDraftUnitWrites`（分批+环） / `draftChainReaches`（下拉防环） / `draftUnitAmounts`（复用 `unitFactor.overrideAmounts` 折算 g/mL） |
| `frontend/src/utils/productDraftUnitPlan.test.ts` → `productDraftPlan.test.ts` | 8 例：分批顺序、同批、环、防环、真实 si_factor 折算（200 g / 220 mL→226.6 g / 12盒→2719.2 g）、原料引用、断裂不臆估 |
| `frontend/src/utils/productDrafts.ts` | `persistProductDrafts`（按批 POST units → POST nutrition，失败收集成结构化 issue，不抛出）+ `buildDraftNotices`（翻译成提示文案/颜色） |
| `frontend/src/components/products/ProductDraftUnitsDialog.vue` | 草稿单位列表 + 行内新增/编辑/删除；全局单位 + 本批草稿 + 关联原料单位三来源下拉（标注「（自定义单位）/（继承自原料）」），体积叶子给密度折算提示 |
| `frontend/src/components/products/ProductDraftNutritionDialog.vue` | 草稿营养表（v-combobox 选/填营养素 + 量 + 单位，每 100 g），`buildNutrientDefinitions` 提供选项 |
| `frontend/src/views/data/ProductsView.vue` | 「添加商品」对话框内新增两个按钮 + 计数（`自定义单位（N）`/`营养信息（N）`）、保存成功后落库并提示 |
| `frontend/src/views/ingredients/IngredientDetail.vue` | 同上（仅**新增**态显示，编辑态不显示）；`ingredientId` 作为单位草稿的继承来源 |

交互要点：
- 两个按钮只是 `v-dialog`（与「移动端是页面」对应），关闭 = 完成；数据通过 `v-model:units` / `v-model:nutrients` 双向上提，
  因此点关闭/X 不会丢草稿。
- 保存商品：`POST /products/entity` → 拿到 `response.id` → `persistProductDrafts(id, drafts)`。
  商品创建成功即视为成功，附加数据失败逐条提示（`draftPartialFailed` 系列文案），
  不把整单判失败（商品已经存在）。
- 营养草稿为空则不发请求（新商品本来就没有自定义营养，不需要走清空分支）。

## 3. 移动端（feat/mobile-app）

| 文件 | 作用 |
| --- | --- |
| `mobile/lib/shared/utils/draft_units.dart` | 纯函数：`nextDraftUnitId` / `planDraftUnitWrites` / `draftChainReaches` / `removeDraftUnit`（删行时清空指向它的引用） |
| `mobile/test/shared/utils/draft_units_test.dart` | 6 例（分批、同批、环、防环、删行清引用） |
| `mobile/lib/shared/screens/entity_units_draft_screen.dart` | 草稿单位整页（列表 + 右上「+」；每次改动 `onChanged` 回写商品表单，返回不丢数据） |
| `mobile/lib/features/products/services/product_draft_persist.dart` | `ProductDraftPersister.persist()`：分批 `createUnit`（负数引用映射真实 id）→ `saveProductNutrition`，返回计数 + 结构化 issue |
| `mobile/lib/shared/widgets/entity_units_card.dart` | `_UnitEditPage` → 公开 `EntityUnitEditPage`（草稿页复用同一套表单/环保护/体积提示）；`_unitDetailLine` → 公开 `entityUnitDetailLine`（同一折算口径显示草稿行） |
| `mobile/lib/shared/screens/nutrition_edit_screen.dart` | 新增 `allowUsda`（默认 true）；草稿模式传 false —— USDA 匹配会**直写服务端** `POST /usda/match/{type}/{id}`，商品还没创建时会打 `entityId=0` |
| `mobile/lib/features/products/screens/product_form_screen.dart` | 新增商品时显示「自定义单位（N）」「营养信息（N）」两个 ListTile；打开单位页前懒加载全局单位 + 关联原料单位/密度；保存商品后 `_persistDrafts` 并按结果弹提示；新增 `entityRepository` / `draftPersister` 测试注入点 |
| `mobile/test/features/products/screens/product_form_drafts_test.dart` | 3 例：入口存在、单位草稿随保存落库（盒子 200 g）、营养草稿随保存落库（且 USDA 段被隐藏） |

营养草稿复用现有 `NutritionEditScreen`：`onSave: (entries) async { _draftNutrients = entries; return null; }`
（`onSave` 返回 null → 页面照常 `pop(NutritionEditResult(saved: true))`，数据由闭包捕获）。

## 4. 验证

- Web：`npm run build`、`npm run check:i18n`、`npm run check:i18n:sources`、`npm run test:utils`（28 例，含新增 8 例）。
- 实机（Edge + localhost:5173 + 真实后端，管理员）：
  添加商品对话框显示两个按钮与提示；进入「自定义单位」→ 添加单位（名称=盒、量=220、单位=默认克）
  → 草稿列表显示 `1盒 = 220 g`，关闭后父对话框按钮变成「自定义单位（1）」。
  （本会话桌面工具无法把合成点击送进 Vuetify 模态层，改用 Tab/Enter 键盘驱动；未点保存，
  未在开发库留下测试商品。）
- 移动端：`flutter analyze` 0 issue；`flutter test` 633 通过 6 存量失败（apple_map×3、locale_preferences×2、
  my_proposals×1，与基线一致）；`flutter gen-l10n` 后 `catalog_integrity_test` 通过。
- 存量用例适配：`product_form_screen_test.dart` 的别名用例在表单变长后需要 `ensureVisible` 再点，
  否则 ListView 外层滚动位置变化会让点击落空（非功能回归）。

## 5. 补充（同日第二轮）：原料也支持，且明确落库层级

用户追加两点：

1. **新增商品时勾选「新建同名原料」→ 附加数据仍写商品层级**（原料只用于关联与引用）。
   实现上本来就是写商品（`persistEntityDrafts('product', response.id, …)`），
   本轮补了一条移动端用例断言：新建原料得到 id=7，但落库目标是 `product` / 42。
2. **新增原料同样支持这两个入口**（界面与新增商品一致），数据写**原料层级**：
   - web：[IngredientsView.vue](../frontend/src/views/data/IngredientsView.vue) 的「添加原料」对话框（`POST /ingredients` → `persistEntityDrafts('ingredient', id, …)`）；
   - 移动端：[ingredient_form_screen.dart](../mobile/lib/features/ingredients/screens/ingredient_form_screen.dart)（`createIngredient` → `EntityDraftPersister.persist(entityType: 'ingredient', …)`）。
   原料没有「关联原料」这一层，所以单位草稿页只传全局单位（`inheritedUnits` 为空）。
   营养草稿页同样传 `allowUsda: false`（原料也还没 id）。

为了让两端共用一套代码，本轮把草稿工具「实体中立化」：

| 旧 | 新 |
| --- | --- |
| `frontend/src/utils/productDraftPlan.ts` | [entityDraftPlan.ts](../frontend/src/utils/entityDraftPlan.ts)（类型 `EntityDraftUnit` / `EntityDraftNutrient`） |
| `frontend/src/utils/productDrafts.ts` | [entityDrafts.ts](../frontend/src/utils/entityDrafts.ts)（`persistEntityDrafts(entityType, entityId, …)`，营养端点按类型选 products/ingredients） |
| `frontend/src/components/products/ProductDraft*Dialog.vue` | `frontend/src/components/entities/EntityDraft*Dialog.vue`（新增 `target` prop） |
| `mobile/.../products/services/product_draft_persist.dart` | [mobile/lib/shared/services/entity_draft_persist.dart](../mobile/lib/shared/services/entity_draft_persist.dart)（`persist({required String entityType, …})`） |

文案里「商品」改为 `{target}` 占位（web `common.entityProduct/entityIngredient`；移动端
`productDraftTargetProduct/productDraftTargetIngredient`），三语同步并重新生成 l10n。

### 踩坑：`vite build` 不做类型检查

第一轮把 `productDrafts.ts` 里的 `const failedDraftIds = new Set<number>()` 删掉时漏删了 3 处引用
（`failedDraftIds.add(...)`），`npm run build`、`check:i18n`、单测全绿 —— 因为 Vite/esbuild 只转译不做类型检查，
而 `vue-tsc@1.8` 与本仓 TypeScript 5 不兼容（`Search string not found: "/supportedTSExtensions = .*(?=;)/"`）。
本轮改用 `npx tsc --noEmit -p tsconfig.json` 兜底：它只报 `*.vue` 无法解析等 137 条存量噪音，
但能稳定抓出「未声明标识符」这类会直接抛 `ReferenceError` 的问题（含本次修掉的这一处）。
**结论：改完前端除了 `npm run build`，还要跑一次 `npx tsc --noEmit`（忽略 `*.vue` 相关噪音），并把其中真实错误清掉。**

### BUGFIX（用户实测）：新增商品/原料时单位下拉「没有数据」

用户反馈：新增商品/原料时进单位编辑，「单位」下拉是空的（没有数据）；而详情页里加单位正常、移动端正常。

**根因**：[EntityDraftUnitsDialog.vue](../frontend/src/components/entities/EntityDraftUnitsDialog.vue) 用
`loadedFor = ref<number | null>(null)` 当「已加载哪个原料」的哨兵，判定是 `if (loadedFor.value === ingredientId) return`。
新增商品未选原料 / 新增原料时 `props.ingredientId` 就是 `null` → `null === null` → **第一次打开就直接 return**，
`/units/` 根本没请求，`globalUnits` 恒为空。详情页正常是因为它根本不走这个组件（数据来自 provider）；
移动端正常是因为移动端的判定用的是独立布尔 `_draftUnitsLoaded`（没有把 null 当哨兵）。

**修复**：把「是否已加载」与「加载的是哪个原料」分成两个状态
（`globalUnitsLoaded` 布尔 + `loadedIngredientId`），加载失败不置位 → 下次打开自动重试；
`ingredientId` 变化时重置。

**经验**：①用「可为 null 的业务值」当缓存哨兵时，`null` 往往就是合法取值——哨兵要用独立布尔或 `undefined` 并写注释；
②「详情页正常、新增页不正常」并不总意味着新增页取数口径不同，也可能是共用组件的初始化路径不同（本例：详情页根本不用该组件）。

## 6. 第三轮：移动端下拉丢继承单位 + 换绑原料清理悬空单位

### BUGFIX：移动端「添加/修改单位」下拉里没有关联原料的自定义单位

用户反馈：移动端新增商品页，进入添加/修改单位，「单位」下拉只有全局单位，带不出关联原料层面的自定义单位
（全局单位正常，所以不是整个下拉坏掉）。

**根因**：`EntityUnitEditPage._weightUnitItems()` 把两类来源塞进**同一个 `Set<int>`** 去重：

```dart
final values = <int?>{};
for (final option in widget.globalUnitOptions) { if (!values.add(option.id)) continue; ... }  // 全局单位先加入
for (final unit in widget.units) { if (excluded.contains(unit.id) || !values.add(unit.id)) continue; ... } // 撞车 → 静默丢弃
```

全局单位表（`/units/`）与实体单位覆盖表（`entity_unit_overrides`）是**两张表，id 空间重叠**（都从 1 开始）。
只要原料自定义单位的 id 撞上任意一个全局单位 id（几乎必然），它就被 `continue` 掉，下拉里彻底消失。
web 之所以没事：它的选项值本来就带前缀（`u:` 全局 / `d:` 草稿 / `i:` 继承），天然不会撞车。

**修复**：移动端选项值改带来源前缀 —— `''` 默认克、`u:<全局单位 id>`、`e:<本实体或继承的自定义单位 id>`；
`_weightUnit` 保存这个字符串，`_selectedGlobalUnitId` / `_selectedOverrideUnitId` 负责解析回 id
（`_selectedIsVolume` / `_selectedSiFactor` / 保存/自引用校验都改走解析）。
回归用例：让假仓库的原料单位 id 与全局单位 id 相同（都 = 1），断言继承项仍出现在下拉里。

同一个 `EntityUnitsCard`（详情页）走同一个编辑页，所以详情页的同类隐患一并修好。

### BUGFIX：继承单位加载失败会被缓存，本轮表单不再重试

`ProductFormScreen._ensureDraftUnitReference()` 原来在 `catch` 之后照样置 `_draftUnitsLoaded = true`
并缓存原料 id：一次网络抖动/鉴权竞态就会让**本轮表单**再也带不出关联原料的单位（用户感知就是「下拉里没有继承项」）。
改为「必要数据都成功才缓存」：`_draftUnitsLoaded = globalsLoaded && inheritedLoaded`，失败项下次打开自动重试。
回归用例：假仓库第一次 `listUnits('ingredient', …)` 抛异常、之后成功 —— 第一次打开无继承项、第二次出现。

### 新功能：换绑关联原料时清理引用失效的商品自定义单位（两端）

商品自定义单位可以引用**关联原料**的单位（`weight_unit_override_id` 指向原料的单位行）。
一旦把商品的关联原料换成另一个原料，这些引用就可能悬空（旧原料的单位 id 在新原料里不存在）。

- 判定：`unresolvableUnitIds(units, availableExternalIds)`
  （web [entityDraftPlan.ts](../frontend/src/utils/entityDraftPlan.ts) / 移动端 [draft_units.dart](../mobile/lib/shared/utils/draft_units.dart)）：
  引用既不在本商品自己的单位里、也不在目标原料的单位里 → 失效；**依赖失效单位的下游单位一并判失效**；
  自引用也算失效；指向全局单位（`weight_unit_id`）的行不受影响。
- 动作：逐条 `DELETE /entities/product/{id}/units/{unitId}`，把被移除的单位名告诉用户
  （普通用户的删除走待审 → 文案区分「已移除」/「已提交移除申请，待审核」）。
- **只在变更真正落地时执行**：管理员直写才清理；普通用户换绑走待审（可能被驳回），此时不动任何数据。
- 读取失败时不动数据（宁可留着悬空引用，也不误删）；单条删除失败不阻断其余清理，也不让保存失败。

## 7. 第四轮：同名单位跨来源重复（全局「颗」vs 原料自定义「颗」）

用户实测：测试库里包菜原料自定义了「颗 = 500 克」，而全局单位表里本来就有 `颗 / 颗 / count`
（开发库 id=49；全局单位表里这类「颗/个/盒/把」计数单位共几十个），于是单位下拉同时列出
**「颗 (颗)」**（全局，标签是 `名称 (缩写)`）和 **「颗（继承自原料）」**（实体覆盖），用户无从分辨该选哪条。

**根因**：单位下拉把两个来源的选项直接拼起来，只在**同一来源内**去重（值前缀/`Set` 去重），
从不做**跨来源按名字**的合并。价格记录的单位下拉其实早就按名字合并过（移动端
`mergePriceUnitOptions`、web `mergeUnitOptions` + `dedupeUnitOptions` 恰好按 value 去重），
所以只有「单位编辑」这条路径会出现两条同名项。

**修复**：按后端 `UnitConversionService.get_entity_override` 的优先级链（**实体覆盖 > 全局单位**），
与实体自定义单位**同名**的全局单位不再列出（实体那条更具体，且通常带明确重量）：

- 移动端 [entity_units_card.dart](../mobile/lib/shared/widgets/entity_units_card.dart) `_weightUnitItems()`：
  先用 `widget.units`（本实体 + 继承）算出 `entityNames`，再跳过同名的全局项。
  一个编辑页同时服务详情页与新增页草稿，两处一起生效。
- web 新增纯函数 [unitOptions.ts](../frontend/src/utils/unitOptions.ts) `withoutShadowedGlobals(globals, entityRows)`
  （4 例单测），接入三处构建：商品详情 `unitWeightUnitOptions`（对本商品 + 关联原料的行）、
  原料详情 `unitWeightUnitOptions`、新增商品/原料的 [EntityDraftUnitsDialog.vue](../frontend/src/components/entities/EntityDraftUnitsDialog.vue)（对草稿 + 继承行）。

注意这是**展示层合并**，不改任何数据：实体单位仍以 `weight_unit_override_id` 存引用，
全局单位行也照旧存在（其它商品/实体继续可用）。

## 8. 第五轮：新增态换原料时的清理（上一轮的覆盖盲区）

用户实测反馈：**在「新增商品」里**选关联原料 = 包菜，加了一个引用包菜独有单位「哈」的自定义单位，
再把关联原料换成别的原料 —— 这条单位既没被去掉、也没有任何提示（Web 与移动端都是）。

**根因**：上一轮的清理只挂在**编辑商品保存**这条路径上（`_isEdit` 分支 / `saveBasicInfo`），
而新增态的单位是**本地草稿**：换原料时既没有 re-link 保存动作，也没有任何钩子去看草稿的引用；
草稿最后被原样落库，于是在服务端留下一条悬空引用（或者用户看到的「还在列表里」）。

**修复**：新增态在**切换关联原料的那一刻**就地清理草稿（草稿只在本地，没有服务端副作用）：

- 移动端 [product_form_screen.dart](../mobile/lib/features/products/screens/product_form_screen.dart)
  `_pruneDraftUnitsAfterIngredientChange()`：`onSelected` 里异步执行（`unawaited`），
  用同一个 `unresolvableUnitIds(草稿, 新原料单位 id)` 判定，命中的行**直接丢弃**并弹提示
  （复用 `productDanglingUnitsRemoved` 文案）。
- web [ProductsView.vue](../frontend/src/views/data/ProductsView.vue)：
  `watch(selectedIngredient)` 里，当目标原料**确实变了**（新旧 id 不同且新值非空）时调
  `pruneDraftUnitsForIngredient()`，同样丢弃 + `showMessage(..., 'warning')`。

两个刻意的取舍：

1. **只在「选中了另一个原料」时触发，不挂在文本变化上**：移动端 `onChanged`、web 清空选择都会
   把 `_selectedIngredient` 置空（用户往往只是想重打一遍），此时若触发清理会把用户刚填的草稿全删掉。
   清空后重新选同一个原料 → 引用都能解析 → 不会误删。
2. **读取原料单位失败时什么都不动**（宁可留一条悬空引用，也不误删），与编辑态口径一致。

编辑态仍然是**保存时**清理（那是服务端数据，用户可能取消编辑，不能提前删）。

## 9. 第六轮：web 端「删了却没有任何提示」

用户实测：web 端换原料后单位被清理了，但**一条提示都没有**。两个独立原因：

1. **草稿态（新增商品）**：[ProductsView.vue](../frontend/src/views/data/ProductsView.vue) 里
   根本**没有 `showMessage`** 这个函数（该文件用的是 `const { notify } = useGlobalSnackbar()`），
   清理提示那一行会抛 `ReferenceError` —— 单位已经先被过滤掉了，提示永远出不来。
   改成 `notify(text, 'warning')`。
2. **落库态（编辑商品）**：[ProductDetail.vue](../frontend/src/views/products/ProductDetail.vue) 的
   snackbar 是**单槽位**（`snackbar.value = {...}`，后一条覆盖前一条），清理提示紧接着就被
   `products.basicInfoSaved`（保存成功）覆盖 → 用户只看到「保存成功」。
   改成：清理结果先收集到 `danglingNotice`，最后**合并成一条**警示
   （`basicInfoSavedDanglingUnitsRemoved`，含「已保存」+「已移除哪些单位」），
   没有清理时才弹普通的成功提示。

**为什么没被拦住**：`.vue` 文件在本仓**没有任何工具兜底** —— `vite build` 只转译不做类型检查，
`npx tsc --noEmit` 对 `.vue` 一律报「Cannot find module …」（连文件内容都不看），
仓库又没有 ESLint 配置（`frontend/package.json` 无 lint 脚本、依赖里没有 eslint）。
**结论：在 `.vue` 里新增任何标识符引用前，先在文件里确认它已定义/已导入；改完尽量实机点一遍。**

## 10. 经验

1. 「商品创建成功」与「附加数据保存成功」是两个失败域：附加数据失败必须逐条提示，不能回滚/报整单失败，
   否则用户会以为商品没建成而重复创建。
2. 嵌套结构（1箱 = 12 盒）在「先编辑后落库」的场景下必须做**拓扑分批 + id 映射**，
   否则要么顺序错（引用不存在的 id），要么把环当成正常数据发出去。
3. 普通用户保存走提议分流时后端只返回 `id=0` 的占位骨架 —— 依赖它的嵌套单位注定无法解析，
   要显式跳过并提示，不能静默丢数据。
4. 直写服务端的侧路（此处是 USDA 匹配）必须提供开关：草稿态实体 id 还不存在，任何直写都会打到错误的 id 上。

5. 「新增 X」类表单里的附加数据编辑器必须**实体中立**（`entityType` 参数化）：
   商品/原料两份需求只差端点与文案，复制一份代码会在下一次改口径时漏掉一半。
6. 前端「构建通过」不等于「能跑」：Vite 只转译，`vue-tsc` 在本仓不可用，务必用 `npx tsc --noEmit` 兜底。
7. 「详情页正常、新增页不正常」要先确认两边是否真的走同一组件/同一初始化路径，再怀疑取数口径；
   缓存哨兵不要用可为 null 的业务值充当（null 常是合法取值，`null === null` 会误判「已加载」）。
8. **两张表的 id 不能放进同一个去重集合**：全局单位 id 与实体单位覆盖 id 空间重叠，
   用 `Set<int>` 去重时后加入的一方会被静默丢弃（下拉里「就是没有那几项」，且没有任何报错）。
   选项值必须带来源前缀（web `u:`/`d:`/`i:`，移动端 `u:`/`e:`）——这也是 web 一直没这个 bug 的原因。
9. 「加载失败」与「加载成功但为空」必须区分：把失败也当成已完成缓存，会让一次网络抖动永久污染当前会话
   （用户只看到「没有数据」，日志里才有线索）。
10. 引用型数据的清理要**先确认变更已落地**再执行（审批/待审场景下不能提前删），
    并且读取失败时不动数据、单条失败不阻断其余 —— 清理永远是「尽力而为 + 明确告知」。
11. 同一个下拉里拼多个来源（全局 / 本实体 / 继承）时，**必须按用户看得见的名字跨来源合并**，
    否则全局单位表里的「颗/个/盒」和实体自定义的同名单位会同时出现两条，用户无从选择；
    合并方向遵循数据解析的优先级链（更具体的一方胜出），并且只合并展示、不动数据。
12. **同一份数据有「草稿态」和「已落库态」两条路径时，校验/清理逻辑必须两条都挂**：
    本轮就是只在保存路径上做了清理，新增态（草稿）整条漏掉，用户实测立刻发现。
    草稿态可以在交互当下同步处理（无服务端副作用），落库态必须等保存落地后再动。
13. 挂在「输入/选择」上的破坏性动作要分清**用户意图**：文本变化常只是重打，不代表改变选择；
    只在「确实选中了另一个目标」时触发，才能既不漏、又不误删。
14. **单槽位 snackbar（`snackbar.value = {...}`）里连续两条消息，后一条会把前一条吃掉** ——
    「操作成功」+「顺带清理了什么」这类复合结果必须合并成一条，或者改成队列；
    否则用户只看到成功、看不到副作用。
15. `.vue` 在本仓是**工具盲区**：build 不查类型、`tsc` 跳过 `.vue`、没有 ESLint。
    在 `.vue` 里新增引用（尤其是与相邻文件命名相近的 `showMessage` / `notify`）必须人工确认定义，
    并尽量实机验证一次。

## 11. 分支

Web 改动属于 master（先提交 master，再 merge 到 feat/mobile-app）；移动端改动属于 feat/mobile-app。

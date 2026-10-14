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

## 6. 经验

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

## 7. 分支

Web 改动属于 master（先提交 master，再 merge 到 feat/mobile-app）；移动端改动属于 feat/mobile-app。

# 记价搜索不到商品时新增商品闭环

日期：2026-11-13　分支：web master `b577cc1f`／移动端 feat/mobile-app `e94c21c4`

## 用户报告

新增价格记录时，输入商品名搜索不到对应商品的情况经常出现；现在只能退到原料/商品页面新增，只有扫码才有「扫码 → 发现没有记录 → 新增」的闭环。要求改善。

## 调研结论（先于动手）

- **后端通路早已存在**：`POST /products` 带 `product_name`（无 `product_id`）时 `_get_or_create_product`（backend/app/api/products.py:61-92）自动建商品 + 同名原料（`_get_or_create_ingredient`），**后端零改动**。
- **扫码闭环模式现成**：
  - 移动端 `price_record_form_screen.dart` `_scanBarcode`：未命中 → 对话框确认 → `context.push<ProductFormResult>('/products/new', extra: ProductFormPrefill(...))` → 返回 `_selectProduct(saved.product!)`（自动加载自定义单位/默认单位）。
  - Web `PricesView.vue`：`goCreateProduct`（sessionStorage `barcode-new-product` 存 prefill → `/data/products?returnTo=` → 商品页 `consumePrefill` 打开新增对话框）→ 返回后 `consumeReturnedProduct` 灌回 selectedProduct/product_id。
  - 本次只是把该闭环推广到「手动搜索无结果」场景。
- **Web 校验矛盾（既有 bug）**：`productIdRules` 标红「请选择或输入商品名称」，但 `saveRecord` 里 `if (!formRef.value?.validate()) return` 因 Vuetify 3 `validate()` 返回 Promise（truthy）而拦不住提交——显示校验错误却保存成功。
- 快速填写（web）显式拦死「新行必须有商品」（`saveAll` L764-769），按名回退是死代码；移动端快速填写无搜索下拉（历史商品行），不涉及。

## Web（master `b577cc1f`）

### PricesView.vue（主记价表单，新增/编辑共用）

- **「未找到」提示块**：原 disabled 预览字段（仅显示「新商品名称/将创建新商品」，不可操作）改为 `v-alert` tonal：显示「未找到「{name}」，将按此名称创建新商品」+「新增商品」按钮（复用 `prices.createProduct`）。
- **跳转新增商品页**：新增 `goCreateProductByName()`，与扫码 `goCreateProduct` 同构：sessionStorage `barcode-new-product` 存 `{ name, brand: '', barcode: '' }` → `router.push('/data/products', { name, returnTo: '/prices' })`。返回后复用已有 `consumeReturnedProduct()`（onMounted）自动选中并重开对话框。
- **校验修正（两处）**：
  - `productIdRules` 按新增/编辑区分：新增态放宽为「选中商品 **或** 输入名称」其一（`!!v || normalizeProductSearch(productSearch.value)`）；编辑态保持必须选商品（PUT 不支持按名建）。
  - `saveRecord`：`const validation = await formRef.value?.validate(); if (validation && !validation.valid) return`（Vuetify 3 正确用法；formRef 缺失时沿用旧行为放行）。
  - 「直接输名字保存 → 后端隐式建商品」保留为兜底（与移动端一致）；`onProductSearchUpdate` 在新增态 `resetValidation()` 清旧错误（保存时重新校验）。

### QuickFillView.vue（快速填写）

- `#no-data` 槽从纯文字改为「未找到商品，将创建新商品」+「新增商品「{name}」」按钮 → `goCreateProductForRow(row)`：`saveDraft()`（存整页草稿）→ sessionStorage prefill → 跳 `/data/products?returnTo=/prices/quick-fill`（与扫码 `goCreateProduct` 完全同构）。
- **`consumeProductReturn` 增强**：返回后优先把新商品**回填到草稿里同名的未选中行**（保留已填价格/数量），没有才 `appendProductRow` 追加新行。否则用户在行内输入的名字+价格会变成一条无 productId 的死行（`saveAll` 守卫会拦死全部保存）。
- `saveAll` 的「新行必须选商品」守卫保留（返回后行已选中）。

### i18n

- 新增 `prices.willCreateProductNamed`（zh「未找到「{name}」，将按此名称创建新商品」/ en / ar 三语）与 `prices.goCreateProductNamed`（「新增商品「{name}」」）。
- 删失去用点的 `prices.newProductName` / `prices.willCreateProduct`。
- 顺手补上缺失的 `common.edit`（上个会话「自定义计算范围」的 CalcScopeManagerDialog 引用但三语均未定义，按钮 title 显示字面量）。

## 移动端（feat/mobile-app `e94c21c4`）

### price_record_form_screen.dart（新增记价）

- `_createProductFromName()`：`context.push<ProductFormResult>('/products/new', extra: ProductFormPrefill(name))` → 返回 `saved?.product != null` 时 `_selectProduct(saved.product!)`——照抄扫码分支。
- 结果区渲染条件：`!_lockProduct && _selectedProduct == null && !_searching && _searchResults.isEmpty && 名称非空` 时显示「未找到「{name}」，点此新增商品」Card（ListTile，leading `Icons.add_business_outlined`）。

### price_record_edit_screen.dart（编辑换商品）

- 同构入口 + `_createProductFromName()`。
- **防误显示**：编辑页打开时商品名已回填（fixedProductName 种子）但 `_selectedProduct == null` 且从未搜索 → 未找到卡片会立即误显示。加 `_productSearchEdited` 标记（`_onProductTextChanged` 里按文本非空置位），卡片条件加 `_productSearchEdited`。`_selectedProduct` 语义（「用户本轮重新点选」，保存结果据此带新商品名快照）不动。

### i18n

- 三语 ARB 新增 `priceNoProductFoundCreate`（`{name}` 占位符，zh 模板带 `@key` metadata）。

## 测试

- 移动端新增 2 例 go_router 存根页测试（`_StubProductCreatePage` pop `ProductFormResult`）：
  - 表单页：输入不存在名称 → 入口出现 → 点击跳转带预填 → 返回自动选中、入口消失。
  - 编辑页：初始回显不显示入口（防误显示）；编辑后无结果显示入口 → 跳转 → 返回自动选中。
  - **关键**：表单与新增商品页都要走 go_router 路由（MaterialApp.router + GoRouter 路由表），不能用裸 Navigator push 表单——`context.push` 是 go_router 扩展，且裸 push 的非路由页在栈顶时 go_router push 的页面会插到它下面。
- 验证：`flutter analyze` 0 issue；form+edit 两个测试文件 31 例全过；`test/features/prices/` 全目录 123 例全过；pubspec.lock 被 pub get 改写后还原。
- Web：`npm run build` ✓、`check:i18n` ✓、`check:i18n:sources` ✓（补 common.edit 后归绿）、`test:utils` ✓。

## 坑

1. **Vuetify 3 `validate()` 返回 Promise**：`if (!formRef.value?.validate()) return` 恒不拦截（Promise truthy）。要 `await` 后判 `valid`。
2. **编辑页初始回显 ≠ 搜索无结果**：商品名种子 + `_selectedProduct` 初始 null，若无「编辑过文本」标记，未找到卡片会在刚打开时误显示。`_selectedProduct` 不能拿来初始化——它的语义是「用户本轮重新点选」，动了会改变保存结果的 productName 快照契约。
3. **测试里 go_router push 的栈序**：裸 `Navigator.push` 的页面在栈顶时，go_router 的 push 页面会插到它下面（router 页面栈与命令式路由混用）。测试 harness 要让表单本身也经 go_router 路由进入。
4. **快速填写回填行**：跨页跳转前 `saveDraft()` 存的是整页草稿，返回后 `restoreDraft` 恢复旧行——不把新商品回填进同名行而是盲追加新行，会留下无 productId 的死行卡死批量保存。
5. **check:i18n:sources 会查「源码引用了但 locale 缺失」的 key**（本例 `common.edit`），keys 模式只查语料间一致性，两把都要跑。
6. **web 提交被 Mimosa 钩子拦截**：14 个 high 全为既有文件（本地模式哨兵 token `auth.ts` + gitignore 内的 `dev-dist/` 生成物），与本次改动无关；经用户放行后以 `--no-verify` 提交，提交说明注明「人工复核为既有误报」。完整审计仍待安排。

## 分支

- 移动端 feat/mobile-app `e94c21c4`（11 文件）。
- Web master `b577cc1f` → 合入 feat/mobile-app（`fcd5686a`）。

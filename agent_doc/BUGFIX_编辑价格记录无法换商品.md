# BUGFIX 编辑价格记录无法编辑商品

- 日期：2026-11-07
- 分支：后端+web → master `6de79ca3`；移动端 → feat/mobile-app（合并 master 后提交）
- 关联：`PUT /products/{record_id}`（`update_product_record`）、web `PricesView`、web 本地模式 `handlers/products.ts`、移动端 `PriceRecordEditScreen`

## 现象

编辑价格记录时无法编辑商品：web 上商品下拉看似可改但保存后无效（改动被静默丢弃）；移动端商品干脆是只读文本。

## 排查（数据流三层都卡住）

| 层 | web（价格列表编辑） | 移动端（价格列表编辑） |
|---|---|---|
| UI | 商品下拉可编辑（仅扫码按钮 `:disabled="isEditing"`），校验 `productIdRules` 要求选中已有商品 | 商品固定只读文本（`fixedProductId`/`fixedProductName`），无切换入口 |
| 请求 | `saveRecord` 编辑分支的 payload 不含 `product_id`（只有新增分支带） | `PriceRepository.updateRecord` 不带商品字段 |
| 后端 | `ProductRecordUpdate` schema 无 `product_id`/`product_name`，传了也会被 Pydantic 丢弃 | 同左 |

商品/原料详情页内嵌的记录编辑两端本来就锁定商品（web 详情页编辑对话框无商品字段），保持不变——**可换商品的是价格记录列表的编辑**。

## 修复

### 后端（master）
- `ProductRecordUpdate` 增加 `product_id: Optional[int]`。
- `update_product_record`：
  - `product_id` 显式置空 → 400「商品不能为空」（商品是记录必填归属）；不存在/非活跃 → 404（口径同新增端点）。
  - 换绑后同步记录上的冗余快照 `product_name = product.name`。
  - **标准量重算**：换绑商品即使未传数量/单位也按「新商品上下文 + 现有数量单位」重算 `standard_quantity`/`standard_unit`（自定义单位换算按商品挂靠，`UnitConversionService.convert(entityType='product', new_product_id)`，失败回退 `convert_to_standard`）；传了数量/单位时行为同旧逻辑。`matcher = UnitMatcher(db)` 无条件创建（换绑分支在未传 unit 时也会用到，原先只在传 unit 分支里定义）。
- 测试 `tests/test_product_record_update_product.py` 3 例：换绑+快照+重算（1 斤换绑后仍 500 g；换绑+改 2 斤 → 1000 g）/ 置空 400 / 未知商品 404。**坑**：`products.ingredient_id` NOT NULL（测试商品必须挂原料）；测试手建单位需设 `si_factor`（斤=0.5、g=0.001，kg 口径）否则换算退化 1:1；Decimal 序列化带尾零（断言用 float 比较）。

### web（master）
- `PricesView.saveRecord` 编辑分支补 `data.product_id = form.value.product_id`（校验规则保证非空；不改商品时等于原值，后端 no-op）。
- 本地模式 `handlers/products.ts updateRecord`：`product_id` 变化时从 products store 取名同步 `product_name` 快照（本地模式不建标准量，与既有 create 一致）。
- 验证：`npm run build` ✓（vue-tsc 本机损坏属既有问题）。

### 移动端（feat/mobile-app）
- `PriceRecordFormArguments` 增加 `allowProductChange`（默认 false）；价格列表 `_openEditRecord` 传 `true`，商品/原料详情入口不传（保持固定）。
- `PriceRecordEditScreen`：`allowProductChange` 时把只读文本换成可搜索 TextField（初始回显原商品名）+ 建议卡片，搜索对齐新增页 300ms 防抖 + 请求序号（防 IME 组合态重复触发）；点选建议 → `_productId` 更新并重拉自定义单位；**改文本未点选 → 撤销选中，保存拦截 toast `priceProductRequired`（新增三语 key）**——编辑态不能像新增那样按名自动建商品，必须换到已有商品。
- `PriceRecordFormResult` 增加 `productName`；`PriceListProvider.updateRecord` / `PriceRepository.updateRecord` 透传 `productId`（repository 有值才写 `product_id`），列表局部更新用新商品 id/名。
- 测试 `test/features/prices/screens/price_record_edit_product_change_test.dart` 2 例：初始回显 + 搜索点选 + 结果带新商品；改文本未点选被拦。
- **坑**：`PriceRecordFormArguments.initialPrice` 改动时误写成 `String?`（应为 `double?`），analyze 立即暴露。
- 验证：`flutter analyze` 基线；新增 2 例 + prices 全量 + 三端详情既有 121 例全过。

## 遗留

- 编辑态「输入全新商品名直接建新品」两端都未支持（web 校验本就要求选中已有商品；新增流程才建新品），如需要另行评估。
- Mimosa 提交门禁在本机对既有文件（本地模式演示账号 `auth.ts`、gitignore 的 `dev-dist/` workbox 产物）报 high 误报，重试后按兼容策略放行；建议后续跑一次完整审计并给本地模式/生成产物加豁免规则。

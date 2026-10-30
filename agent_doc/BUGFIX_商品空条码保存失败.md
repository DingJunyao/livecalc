# 商品保存报「保存失败，请重试」（空条码字符串撞唯一约束）

## 现象

移动端：先把原料「鹿茸菇」改名（例如改成「鹿茸菇（干）」），再进其下的商品改名，保存时提示「**保存失败，请重试**」。换名字、换商品都不行，与原料改名本身无关。

## 根因链路

1. 移动端商品表单（`mobile/lib/features/products/screens/product_form_screen.dart` → `ProductRepository.updateProduct`）保存时**总是**带上 `brand` / `barcode`，用户留空时传的是空字符串 `""`（不是 null）。
2. 后端 `PUT /api/v1/products/entity/{id}`（`backend/app/api/products_entity.py`）的逻辑是「只要 payload 里有 barcode 且非空才查重」，`""` 被当作「不用查重」，随后 `setattr` 直接把 `barcode=''` 写进库。
3. `products.barcode` 有 `unique=True`。SQLite/MySQL/PostgreSQL 的唯一约束对空字符串照样生效——一旦库里存在一条 `barcode=''` 的历史行（本库是 `products.id=622`），**任何其他商品**再存 `barcode=''` 就会 `IntegrityError: UNIQUE constraint failed: products.barcode` → 500 → 移动端 catch 成「保存失败，请重试」。
4. 于是产品里「先改原料、再改商品」只是碰巧碰上，实际是「该商品第一次在移动端保存」就会炸。

复现：库里先放一条 `barcode=''` 的商品，再 `PUT /api/v1/products/entity/{另一个商品}`，body `{"name":"x","barcode":""}` → 500。测试见 `backend/tests/test_product_empty_barcode_brand.py`。

## 修复

后端统一把空字符串归一化成 NULL（**改一处即覆盖 web / 移动端 / 后续所有调用方**）：

- `create_product`：`product.barcode` / `product.brand` 为 `str` 时 `strip()`，空则置 `None`（在建实体前）。
- `update_product`：`update_data` 中的 `barcode` / `brand` 同样归一化，放在条码查重之前。

真实条码的查重逻辑不变（第三条测试：两个商品填同一个真实条码仍 400）。

## 遗留数据（需人工确认，未自动改库）

库里那条 `barcode=''` 的历史行仍然存在。修复后不会再产生新的 `''`，也不会再撞车；如需彻底清理，可执行：

```sql
-- SQLite / MySQL / PostgreSQL 通用
UPDATE products SET barcode = NULL WHERE barcode = '';
```

（`barcode` 列为 NULL 表示没有条码，符合语义；不影响任何编码查询。）

## 验证

- `backend/tests/test_product_empty_barcode_brand.py`：3 passed（更新空条码 / 创建空条码 / 真实条码查重仍生效）。
- 相关子集 `test_product_rename_syncs_records.py` + `test_product_ingredient_e2e.py` + `test_entity_executors.py` 共 25 passed。
- 无表结构改动，无需 alembic；后端自动重载即可生效。

## 分支

后端问题按规范在 `master` 修复（`fd033951`），再合并回 `feat/mobile-app`。

# 商品/原料「各商家价格」包含已软删记录

## 现象

商品详情页（`/data/products/1136`）中：

- **各商家价格**卡片显示「千禧三分店 ¥13.5/斤」
- **价格记录**列表里没有任何千禧三分店的记录

Web 与移动 App 表现一致（两端都调用同一后端接口）。

## 数据层事实（真实库 `backend/data/livecalc.db`）

```
product_records:
  id=3859  product_id=1136  merchant_id=6（千禧三分店）  price=13.5
           recorded_at=2026-10-26  is_active=0  ← 已软删除
  id=...   product_id=1136  merchant_id=1（美道家梦之城店）  is_active=1 × 2 条
```

商品 1136 的千禧三分店记录通过「删除记录」被软删除（`DELETE /products/{record_id}`
只置 `is_active=False`，见 `backend/app/api/products.py`），记录本身仍在表中。

## 根因

`ProductRecord.is_active` 是价格记录的软删除标记：

| 数据入口 | SQL 是否过滤 `is_active` | 结果 |
| --- | --- | --- |
| 价格记录列表 `GET /api/v1/products/?product_id=1136` | ✅ `is_active == True` | 2 条（美道家） |
| 商品各商家价格 `GET /api/v1/products/entity/1136/latest-price-by-merchant` | ❌ 只过滤 `merchant_id` + `Merchant.is_open` | 2 家（含千禧三分店） |
| 原料各商家价格 `GET /api/v1/nutrition/ingredients/450/latest-price-by-merchant`（`_lookup_rows`） | ❌ 同上 | 已删记录仍可成为该商家「最新价」 |

`latest-price-by-merchant` 以「按商家取最新一条」聚合，已删记录仍参与
`order_by(recorded_at.desc())` 的分组，于是软删除后被列表隐藏的价格又出现在
商家价区块（并参与最低价标注）。

## 修复（数据层一处，两端自动生效）

统一补 `ProductRecord.is_active == True`：

1. `backend/app/api/products_entity.py` — `get_product_latest_price_by_merchant`
   （商品各商家价格，本次报告的问题）
2. `backend/app/api/nutrition.py` — `_lookup_rows`
   （原料各商家价格；原料详情、菜谱分析、移动端原料/菜谱页共用）
3. `backend/app/api/products_entity.py` — `get_product_latest_price`
   （商品最近价，商品列表/收藏页使用）
4. `backend/app/api/products.py` — `get_product_history`（历史价格）
5. `backend/app/api/products.py` — `GET /products` 的 `sort_by=price_records` 分支
   （默认分支本来就有过滤，该分支遗漏）

说明：

- Web 本地模式（`frontend/src/api/local/handlers/*`）删除记录是硬删除
  （`deleteOne`），不存在软删除记录，无需改动。
- 移动 App 直接调用后端接口，随本次修复自动生效。
- 库存数据无需迁移：已删记录保持 `is_active=0`，只是不再参与取价。

## 验证

- 新增回归 `backend/tests/test_merchant_price_soft_deleted.py`：
  同一商品下「有效商家 + 已软删商家」两条记录，断言
  商品/原料两个 `latest-price-by-merchant` 只返回有效商家、
  最近价按有效记录计算、`GET /products` 总数与商家价口径一致。
- 相关子集（products / merchant price / ingredient merchant / product detail region /
  product-ingredient e2e / record currency）共 `23 passed`；
  `test_products.py` 2 个用例因依赖真实库预置 `testuser` 登录（401）失败，为既有问题。
- 真实库调用端点函数：商品 1136 商家价只剩「美道家梦之城店」（`prices[0].price=14.32`），
  千禧三分店不再出现。
- 商品 1136 的价格记录列表仍为 2 条；原料 450 的商家价仍含千禧三分店——因为该原料
  下**其他商品**在该商家有有效记录，属正常数据，不是本 bug。

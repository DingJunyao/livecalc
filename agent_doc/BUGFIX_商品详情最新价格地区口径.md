# BUGFIX：商品详情「最新价格」未按地区口径过滤

## 现象

商品 `277`（空心菜）详情页，地区选择「三门峡湖滨区 / 计算范围地级」时：

- 最新价格卡片：**16.67 CNY / 斤**（2026-07-29）
- 同卡片区间：**2.99 - 4.18 CNY / 斤**（2026-06-17）
- 价格记录列表里根本看不到那条 16.67 的记录；切成「全部地区」后才出现
  `10.00 CNY / 3 把`（南京 万客隆鲸选超市雨山天街店，浦口区 1100）

## 数据链路

| 层 | 行为 |
| --- | --- |
| DB | `product_records` 共 11 条 active：2 条南京商家（region 1100，2026-07-29，10 元/3 把，standard 300g）+ 9 条三门峡商家（region 1951，最新一天 2026-06-17：2.99 / 4.18 / 4.18） |
| 后端 `GET /products/entity/{id}`（get_product） | **没有任何地区过滤**：取全局最新一天（2026-07-29）的全部记录求均价 |
| 后端 `GET /products`（价格记录列表 / 趋势图取数）、`GET .../latest-price-by-merchant` | `resolve_region_param` + `apply_region_filter`，按 `X-Region` 头 / 用户默认计算范围过滤 |
| 前端 `ProductDetail.vue` | `product.latest_price` 来自详情接口（未过滤）；区间 `latestRecordStats` 来自 `/products` 图表取数（已过滤）→ 两个数字口径分裂 |

`10 元 / 3 把` 经 piece_weight 折算 `3 把 → 0.6 斤` → `10 / 0.6 = 16.67 元/斤`，
正是被地区过滤排除掉的南京记录。

## 根因

`get_product` 是商品/价格相关端点里唯一没接地区口径的：
`resolve_region_param` 在同文件 686、789 行（latest-price、latest-price-by-merchant）都在用，
详情端点却直接查全表。

## 修复

`backend/app/api/products_entity.py` `get_product`：

1. 新增 `region_id` query 参数，并 `region_id = resolve_region_param(db, current_user, region_id)`
   （会话 `X-Region` 优先，其次用户默认计算范围）。
2. 「取最新有记录日期」与「最新一天记录」两处查询都套 `apply_region_filter`。

其余均价、单位折算、时区口径不变。

## 验证

真实库（`backend/data/livecalc.db`）直接调用 `get_product`：

| 场景 | latest_price | latest_price_date |
| --- | --- | --- |
| 不过滤（修复前行为） | 16.667 | 2026-07-29 |
| 会话地区 = 三门峡市(1950) / 湖滨区(1951) | 3.7833 | 2026-06-17 |

新增 `backend/tests/test_product_detail_region_price.py`：
`X-Region=市级/县级 → 3.0`、无覆盖且用户未设置地区 → `10.0`，通过。
`tests/api` + entity 相关 72 项通过（`test_products.py` 2 个 `KeyError: access_token`
为存量登录夹具问题，与本次改动无关）。

## 遗留

本地模式（`VITE_STORAGE_MODE=local`）的 handler 虽然支持 `region_id`，但
`createLocalApi` 只把 `config.params` 透传给 handler，`X-Region` 头 / calc-context
不会进 query，因此本地模式目前整体不生效地区过滤（不止商品详情）。
要统一需要在 `createLocalApi` 里读 calc-context 并注入 `region_id`，涉及面较大，另议。

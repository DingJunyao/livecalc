# BUGFIX：原料各商家最新价未按汇率折算（25750 IDR 显示成 25750 CNY）

## 症状

移动端原料详情（蒜）「最新价格」卡里，印尼超市的商家价直接显示 `25,750 CNY`——
25750 是印尼盾（IDR）记录的原币面额，既没折算、币种还标成了用户币种 CNY。

## 根因（数据流分层定位）

- **后端** `GET /nutrition/ingredients/{id}/latest-price-by-merchant` 的
  `_lookup_rows`（`backend/app/api/nutrition.py`）：
  - `total_price = float(record.price)` 直接用**记录原币金额**参与同商家多商品的
    权重加权——混币种时加权结果本身就是错的（25750 IDR 与 10 CNY 直接加权）；
  - 响应行**不回传 `currency`/`exchange_rate`**。移动端 `MerchantPriceList`
    按 `price.currency ?? userCurrency` 显示 → 原币面额被标成 CNY；
  - 排序与最低价比较按原币金额 → 面额大的外币永远排最后、面额小的外币会错误中标最低价。
  - 对照：商品端 `GET /products/entity/{id}/latest-price-by-merchant`
    （`products_entity.py`）单商品无混币种问题，且回传原币 `currency` +
    `display_exchange_rate`，两端展示层都有「原币 ≈ 折算」UI，无此问题。
  - 同文件内原料级聚合（`latest-price` 加权综合价、`price-series` 趋势、
    商品 `latest_price`）早已用 `record_price_in_user_currency` 折算——
    只有本接口漏了，导致原料详情页商家卡与页内趋势图/headline 数值互相矛盾。
- **web 云端**：`IngredientDetail.vue` 商家行按 `formatMoney(mp.price, userCurrency)`
  显示——同样把原币面额标成用户币种，**同一问题存在**（菜谱分析页
  `MerchantPriceMatrix` 同理）。
- **web 本地模式**：`api/local/handlers/{nutrition,products}.ts` 的
  `getLatestPriceByMerchant` 里 `normalizeRecordToJin` **已经**按
  `exchange_rate` 折算到用户币种（与后端同口径），但响应行
  `currency: r.currency` 仍标记录原币——价格已折算、标签是原币。

## 修复（master `d7ef4d72`，数据层一处修、两端展示零改动）

- `_lookup_rows`：`total_price = float(record_price_in_user_currency(record))`，
  先折算到用户/会话币种（`record.exchange_rate` 原币→用户默认币种快照 ×
  会话币种覆盖汇率）再参与加权；响应行新增
  `"currency": get_user_default_currency(db, current_user)`（会话覆盖优先）。
  关联/回退/从属折算行都从 `_lookup_rows` 派生，自动同币种；
  排序/最低价/`min_price`/`max_price`/`total_cost` 随之全部正确，无需再改。
  修复后原料行语义与商品端不同：**商家行金额即用户币种**（与页内加权综合价、
  趋势图同口径），不再展示「原币 ≈ 折算」两段式。
- web 本地模式两处 handler：`currency` 标签改 `LOCAL_USER_CURRENCY` /
  `DEFAULT_USER_CURRENCY`（均为 'CNY'），对齐「价格已折算」的事实。
- 展示层无需改动：web 原料详情/菜谱矩阵本就按 `userCurrency` 格式化；
  移动端 `MerchantPriceList` 按 `price.currency ?? userCurrency` 显示，
  currency 现在等于用户币种 → 直接显示折算后金额，`≈` 行自动隐藏；
  移动端菜谱分析 `MerchantPriceRecord` 不解析币种、按用户币种格式化，同样自动修复。

## 回归测试

`backend/tests/test_ingredient_merchant_weighted.py` 新增 2 例：

- `test_foreign_currency_merchant_price_converted`：CNY 10 vs IDR 25750
  （rate 0.00044）两商家 → IDR 行 11.33、currency=CNY、排序按折算后、
  最低价标在 CNY 行；
- `test_mixed_currency_weighted_average_converted_first`：同商家 CNY 10（权重 30）+
  IDR≈11.33（权重 70）→ 加权 10.93 而非原值加权。

## 验证

- 后端：`test_ingredient_merchant_weighted.py + test_merchant_price_stale.py`
  8 passed；相关子集（merchant/price/recipe/sparkline/nutrition）
  9 failed + 9 errors 与未改动基线**逐条一致**（既有失败，非本次引入）、157 passed。
- web：`npm run build` ✓、`test:utils` 73 ✓。
- 分支：master `d7ef4d72` → 合入 feat/mobile-app（merge）。移动端无代码改动
  （修复在后端数据层），无 schema/迁移改动，后端需重启调试会话后生效。

## 已知边界（未改，属同类但不同症）

- 列表页迷你图三接口 `_compute_sparkline_for_entity` 等仍按记录原币画线
  （无货币标签，但跨原料/跨币种尺度不可比）；web 原料详情「关联商品」卡
  客户端拼的 sparkline（`IngredientDetail.vue` 用原始 `r.price/qty`）同理。
  如需统一，后续用 `record_price_in_user_currency` 同口径折算。

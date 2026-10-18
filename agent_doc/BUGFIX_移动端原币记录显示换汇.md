# BUGFIX：移动端原币价格记录显示换汇

## 现象

- 原料详情的价格记录中，`1250 IDR` 被移动端渲染成 `1250 CNY`。
- Web 端同一记录正常：先显示 `1250 IDR`，再按 `exchange_rate` 折算显示约值。

## 数据链路

1. `product_records` 保存 `price`、`currency`、`exchange_rate`；`price` 是记录币种原值，不是用户币种值。
2. `GET /api/v1/products` 返回 `price=1250`、`currency=IDR`、`exchange_rate`，不把 `price` 改写成用户币种。
3. Web `PriceWithConvert` 使用 `record.currency` 显示原币，并用 `record.exchange_rate` 计算折算值。
4. 移动端 `PriceRecord.fromJson` 也保留了 `currency` / `exchangeRate`，但原料、商品详情的历史行误用展示币种 `userCurrency` 格式化 `r.price`，导致 `1250 + CNY`。

## 修复

- 新增 `formatMoneyWithConvert`：统一输出原币金额；当记录币种与展示币种不同且汇率有效时，追加 `≈` 折算金额。
- 原料详情价格记录改用该函数。
- 商品详情价格记录同步修复。
- 价格列表删除确认框同步修复；列表卡片本身已有原币和折算显示。
- 保留已有口径：汇率缺失或非法时不做折算，避免伪造 `1:1` 结果。

## 其他货币换算检查

- 价格列表卡片、商家价格列表、商家详情：已分别显示原币与折算值，未改。
- 原料/商品列表与最新价卡：后端最新价已按用户/会话币种折算，移动端用展示币种标记，口径正确。
- 菜谱成本、试算、首页推荐：返回值是后端折算后的成本，使用后端返回币种或展示币种，未发现同类误标。

## 验证

- 新增工具函数回归：IDR 原值保留、有效汇率追加 CNY 折算、缺失汇率不折算、大小写币种归一。
- 新增原料详情、商品详情记录行回归。
- 新增价格列表删除确认框回归。
- `flutter analyze`：No issues found。
- 相关 Flutter 测试：17 passed。

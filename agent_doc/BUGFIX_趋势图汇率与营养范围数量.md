# 趋势图外币未换汇 / 原料袋装按 1:1 折斤 / 营养把「无数量」当 0

用户报告两条：①原料「大米」价格趋势图平均值到了十几块、区间特别高（而列表里全部价格都没这么多）；②菜谱「电饭煲蒸米饭」营养成分全是 0。

## 问题一：大米价格趋势图异常

### 数据事实（开发库，2026-10-18 排查）

原料 142「大米」下挂 14 个商品（`Product.ingredient_id`），其中两条记录异常：

| 商品 | 记录 | 原始值 | 正确折算 | 图表实际按 |
| --- | --- | --- | --- | --- |
| 商品 142「大米」 | 2026-09-02 | 76500 **IDR** / 5kg（`exchange_rate=0.000379`） | ≈2.9 元/斤 | **7650 元/斤** |
| 商品 1041「美道家长粒香米 5kg」 | 2026-10-13 | 39 元 / 1**袋**（std 5000g） | 3.9 元/斤 | 移动端 **39 元/斤** |
| 商品 1042「美道家五常大米 5kg」 | 2026-10-13 | 58 元 / 1**袋**（std 5000g） | 5.8 元/斤 | 移动端 **58 元/斤** |

数据本身不脏：后端综合价 / 最新价卡片 / 菜谱成本都走 `record_price_in_user_currency`（price × exchange_rate），列表与卡片显示正常（价格列表用 `PriceWithConvert` 组件在展示层换汇）。

### 根因 1（web + 移动端）：图表逐日加权不乘汇率

加权综合价在前端计算，直接用记录的 `price`（币种原值）：

- web 原料：`IngredientDetail.vue` `chartData` 用 `price / standard_quantity`，没乘接口返回的 `exchange_rate`；
- web 商品 + 本地模式（sparkline / 最新价 / 加权均价）：`api/local/business/priceNormalize.ts` 的 `normalizeRecordToJin` 同样没乘；
- 移动端：`mobile/lib/features/prices/utils/price_trend.dart` 的 `_pricePerJin` 同样没乘（`PriceRecord.exchangeRate` 字段解析了但没用）。

后果（按 `priceAsOf.ts` 算法逐日复算）：IDR 记录的「新鲜期」是 9-02~10-02（30 天参与上限 `expiresOn = 最后记录日 + 30`），期间它是唯一未超期商品 → **月视图 9-18~10-02 平均线 1915~3826 元/斤、区间上限 7650**，把 y 轴撑爆，其余 2~7.5 的真实数据被压扁。

注意：web `priceAsOf.ts` 的 `expiresOn` 按「商品**最后一条**记录日 + 30」判定（而后端 `apply_stale_participation` 按「当日生效记录的最近记录日」），商品在窗口后段有新记录时前端会更早把它算作 fresh——本次不改变该语义，仅记录两端口径差异。

### 根因 2（仅移动端）：原料趋势没走标准量路径

`buildPriceTrendPoints(..., useStandardQuantity = false)` 默认 false；商品详情传了 `true`，**原料详情没传**（`ingredient_provider.dart` `_loadChart`）。于是 `_unitsPerJin('袋')` 查不到 → factor 兜底 1 → 39/58 元 5kg 袋装按 39/58 元/斤参与加权 → **10-13 起平均线约 21.9 元/斤、区间上限 58**（用户看到的「平均值十几块」的直接来源；web 走 standard_quantity 路径所以近几天平均 4.4 正常）。

### 修复

1. `priceNormalize.ts`：`PriceRecordLike` 增加 `exchange_rate?`，`normalizeRecordToJin` 内部统一 `price × rate`（缺失/非法 ≤0 按 1，与后端同口径）——商品详情图表、本地模式 sparkline / 最新价 / `aggregatePrices` 全部覆盖。
2. `IngredientDetail.vue` `chartData`：同口径乘 `exchange_rate`。
3. 移动端 `price_trend.dart` `_pricePerJin`：两条路径（standard / original）都乘 `rateFactor`；`ingredient_provider.dart` 传 `useStandardQuantity: true`。

## 问题二：电饭煲蒸米饭营养全 0

### 数据流与根因

- 菜谱 185 两个条目 `quantity` 均为 NULL：大米条目源数据是范围（`quantity_range={"min":100,"max":200}`，howtocook 导入器只存 range 不落确定值），水条目源数据「适量」（文本存在 `original_quantity`）。
- `recipe_service.calculate_recipe_nutrition` 把 `quantity is None` 当 `"0"` → 两个条目贡献全 0 → 整谱营养 0。
- 营养数据本身在：大米有 USDA 169756（365 kcal / 100g），水有 174158（水本就近 0）。
- 影响面：`GET /recipes/{id}/nutrition`（web / 移动端菜谱详情）与试算页 `meal_plan_service` 共用该实现。
- 对照：成本计算早已通过 `_get_effective_quantity` 处理（quantity → range **最大值**（缺 max 退 min）→ 模糊量关键词 适量=100g / 少许=5g → 0），注释却写「取平均值」；`nutrition_calculator._parse_quantity`（`/nutrition/recipes/*` 路径）取 range 平均值，是另一条链路。

### 修复（用户定口径：范围按最大值）

`calculate_recipe_nutrition` 的数量解析段改用 `_get_effective_quantity`（与成本完全同口径）：返回 `(Decimal, effective_unit_id)`，模糊量回退给出的克单位（id=3）与条目单位（如 mL）不同时按 id 加载 Unit。顺带把 helper docstring 与两处调用点注释的「取平均值」改为「取最大值」。

## 验证

- 后端：新增 `test_recipe_nutrition_falls_back_to_range_max`（范围条目 200g / 适量条目 100g / 对照 50g → 能量 1277.5 kcal、蛋白质 24.955），先红（旧代码 total=0）后绿；`test_recipes / test_meal_plans_api / test_nutrition*` 子集与 HEAD 基线逐条一致（基线失败为 401/login 类存量），无新增失败。注意：`backend/.venv` 缺 pytest-asyncio（async 测试会 skip），需用根目录 `.venv` 跑。
- web：`build` ✓ / `check:i18n`+`sources` ✓ / `test:utils` 66 ✓ / `tsc --noEmit` 137（基线）。
- 移动端：`price_trend_test.dart` 新增 3 例（76500 IDR×汇率≈2.9 元/斤、汇率缺失/0 兜底、袋装 39 元/5kg→3.9 元/斤）先红后绿；`flutter analyze` 仅剩存量 onReorder info；prices+ingredients 定向 135 passed。
- 修复后预期（按同一算法复算）：大米月视图 9-18~10-02 平均线 ≈3.8 元/斤，10-13 起 ≈4.4，区间 [1.99, 7.5]；「电饭煲蒸米饭」营养按 大米 200g + 水 100g 计算（能量 ≈730 kcal 量级）。

## 经验

1. 同一份「加权综合价」逻辑有四份实现（web priceAsOf / web priceNormalize / 移动端 price_trend / 后端 ingredient_price_service），任何「记录价 → 参与价」的口径变化（币种、标准量、权重）必须四处一起对齐，否则列表与图表对不上。
2. 图表在前端算就绕不开「展示层已换汇、计算层没换」的裂缝——凡是拿 `record.price` 直接参与数值运算的地方都要先过 `exchange_rate`。
3. 「缺失」和「0」语义不同：quantity=NULL 是「未设置」（范围/模糊量可回退），按 0 参与会让整谱指标静默归零；口径要让成本和营养共用同一个 helper。
4. 测试夹具用自造单位缩写（如 `tgr`）时，`convert_to_standard` 只认静态表里的缩写，未知单位走「1:1」分支——营养类断言要么用 `g`/`ml`，要么显式验证 1:1 分支。

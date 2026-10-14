# 近月价格筛选 · 价格趋势空白 · 记价默认单位（用户一次反馈四条）

**日期**：2026-10-14
**分支**：web/后端在 `master`（3 commit），移动端在 `feat/mobile-app`（1 commit，已先合并 master）
**涉及**：`backend/app/api/products_entity.py`、`backend/app/api/ingredient_extended.py`、`backend/app/services/ingredient_price_service.py`、`frontend/src/utils/priceAsOf.ts`、`frontend/src/utils/entityUnits.ts`、`frontend/src/utils/unitOptions.ts`、`frontend/src/views/{data,ingredients,products,prices}/*.vue`、`frontend/src/components/{charts,prices}/*.vue`、`frontend/src/api/local/handlers/*`、`mobile/lib/features/{prices,products,ingredients,recipes}/*`、`mobile/lib/shared/utils/entity_unit_names.dart`

## 现象（用户原话四条）

1. 给商品 / 原料添加默认单位后，维护价格时选择商品，**单位下拉未切换到它的默认单位**。
2. web 与移动端「一些图表」**最近一个月没有数据时图表不显示，除非切换区间**；补充：**只有今天维护了数据**时同样不显示。
3. 商品管理筛选，特殊条件需新增：**近一个月未维护过价格**。
4. 原料管理筛选，特殊条件需新增：**近一个月所有商品均未维护过价格**。

## 数据流与根因

### ① 默认单位（数据在、没人消费）

- 「设为默认」落在 `entity_unit_overrides.is_default`（单位编辑弹窗 / 整页里的开关）。
- 消费点只有单位编辑与展示（`ProductDetail.vue` / `IngredientDetail.vue` / `EntityDraftUnitsDialog.vue` / 移动端 `entity_units_card.dart`）。
- 价格录入链路（`PricesView.vue` 的单位下拉、`QuickPriceRecordDialog.vue`、移动端价格记录页）**只按「商品 + 关联原料 + 全局」重建下拉候选，从不读 `is_default`** → 选商品后当前值仍是用户价格偏好（斤），于是「设了默认单位却看不到切换」。
- 单位解析优先级链是 `商品自身覆盖 > 商品关联原料的覆盖 > 全局单位`（后端 `UnitConversionService.get_entity_override`），默认单位的选取沿用同一条链。

### ② 图表空白（判据漏了「区间末尾只有一个点」）

真实开发库取证（2026-10-14，`backend/data/livecalc.db`）：

| 数据形态 | 商品 | 原料 |
| --- | --- | --- |
| 今天 1 条 + 30 天窗口内 0 条 + 更早还有若干条 | 837 / 673 / 692 | 266 / 234 / 46 / 172 / 22 / 21 / 391 / 756 / 110 / 679 / 698 |
| 全部记录只有今天 1 条 | 1048…1060（12 个） | 553 |

- 趋势图按 **as-of** 口径绘制（每商品「最近有记录日」的均价一直有效到下一次记录；全部超期时放开上限），所以**需要区间起点之前最近一次记录作为「携带起点」**。
- 而取数是按 `start_date` 窗口拉的（性能优化），恰好把携带起点挡在区间外。
- 旧修复（见 [BUGFIX_价格趋势区间无记录空白.md](BUGFIX_价格趋势区间无记录空白.md)）的判据是「**区间命中 0 条且累积池为空**才回退全量」。于是当区间里**恰好只有今天这一条新记录**时命中数 = 1 → 不回退 → 池里只有今天 → as-of 序列只剩 1 个点：
  - web：`PriceTrendChart` 的 time 轴 `min:'dataMin' / max:'dataMax'` 退化成同一时刻，点被压在边缘，看起来是空白；
  - 移动端：`CostTrendChart` 的 `_TrendPainter.paint` 第一行就是 `if (points.length < 2) return;` → **一个点等于零个点**；
  - 切到更宽区间把旧记录补进池后才有线 —— 与用户「除非切换区间」完全吻合。
- 第二种形态（**只有一条记录**，新商品第一次记价）：无论怎么回退全量都只有 1 天，序列仍是单点 → 同样空白。

### ③④ 特殊条件（两端都只是缺一个条件键 + 后端实现）

- 后端 `_apply_product_special_conditions` / `_apply_ingredient_special_conditions` 只有 `no_price`（从未维护）/ `single_price` / `single_merchant` 等**无时间维**的口径。
- 前端与移动端都把「特殊条件」当作**查询参数透传**（`params[cond]='true'`），所以补一个 `no_recent_price` 键即可。

## 修复

### 后端（master，commit `47bd18e4`）

- 新增 `recent_price_cutoff_utc(tz, days=INGREDIENT_PRICE_STALE_DAYS)`（`services/ingredient_price_service.py`）：把用户本地「今天 − 30 天」这一天的 00:00 换算成 UTC，作为 `recorded_at >= cutoff` 的判定起点 —— 与图表 / 综合价的 30 天参与上限、商家价陈旧口径同一实现，不各处写 `utcnow() - 30d`。
- `GET /products/entity` 新增 `no_recent_price`：`~exists(ProductRecord where product_id=Product.id and is_active and recorded_at >= cutoff)`；**从未维护过价格的商品同样命中**（确实「近一个月未维护过」）。
- `GET /ingredients` 新增 `no_recent_price`：**其所有活跃商品近 30 天都没有有效记录**（`~exists(... join Product ... Product.is_active and ProductRecord.is_active and recorded_at >= cutoff)`）；**没有任何商品的原料同样命中**（「所有商品均未维护」空真）。
- 软删记录（`ProductRecord.is_active=false`）不算「维护过」。
- 测试 `backend/tests/test_recent_price_filter.py`（3 例）：今天 / 29 天前有记录**不**命中；从未 / 31 天前 / 近月唯一记录已软删**命中**；原料「有商品今天记过」不命中、「所有商品都超期」与「没有商品」命中；不传参数时行为不变。

### Web（master，commit `86793212` 图表 / `ca13c1ec` 默认单位 / 筛选含在 `47bd18e4`）

- 筛选：`products.noRecentPrice` / `ingredients.noRecentPrice` 三语（2066 键）；两个列表的「特殊条件」下拉各加一项（值 `no_recent_price`）；**本地（离线）模式**同步实现同一口径（`api/local/handlers/_filter.ts` 新增 `recentPriceCutoffMs` + `productIdsWithRecentPrice`，products/ingredients handler 接入）。
- 图表判据改造：`shouldLoadFullPriceHistory({ windowStart, poolStartDay })` —— **累积池里没有「不晚于区间起点」的记录就回退全量**（池为空 → 回退；池里最早记录晚于区间起点 → 回退）。旧参数 `windowHits/loadedCount` 删除，`priceAsOf.test.ts` 同步改写真值表并新增 2 例。
- 单点兜底：`buildWeightedAsOfDailySeries` 新增 `backfillSparse` —— **整段只有 1 个记录日**时把每个商品的最早已知价向前补到区间起点（≥2 个记录日一律不补写，不凭空编造趋势）；商品/原料详情把当前区间起点（`chartRangeStartDay`）传进序列。`PriceTrendChart` 在只有 1 个点时把 time 轴左右各撑开半天，让唯一的点落在中间。
- 默认单位：`entityUnits.ts` 新增 `fetchEntityDefaultUnitName(entityType, entityId, ingredientId)`（商品自身 → 关联原料，只认严格 `is_default === true`，失败返回 null）+ 纯函数 `pickDefaultUnitName`（放 `unitOptions.ts`，可被 `node --test` 覆盖）。`PricesView`：**只有用户真正换了另一个商品、且处于新增/扫码流程**时才切换单位（`applyEntityDefaultUnitOnSelect` 开关；编辑既有记录、再次记录保持记录原值）。`QuickPriceRecordDialog`：打开与切换商品时同样套用（商品列表 / 原料页 / 详情页四处入口共用）。

### 移动端（feat/mobile-app，commit `9cb3c742`）

- 筛选：两个列表的 `_productConditions` / `_specialConditions` 加 `no_recent_price`，三语 ARB 新增 `productConditionNoRecentPrice` / `ingredientConditionNoRecentPrice` 并 `flutter gen-l10n`。
- 图表：`price_trend.dart` 新增纯函数 `needsFullPriceHistory({windowStartDay, windowRecords})`（同一判据：池为空或池里最早记录日 > 区间起点 → 回退全量）与 `buildPriceTrendPoints(backfillSparse: true)`；`ingredient_provider` / `product_provider` 的 `_loadChart` 改用新判据并开启补齐；`cost_trend_chart.dart` 的 painter 不再对 `points.length < 2` 直接 return，单点也画出来（含日期标签），`_handleTouch` 单点也能出 tooltip。
- 默认单位：`shared/utils/entity_unit_names.dart` 新增 `loadEntityDefaultUnitName(...)`；价格记录页 `_selectProduct`（用户选商品）与 `initState` 的 prefill（商品详情 / 列表「记价」带着商品进入）都套用默认单位；读取失败或没有默认单位保持原值（绝不因网络抖动改用户已选单位）。编辑既有记录走 `/prices/record/edit`，不受影响。
- 测试：`price_trend_test.dart` +3 例、`entity_unit_names_test.dart` +5 例、`price_record_form_screen_test.dart` +3 例（选中商品切换 / 带商品进入切换 / 无默认单位保持原值）。

## 验证

- **后端**：`pytest tests/test_recent_price_filter.py` 3 passed；另用 ORM 探针在真实开发库交叉验证 —— 命中 873 商品 / 711 原料，与「用 `max(recorded_at) < cutoff` 独立算出的集合**完全一致**」；与「窗口内有记录的商品」交集为空；用户实测的 837/673/692（今天有记录）不命中，142（42 天前）与原料 473 命中。
- **Web**：`npm run test:utils` 52/52（`priceAsOf` 12 例含新增 2 例、`unitOptions` 新增 `pickDefaultUnitName` 2 例）；`npm run check:i18n` 3 目录键树一致；`check:i18n:sources` 2066 键；`npm run build` ✓；`npx tsc --noEmit` 137 条 = 基线（改动文件 0 新增）。以上均在 **master worktree**（`D:\code\live_calc.worktrees\master`）复跑通过。
- **移动端**：`flutter analyze` 0 issue；`flutter test` **665 passed / 6 存量失败**（apple_map×3、locale_preferences×2、my_proposals×1，与基线完全一致）；定向跑 `price_trend_test` 10/10、`entity_unit_names_test` 21/21、`price_record_form_screen_test` 23/23。
- **未实机点验**：桌面工具无法把合成点击送进 Vuetify 模态层，本次未在浏览器/模拟器上人工点一遍（判据与渲染分支均有单测覆盖，图表修复的判据另在真实库数据上复算过）。

## 经验

1. **「区间内没有新记录」有两种形态**：一条都没有 vs **只有区间末尾（今天）一条**。任何「缺 as-of 携带起点」的判据都必须落在「池里是否存在不晚于区间起点的记录」，而不是「命中条数是否为 0」——后者在第二种形态下恰好漏掉。
2. **图表空白先查渲染分支，再查取数**：移动端 painter 对 `points.length < 2` 直接 return，于是「1 个点」和「0 个点」在用户眼里一样是空白；只修数据链路（回退全量）解决不了「真的只有一条记录」的实体。
3. **单点序列的兜底要保守**：向后/向前补齐只在「整段只有一个记录日」时做（有 ≥2 个记录日一律不补），否则会把「刚建档的新商品价」画成过去一个月的既成事实。
4. **筛选条件的「近 N 天」要复用同一口径**：新增 `recent_price_cutoff_utc` 而不是在端点里各写 `utcnow() - 30d`，否则跨时区会差一天、与图表/综合价的 30 天口径也会漂移。
5. **「引用型配置」加在数据层 ≠ 功能完成**：`is_default` 早在表里，缺的是**逐个录入入口接线**；而且要区分「用户新选择商品」与「预填/编辑既有记录」两条路径（编辑时套默认单位会静默改掉用户历史数据）。
6. **同名多来源的下拉要按解析优先级链合并**：默认单位的选取沿用「商品 > 关联原料」，且只认严格 `is_default === true`（后端可能给 `null`/缺字段，宽松真值会把非默认项当默认）。

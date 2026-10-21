# FEATURE：原料趋势图显示「替代 / 回退 / 从属」折算价（逻辑同菜谱成本）

日期：2026-10-21
范围：后端新增折算价序列接口 + Web 原料详情趋势图；移动端未改动。

## 需求

原料价格趋势图此前只画「该原料自己关联商品」的价格记录。若原料没有直接商品价，
但存在 **回退 / 替代（substitutable）/ 半成品 / 从属（contains）** 关系，菜谱成本计算
会自动降级取价，而趋势图是空白。要求趋势图也显示这部分「计算后的结果」，
且逻辑与菜谱成本计算完全一致；并加开关（默认打开）。

## 后端

### 新服务 `calculate_ingredient_price_series()`（`services/recipe_service.py`）

逐日 as-of 跑与 `_ingredient_cost_range` **完全相同的降级链**：

```
direct（自身商品加权价）
  → fallback（_get_ingredient_fallback：fallback + substitutable 双向）
  → name_match（商品名包含匹配）
  → recipe（半成品制作菜谱递归）
  → contains（从属子食材按 strength 聚合）
```

- 返回 `[{date, source, chain, min_ppg, max_ppg, avg_ppg}]`（元/克，已按用户币种折算）。
- `source ∈ direct / fallback / name_match / recipe / contains_aggregation`；
  `chain` 为链路说明（如「酱油 → 生抽」）。
- `days` 上限 **366**：逐日跑降级链成本较高，前端「全部」区间也只取近一年。
- 单日异常只记录 debug 日志、跳过该日，不影响整条序列。

### 新接口

`GET /api/v1/nutrition/ingredients/{id}/price-series?days=30&offset_days=0&region_id=`

- `days` 1..366，`region_id` 走 `resolve_region_param`（默认用户计算范围），`tz` 取请求头时区。

## 前端

### `PriceTrendChart.vue`

- 新增 props：`computedSeries?: DataPoint[]`（带 `source` / `chain`）、`computedTitle?`。
- `computedSeries` 非空时，标题栏出现 **「含替代/从属」开关**（`v-switch`，内部状态默认 `true`）。
- 折算序列画成：紫色 `#7e57c2` **虚线** + 低透明度区间带（不受商家模式影响，商家模式不叠加）。
- tooltip 同时展示：直接价（平均/区间/商品数）与折算价（来源文案 + 链路），
  例如「替代/从属折算: ¥15.90/斤」+「回退/替代关系（酱油 → 生抽）」。
- 空态判定、y 轴范围、单点撑轴都同时考虑折算序列。

### `IngredientDetail.vue`

- 新增 `loadComputedPriceSeries()`：按当前图表区间取 `week=7 / month=30 / quarter=90 /
  year=365 / all=366` 天；进入页面、切换区间、价格记录变更后刷新都会重取。
- `computedChartSeries`：每克价 × 图表单位克数（`CHART_UNIT_FACTORS_TO_GRAMS`）换算成
  `/斤`（或用户质量偏好单位），并**过滤掉 source=direct 的日子**（避免与已有直接价曲线重复）。

### i18n（三语）

`charts.computedPrice` / `charts.includeComputed` / `charts.sourceDirect` /
`charts.sourceFallback` / `charts.sourceNameMatch` / `charts.sourceRecipe` / `charts.sourceContains`。

## 验证

- 只读查库实跑（真实 SQLite 数据）：
  - `酱油`（0 条直接记录）→ 30/30 天 `fallback`，chain「酱油 → 生抽」；
  - `干红椒` → 「干红椒 → 干辣椒」；`中筋面粉` → 「中筋面粉 → 面粉」；`糖` → 「糖 → 白糖」；
  - `猪肉` → 30/30 天 `name_match`（同名商品匹配，与菜谱链顺序一致）；
  - 有直接记录的原料（五花肉/青椒/牛奶等）→ 全部 `direct`，前端不重复绘制。
- 新增回归 `tests/services/test_ingredient_price_series.py`：无直接价时走 fallback
  并透传 chain/三档；有直接价时短路、不调用 fallback。2 passed。
- 前端 `pnpm run build` 通过；`check:i18n` 三语键一致；后端 `py_compile` 通过。

## 实机反馈修复（首版上线后发现）

用户在 `http://localhost:5173/data/ingredients/14`（猪肉）看到「图表、最新价格都是空的」。两个独立原因：

1. **图表空白（ECharts 从未初始化）**：图表容器由 `v-if="hasEverHadData || !displayEmpty"` 控制。
   首帧只有折算序列、没有直接价时 `displayEmpty` 为 true → 容器不存在 → `onMounted` 的
   `initChart()` 拿不到 `chartRef` 直接 return；之后折算数据到达、容器渲染出来，但所有 watch
   只调 `updateChart()`（`if (!chart) return`），于是永远没有实例。
   **修复**：抽出 `renderOrInit()`（无实例且有 ref → `initChart()`，否则 `updateChart()`），
   数据 / 折算序列 / loading / 语言 / 筛选 / 模式等所有 watch 统一走它。
2. **最新价格空白**：卡片条件是 `v-else-if="latestPrice"`，而 `latestPrice` 只来自直接商品价；
   猪肉 0 条直接记录（只有同名商品可折算）→ 整张卡片被隐藏。
   **修复**：卡片条件改为 `latestPrice || latestComputedPoint`；无直接价时展示最新折算价
   （大字 + `/斤`）、`charts.computedPrice` 标签、区间（min–max）、日期 + 来源链路
   （「2026/10/21 · 同名商品匹配」）；有直接价时行为不变。

实机复验（Edge，`/data/ingredients/14`）：最新价显示 `15.90 CNY / 斤` + 「替代/从属折算」+ 区间
`15.90 - 15.90` + 「同名商品匹配」；趋势图为紫色虚线，开关「含替代/从属」默认打开。

## 第二轮反馈修复（猪肉不该是恒定值，也要区间）

用户指出：猪肉下属一大堆原料，价格不可能一直不变，而且要显示区间。

### 根因 1：同名匹配命中了「从属子食材」的商品，绕过了从属聚合

- 猪肉（id=14）本身 0 条价格记录，但有 11 个有记录的子食材
  （五花肉 35 条、前腿肉 33 条、梅花肉 16 条、里脊 22 条、后腿肉 23 条、肋排 11 条…）。
- `_name_match_cost_range_ppg` 用 `product_name.contains('猪肉')` 匹配，命中了**子食材「猪肉末」**
  的商品（只有 2026-06 的 3 条记录，12.98/9.90/15.90 每 500g）→ 前向填充成恒定 `15.90/斤`，
  在降级链里先于 `contains` 命中，直接短路。
- **修复**：新增 `_contains_descendant_ids()`（contains 子树，请求级缓存）；
  同名匹配时通过 `Product.ingredient_id` 过滤掉**从属后代食材**的商品。
  修复后猪肉走 `contains_aggregation`，平均值随子食材记录变化：
  30 天内 `11.73 → 11.27 → 11.30 → 11.05 → 11.16 → 12.31 → 11.85`（7 个变化点）。

### 根因 2：从属聚合的区间被「加权 min/max」压平

- 旧实现：`min = Σ(子食材.min × strength) / Σstrength`、`max` 同理。
  子食材平时只有单一前向填充价（min==max），加权后整体 min==max，区间塌缩成一条线。
- **修复**：`min/max` 改为**跨子食材取极值**（最便宜子食材下沿 ~ 最贵子食材上沿），
  `avg` 仍按 strength 加权，数学上仍保证 `min ≤ avg ≤ max`。
  猪肉 30 天区间变为 `5.80 – 29.90`（五花肉…肋排…猪蹄），随数据稳定；平均值不变。

### 其它

- `PriceTrendChart` 折算序列 tooltip 增加区间行（有区间时显示 `范围: min - max`）。
- 新增回归：
  - `test_contains_band_uses_cross_child_extremes`：子食材价 0.01/0.03（80/20 权重）→
    `min=0.010, max=0.032, avg=0.0150`（跨子食材极值 + 加权均值）；
  - `test_name_match_skips_descendant_ingredient_products`：同名匹配只保留非后代商品记录。
- 排查中发现：后端当前由 **VS Code 调试进程（`python -m app.main`）** 启动，**没有 `--reload`**，
  改 Python 后不会自动生效——需要重启调试会话。这也是第二轮修复在页面上暂时看不到区间的原因。

## 第三轮反馈修复（开关切回后图表消失 / tooltip 贴左）

用户反馈：①「含替代/从属」开关关掉再打开，图表就没了；②鼠标在图表上时 tooltip 一直在左边、还会被遮挡。

### 根因 1：容器被 `v-if` 销毁后重建，ECharts 实例仍指向旧 DOM

- 图表容器条件是 `v-if="hasEverHadData || !displayEmpty"`。猪肉没有直接商品价时，
  关掉开关 → `computedData` 为空 → `displayEmpty` 为 true → 容器被移除；
  但 `chart` 实例还在（指向已移除的 DOM）。再打开时容器重建，`updateChart()` 往旧实例写，
  画面自然空白（ECharts 不报错，只是画在已脱离文档的 canvas 上）。
- **修复**：
  - 容器条件加 `|| hasComputed`：只要存在折算数据，关闭开关时也保留容器（只是清空图形）；
  - `renderOrInit()` 增加「DOM 被替换」检测：`chart.getDom() !== chartRef.value` 时
    `dispose()` 并重建实例。

### 根因 2：tooltip 宽度超过容器被钳在左侧

- 从属链路文案很长（`猪肉 ← 子食材(五花肉, 前腿肉, 梅花肉, 里脊, …, 猪蹄)`），
  加上 ECharts 默认 `confine: false`（允许溢出容器），容器裁切后视觉上「一直贴在左边」。
- **修复**：
  - tooltip 加 `confine: true`（限制在图表容器内，跟随指针正常左右移动）+ `max-width: 320px`；
  - `shortChain()` 把链路截断到 36 字符（超出加 `…`），避免 tooltip 撑到容器外；
  - 商家对比模式 tooltip 同样加 `confine` 与最大宽度。

## 第四轮：直接价超期时优先关系折算（可切换，默认开）

用户问「食用油（id=3）为什么没有展示回退/替代/从属的计算后价格」，并选择
「**直接价超期（>30 天）时优先用关系折算，但要能切换**」。

### 数据事实

- 食用油有 1 个商品、3 条记录，最新 2026-06-13（>130 天，早已超期）；同时有 4 个
  `contains` 子食材：植物油、猪油、牛油、黄油（后两者无价格）。
- 旧口径：`direct` 优先 + 「全部超期放开」→ 30 天都是 `direct`，恒定 6.59 元/斤，
  从属聚合（5.99–14.33）被挡掉。
- 修复中又发现：`name_match` 会把**原料自己的商品**也匹配进来（食用油→同名商品），
  等于把同一个旧价换个 source。已把「自身 id」一并加入排除集合。

### 后端

- `calculate_ingredient_price_series(..., prefer_relations_when_stale=False)`：
  - 直接价存在但最近记录超过 `INGREDIENT_PRICE_STALE_DAYS`（30 天），且关系折算可用时，
    改用 `fallback → name_match → recipe → contains` 的结果；
  - 返回点新增 `direct_ppg`（原直接均价）与 `direct_stale`（是否被替代）；
  - 关系折算不可用时保留直接价（宁可显示旧价也不能没有价格）。
- 抽出 `_relation_cost_range_ppg()`（非直接价的几层）与 `_direct_latest_record_day()`（判断超期）。
- 接口 `GET /nutrition/ingredients/{id}/price-series` 新增
  `prefer_relations_when_stale`（bool，默认 false）。
- `_name_match_cost_range_ppg` 排除集合 = 自身 + contains 后代。

实跑（30 天）：
- 食用油 `prefer=False` → `direct` ×30，6.59 元/斤；
- 食用油 `prefer=True` → `contains_aggregation` ×30，5.99–14.33 元/斤，`direct_stale=true`，
  链路「食用油 ← 子食材(植物油, 猪油)」；
- 猪肉（无直接价）两种开关结果一致（本来就走 contains）。

### 前端

- 图表标题栏只保留 **一个开关「含替代/从属」**（原料存在层级关系时显示，默认开）：
  - **开** = 显示关系折算序列，且「直接价超期（>30 天）时优先用关系结果」同时生效；
  - **关** = 不取折算数据、也不再超期优先，图表只显示直接价。
  切换会带 `prefer_relations_when_stale` 重新请求折算序列（口径在后端，不能只切展示）。
- 折算 tooltip 在直接价被替代时多一行红字：
  「直接价已超期，按关系折算（原直接价 {price}）」。
- 最新价格卡片：当折叠算点 `directStale=true` 时，折算价作为主显示（大字 + `替代/从属折算`
  标签 + 区间 + 日期/来源），并在下方提示原直接价；关闭开关后恢复「直接价优先」。

### 回归

- `test_prefer_relations_when_direct_is_stale`：直接价超期 + 开关 → 关系结果、
  `direct_stale=true`、`direct_ppg` 保留；关闭 → direct。
- `test_name_match_skips_descendant_ingredient_products`：自身商品与子食材商品都被排除，
  只保留无关商品记录。

## 第五轮：各商家价格也按关系折算

用户要求：**「各商家价格」也要有折算相关的计算**。

### 原实现与问题

- `GET /nutrition/ingredients/{id}/latest-price-by-merchant` 只按「该原料自己的商品」算每个商家的
  代表价；只有**完全没有直接价**时才整体回退到 fallback 食材，且不处理 name_match / contains。
- 结果：猪肉（0 条直接记录）虽然图表能显示从属折算，但「各商家价格」一片空白；
  食用油只有 3 家有直接价的门店，其它有子食材价格的门店也不会出现。

### 新逻辑（`include_relations=true`）

按商家逐条补齐，**直接价优先**：

```
每个商家：direct（该商家该原料的商品加权价）
        → 缺失时才取 fallback（回退/替代食材在该商家的价）
        → 再缺失取 name_match（同名商品，排除自身 + contains 后代）
        → 再缺失取 contains（各子食材在该商家的代表价按 strength 加权；区间取子食材极值）
```

- 拆分 `_lookup_merchant_prices(ing)` → `_lookup_rows(products)`，供直接/同名商品复用；
- 回退链查找抽成 `_find_fallback_ingredient()`；
- 每行新增 `source` / `chain` / `is_derived`，从属聚合额外给 `min_price` / `max_price`；
- 已有直接价的商家不会被折算行覆盖（`seen_merchants` 去重）。

接口参数：`include_relations`（bool，默认 false，保持旧消费者行为）。前端与图表共用
「含替代/从属」开关：开关切换时同时重取趋势序列 + 各商家价格。

### 前端展示

- 各商家价格行：折算行显示紫色小标签（回退/替代关系 / 同名商品匹配 / 从属子食材聚合），
  hover 显示完整链路；从属聚合行额外显示区间（子食材最低–最高）。
- 直接价行外观不变。

### 实跑（只读真实库）

- 猪肉（14）`include_relations=false` → 0 家；`true` → 6 家，全部 `contains_aggregation`，
  价格 9.15 / 11.29 / 11.92 / 12.26 / 13.25 / 20.88 元/斤；
- 食用油（3）→ 3 家直接价（6.58/6.58/6.59），未被折算行覆盖。



> 注意：HMR 只热替换模板时会出现 `Property "latestComputedPoint" was accessed during render but is
> not defined on instance` 的假报警，刷新页面即消失（脚本部分未热重载）。

## 已知限制

- 本地模式（IndexedDB）没有该接口，调用失败会静默隐藏折算序列（开关也不出现）。
- 「全部」区间折算最多近一年（逐日降级链的性能取舍）；更早区间的折算曲线不显示。

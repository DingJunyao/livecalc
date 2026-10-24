# BUGFIX 移动端原料列表价格/迷你图只显示前 40 项

## 现象

移动端原料列表页无限滚动时，只有**前 40 项**有价格与迷你图，之后的项目这两项要素永远加载不出来（名称、分类等正常）。

## 根因（三层链路追踪）

1. **后端**：`GET /nutrition/ingredients/latest-price/batch` 的 `_parse_ingredient_ids`（`backend/app/api/nutrition.py`）限制 `ingredient_ids` **单次最多 50 个，超出直接 400**（`ingredient_ids 一次最多支持50个ID`）。
2. **移动端仓库层**：`IngredientRepository.getLatestPrices` 把调用方传入的全部 id 一次性发出，不感知上限。
3. **移动端 provider**：列表是无限滚动（每页 20 条、**累计列表**，与 Web 端「页内分页、每次替换」不同），`_loadDetails` 每页加载后把**累计全部 id** 传给批量价接口，且用 `copyWith` **整体替换** `latestPrices`/`sparklines` map。

组合效果：第 1、2 页（20、40 个 id）成功；第 3 页起累计 60 个 id → 批量价接口 400 → `_loadDetails` 整个 try 块中断（迷你图接口 `/sparklines/ingredients` 无 id 上限，但根本轮不到执行）→ state 里保留的仍是第 2 页时的旧 map（正好覆盖前 40 项）→ 之后每一页都重复同样失败，**永远停在前 40**。

`40 = 2 × 每页 20`，正是「最后一次全部成功的轮次」。

## 修复（feat/mobile-app，3 处）

1. **仓库层分块**（`ingredient_repository.dart`）：
   - 新增 `latestPriceBatchChunkSize = 50`（与后端上限对齐，`>50` 才 400）；
   - `getLatestPrices` 内部按 50 分块请求后合并，**单块失败只丢该块、不拖垮整批**（静默吞掉，与列表页「宁可部分展示」的既有容错一致）。收藏页（一次最多传 100 个收藏原料 id）等所有调用方一并受益。
2. **原料列表 provider**（`ingredient_provider.dart` `_loadDetails`）：
   - 结果与已有 map **合并**（`{...base, ...新数据}`）而非整体替换——翻页/局部失败时已加载项不丢失；
   - 新增 `_detailsSequence` 序号防竞态，过期响应不回写。
3. **商品列表 provider**（`product_provider.dart` `_loadDetails`）同类隐患：
   - 原实现 `Future.wait` 逐商品取价，**任一单项失败整轮作废**（价格+迷你图都不更新，症状同类：后面的加载不出来）；改为单商品失败只跳过自己（`_safeLatestPrice` 返回 null），迷你图单独 try/catch；
   - 同样改为合并 + `_detailsSequence` 防竞态。

商品无批量最新价接口（后端只有原料 batch），维持逐项请求不变。菜谱批量成本 `POST /recipes/batch-cost` 用 POST body、无数量上限，无需处理。迷你图三个接口均无 id 数量上限，无需分块。

## 验证

- `flutter analyze`：No issues found。
- 新增回归 4 项：
  - 仓库层：55 个 id 分 2 块请求且合并（verify 两次调用参数各 50/5 个 id）；
  - 仓库层：前一块 400 不影响后一块返回；
  - 原料 provider：模拟批量价「只有后一半 id 成功」，翻页后上一页 11–20 与本页 21–40 并存（整体替换旧行为会丢 11–20）；
  - 商品 provider：id=1 取价恒失败，其余 19/39 项照常展示且翻页后合并。
- 原料 + 商品全目录 78 项测试通过；全量 `flutter test` 仅剩 7 个**既有**失败（home 汇总、Apple 地图 ×3、语言偏好 ×2、我的提议），stash 对照基线一致，与本次无关。

## 备注

- Web 端不受影响：`IngredientsView` 是页内分页（`items` 只装当前页），id 数最多一页，不会撞 50 上限。
- 后端批量价接口的 50 上限是当时为 SQLite QueuePool 压力加的保护，分块请求仍复用该约束，不放松后端。

# FEATURE: 原料营养缺项从商品加权平均回填 + 新建默认七项 + 全量营养素下拉

- **日期**：2026-10-24
- **分支**：master（后端 `d78922c8` + web `4f6cb306`）；feat/mobile-app（移动端 `daaeacdd`，master 经 merge `7f2075bd` 合入）
- **关联**：[FEATURE_营养基准与默认项.md](FEATURE_营养基准与默认项.md)（默认五项/基准缩放的前序）

## 需求（用户三条）

1. 原料没有某个营养素的记录时，从各商品的营养信息里**加权平均**带出（商品也没有就不加了）；必须区分「某营养素为 0」与「没有某营养素记录」——**新增时填 0 也要记进去**。
2. 新建商品/原料时营养默认带出七项：**能量、蛋白质、脂肪、饱和脂肪、碳水化合物、糖、钠**；能量默认单位随用户配置，蛋白质/脂肪/饱和脂肪/碳水化合物/糖 g，其余 mg。
3. 营养素下拉展示**全部营养素**（上述七项始终置顶；下拉要包含**反式脂肪**），单位下拉展示全部单位。

## 数据模型与链路（零迁移）

营养存储不变：原料 `nutrition_data.nutrients`（`all_nutrients` 英文键 + `core_nutrients` 中文显示名），商品 `products.custom_nutrition_data`（同构 JSON，另有 `reference_amount/reference_unit`）。

### 后端回填（`services/nutrition_calculator.py`）

- `calculate_ingredient_nutrition` 重构：
  - 旧版扁平格式的结构化转换抽成 `_ensure_structured`（行为不变）；
  - 原料缺项 → `_products_weighted_average_nutrients(ingredient_id, own_keys)`：
    - 商品集合：`ingredient_id` 关联 + `is_active` + 有自定义营养；
    - 权重：**商品价格权重** `Product.price_weight`（默认 50，≤0 不参与）——与价格聚合同一权重概念，且对全部用户确定一致；
    - **0 与缺失的区分**：商品行里键存在（含 value=0）才参与该营养素的平均，键不存在不算 0；原料自身已有（含 0）的营养素不回填；
    - 归一：商品基准 `reference_unit` 为 g/克时按 `reference_amount` 折到每 100 g；其他单位**不折算**（与商品营养读取「不参与缩放」的既有口径一致，不臆估）；
    - 单位归一并取平均：能量 → kcal（kJ÷4.184）、g 家族（蛋白/脂肪/碳水/糖/纤维/三类脂肪酸/反式脂肪）→ g、μg 类维生素（A/D/B12/K/叶酸/硒）→ μg、其余默认 mg；换算不到基准单位（IU/% 等）的商品行该营养素跳过；
    - 别名互通：`sugar↔total_sugars`、`trans_fat↔fatty_acids_total_trans`、`saturated↔saturated_fat`、单/多不饱和、`fiber↔dietary_fiber`、`carbs↔carbohydrate`（维生素A 的 RAE/IU 故意不并，量纲不同）；
    - 回填值标记 `from_products: true` + `products_used: N`，先折到原料自身基准再统一缩放，核心营养素同时补 `core_nutrients`；
  - 原料**完全没有营养行**时：整表从商品带出（每 100 g 按请求量缩放）；商品也没有 → 维持 `None`（404 语义不变）。
- `NUTRIENT_NAMES` 补 `sugar→糖`、`trans_fat→反式脂肪`（编辑器保存键的显示名）。
- 菜谱营养、仪表盘等所有 `calculate_ingredient_nutrition` 消费方自动享受回填（多出的 `from_products` 键对累加无害）。

### 「0 也要记进去」——各端保存过滤修复

| 端 | 位置 | 旧 → 新 |
|---|---|---|
| web | `IngredientDetail.vue` / `ProductDetail.vue` 保存 payload | `value > 0` → `value >= 0`（只过滤未填/负数） |
| web | `utils/entityDrafts.ts` 草稿持久化、`IngredientDetail.vue` 草稿计数 | 同上 |
| 移动端 | `shared/screens/nutrition_edit_screen.dart` `_saveManual` / `_hadNutritionData`、`shared/services/entity_draft_persist.dart`、两个表单页 `_draftNutrientCount` | 同上（hadData 判定改为 `value != null`） |

后端保存路径（`_build_structured_nutrients`）本就不丢 0，无需改。

### 前端编辑器（web + 移动端）

- **默认七项**：web `nutritionBasis.ts` `DEFAULT_NUTRIENT_KEYS` → 7 键；移动端 `nutrition_basis.dart` `kDefaultNutrientLabels/Units` → 7 项（饱和脂肪/糖 g）。能量随用户偏好、钠 mg 的机制沿用。
- **全量目录**：web `composables/nutrientDefinitions.ts` `BASE_DEFS` 补 `sugar`、`trans_fat`（units g/mg，defaultUnit g）；新增 `orderNutrientDefsDefaultsFirst()`——两个详情页 `getNutrientOptionsForRow` 与草稿对话框 `defs` 都用它把七项置顶、其余按定义表顺序。移动端 `_nutrientOptions` 对齐 web 全量（补 糖/反式脂肪/单/多不饱和脂肪/铜/锰/硒，补回钾），七项置顶。
- **i18n**：web `nutrients.sugar`（糖/Sugar/سكر）；移动端 arb 补 `nutritionNutrientSugar/TransFat/MonounsaturatedFat/PolyunsaturatedFat` 三语 + gen-l10n（铜/锰/硒已有）。
- 硬编码中文 lint 白名单：`test/l10n/no_unlocalized_user_text_test.dart` `_canonicalNutrientHan` 补新标签（营养素目录的中文键是**数据键**，展示经 `_nutrientDisplayLabel` 走 l10n）。

## 验证

- 后端：新增 `tests/test_nutrition_products_fallback.py` 6 例（加权平均、显式 0 参与而缺失不算、自身值优先、无自身行整表带出/仍 404、别名+单位归一 kJ→kcal mg→g IU 跳过、0 值保存回读）；`test_nutrition_basis.py` 10 例回归全过；`pytest -k "nutrition or recipe"` 与基线 stash 对照**零新增失败**（7 个既有失败为 auth/fixture 老问题）。
- web：`npm run build` ✓、`check:i18n` + `check:i18n:sources` ✓、`test:utils` 73 ✓（`buildDefaultNutrientRows` 断言改七项）。
- 移动端：`flutter analyze` No issues；营养相关 + 草稿 33 项全过；全量 729 过、仅剩 7 个既有失败。

## 复盘 / 经验

1. **widget 测试的懒构建陷阱（本次最坑）**：编辑器默认行 5→7 后首屏放不下，`tester.ensureVisible(能量值字段)` 会把**基准行**滚出 ListView 懒构建缓存 → `find.byType(TextField).first/.at(1)` 整体错位一行（'12' 进了蛋白质、'1' 进了能量）。修复：测试里先 `drag` 回顶部、**删掉 ensureVisible**；断言「钠」这类低处行用 `find.text('Sodium', skipOffstage: false)` + `findsWidgets`（offstage 下拉里的选项会让精确计数失真）。
2. **「取列表第一项」与「取默认单位」是两种语义**（上轮关联弹层的同族教训）：默认行顺序改变只影响 UI，不影响后端键；新目录键（`sugar`/`trans_fat`）与 USDA 键（`total_sugars`/`fatty_acids_total_trans`）必须在合并层做别名归并，否则「有没有」的判断按键名各说各话。
3. 商品营养「基准只影响展示与录入、读取不缩放」是既有口径——回填归一只对 g/克基准生效，其他单位不动，避免在回填层引入与读取层不一致的第二套换算。
4. **实机首验即翻车（2026-10-24 追加 `3bb62b08`）**：`/data/ingredients/729` 页面仍无营养。两个原因：①后端是 VS Code 调试进程无 `--reload`，改动未生效（需重启）；②**移动端编辑器保存的商品营养键是中文显示名**（`NutrientEntry(key: 中文标签)` → `all_nutrients` 键 = 能量/蛋白质/…）且基准可能是「每 10.7 g」——英文别名表认不出，能量（kJ）被当未知营养素换算失败剔除。修复：`_canonical_nutrient_key` 增加 `NUTRIENT_NAMES` 反查（中文 → 英文键，同名先到先得）；无自身行分支补 `_core_entries_for`（此前 core_nutrients 只有自身行合并路径会填）。真实库实跑 729：每 100 g 能量 143.26 kcal / 蛋白质 4.83 g / 脂肪 10.59 g / 碳水 7.32 g / 钠 7709.57 mg / 饱和脂肪 4.7 g（全部 from_products）。**教训：读「真实数据长什么样」要趁早——测试里构造的英文键数据与存量中文键数据根本不是同一种东西。**

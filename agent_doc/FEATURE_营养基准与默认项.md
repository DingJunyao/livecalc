# FEATURE: 营养基准（每 X 单位）+ 新建默认五项 + 空保存不记录

- **日期**：2026-10-15
- **分支**：master（后端 + web + 本地离线模式，`7168d590` + `a53f194d`）；`feat/mobile-app`（移动端，合并 master 后实现）
- **关联**：前序 [FEATURE_新增商品页自定义单位与营养信息.md](FEATURE_新增商品页自定义单位与营养信息.md)（草稿态营养 / 自定义单位底座）

## 需求（用户三条）

1. 移动端：添加价格时扫一部分条码没反应（**另见 [BUGFIX_移动端扫码无反应.md](BUGFIX_移动端扫码无反应.md)**）。
2. 新建原料/商品添加营养时，默认带出**能量 / 蛋白质 / 脂肪 / 碳水化合物 / 钠**；钠默认 **mg**；**只点开没填则不记录**。（能量默认单位最初按需求原文写死 kJ，**同日用户追加改为跟随用户的能量单位偏好** —— kcal | kJ，缺省 kcal，与两端 `useUserUnits` / `authProvider.unitPreferences` 的回退一致。）
3. 填写营养时能改「剂量」的基准（一直是每 100 g），可换成别的量/单位，**也能从自定义单位里选**；是否需要每个营养素各带基准 —— 用户自己也在犹豫，本轮按**整表一个基准**做。

## 数据模型（后端）

基准字段**早就存在**，只是没人写、没人读：

- 原料：`nutrition_data.reference_amount`（Float，默认 100）+ `reference_unit`（原 `VARCHAR(10)`，**本轮加宽到 50**，见迁移）。
- 商品：`products.custom_nutrition_data` JSON 的顶层 `reference_amount` / `reference_unit` —— **与 USDA 商品匹配（`services/usda/matcher.py`）写入的字段同名同义**，读侧 `merge_nutrition_data` 只认 `core_nutrients`/`all_nutrients`，多两个标量键不影响。
- 迁移：`alembic/versions/20261015_0002_widen_nutrition_reference_unit.py` + `scripts/sql/20261015_nutrition_reference_unit_{sqlite,mysql,postgresql}.sql`（SQLite 无长度语义，脚本内注明）。

## 写入链路

| 入口 | 落库位置 | 说明 |
|---|---|---|
| `POST /nutrition/ingredients/{id}/nutrition` | `NutritionData.reference_amount/reference_unit` | 提议执行器 `proposals/executors/nutrition.py` 新增 `parse_base_reference` / `apply_base_reference`；**snapshot 与 revert 一并带上基准**（否则回滚后旧值配新基准） |
| `POST /nutrition/products/{id}/nutrition` | `custom_nutrition_data.reference_amount/reference_unit` | 端点把 `request.base_quantity/base_unit` 写进 structured_nutrients |
| 商品拆分为原料 | 新原料的 `reference_*` | `product_split.py` 用 `_nutrition_reference` 把商品的基准搬过去（此前硬编码 100 g） |
| 导出导入 | 原料基准随 `nutritions.json` 往返 | 导出侧本来就有这两个字段，导入侧此前丢弃 → 补上 |
| 本地（离线）模式 | 原料：写在该原料的每条营养素行上，读回取首行；商品：`custom_nutrition_data` 存 `{items, reference_amount, reference_unit}`（默认 100 g 时仍写纯数组，兼容旧数据） | `frontend/src/api/local/handlers/nutrition.ts` |

校验：`NutritionEditRequest.base_quantity > 0`、`base_unit` 去空白 + `max_length=50`（执行器侧另有一份防御性校验，因为提议 payload 不一定来自 API）。

## 读取与计算

- `GET /nutrition/ingredients/{id}/nutrition`：`reference_amount/reference_unit` 改为取 `NutritionMixin.get_best_nutrition_data`（**与计算器同一行**；此前用 `.first()`，多条营养数据并存时基准与实际缩放来源可能不是同一行）。
- `GET /nutrition/products/{id}/nutrition`：新增 `reference_amount/reference_unit`，口径「商品自定义 > 关联原料 > 100 g」（`calculate_product_nutrition` 的 `_product_reference`）。
- **缩放**：`NutritionCalculator.calculate_ingredient_nutrition` 的 `scale_factor` 从 `base_quantity / reference_amount` 改为 `base_quantity / _reference_base_amount(...)` —— 基准先经 `_convert_to_base` 折算成**克当量**，因此 `每 250 mL`、`每 1 斤`、`每 1 袋（= 250 g，走实体单位覆盖）` 都能正确缩放；单位解析不出来（单位被删/改名）时**退回「amount 即克数」的旧口径**，不臆估、不产生离谱缩放比。
- 商品自定义营养不参与缩放（沿用既有行为），基准只影响展示与录入。

## 前端

**web**（`7168d590` 之后的 `a53f194d`）：

- `utils/nutritionBasis.ts`（纯函数 + 10 例单测）：`buildDefaultNutrientRows`（五项默认行，能量随定义表=用户能量偏好 / 钠 mg）、`resolvableBasisUnitNames`（**与后端 `resolve_override_amount` 同口径**：跟随嵌套引用、最多 8 层、悬空引用只看本行 `weight_per_unit`、引用的全局单位必须是质量/体积）、`buildBasisUnitOptions` / `withCurrentBasisUnit`（自定义单位在前、同名全局项让位、当前值必须能回显）、`readNutritionBasis`（reference_* > custom_nutrition_data.* > base_* > 100 g）。
- `components/nutrition/NutritionBasisField.vue`：基准量 + 单位下拉（含本实体可折算的自定义单位），供两处详情页与草稿对话框共用。
- `ProductDetail.vue` / `IngredientDetail.vue`：编辑区顶部加基准输入；标题「（每 X 单位）」由 `nutritionBasisLabel`（`products.perBasis` / `ingredients.perBasis`）动态渲染，未编辑时用 `watch(nutritionData)` 同步。
- 空保存：进入编辑时记录「本来有没有数据」（`nutritionHadData`）。商品本来没有自定义营养 → 什么都不填直接关（**不发清空请求、不弹「已保存」**）；本来有 → 保持原有「清空覆盖」语义。原料本来没有 → 静默关闭；本来有且被清空 → 仍提示「至少填一项」。
- 草稿态（新增商品/原料对话框）：同样默认五项 + 基准；基准随实体创建后由 `persistEntityDrafts(entityType, id, units, nutrients, basis)` 一并落库（此前后端参数硬编码 100/g）。

**移动端**（`feat/mobile-app`）：同口径复用一套纯函数 `shared/utils/nutrition_basis.dart`（`NutritionBasis` / `readNutritionBasisFromJson` / `resolvableBasisUnitNames` / `mergeBasisUnitOptions` …，7 例单测），取数缝 `loadNutritionBasisUnitNames`（`entity_unit_names.dart`，失败回退 g/mL）。`NutritionEditScreen`：基准行（量 + 单位下拉）+ `_hadNutritionData` 空保存语义 + 默认五项；`onSave` 签名扩为 `(entries, basis)`，`NutritionRepository.save*Nutrition(..., {basis})` 落到 `base_quantity/base_unit`，草稿 persister 与两个表单页（`_draftNutritionBasis`）同步；`NutritionInfo.baseQuantity/baseUnit` 改为优先读 `reference_*`，卡片「（每 X）」标签因此自动正确。

## 验证

- 后端新增 `tests/test_nutrition_basis.py` 10 例：原料/商品基准落库与回读、默认 100 g 不回归、非法值 422、执行器 revert 还原基准、商品继承原料基准、四项缩放（存量 100 g / 250 mL / 1 袋=250 g / 悬空单位回落）。
- **等价性**：开发库全部 565 个有营养数据的原料 × (100 g, 250 g, 1 斤)，新旧代码输出 **sha256 完全一致**（旧数据全是 100 g，走短路分支 `unit=='g'` 直接返回 amount）。
- web：`npm run build` ✓、`check:i18n` 三语一致、`check:i18n:sources` ✓、`test:utils` 52→62 ✓、`npx tsc --noEmit` 归一化后与基线**逐条一致**（118 组）。
- 移动端：`flutter analyze` 0 error、`flutter test`（定向新增用例全绿；全量见提交记录）。
- **实机 GUI 验证待服务启动后补做**（本轮开发时前端 5173 / 后端 8000 均未运行）。

## 经验

1. **「数据层早就有、链路没人接」是最容易漏的一类**：`reference_amount/reference_unit` 在表里躺了很久，写入链路（提议执行器 / 商品端点）与读取链路（前端模型）都没接，所以功能表现为「永远每 100 g」。判断一个字段是不是「已支持」，要看**写入 → 读取 → 消费**三段是否都通。
2. **数值口径变更必须先证等价**：缩放公式动了就会影响菜谱营养，本项目约定「基线 sha256 + 同库对跑」；本次靠 `reference_unit == 'g'` 的短路分支把存量数据逐位锁死。
3. **基准单位要过滤「折算不出来」的**：自定义单位可以没有单件重量，选它当基准后端只能退化成「按克」口径 → 前端候选必须用**与后端同一条解析链**（含嵌套跟随、悬空引用退化）先筛一遍，两端各写一份纯函数 + 单测。
4. **「点进来但没填」与「把已有数据删空」是两种意图**：前者应当静默不记录（否则留下"已保存"的错觉），后者必须提示（避免误清空）。判据要在**打开编辑器的瞬间**记下来（`nutritionHadData`），不能用「当前表格是否为空」。
5. **改了共享函数签名，要一次搜干净所有调用点**：`onSave(List<NutrientEntry>)` → `onSave(List<NutrientEntry>, NutritionBasis)` 牵动 4 个 lib 文件 + 5 个测试文件的假实现/回调（本项目已有同类经验：repo 签名变更要同步测试 fake）。

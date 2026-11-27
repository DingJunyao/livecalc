# 自定义单位支持质量/体积双类型（如 1瓶 = 500 mL）

## 核心方案

`entity_unit_overrides` 的 `weight_per_unit` + `weight_unit_id` 两列已存在且全链路打通（schema / API / 提议执行器 / 导出导入 / web 类型定义），现状只是被默认当克用。方案：**允许 `weight_unit_id` 指向体积单位（mL），即"1瓶 = 500 mL"；折算质量时经实体密度动态换算**。零数据库迁移、零 schema 变更、现有数据（全为质量语义）行为不变。

密度问题：复用既有 `entity_densities` 链——实体记录（AI 填充 / 手动编辑，两端 UI 已有）→ 商品回退关联原料 → **水密度 1000 kg/m³ 兜底**（牛奶误差约 3%，酱油约 15%，可填密度消除）。表单选体积时显示生效密度与折算预览；密度表单增加常见液体快捷预设（水 1000 / 牛奶 1030 / 食用油 920 / 酱油 1150 / 蜂蜜 1420，一键填入可改）。

## 后端（master 分支）

1. `backend/app/services/unit_conversion_service.py`
   - `convert()` §2 实体覆盖分支（~L321-340）：`convert_si` 跨类型失败后补密度桥接——weight_unit 为 volume 且 to_unit 为 mass 时走 `convert_volume_to_mass(total, weight_unit, entity_type, entity_id)` 再 si 换算到目标；对称补 mass→volume 方向。
   - `_get_piece_weight_kg`（~L40-50）：weight_unit 为 volume 时经 `convert_volume_to_mass` 折 kg（entity 上下文入参已有）。
2. `backend/app/services/recipe_service.py` 菜谱营养 count 分支（~L1895-1924）：override 的 weight_unit 为 volume 时经 `UnitConversionService` 密度折克后再算 ratio（现状会落到 ratio=0）。
3. 轻校验：`api/units.py` 实体覆盖 create/update 校验 weight_unit_id（若提供）须为 mass/volume 类型单位。
4. 测试：新增换算用例（体积覆盖→g：有密度 / 水兜底 / 商品回退关联原料；count 兜底路径；菜谱营养 count 体积覆盖）。跑目标用例，全量 pytest 失败需 stash 在 HEAD 对照定责（存量约 30 个）。
5. 存量问题记录到 agent_doc：`/nutrition/*` 单品接口 count 单位按"1单位=1克"算（`nutrition_calculator._convert_to_base` 无实体上下文），本次不动。

## Web 前端（master 分支）

1. `ProductDetail.vue` / `IngredientDetail.vue` 单位覆盖表单：新增"类型"选择（质量·克 / 体积·毫升），提交对应 `weight_unit_id`（页面已加载 units 列表）；选体积时显示密度提示行（当前生效密度 + 折算预览"500 mL ≈ 515 g" + 引导维护密度）。
2. 单位列表展示：体积行显示"1瓶 = 500 mL（≈515 g）"。
3. `EntityUnitOverrideDiff.vue` 审核端显示类型字段。
4. 两页密度编辑对话框：常见液体快捷预设 chips（点击填入数值，可修改）。
5. 本地模式：`api/local/business/unitConverter.ts` 实体覆盖分支补体积密度桥接（已有 mass↔volume 桥结构，L109-117 已有 count→volume 二层链，对齐后端语义）；handlers 透传不变（weight_unit_id 已在类型中）。
6. i18n 三语言文案；验证 vite build + check:i18n（vue-tsc 不可用）。

## 移动端（feat/mobile-app 分支，先合并 master）

1. `mobile/lib/shared/models/entity_unit.dart` 解析 `weight_unit_id`。
2. `entity_units_screen.dart` 表单：质量/体积 SegmentedButton，字段含义联动 + 密度提示；需拉取 `/units/` 获取 mL/g 的单位 id（`profile_repository.dart` 已有同模式调用）。
3. `entity_units_card.dart` 展示体积与 ≈ 克。
4. 密度 Tab 快捷预设 chips（与 web 同组数值）。
5. l10n：`app_zh.arb` 模板 + en/ar，gen-l10n。
6. 验证：flutter analyze 0 issue、全量 flutter test（失败 stash 在 HEAD 对照定责）。

## 分支与提交顺序（按 AGENTS.md）

1. master：后端 + web 完成并提交；
2. merge master → feat/mobile-app；
3. feat/mobile-app：移动端完成并提交；
4. 按"记录要点"规则更新 agent_doc 修复记录。

## 明确不做

- `/nutrition` 单品接口的 count 单位解析（存量问题，仅记录）；
- 废弃 `ingredient_densities` 表 / `ingredients.density` 列的清理；
- `UnitMatcher` 自动建单位行为不变（"瓶"仍是 count 单位，体积语义由覆盖承载）；
- 无 alembic 迁移与 SQL 脚本（未动表结构）。
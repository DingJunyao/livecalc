# FEATURE：自定义单位体积语义与密度折算（1瓶=500mL）

> 2026-10-10。背景：自定义单位（entity_unit_overrides）的"每单位量"此前只有质量语义
> （weight_per_unit 按 g 记录），牛奶/酱油这类按瓶售卖的液体商品数值其实是体积；
> 而密度不易记录（长期靠 AI 填充）。

## 方案

**复用既有列，零表结构变更**：`entity_unit_overrides.weight_unit_id` 在 schema / API /
提议执行器 / 导出导入 / web 类型里早已全链路打通，只是所有消费方都默认它是克。
本次允许 `weight_unit_id` 指向体积单位（mL），即"1瓶=500 mL"；折算质量时经实体密度
动态换算。存量数据（weight_unit_id 全为质量单位）行为不变。

密度复用 `entity_densities` 链：实体自身记录 → 商品回退关联原料 → **水密度
1000 kg/m³ 兜底**（`UnitConversionService.get_density`）。牛奶误差约 3%、酱油约 15%，
填密度可消除；两端密度编辑 UI 已有（web 完整、移动端 density+condition）。

## weight_unit_id 消费点全景（本次改动的 6 处）

| 消费点 | 文件 | 改动 |
|---|---|---|
| 换算核心·实体覆盖分支 | `backend/app/services/unit_conversion_service.py` | 新增 `_convert_override_weight`：同类型走 si_factor，体积↔质量经 `convert_volume_to_mass/mass_to_volume` 密度桥接 |
| 换算核心·count 兜底 | 同上 `_get_piece_weight_kg` | weight_unit 为 volume 时经密度折 kg（防 §2 未命中时回退 100g/个 的错误兜底） |
| 菜谱营养 | `backend/app/services/recipe_service.py` count 分支 | override 的 weight_unit 为 volume 时经 `ucs.convert(..., "g")` 密度折克（原逻辑落到 ratio=0 静默归零） |
| 提议执行器 | `backend/app/services/proposals/executors/entity_unit_override.py` | validate 校验 weight_unit_id 须为 mass/volume 单位 |
| web 本地模式 | `frontend/src/api/local/business/unitConverter.ts` | 新增共享 `resolveOverrideGramsPerUnit`（体积 wu 经密度、无密度水兜底；wu 解析 name 优先容错云端 id 错位），count 分支重构接入；`priceNormalize.resolveWeightGrams`、`costCalculator.findCostCountGrams` 委托同一实现 |
| web 详情页/审核端 | `ProductDetail.vue` / `IngredientDetail.vue` / `EntityUnitOverrideDiff.vue` | 表单类型切换（质量 g / 体积 mL）+ 生效密度折算提示行；列表体积行显示 "500 mL（≈515 g）"（商品页额外拉关联原料密度保证提示准确）；审核端 diff 用单位缩写替代裸 id |

## 密度录入降门槛

两端密度表单加**常见液体预设**（一键填入可改）：
水 1000 / 牛奶 1030 / 食用油 920 / 酱油 1150 / 蜂蜜 1420 kg/m³（web 表单支持
g/cm³↔kg/m³ 切换，预设按 g/cm³ 值填入；移动端固定 kg/m³）。

## 移动端（feat/mobile-app 4c15d9e）

- `EntityUnit` 模型解析 `weight_unit_id`，新增 `isVolumeWeight`（provider 拉取
  `/units/` 全局单位表标注）+ `copyWith`。
- provider（product/ingredient 同构）：`_ensureGlobalUnits` 缓存 g/mL 单位 id 与
  体积单位 id 集；`_computeEffectiveDensity`（自身>关联原料，null 时 UI 水兜底）；
  写入时 `UnitWeightKind` → `weight_unit_id`；pending 草稿叠加同步合并 weight 字段。
- 维护页：`SegmentedButton`（质量 g / 体积 mL）+ 体积密度提示（随输入实时更新）；
  列表与卡片体积行显示 ≈g；密度 Tab 预设 chips。

## 验证

- 后端：新增 `tests/services/test_volume_weight_override.py` 6 用例（体积覆盖有密度
  515g / 水兜底 500g / 商品回退关联原料密度 257.5g / `_get_piece_weight_kg` 体积分支
  / 质量语义回归 / 菜谱营养 54kcal×5.15=278.1）；存量失败 stash 对照确认与本次无关。
- web：vite build + check:i18n（keys/sources）通过。
- 移动端：flutter analyze 0 issue；全量 flutter test 565 通过，6 失败（apple_map×3、
  locale×2、my_proposals×1）经 stash 在 HEAD 复跑确认为存量。

## 已知存量问题（本次未动）

1. **/nutrition/* 单品接口 count 单位按"1单位=1克"算**：
   `nutrition_calculator._convert_to_base`（backend/app/services/nutrition_calculator.py）
   依赖废弃的 `unit_converter.convert_to_standard`，无实体上下文，"瓶"不在转换表时
   base_quantity=1 直接当克 → 按 100g 基准的 1% 计算。菜谱营养链路（recipe_service）
   本次已修，单品接口需给 NutritionCalculator 增加实体上下文的单位解析后另行对齐。
2. 废弃存储未清理：`ingredient_densities` 表（recipe_service 营养 ml 分支还在用，
   查不到按 1.0 g/mL）、`ingredients.density` 列（仅导出/回显）。
3. `ingredient_extended.py` 旧换算端点调用 `UnitConversionService` 上不存在的
   `convert_volume_to_weight/convert_weight_to_volume` 方法（现名 convert_volume_to_mass/
   convert_mass_to_volume），命中即 500——独立 bug，待修。
4. 商家列表体积记录按元/L 直出（merchants.py `standard_unit_type==volume` 分支），
   与质量口径（元/斤）并存展示，未参与本次密度折算。

## 经验

1. 两端共享的语义字段扩展前，先 grep 全部消费点再动手——weight_unit_id 的消费方
   （换算核心、count 兜底、价格聚合、成本、营养、审核 diff）有 6 处各自独立实现，
   漏一处就是静默错数。
2. 营养链路 count 分支的 `ratio=0` 静默归零比给出错误数值更隐蔽；语义改动要用
   改前/改后数值对照验证。
3. Flutter l10n：`@key` 占位符元数据的**声明顺序**决定生成方法签名的参数顺序，
   消息串里的出现顺序不作数；analyze 查不出 Object 位置参数传反，需人工核对签名。
4. 本地模式三处独立实现（unitConverter/priceNormalize/costCalculator）对 weight
   单位的解析口径曾有细微差异（si_factor≤0.1 启发式 vs name 优先），本次统一到
   name 优先共享实现，与后端字面读 weight_unit_id 的行为一致。

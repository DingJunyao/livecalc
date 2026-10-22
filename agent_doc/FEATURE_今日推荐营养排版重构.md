# 今日推荐汇总与三餐卡片营养排版重构（web + 移动端）

## 需求

- 今日推荐（汇总条 + 三餐卡片）去掉「热量目标」及其进度条。
- 汇总排版改为：一行「预估成本」+ 4 列营养素（能量 / 蛋白质 / 脂肪 / 碳水，各带 NRV%）；窄屏 / 窄容器折成 2×2。
- 三餐卡片同样处理。

## web（frontend）

- 新增 `frontend/src/components/meals/NutrientSummaryGrid.vue`：营养素四宫格。用 **CSS 容器查询**（`container-type: inline-size` + `@container (min-width: 480px)` 切 4 列，否则 2×2；`@supports not` 时按视口 600px 兜底），餐卡在宽屏页面里也能按自身宽度折叠，而不是只看视口。
- `DailySummaryBar.vue`：删除 `goalProgress` / `v-progress-linear` 进度条与热量目标逻辑；改为成本一行 + `NutrientSummaryGrid`；删掉三语 `meals.calorieGoal` 文案键。
- `MealCard.vue`：方案餐、多道菜套餐、单道菜兼容三条路径的合计营养全部换成「成本行 + 宫格」（`dishNutrientItems` / `planNutrientItems`）。顺带修复单道菜兼容路径模板引用了不存在的 `nutritionSummary`（脚本里从未定义）的隐患。

## 移动端（mobile，feat/mobile-app 分支）

- 新增 `mobile/lib/features/home/widgets/nutrient_grid.dart`：`NutrientGrid`（Table 实现，固定 2 列 = 2×2）。
- `home_screen.dart` 汇总条：成本一行（图标 + 标签 + 加粗金额）+ `NutrientGrid` 四项（含 NRV%），去掉原 Wrap 混排。
- `meal_card.dart`：`_buildTotalsFooter` 四行营养素改宫格；单道菜兼容分支的 Wrap chips 也改为成本行 + 宫格。

## 追加：NRV 单独一行

数值与 NRV% 同行会挤在一起，改为每个宫格条目三行：标签 → 数值 → `NRV x%`（灰色 caption）。web 宫格条目增加 `nrv?: string` 字段，`DailySummaryBar` 与 `MealCard` 构造时拆开传；移动端 `NutrientGridItem` 增加 `nrv` 字段，`nutrient_grid.dart` / `home_screen` / `meal_card` 同步。NRV 文案统一为 `NRV 62%`（去掉括号）。验证：前端 build ✓、`flutter analyze` No issues found、meal_card 2 passed。

## 验证

- `pnpm --dir frontend run build` ✓（19s，PWA precache 187）；`pnpm run check:i18n` ✓。
- `flutter analyze`：仅剩既有 1 条提示；`flutter test test/features/home/meal_card_test.dart` 2 passed。

## 注意

- 用 PowerShell 改 JSON 时曾因默认编码把三份 locale 写成乱码，已 `git checkout` 还原后改用 `[System.IO.File]::ReadAllText/WriteAllText` 显式 UTF-8（无 BOM）重做；diff 每文件仅 1 行（删 `calorieGoal`）。

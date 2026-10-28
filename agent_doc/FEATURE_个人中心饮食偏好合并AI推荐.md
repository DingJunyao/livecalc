# 个人中心：AI 推荐设置并入「饮食偏好」

## 需求

- 个人中心页底部独立的「AI 推荐」卡片移到「饮食偏好」对话框里（设置项归位，减少首页纵向堆叠）。
- 顺带复查「每日营养目标与预算」是否仍被使用（结论：都在用，见下）。

## 现状与根因

- `ProfileView.vue` 原本有两块设置：
  1. 列表项「饮食偏好」→ `nutritionDialog`（每日热量/蛋白质/碳水/脂肪 + 每日预算）。
  2. 列表之后的独立 `v-card`「AI 推荐」（推荐方式 / BYOK 提供商 / 模型 / 端点 / API 密钥），只在云端模式显示。
- 「每日预算」标签硬编码「元」，与用户默认币种不一致。

## 改动

### Web（`frontend/src/views/profile/ProfileView.vue`）

- 删除页底独立「AI 推荐」卡片，把其表单原样搬进「饮食偏好」对话框：
  - 对话框宽度 480 → 560，加 `scrollable`；营养目标区块下加 `v-divider` + 「AI 推荐」小标题。
  - AI 区块仍 `v-if="!isLocalMode"`（本地模式继续走「设置 · AI 配置」）。
  - 字段排布改为 `cols="12" sm="6"`，端点与 API 密钥独占整行；密钥清除按钮、系统 AI 提示、隐私说明保留。
- 保存合并：对话框底部单个「保存」→ `saveDietPreferences()`：
  1. `PATCH /auth/me` 保存营养目标与预算（与原来完全一致）；
  2. 云端模式且 `aiChanged` 为真时再 `PUT /profile/ai-settings`（沿用 `saveAiSettings()`）；
  3. `userStore.fetchUser()` 后关闭对话框。
  - 按钮 loading 合并 `savingNutrition || aiSaving`。
- 打开对话框时在云端模式刷新一次 AI 设置（`loadAiSettings()`），与营养表单每次打开重读 userStore 的语义一致。
- 每日预算标签改为 `t('profile.dailyBudget', { currency: userCurrency })`，跟随用户默认币种，不再写死「元」。

### i18n（zh-CN / en-US / ar 三套语料同步）

- `profile.nutritionSubtitle`：每日营养目标与预算 → 每日营养目标、预算与 AI 推荐方式
- `profile.nutritionDescription`：说明用于「AI 推荐排序与试算目标对比」，并可在此选择 AI 推荐方式
- `profile.dailyBudget`：`每日预算 (元，留空不限)` → `每日预算 ({currency}，留空不限)`

### 文档

- `docs/profile.md` 饮食偏好：补「AI 推荐方式」条目、预算按默认币种填写、以及与「试算页合计 vs 目标」的关系。
- `docs/README.md` 个人中心索引行补「AI 推荐方式」。

## 「每日营养目标与预算」是否还有用（复查结论）

仍在用，不能删：

| 值 | 消费方 | 位置 |
| --- | --- | --- |
| `daily_calorie/protein/carb/fat_target` | AI 一餐推荐短名单打分（`_get_meal_targets` → `_calc_nutrition_score`） | `backend/app/services/meal_recommender.py` |
| `daily_budget` | AI 推荐成本分（`_calc_cost_score`，未设时中性 0.5） | `backend/app/services/meal_recommender.py` |
| 四项目标 + 预算 | 试算求值 `targets` / `deltas` → Web `PlanDetailView`「合计 vs 目标」、移动端 `PlanTotalsGrid` | `backend/app/services/meal_plan_service.py` |

- 「今日推荐」页面本身不显示目标数值，目标只影响排序打分；**试算页详情**才会展示「合计 / 目标」。
- 发现的不一致（未在本次改动范围内，待确认是否补）：
  - 移动端「营养目标」页只有 4 个营养目标，**没有每日预算**输入（`mobile/lib/features/profile/screens/nutrition_goals_screen.dart`）；
  - 移动端没有 AI 推荐方式设置项。

## 验证

- `npm run build`（master worktree）✓ 31.6s
- `npm run check:i18n` / `check:i18n:sources` ✓
- `npm run test:utils` 73 passed ✓
- 合并回 feat/mobile-app 后再 `npm run build` ✓ 37.8s

## 分支

- master `e52c61df` → 合入 feat/mobile-app（merge `ec2456c4`）。

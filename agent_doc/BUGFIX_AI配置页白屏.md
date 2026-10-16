# AI 与机翻配置页打不开（配置序列化丢掉 meal_plan / ai_policy 区块）

## 现象

后台「AI 与机翻配置」页（`/admin/ai-config`，`AiConfigView.vue`）整页渲染失败，控制台：

```
AiConfigView.vue:108 [Vue warn]: Unhandled error during execution of render function
  ... at <VExpansionPanelText>
AiConfigView.vue:257 Uncaught (in promise) TypeError:
  Cannot read properties of undefined (reading 'allow_user_choice')
```

`allow_user_choice` / `provider` 是 `config.ai_policy` / `config.meal_plan` 的字段，说明前端拿到的
配置对象里**根本没有这两个区块**。

## 根因（端到端数据流逐层追踪）

配置是单行 JSON（`translation_configs.config`），含四个顶层区块：
`ai` / `machine` / `meal_plan` / `ai_policy`（后两者由 AI 一餐推荐与 AI 使用策略引入）。

| 层 | 实际行为 | 结论 |
| --- | --- | --- |
| DB | 开发库该行**确实存了** `ai`、`machine`、`meal_plan`、`ai_policy`（`meal_plan.provider = openai`） | ✅ 数据在 |
| 序列化 | `TranslationConfig.to_dict()` 硬编码只回 `{ai, machine}` | ❌ **丢区块** |
| API | `GET /api/v1/admin/translation-config` 返回 `get_stored_translation_config(db).to_dict()`，即只有 `ai`/`machine` | ❌ 前端拿不到 `ai_policy` |
| 前端 | 模板直接 `v-model="config.ai_policy.allow_user_choice"`、`v-model="config.meal_plan.provider"` | ❌ 渲染期抛 TypeError → 整页白屏 |

同一个 `to_dict()` 还是**第二个隐性 bug**的源头：`app/services/ai_policy.py` 的
`get_policy()` / `get_meal_plan_cfg()` 也走 `row.to_dict()`，于是管理员在页面上保存的 AI 使用策略
（BYOK 开关、每日上限、餐食推荐 provider）**服务端永远读不到**，一直按代码默认值执行。

外加 `_merge_default_config()` 的旧写法有两个坑：

1. `for region in ("ai","machine")` 里 **整块替换** provider 字典 → 存量里没写的默认字段被抹掉；
2. `if key not in merged: merged[key] = value` → `meal_plan` / `ai_policy` 因为**默认里已经存在**这个
   判据，存储值被当成「未知键」的反面丢弃 → 每次 GET 都把策略读成默认值，并在
   `get_stored_translation_config()` 里**提交回写**，等于每次都悄悄回滚管理员保存的策略。

## 修复

### 后端

- `backend/app/models/usda.py`：`TranslationConfig.to_dict()` 改为返回**整份**配置
  （深拷贝 + `setdefault` 保证 `ai` / `machine` 仍在，翻译链路 `find_provider_section` 不受影响）。
- `backend/app/api/usda_admin.py`：
  - 新增 `_deep_merge()`；`_merge_default_config()` = `deepcopy(DEFAULT_TRANSLATION_CONFIG)` 再递归合并存储值
    → 默认值补齐、**存库值优先**，`meal_plan` / `ai_policy` 不再被回滚。
  - `PUT /admin/translation-config` 改为把入参**递归合并**进当前配置，而不是整份替换：
    旧前端（只提交 `ai`/`machine`）保存时不会再抹掉其它区块。

### 前端

- 新增 `frontend/src/utils/translationConfig.ts`：`DEFAULT_TRANSLATION_CONFIG`（与后端逐字对齐）+
  `deepMergeConfig()` + `normalizeTranslationConfig()`（纯函数，无框架依赖）。
- `AiConfigView.vue`：`onMounted` 取回配置后过一遍 `normalizeTranslationConfig()`，
  缺区块按默认补齐 —— 即使后端/存档结构落后，页面也不会白屏。
- `frontend/src/api/local/handlers/admin.ts`（本地模式 IndexedDB 同款接口）：
  默认结构换成同一份 util（原来只写 `ai`/`machine`，**本地模式同样是白屏的**）；
  `updateTranslationConfig` 改为与存档递归合并后再写回。

**无需数据库迁移**：数据本来就在库里，只是序列化层丢了。

## 验证

- 后端新增 3 例（`backend/tests/test_usda_admin_api.py`）：
  GET 带 `meal_plan`/`ai_policy`；策略与餐食 provider 存取往返 + `get_policy()`/`get_meal_plan_cfg()`
  读到存库值；**旧客户端只提交 `ai` 时其余区块与缺省字段都不丢**。
  `pytest tests/test_usda_admin_api.py tests/models/test_usda_models.py` → 12 passed。
- 前端 `test:utils` 新增 `src/utils/translationConfig.test.ts` 4 例（缺失区块补齐 / 已存值优先 + 未知键保留 /
  空值取默认 / 合并不修改入参）→ 66 passed；`npm run build` ✓、`npm run check:i18n` ✓（三语 key 树一致）、
  `npx tsc --noEmit` 无新增错误（137 条 = 存量基线，其中 48 条是 `.vue` 无法解析的既有盲区）。
- 开发库只读核对：`stored keys = [ai, ai_policy, machine, meal_plan]`；
  `to_dict()` 现在返回同样四个键；`_merge_default_config()` 保住了
  `meal_plan.provider = openai` 与用户自定义的 deepseek `base_url`。

## 经验

1. **表的 JSON 列里有数据 ≠ API 有数据**：序列化层（`to_dict`）是最容易被写死的地方，
   加了新顶层区块必须同步改它，否则「前端崩 + 服务端读默认值」两个 bug 一起发生，且都没有日志。
2. **`if key not in default: keep` 这种「保留未知键」的判据救不了「默认里新增过的键」**——
   要表达「存库值优先」，只能用递归合并（`default ← stored`），不能用成员判断。
3. **PUT 用整份替换**时要警惕客户端结构落后：一旦前端拿到的旧结构被回写，服务端就永久丢数据。
   合并写更安全。
4. 前端对「后加的配置区块」要做归一化兜底（默认值 + 深合并），否则服务端一次序列化疏忽就是整页白屏。
5. 本地模式（IndexedDB）与云端各有一份默认结构，**两边都要改**，且最好共用同一份 util。

## 遗留 / 后续

- 分支：本次改动落在 `feat/mobile-app` 工作区，但按仓库规则 web/后端修复应先落 `master`
  再同步到 feat 分支（待用户确认后再搬运）。
- 顺手发现（**未修**，与本 bug 无关）：`backend/tests/test_usda_api.py` 的两个
  `match/*` 用例缺 `register_all()` fixture（TestClient 不触发 lifespan），
  单跑该文件即失败（400 != 200/404），属存量基线。

## 追加：「组合模型 provider」下拉要跟着开关实时变（同日第二轮）

用户反馈：`餐食推荐（AI 组合）` 里的「组合模型 provider」选项应当**随上方 AI provider 的启用开关
实时变化**，而不是写死一份 provider 清单。

原实现是 `:items="MEAL_PROVIDERS"`（写死的 `claude_code/codex/openai/anthropic` 四项），
与上方开关的状态毫无关系 —— 停用的 provider 照样能选，选了之后后端 `_global_ai_section()`
因为 `enabled=false` 返回 `None`，推荐**静默降级为规则组合**，页面上什么都看不出来。

改为（`AiConfigView.vue`）：

- `enabledMealProviders`：白名单 ∩ `config.ai.providers[key].enabled`（**未保存的勾选也立刻生效**，
  computed 依赖的是同一份响应式 config）；本地模式再收窄到浏览器可直连的 `openai/anthropic`
  且要求已填 `api_key`/`base_url`（与 `utils/agentProviders.ts` 的 `enabledProviderOptions` 同口径，
  也与本地组合器 `resolveLocalAi()` 的判定一致）。
- `mealProviderItems`：选项 = 上面这份清单，标题复用 provider 卡片的 i18n 标题；
  **当前已保存的选择若未启用，仍保留一条并标注「（未启用）」**，避免下拉值凭空消失被静默改掉。
- `mealProviderDisabled`：所选 provider 未启用时在下方显示警示文案
  （`adminAI.mealPlanProviderDisabledHint`，三语），说明会降级为规则组合、要去开关里启用。
- 新增 i18n：`adminAI.mealPlanProviderDisabled`（含括号/空格，交由各语言自带标点）、
  `adminAI.mealPlanProviderDisabledHint`；`mealPlanProviderHint` 文案改为「只列出已启用的 provider」。

取舍：**没有**改成「列出全部四项再把未启用的灰掉」。用户的要求是「选项要随开关实时变化」，
所以选项集合本身要变；但为了不丢用户已保存的值，给当前选择留了一条带标注的例外项。

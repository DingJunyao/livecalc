# FEATURE: AI 一餐推荐（阶段 2 后端）

- **日期**：2026-10-15
- **分支**：master（后端）；2B（web + 本地模式）与 2C（移动端）待做
- **关联**：设计 [docs/plans/2026-10-15-favorites-ai-meals-planner-design.md](../docs/plans/2026-10-15-favorites-ai-meals-planner-design.md) §4；实现计划 [docs/plans/2026-10-15-ai-meals-backend-implementation.md](../docs/plans/2026-10-15-ai-meals-backend-implementation.md)
- **提交**：674bcf59（数据层）/ 5f3653a9（策略层）/ 91529c37（组合层）/ 4b359b66（推荐重写 + API）

## 需求

旧推荐「每餐 1 道、绝大多数没有主食、调料/饮料会进午晚池」不可用。新设计：一餐 = 多道菜套餐（1-4 道，**≥1 主食**；主食自足型可单独成餐），AI 从现有菜谱池组合并给理由，规则兜底；支持一句话偏好、整餐重搭 + 单道换、7 天去重；配套**通用 AI 使用策略层**（全局/用户级方法、BYOK、每日上限、用量留痕，为对外服务与商业化预留）。

## 架构

```
候选池（分类口径 + 黑名单 + 近7天去重，放宽链 7→3→0）
  → 确定性打分（0.5 营养 + 0.5 成本 + 收藏 0.1，封顶 1.0）
  → 分类 top-K 短名单（主食 8/荤 6/素 6/水产 4/汤 4；早餐：早 8/主食 6/汤 4）
  → meal_composer（LLMMealComposer 经 Translator 通道 | RuleMealComposer）
  → 校验器（≥1 staple / id∈短名单 / 1-4 道 / 无重复 / 午晚 staple 必须「主食」分类；
    失败回灌重试 1 次 → 规则降级）
  → 落库（daily_recommendations 父行 + daily_recommendation_items 子表）
```

- **`services/meal_composer.py`**：纯函数校验器 + 两个组合器；`LLMMealComposer(complete)` 的模型调用抽象为可注入 callable（生产 = Translator 通道 `get_translator(provider, section, timeout).translate_batch([user], system_prompt=system)`，测试注入假实现）。
- **`services/ai_policy.py`**：`resolve_ai_credentials`（用户 method → 全局 default → rule；BYOK 的 base_url 受 `allow_custom_base_url` 约束）、Fernet 加密（key=sha256(SECRET_KEY)）、每日上限（`ai_usage_events` 中 method=system_ai 且 status∈{ok,fallback} 计数；用户级 override 优先）、`record_usage`。
- **存储**：父表加 `reason/preference/source/refresh_count`、删 `recipe_id`；子表 `daily_recommendation_items(recommendation_id, recipe_id, sort_order, role, reason)`；`user_ai_settings`（user 唯一，api_key_enc 密文）；`ai_usage_events`。
- **刷新**：整餐重搭（排除当前餐全部）与单道换（`recipe_id` 给定，保留 sort_order，换 staple 则新道也 staple）共享每餐 5 次上限——**读 `refresh_count` 列**（修复旧「行数-1」口径从未生效的 bug）。
- **响应兼容**：`recommendations[].dishes[]` 为完整套餐（RecipeBrief + role + reason）；`recipe` 保留为别名（staple 或首道），旧前端不断。

## 配置（translation_configs 新增区块）

- `meal_plan`: `{provider: claude_code, timeout_seconds: 120}`（provider 白名单 openai/anthropic/claude_code/codex）
- `ai_policy`: `{default_method: system_ai, allow_user_choice: true, allow_byok: true, allow_custom_base_url: false, daily_ai_limit: 20, show_ai_badge: true}`

`_merge_default_config` 已修复为**保留未知顶层区块**（否则 PUT 回写会丢掉这两个块）。

## 端点

- `GET/PUT /api/v1/profile/ai-settings`（管理员可 `?user_id=` 代理；api_key 只回显打码；`DELETE .../api-key` 清除）
- `POST /api/v1/meals/recommendations/generate`（可选 body `{preference}`）
- `POST /api/v1/meals/recommendations/refresh`（body `{meal_type, recipe_id?, preference?}`）
- AI 文案语言随 `Accept-Language`（zh/en/ar），生成时快照落库。

## 迁移与存量库 ⚠️

- alembic `20261015_0002`（down_revision=20261015_0001）。
- **开发/存量库必须手工执行** `backend/scripts/sql/20261015_recommendation_items_{sqlite,mysql,postgresql}.sql`（列变更 create_all 不覆盖；新表会由启动 create_all 建）。**未执行前，运行中的后端推荐接口会 500**（缺 source/refresh_count 等列）。

## 测试（57 项相关回归全绿）

- `test_meal_recommendation_items`（数据层）/ `services/test_ai_policy`（加密/解析/上限）/ `test_ai_settings_api`（端点/权限/打码）/ `services/test_meal_composer`（校验器 9 例：无主食/越界/重复/道数/排除/单道 role 交叉/规则结构/提示词）/ `test_meal_recommendation_rework`（端到端：假 LLM 落库 system_ai + 兼容别名 + 偏好快照 + ok 事件；坏输出降级 rule + fallback 事件；5 次上限真实生效 + 单道换保持 staple；去重放宽链）/ 旧 `test_meal_recommendation_route`（同步路由约定 + 409 文案）适配。
- **真实 claude_code CLI 超时降级链路被意外端到端验证**（测试早期未 mock 时，3 餐各等 120s 超时后全部规则兜底、无 500）。

## 经验（踩坑）

1. **测试假通过 2.0**：服务层直调 + 假 LLM 注入是测推荐逻辑的唯一稳态路径——走 API + 后台线程 + 轮询会撞上 **StaticPool 单连接**（轮询请求读到后台事务未提交的中间 flush 状态），产生「父行已见、items 未插完」的幻读断言失败。
2. **批量 `query.delete()` 不触发 ORM cascade**：删父行后孤儿 item 仍在；SQLite rowid 复用会让新父行复用被删 id、孤儿「挂尸」到新记录上（表现为同餐重复菜）。清理必须连子表一起删。
3. **跨测试共享内存库的残留三件套**：AI 设置行（改变凭据解析路径）、用量事件（改变计数断言）、当日推荐行（改变 ready 判定）——每个测试文件的公共准备里显式清空本用户相关行。
4. **conftest 的 FakeUser 要补齐服务层读到的属性**（daily_* 目标），否则后台线程 AttributeError 且只留一行日志。
5. **默认策略 = claude_code 意味着测试默认会拉起真实 CLI**：不 mock `resolve_ai_credentials` 的测试必须显式强制 rule，否则每餐等 120s 超时（全量 26 分钟的元凶）。
6. `_merge_default_config` 类「默认合并」函数必须保留未知顶层键，否则前端 PUT 回写会静默丢掉后续新增的配置区块。
7. 提示词 system 部分自身含空行时，不能用「空行 partition」拆分 system/user——builder 直接返回元组。

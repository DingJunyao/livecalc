# AI 一餐推荐（阶段 2A：后端）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 后端推荐从「每餐 1 道」升级为「多道菜套餐（≥1 主食）」：池口径收窄、7 天去重、确定性短名单、可插拔组合层（规则 + LLM，经现有 Translator 通道）、一句话偏好、整餐重搭 + 单道换、修复刷新上限失效 bug，以及通用的 AI 使用策略层（全局/用户级方法、BYOK、每日上限、用量留痕）。

**Architecture:** 新服务 `meal_composer.py`（`MealComposer` 协议 + `RuleMealComposer` + `LLMMealComposer` + 纯函数校验器）；新服务 `ai_policy.py`（凭据解析 + Fernet 加密 + 每日上限 + 用量事件）；`meal_recommender.py` 保留编排/落库/后台线程，选取逻辑改为「池 → 短名单 → 组合 → 校验 → 降级」。存储改父表 + 子表（`daily_recommendation_items`），父表加 `reason/preference/source/refresh_count` 并删除 `recipe_id`。**响应向后兼容**：`recipe` 字段保留（取 staple/首道菜），新增 `dishes` 数组，现有 web/移动端不断。

**Tech Stack:** FastAPI + SQLAlchemy + Alembic（三引擎 SQL）；cryptography.Fernet（已是依赖）；Translator 通道（`get_translator` + `translate_batch`，claude_code/codex/openai/anthropic 四 provider 配置在 DB `translation_configs`）。

**Spec:** `docs/plans/2026-10-15-favorites-ai-meals-planner-design.md` §4（决策清单 #2-#8、#17-#21）

## Global Constraints

- 分支：`master` 先行，完成后合并 `feat/mobile-app`。
- 测试：`cd backend && /home/ding/code/livecalc/.venv/bin/python -m pytest <files> -v`；不跑全量（网络用例卡死，见 memory）；基线失败不新增。
- **不直接改开发库**（AGENTS.md 约束）。本迁移含**列变更**（create_all 不会补列），完成后必须把 `backend/scripts/sql/20261015_recommendation_items_sqlite.sql` 交用户执行（或用户明确允许后代跑）。
- 新表（`daily_recommendation_items`/`user_ai_settings`/`ai_usage_events`）由启动 `create_all` 自动建，无此问题。
- 测试假仓库/假 provider 注入：LLM composer 的模型调用抽象为可注入 callable。

## Review Focus

1. **池不足**：菜谱很少的用户，7 天去重后池为空 → 放宽链必须兜底（7→3→0），任何用户都能出餐。
2. **LLM 坏输出**：非 JSON / 越界 id / 无主食 → 回灌重试 1 次 → 规则降级，绝不 500。
3. **每日上限**：`system_ai` 超限后自动走规则且 UI 可感知（source=rule），BYOK 不受限但仍记事件。
4. **刷新上限**：修复后「5 次/餐/天」真实生效；首次生成不算刷新。
5. **向后兼容**：旧前端读 `recipe` 字段必须继续工作（取 staple 或首道）。

---

### Task 1: 模型与迁移（items 表 + 父表列 + AI 策略表）

**Files:**
- Modify: `backend/app/models/daily_recommendation.py`（父表新列 + items 关系；删 `recipe_id`）
- Create: `backend/app/models/daily_recommendation_item.py`
- Create: `backend/app/models/user_ai_settings.py`、`backend/app/models/ai_usage_event.py`
- Modify: `backend/app/models/__init__.py`（注册三个新模型）
- Modify: `backend/app/models/user.py`（加 `ai_settings` 关系，可选）
- Create: `backend/alembic/versions/20261015_0002_recommendation_items_ai_policy.py`
- Create: `backend/scripts/sql/20261015_recommendation_items_{sqlite,mysql,postgresql}.sql`
- Test: `backend/tests/test_meal_recommendation_items.py`

父表新列：`reason TEXT NULL`、`preference String(200) NULL`、`source String(20) NOT NULL DEFAULT 'rule'`、`refresh_count Integer NOT NULL DEFAULT 0`；删除 `recipe_id`（batch 模式）。
子表：`id / recommendation_id FK daily_recommendations (index) / recipe_id FK recipes (index) / sort_order Integer NOT NULL DEFAULT 0 / reason TEXT NULL`。
`user_ai_settings`：`id / user_id FK unique / method String(20) NULL('rule'|'system_ai'|'user_ai') / provider String(20) NULL / base_url String(200) NULL / api_key_enc String(500) NULL / model String(100) NULL / daily_ai_limit_override Integer NULL / created_at / updated_at`。
`ai_usage_events`：`id / user_id FK (index) / scope String(40) / method String(20) / provider String(20) NULL / status String(20) / created_at (index)`。

迁移要点：`op.batch_alter_table` 兼容 SQLite；回填 `INSERT INTO daily_recommendation_items (recommendation_id, recipe_id, sort_order) SELECT id, recipe_id, 0 FROM daily_recommendations WHERE recipe_id IS NOT NULL`（三引擎通用 SQL）→ 再删 `recipe_id`；全部步骤带存在性守卫（`_has_column`/`_has_table`/`_has_index`）。

**测试**：内存库 `create_all` 后——父表无 `recipe_id` 属性；子表可插入并随父查询；`refresh_count` 默认 0；（迁移 SQL 的语法在三引擎脚本评审时核对，alembic 链用 `alembic heads` 验证单头）。

### Task 2: AI 使用策略层（ai_policy.py + 端点）

**Files:**
- Create: `backend/app/services/ai_policy.py`
- Modify: `backend/app/api/usda_admin.py`（`DEFAULT_TRANSLATION_CONFIG` 加 `meal_plan` / `ai_policy` 块；`_merge_default_config` 合并未知顶层块）
- Create: `backend/app/api/ai_settings.py`（用户 + 管理员端点）
- Modify: `backend/app/main.py`（挂载 `/api/v1/profile/ai-settings`）
- Test: `backend/tests/services/test_ai_policy.py`、`backend/tests/test_ai_settings_api.py`

`ai_policy.py`（核心接口）：
```python
def _fernet() -> Fernet  # key = urlsafe_b64encode(sha256(settings.jwt_secret_key))
def encrypt_api_key(plain: str) -> str
def decrypt_api_key(enc: str) -> str
def mask_key(plain_or_enc: str) -> str  # 前4后4，短值全掩
DEFAULT_MEAL_PLAN = {"provider": "claude_code", "timeout_seconds": 120}
DEFAULT_AI_POLICY = {"default_method": "system_ai", "allow_user_choice": True,
                     "allow_byok": True, "allow_custom_base_url": False,
                     "daily_ai_limit": 20, "show_ai_badge": True}
def get_policy(db) -> dict            # translation_configs 单行 JSON 读取 + 默认合并
def resolve_ai_credentials(db, user, scope="meal_plan") -> dict
  # {"method": "rule"} 或 {"method": "system_ai"|"user_ai", "provider", "section", "timeout"}
  # 解析顺序：用户 method（在允许范围内）→ 全局 default_method → rule
  # system_ai：provider 取 meal_plan.provider，section 取 translation_configs ai.providers[name]
  # user_ai：provider/section 由 user_ai_settings 构造（base_url 受 allow_custom_base_url 约束）
def count_today_system_ai_usage(db, user_id, scope="meal_plan") -> int
def record_usage(db, user_id, scope, method, provider, status)  # 自行 commit
def system_ai_limit_reached(db, user, policy) -> bool  # override > 全局 daily_ai_limit
```

端点（登录；管理员可带 user_id）：
- `GET /api/v1/profile/ai-settings?user_id=`（非管理员强制自己）→ `{method, provider, base_url, model, api_key_masked, has_api_key, daily_limit_override, policy}`（policy 一并返回供前端隐藏不允许的选项）
- `PUT` body `{method?, provider?, base_url?, model?, api_key?（空串=不改，null=清除）, daily_limit_override?}`；管理员改他人需 `is_admin`；违反 allow flags 400。

### Task 3: 池口径 + 去重放宽 + 短名单 + 收藏加权（meal_recommender 改造·上）

**Files:**
- Modify: `backend/app/services/meal_recommender.py`
- Test: `backend/tests/test_meal_shortlist.py`

- 池常量：`MEAL_POOL_CATEGORIES = {"breakfast": ["早餐","主食","汤与粥"], "lunch"/"dinner": ["主食","荤菜","素菜","水产","汤与粥"]}`；`_get_candidate_pool` 改 `category.in_(...)`。
- 去重窗口：`_recently_recommended_ids(db, user_id, today, days)`（items ⨝ 父表，date >= today-days+1）；`_get_candidate_pool` 加 `dedup_days` 参数由调用方按 7→3→0 放宽。
- 打分加收藏：`score = min(1.0, 0.5n + 0.5c + (0.1 if recipe_id in favorite_ids else 0))`；`favorite_ids` 一次查询 `user_favorites(entity_type='recipe')`。
- `_build_shortlist(db, user, meal_type, exclude_ids, favorite_ids)` → 按分类 top-K（主食 8/荤 6/素 6/水产 4/汤 4；早餐模式：早餐 8/主食 6/汤 4）条目 `{id,name,category,cost_estimate,currency,nutrition_per_serving,total_time_minutes,is_favorite,has_favorite_ingredient,top_ingredients}`。
- `_count_today_refreshes` 改读 `refresh_count` 列（每餐一行）。

### Task 4: 组合层（meal_composer.py：校验器 + 规则 + LLM）

**Files:**
- Create: `backend/app/services/meal_composer.py`
- Test: `backend/tests/services/test_meal_composer.py`

```python
@dataclass
class ComposedDish: recipe_id: int; role: str; reason: str|None
@dataclass
class ComposedMeal: dishes: list[ComposedDish]; note: str|None; source: str  # system_ai|user_ai|rule

def validate_composition(raw: dict|str, shortlist, meal_type, exclude_ids, require_single_role=None) -> list[str]
  # 错误清单（空=通过）：JSON 解析 / 结构 / id 越界 / 重复 / 1..4 道(单道=1) /
  # ≥1 staple / 午晚 staple 的 category=="主食" 且 category=="主食"必须标 staple /
  # 排除集命中 / 单道换时 role 必须等于 require_single_role

class RuleMealComposer:
  def compose(shortlist, meal_type, exclude_ids, require_single_role=None) -> ComposedMeal
  # 午晚：主食最高分 + 主菜（荤/素/水产最高分）+（汤 score>=0.5）；早餐：主食最高分 + 早餐类最高分（+粥 score>=0.5）
  # 单道模式：在允许集合里取最高分（require_single_role=staple 时只看 staple 候选）

class LLMMealComposer:
  def __init__(self, complete: Callable[[str, str], Awaitable[str]]): ...  # (system, user) -> text；测试注入假实现
  async def compose(...) -> ComposedMeal | None   # None = 校验失败（重试 1 次后仍失败）

MEAL_PLANNER_SYSTEM_PROMPT  # 输出严格 JSON：{"dishes":[{"recipe_id":int,"role":"staple|main|side|soup|drink","reason":"≤30字"}],"note":"一句话"}；按请求语言输出文案
def build_compose_prompt(shortlist, meal_type, targets, budget, excluded_names, recent_names, preference, lang, single_role=None) -> str

async def compose_meal(db, user, meal_type, shortlist, exclude_ids, preference, lang, policy_ctx) -> ComposedMeal
  # 顶层入口：policy_ctx 为 None 或 method=rule → 规则；否则 LLM（超时 wait_for(policy timeout)）
  # 成功 → record_usage(ok)；校验败重试 1 次仍败/超时/异常 → record_usage(fallback|error) → 规则
  # system_ai 调用前检查 system_ai_limit_reached → 直接规则（不记 AI 事件，记 rule）
```

单道换：`require_single_role` 传被换道的 role（staple 时校验器强制新道也是 staple）。

### Task 5: generate / refresh 重写 + API + schemas

**Files:**
- Modify: `backend/app/services/meal_recommender.py`（生成/刷新主流程 + 响应构建 + 后台线程签名）
- Modify: `backend/app/schemas/meal.py`（`RecommendedDish`(RecipeBrief+role+reason)、`MealRecommendationItem.dishes`、`source/reason/preference`、`GenerateMealRequest{preference?}`、`RefreshMealRequest{recipe_id?, preference?}`）
- Modify: `backend/app/api/meals.py`（generate 收可选 body；refresh 传 recipe_id/preference；Accept-Language → lang）
- Test: `backend/tests/test_meal_recommendation_rework.py`

主流程：
- `generate_recommendations(db, user, tz, preference=None, lang="zh")`：黑名单复核（按 items 关联的 recipe）→ 逐餐 `build_shortlist`（exclude=全部已选）→ `compose_meal` → 批量写父行（source/reason/preference）+ items → 响应。
- `refresh_meal_recommendation(db, user, meal_type, tz, recipe_id=None, preference=None, lang="zh")`：`refresh_count >= 5` → 错误；整餐（recipe_id=None）重走组合（exclude 含当前餐全部）；单道（recipe_id 给定）：删除该 item，用 `require_single_role=被删道 role` 重选一个补位（新 item sort_order 沿用原位）；`refresh_count += 1`；commit 后重建响应。
- `_build_response_from_records`：父行 eager-load `items.recipe`；逐 dish 构建 brief + role + reason；totals 累加全部 dishes；`recommendations[].recipe` = dishes 中 staple（无则首道）的 brief（**兼容别名**）；`source/reason/preference` 上提到 item 层。
- 后台线程 `trigger_background_generation(user_id, tz, preference, lang)` / `trigger_background_refresh(user_id, meal_type, tz, recipe_id, preference, lang)`；黑名单兜底刷新路径同样携带当前 preference/lang（从父行读）。
- `check_today_status` 的 `joinedload` 改 `items`。

**验收**：新测试全绿 + 既有 `tests/api/test_meal_recommendation_route.py` 适配（同步路由约定不变）+ 5 次上限真实生效用例 + 单道换用例 + 假 provider 端到端用例（注入 complete callable 断言 source=system_ai 与 dishes 落库）。

### Task 6: 回归、要点记录、合并

- 定向回归：`tests/test_meal_recommendation_route.py tests/api/...`（黑名单、时区依赖既有用例）；导出模块基线照旧不跑全量。
- `docs/recommend.md` 更新机制说明；`agent_doc/FEATURE_AI一餐推荐.md` 记录；AGENTS.md 索引 + 最新修复记录。
- **明确告知用户**：开发库需执行 `backend/scripts/sql/20261015_recommendation_items_sqlite.sql`（列变更 create_all 不覆盖）；否则后端启动后推荐接口报错。
- 合并 `feat/mobile-app`。

### 后续（另计划）

- 2B web：meals store/types、DailyMealsView + MealCard 多道菜、偏好输入、AI 标、换菜菜单；AiConfigView 两个新区块；Profile AI 设置卡；本地模式（TS 校验器 + 规则 + 浏览器端 agent AI）。
- 2C 移动端：home 多道菜展开、偏好输入、整餐/单道换、AI 标。

## 计划自审记录

- Spec 覆盖：§4.1-4.8 全部落任务；§4.9 provider caps 简化为 LLM composer 的 provider 白名单（openai/anthropic/claude_code/codex 均可配，决策模型骨架不在本期）；§4.10 三端 → 2B/2C。
- 类型一致性：`ComposedMeal.source ∈ {'system_ai','user_ai','rule'}` 与父表 `source` 列、响应 `source` 一致；`role` 枚举统一 `staple|main|side|soup|drink`。
- Review Focus 对应：放宽链（Task 3 测试）、坏输出（Task 4 校验器测试）、上限（Task 2 策略测试 + Task 5 端到端）、刷新计数（Task 5 测试）、兼容别名（Task 5 测试断言 `recipe` 非空）。

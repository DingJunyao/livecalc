# 生计 - 生活成本计算器

## 项目概述

这是一个全栈的生活成本计算器应用，旨在帮助用户记录商品价格、计算烹饪成本、优化生活开支。

### 核心功能
- 📝 商品价格记录 - 记录不同时间、不同地点的商品价格
- 🍳 菜谱成本计算 - 根据价格记录计算菜谱成本
- 🥗 营养成分分析 - 基于 USDA 数据库的营养分析
- 📍 地图与路线规划 - 集成地图服务，计算出行成本
- 📊 生活成本报告 - 生成每日、每周、每月报告
- 💰 多币种支持 - 支持多种货币
- 🌏 多单位转换 - 支持公制/市制/英制转换
- 🔐 用户认证 - 支持 JWT 认证和邀请码注册

## 系统架构

```
livecalc/
├── backend/              # 后端服务 (FastAPI)
│   ├── app/
│   │   ├── api/        # API 路由定义
│   │   ├── core/       # 核心配置与安全
│   │   ├── models/     # 数据库模型
│   │   ├── schemas/    # Pydantic 模式
│   │   ├── services/   # 业务逻辑层
│   │   └── utils/      # 工具函数
│   ├── alembic/        # 数据库迁移
│   └── tests/          # 测试用例
├── frontend/            # 前端应用 (Vue 3)
│   ├── src/
│   │   ├── api/       # API 客户端
│   │   ├── components/ # 可复用组件
│   │   ├── stores/    # Pinia 状态管理
│   │   ├── views/     # 页面视图
│   │   └── router/    # 路由配置
│   └── public/         # 静态资源
├── docker-compose.yml   # Docker 编排
└── README.md           # 项目文档
```

## 技术栈

### 后端 (FastAPI)
- **框架**: FastAPI - 现代化的 Python Web 框架
- **ORM**: SQLAlchemy - Python SQL 工具包和对象关系映射
- **迁移**: Alembic - 数据库迁移工具
- **认证**: Python-JOSE + Passlib - JWT 认证和密码哈希
- **任务调度**: APScheduler - 任务调度器
- **异步任务**: Celery（可选）- 分布式任务队列

### 前端 (Vue 3)
- **框架**: Vue 3 - 渐进式 JavaScript 框架
- **构建工具**: Vite - 新一代前端构建工具
- **状态管理**: Pinia - Vue 的官方状态管理库
- **路由**: Vue Router - 官方路由管理器
- **HTTP 客户端**: Axios - Promise 基础的 HTTP 客户端
- **地图**: Leaflet - 开源地图库
- **图表**: Chart.js - 简单灵活的图表库

### 数据库
- **开发**: SQLite - 轻量级嵌入式数据库
- **生产**: PostgreSQL / MySQL - 企业级数据库

### 容器化
- **容器**: Docker - 容器化平台
- **编排**: Docker Compose - 多容器应用编排
- **Web 服务器**: Nginx - 高性能 Web 服务器

## 模块说明

### 后端模块
- **auth** - 用户认证与授权
- **products** - 商品价格记录与历史追踪
- **locations** - 地点管理与地图服务
- **nutrition** - 营养数据库与匹配算法
- **recipes** - 菜谱管理与成本计算
- **reports** - 报告生成与统计分析

### 前端模块
- **auth** - 登录/注册页面
- **dashboard** - 仪表盘与概览
- **products** - 商品管理界面
- **recipes** - 菜谱管理界面
- **locations** - 地点与地图界面
- **reports** - 报告与统计界面

## API 端点

### 认证 API
- `GET /api/v1/auth/config` - 获取注册配置
- `POST /api/v1/auth/register` - 用户注册
- `POST /api/v1/auth/login` - 用户登录
- `POST /api/v1/auth/refresh` - 刷新令牌
- `GET /api/v1/auth/me` - 获取当前用户信息

### 核心 API
- `GET/POST /api/v1/products/` - 商品价格记录
- `GET/POST /api/v1/locations/` - 地点管理
- `GET/POST /api/v1/nutrition/` - 营养数据
- `GET/POST /api/v1/recipes/` - 菜谱管理
- `GET/POST /api/v1/reports/` - 报告统计

## 开发规范

### Python 代码规范
- 使用 Black 进行代码格式化
- 使用 isort 进行导入排序
- 使用 Flake8 进行代码检查
- 使用 MyPy 进行类型检查

### JavaScript/TypeScript 代码规范
- 使用 Prettier 进行代码格式化
- 使用 ESLint 进行代码检查
- 遵循 Vue 3 最佳实践

### Git 工作流
- 使用 Conventional Commits 提交规范
- 保持主分支稳定
- 功能开发在特性分支进行
- 通过 Pull Request 进行代码审查

## 环境变量

### 后端
- `DATABASE_URL` - 数据库连接字符串
- `SECRET_KEY` - 应用密钥
- `JWT_SECRET_KEY` - JWT 签名密钥
- `REGISTRATION_REQUIRE_INVITE_CODE` - 是否需要邀请码注册

### 前端
- `VITE_API_URL` - 后端 API 地址（默认为 `/api/v1`）

## 开发情况

本项目为 monorepo 项目，包含前端和后端。

### 前端

技术栈：TypeScrPt + Vue + Vite

目录：`frontend`，所有前端相关操作均在此目录下进行。

开发 URL：`http://localhost:5173`

通常会打开浏览器调试。如果需要启动浏览器测试，请确保优先看已经打开的浏览器（优先级：Edge > Chrome > Chromium）会话，而非新开浏览器（不管是用 Playwright 还是使用对应的 MCP）。尤其是在本地（纯前端）版本的功能测试中，因为数据存储在 localStorage 中，新开浏览器会话并不会读取已有会话的 localStorage。

响应式设计。开发时要兼顾不同地图引擎和桌面、移动端的体验。

目前需要考虑的地图引擎如下：

- 高德地图
- 百度地图（分为 GL 版本和 Legacy 版本，前者常用，后者只在一些特殊场景下使用）
- 腾讯地图
- Leaflet：目前支持高德地图、百度地图、腾讯地图、天地图、OpenStreetMap。

所有前端的修改都必须确保构建通过。

### 后端

技术栈：Python + FastAPI

目录：`backend`，所有后端相关操作均在此目录下进行，并且使用虚拟环境。

开发时使用 `uv` 管理。

虚拟环境：根目录下的 `.venv` 下的环境。

所有后端的修改都必须确保无语法错误。

### 数据库

数据库：`backend/.env` 文件中指定。一般情况下为 `backend/data/livecalc.db`。

数据库操作优先使用相应的 MCP。

开发过程中不要自行修改数据库，除非开发者明确允许此操作。

表结构需要变动时，除了维护 alembic 外，还需要提供对应的 SQL 脚本，包括一下数据库引擎的版本：

- SQLite
- MySQL
- PostgreSQL（未启用 PostGIS 支持）
- PostgreSQL（启用 PostGIS 支持）（如与 PostGIS 无关，则不需要此项）

### 测试

所有操作均需确保无语法层面上的报错，构建、编译通过。

不要在对话中启动服务，因为我已经启动了自动重载的前端、后端服务。

### 记录要点

当某项开发工作完成、告一段落或有关键性进展时，需要自动记录要点。用户要求记录要点时，也要记录。

要点按照以下的索引记录。

注意：为了节约 token，即便用户要求记录到 AGENTS.md，也要按照下面的索引记录。

定期清理最新修复记录，以减少 token 消耗。保留 10 条最近的修复记录。

### 不同分支的修改限制

目前有两个需要留意的分支：

- `master`: 主分支，包括 web 前端、后端
- `feat/mobile-app`：开发移动 App 的分支

注意：feat 分支只更改各自新增功能的问题和功能。比如：feat/mobile-app 只更改移动端的功能和问题。如确有涉及到主分支上 web 前端、后端的问题，请更改到 master 分支修改，然后将修改合并到各 feat 分支。

现阶段，涉及到 web 前后端问题提交到 master 分支，然后同步到 feat/mobile-app 分支；涉及到 app 的问题提交到 feat/mobile-app 分支。顺序不要弄错。

### 各端体验一致性

移动端 app 在体验上要与 web 前端保持一致。

尽管移动端 app 在 UI 上偏向于原生，但功能上要保持一致，比如：价格列表，每项能够看到的内容要一样。

## Tips

> 来自 Claude Code 的 Inspect 工具。

### Overall

Before writing any fix, trace the full data flow for this bug: from database query → serialization → API response → frontend rendering. Show me what each layer returns at each step, and identify exactly which layer the bug is in. Do NOT propose a fix until you've completed this trace.

Before writing any SQL, run \d tablename or SELECT column_name, data_type FROM information_schema.columns WHERE table_name='tablename' to verify the exact column names and types. Then write your SQL using only confirmed column names.

Use a subagent to explore and map out the full codebase structure for feature, including all files, functions, and data flows involved. Return a detailed map. Then I'll review it before we start implementing step by step.

### Code Quality

Always verify column names, field names, and API paths against the actual codebase before writing SQL or making edits. Never guess — use Grep or Read to confirm the correct name.

### Debugging

When fixing bugs, always trace the full data pipeline end-to-end before proposing a fix. For backend→API→frontend flows, check: (1) DB query/storage, (2) serialization (_to_response or schema), (3) API response shape, (4) frontend consumption.

Before creating new data mappings or lookups, always check if the data already exists in related tables (e.g., entity_unit_overrides, existing product/ingredient records). Use Grep to search for existing implementations.

### Database

When working with PostgreSQL, never use JSON LIKE queries or naive/aware datetime comparisons without explicitly checking compatibility. Prefer ilike for text, and always ensure datetime objects are timezone-aware before comparison.

For boolean columns in SQL INSERT/UPDATE statements, always use true/false (SQL literals), not 0/1 (integers). Python False does not automatically map correctly in all ORMs.

### Architecture

When the user reports a permission/error issue, do not just add a permission check or toggle on the endpoint. First understand the intended UX flow — some operations should not exist as separate endpoints at all (e.g., image deletion should be part of recipe update, not a standalone DELETE).

## Testing

After editing Python files that may be cached (__pycache__, .pyc), remind the user to restart the server or clear cache before testing, to avoid false negatives where the fix appears not to work.

## 项目索引

本项目文档已模块化拆分，按需加载以提高性能。详细信息请按需查看 `./agent_doc` 目录下的对应文件。

所有与智能体（包括但不限于 Claude Code、Codex、ZCode、Deepseek Harness）相关的文档，都放在 `./agent_doc` 目录下。并且，在这里描述文档内容，以便索引。

如：部署说明：详见 [DEPLOYMENT.md](agent_doc/DEPLOYMENT.md) 和 [QUICKSTART.md](agent_doc/QUICKSTART.md)；开发时的规则，详见 [DEV_RULE.md](agent_doc/DEV_RULE.md)

价格计算逻辑（原料综合价 / 菜谱成本：每商品最近价 → 30 天参与上限 → 全部超期放开 → 按权重加权）：详见 [FEATURE_商品加权价格机制.md](agent_doc/FEATURE_商品加权价格机制.md)
自定义单位嵌套（1箱=12盒）/ 商品改名同步价格记录 / 保存按钮位置：详见 [FEATURE_自定义单位嵌套与保存按钮位置.md](agent_doc/FEATURE_自定义单位嵌套与保存按钮位置.md)
自定义单位显示折算（si_factor 口径：质量→kg、体积→L）：详见 [BUGFIX_自定义单位显示si_factor口径.md](agent_doc/BUGFIX_自定义单位显示si_factor口径.md)
移动端价格单位下拉（基准列表同源）/ 单位编辑整页化 / 换算系数移除 / 继承原料单位：详见 [BUGFIX_移动端价格单位下拉与单位编辑体验.md](agent_doc/BUGFIX_移动端价格单位下拉与单位编辑体验.md)
VS Code 打不开 Flutter 运行调试（Windows 桌面构建失败：CMake 生成器 VS18/VS17 不匹配 + v143 工具集缺 ATL）：详见 [BUGFIX_VSCode_Flutter调试打不开.md](agent_doc/BUGFIX_VSCode_Flutter调试打不开.md)
移动端原料搜索下拉「完整词为空、短词有结果」（IME 组合态同文本二次通知导致 pending Future 被取消）：详见 [BUGFIX_移动端IME重复组合态下拉为空.md](agent_doc/BUGFIX_移动端IME重复组合态下拉为空.md)
新增商品/原料页内置「自定义单位 / 营养信息」（端内按钮 + 草稿 + 负数 id 拓扑落库；商品勾选「新建同名原料」时附加数据仍写商品层级，原料则写原料层级；web 对话框 / 移动端整页）：详见 [FEATURE_新增商品页自定义单位与营养信息.md](agent_doc/FEATURE_新增商品页自定义单位与营养信息.md)
移动端搜索下拉防抖（商品关联原料 / 黑名单 / 价格商品 / 粘贴导入 / 原料合并 / 菜谱原料，300ms + 请求序号）：详见 [BUGFIX_mobile_search_ime_debounce.md](agent_doc/BUGFIX_mobile_search_ime_debounce.md)
价格趋势图「区间内无新记录则空白」（区间取数需覆盖最近一次记录 + 逐日 as-of）：详见 [BUGFIX_价格趋势区间无记录空白.md](agent_doc/BUGFIX_价格趋势区间无记录空白.md)
近月价格筛选 / 价格趋势「只有今天有记录」仍空白（判据改「as-of 携带起点是否存在」+ `backfillSparse`）/ 记价默认单位联动（`no_recent_price`）：详见 [BUGFIX_近月价格筛选与图表空白与默认单位.md](agent_doc/BUGFIX_近月价格筛选与图表空白与默认单位.md)
收藏（原料 / 商品 / 菜谱；列表心形 + 仅看收藏 + 收藏置顶 + 聚合页 + 合并/导出导入联动 + 本地模式）：详见 [FEATURE_收藏.md](agent_doc/FEATURE_收藏.md)
AI 一餐推荐（多道菜套餐保底主食 / AI 组合+规则降级 / 一句话偏好 / 整餐重搭+单道换 / 7天去重 / AI 使用策略层 BYOK+每日上限）：详见 [FEATURE_AI一餐推荐.md](agent_doc/FEATURE_AI一餐推荐.md)

### 最新修复记录
- AI 一餐推荐后端重写（用户需求：一餐只推一道、没有主食不可用；要求 AI 组合 + 管理员/用户级推荐方法 + BYOK + 对外服务合规姿态）：**架构**：候选池收窄（午晚=主食/荤/素/水产/汤粥，早餐=早/主食/汤粥）+ 近 7 天去重放宽链 7→3→0 + 收藏加权（+0.1）→ 分类 top-K 短名单 → `meal_composer` 组合层（`LLMMealComposer` 走 Translator 四 provider 通道 + 校验器（≥1 staple/id∈短名单/午晚 staple 必须「主食」分类，失败回灌重试 1 次）→ `RuleMealComposer` 降级）→ 父表+子表落库；**存储**：`daily_recommendations` 加 reason/preference/source/refresh_count 删 recipe_id，新表 `daily_recommendation_items`/`user_ai_settings`（Fernet 加密 BYOK）/`ai_usage_events`；**策略层** `ai_policy.resolve_ai_credentials`（用户 method→全局默认→rule；`allow_custom_base_url` 默认关；每日 AI 上限按 system_ai 的 ok/fallback 计数、用户级 override 优先，超限自动降级 rule）+ `/profile/ai-settings` 端点（管理员可代理，key 只回显打码）；**刷新**：整餐重搭 + 单道换（换 staple 保 staple），5 次/餐/天上限改读 `refresh_count` 列（**修复旧「行数-1」口径从未生效的 bug**）；**响应兼容**：`recipe` 保留为 staple/首道别名 + 新增 `dishes[]`（旧前端不断）。**验证**：相关回归 57 项全绿（校验器 9 例 / 策略 3 例 / 端点 3 例 / 端到端 4 例：假 LLM 落库 system_ai+兼容别名+偏好快照、坏输出降级 fallback 事件、5 次上限、放宽链；真实 claude CLI 超时降级链路被意外端到端验证）。**⚠️ 存量库须手工执行 `backend/scripts/sql/20261015_recommendation_items_*.sql`（列变更 create_all 不覆盖，未执行前推荐接口 500）**；2B（web+本地）/2C（移动端）待做。详见 [FEATURE_AI一餐推荐.md](agent_doc/FEATURE_AI一餐推荐.md)。**经验：①测试走「API+后台线程+轮询」撞 StaticPool 单连接会读到未提交的中间 flush 状态——推荐逻辑一律服务层直调+假 LLM 注入；②批量 query.delete() 不触发 ORM cascade，删父行留孤儿 item，SQLite rowid 复用会让孤儿挂尸到新记录（同餐重复菜假象）；③共享内存库的跨测试残留三件套（AI 设置行/用量事件/当日推荐）必须在各测试文件公共准备里显式清空；④默认策略=claude_code 时测试默认拉起真实 CLI（每餐 120s 超时，全量 26 分钟的元凶），不测 AI 路径的用例要显式强制 rule；⑤「默认合并」函数必须保留未知顶层键，否则 PUT 回写静默丢新配置区块。**
- 收藏修复轮（用户实机三条：①商品/原料列表点心形会连带跳进详情；②「我的收藏」页过于简陋，要与各列表页观感一致；③移动端还没做三类收藏与统一收藏页）：**根因①**：商品/原料的卡片与列表项都是 `:to` 链接（Vuetify 渲染成 `<a>`），`FavoriteButton` 只写了 `@click.stop` —— `stopPropagation` 拦得住 JS 冒泡，拦不住锚点的**默认导航**，既有按钮一律用 `@click.prevent` 正是这个原因；**修复①**：`FavoriteButton` 改 `@click.stop.prevent`。**修复②**：`FavoritesView` 不再用精简的 `/favorites` 聚合数据直出文本列表，改为复用三个列表端点（`favorites_only=true`）拿与列表页同型的 payload，新增 4 个按类型卡片组件（`components/favorites/Favorite{Product,Ingredient,Recipe,Merchant}Card.vue`，逐条对齐各自列表页的卡片：头像/图片、名称、品牌/分类/地址、最新价、迷你图、成本·热量、心形），并用 `useLatestPrices`、`/sparklines/*`、`/recipes/batch-cost` 做同源富化；聚合 `/favorites` 端点保留（接口仍可用）。**修复③（feat/mobile-app）**：新增 `shared/repositories/favorites_repository.dart`（多态增删查）+ 三个 provider（`favoritesOnly`/`favoriteIds`/`loadFavorites`/`toggleFavorite`，乐观更新＋正确回滚）、三个 repository 的 `search/getRecipes` 增加 `favorites_only`/`favorites_first` 参数、三个列表屏加心形与筛选面板「仅看我的收藏」开关、三个详情屏 app bar 加心形；新增 `features/favorites/screens/favorites_screen.dart`（四类 tab，原料/商品带最新价与迷你图、菜谱带成本·热量、商家带地址；取消收藏即移除）；`app_router` 新增 `/favorites` 路由与 `_favoritesTab`（桌面侧栏 + 移动「更多」弹出菜单），「更多」菜单由单行 4 项 `Row(Expanded)` 改为每行 4 项的 `Wrap`（5 项时换行）；顺手修 `merchant_provider.toggleFavorite` 的**无效回滚**（`copyWith(favoriteIds: state.favoriteIds)` 把乐观值赋回自己 → 改为保存 `previous` 回滚）。**验证**：web `build` ✓ / `check:i18n` ✓ / sources 2081 / `tsc --noEmit` 归一化后与基线一致；移动端 `flutter analyze` 0 error（仅 1 条未触碰文件的 onReorder deprecation info）、`flutter test` **665 通过 / 6 存量失败**（apple_map×3、locale_preferences×2、my_proposals×1 = 基线）；11 处测试假仓库签名随接口补参同步。详见 [FEATURE_收藏.md](agent_doc/FEATURE_收藏.md)。**经验：①`@click.stop` 防不住「链接型容器」的默认导航，卡片/列表项是 `:to` 时子按钮必须 `.prevent`（本仓既有按钮的写法就是活文档）；②「我的收藏」这类聚合页要复用列表端点（带完整字段）而不是另造精简接口，否则页面必然简陋；③给 repo 方法加参数会让所有测试 fake 的 override 失效——一次改签名要同步搜 `test/` 下的假实现。**
- 收藏（原料 / 商品 / 菜谱）（用户要求：收藏要和商家一样，并作为后续 AI 推荐的偏好信号）：**方案**：新表 `user_favorites`（多态纯链接表，`(user_id, entity_type, entity_id)` 唯一，取消=物理删，`entity_id` 不加跨表外键）；新路由 `/api/v1/favorites`（聚合/单类/加/删，登录直写不走审批，实体不存在或软删 404、幂等）；三个列表端点新增**参数化** `favorites_first`（收藏置顶、组内保持原排序）与 `favorites_only`（服务端过滤，默认 false 行为不变，只由主列表页开启）；合并删除源收藏并可回滚（商品 `ProductMergeExecutor`、原料 `IngredientMerger` + `IngredientExecutor`，口径对齐 merchant_merge 不搬迁）；云导出新增 `user_favorites.json` 与 **`user_merchant_favorites.json`（商家收藏此前未导出，一并补上）**，导入两遍法（mapping 为主 + 名字兜底，解析不到跳过计数，归属导入用户、幂等）；web 新增 `useFavorites` composable + `FavoriteButton`（商家页三处内联迁移到通用件）+ 三列表/三详情接入 + `/favorites` 聚合页 + 导航；本地离线模式 `DB_VERSION 3→4` 新 store（`by_entity_key`）+ handlers + 列表参数 + 导出导入 + 两个 `localErrors` 键；i18n 三语（sources 2066→2081）。**验证**：后端新增 9 例全绿（唯一约束/幂等/404/软删隐藏/排序稳定性/叠加筛选 total/合并删除源收藏/导出往返幂等）；导出模块既有 4 项失败为基线（stash 对照），另 1 项为开发库 schema 滞后（表待后端启动 create_all 创建）；web build ✓ / check:i18n ✓ / sources 2081 / test:utils 52/52 / `tsc --noEmit` 与基线归一化后完全一致（仅行号位移）。**实机 GUI 验证待服务启动后补做**。详见 [FEATURE_收藏.md](agent_doc/FEATURE_收藏.md)。**经验：①「忽略未知参数」与「正确过滤」在单条数据下结果相同——测试夹具必须建 2 条只收藏 1 条，否则假通过；②提案执行器注册在 lifespan 里，TestClient 不触发 → 合并类端点测试要显式 `register_all()`；③多态引用要四件套（API 存在性校验 / 列表软删过滤 / 合并搬迁 + 回滚 / 导入名字兜底）；④共用列表端点排序过滤必须参数化且服务端实现（客户端排序只排当前页）。**
- 近月价格筛选 / 价格趋势「只有今天有记录」仍空白 / 记价默认单位（用户一次反馈四条：①给商品/原料设了默认单位，维护价格选商品时单位下拉不切过去；②web 与移动端部分图表最近一个月没数据就不显示、要切区间才出来，补充「只有今天维护了数据」同样不显示；③商品筛选加「近一个月未维护过价格」；④原料筛选加「近一个月所有商品均未维护过价格」）：**根因①**：`entity_unit_overrides.is_default`（单位编辑里的「设为默认」）只在单位编辑/展示链路被消费，价格录入入口只按「商品+关联原料+全局」重建下拉候选、**从不读 is_default** —— 数据早在、没人消费。**根因②**：趋势图是 as-of 口径，需要「区间起点之前最近一次记录」当携带起点，而取数按 `start_date` 窗口拉；旧修复（BUGFIX_价格趋势区间无记录空白）的判据是「区间命中 0 条**且**池为空才回退全量」，当区间里**恰好只有今天这一条新记录**时命中数 = 1 → 不回退 → 序列只剩 1 个点：web 的 time 轴 `min:'dataMin'/max:'dataMax'` 退化成同一时刻、点压在边缘；移动端 `CostTrendChart` painter 第一行 `if (points.length < 2) return;` → **一个点等于零个点** → 两端都像空白，切到更宽区间把旧记录补进池才有线（开发库实测：商品 837/673/692、原料 266/234/46 等 11 个是「今天 1 条 + 窗口内 0 条 + 更早若干」；另有 12 商品 / 1 原料「全部记录只有今天 1 条」）。**根因③④**：`_apply_*_special_conditions` 只有无时间维的口径，且两端特殊条件都只是把 cond 透传成查询参数，缺一个键。**修复**：①新增 `recent_price_cutoff_utc(tz, days=30)`（用户本地「今天 − 30 天」00:00 换 UTC，与图表/综合价 30 天参与上限同一实现），`GET /products/entity` 与 `/ingredients` 新增 `no_recent_price`（商品：自身近 30 天无有效记录，**从未维护过也算**；原料：**所有活跃商品**都没有；软删记录不算维护过），web 本地离线模式 handlers 同口径（`recentPriceCutoffMs` / `productIdsWithRecentPrice`），三语各加 `noRecentPrice`（sources 2066 键）；②`shouldLoadFullPriceHistory` 判据改为「**累积池里没有不晚于区间起点的记录**」（新参数 windowStart + poolStartDay，商品/原料详情与移动端两个 provider 同步），`buildWeightedAsOfDailySeries` / `buildPriceTrendPoints` 新增 `backfillSparse`（**整段只有 1 个记录日**时把最早已知价向前补到区间起点；≥2 个记录日一律不补，不凭空编造趋势）+ web 单点把 time 轴左右各撑开半天 + 移动端 painter 单点也画（含 tooltip）；③`fetchEntityDefaultUnitName`（**商品自身 > 关联原料**，只认严格 `is_default === true`）+ 纯函数 `pickDefaultUnitName`（放 unitOptions.ts，可单测），维护价格页**只在用户真的换了另一个商品、且处于新增/扫码流程**时切换单位（编辑既有记录/再次记录保留记录原值，用 `applyEntityDefaultUnitOnSelect` 开关），快速记价对话框、移动端「选中商品」与「带着商品进入（商品详情/列表记价 prefill）」都接；移动端另加 `loadEntityDefaultUnitName`。**验证**：后端 3 例新测 + 真实开发库交叉验证（命中 873 商品 / 711 原料，与独立 `max(recorded_at) < cutoff` 集合**完全一致**、与「窗口内有记录的商品」零交集；用户实测的今天有记录的商品不命中，42 天前的商品 142 / 原料 473 命中）；web `test:utils` 52/52（priceAsOf 12 例 / unitOptions 新增 2 例）+ `npm run build` ✓ + `check:i18n` 3 目录一致 + sources 2066 + `npx tsc --noEmit` 137 条 = 基线；移动端 `flutter analyze` 0 issue、`flutter test` **665 通过 / 6 存量失败**（apple_map×3、locale_preferences×2、my_proposals×1，与基线完全一致），定向 `price_trend_test` 10/10、`entity_unit_names_test` 21/21、`price_record_form_screen_test` 23/23。web/后端提交在 master（47bd18e4 / 86793212 / ca13c1ec），移动端在 feat/mobile-app（9cb3c742）。详见 [BUGFIX_近月价格筛选与图表空白与默认单位.md](agent_doc/BUGFIX_近月价格筛选与图表空白与默认单位.md)。**经验：①「区间内没有新记录」有两种形态——一条都没有 vs 只有区间末尾（今天）一条；判据必须落在「as-of 携带起点是否存在」，而不是「命中条数是否为 0」；②图表空白先查渲染分支再查取数（painter 的 `<2 直接 return` 让 1 个点等于 0 个点，只修数据链路救不了「真的只有一条记录」）；③单点兜底要保守（只在整段一个记录日时补齐），否则把刚建档的新价画成过去一个月的既成事实；④新增「近 N 天」筛选要复用同一 cutoff 实现，别各写 `utcnow()-30d`；⑤引用型配置（默认单位）加在数据层 ≠ 功能完成，要逐个录入入口接线，且区分「用户新选择」与「预填/编辑」两条路径。**
- 换原料后「先改指向」+ 单位列表口径统一（用户实测：①引用的「颗」在全局单位里本来就有，换原料后却被清掉了；②同一份单位数据 web 与移动端显示数量不同，价格/商品/原料维护之间也不同）：**根因①**：商品的单位覆盖可以引用关联原料的自定义单位（`weight_unit_override_id`），换原料后原 id 指不到新原料，上一轮直接当「失效」删掉 —— 但那只是**换了归属**（全局单位表里就有同名「颗」，开发库 id=49）；**修复①**：新增纯函数 `reconcileUnitsAfterIngredientChange`（web [entityDraftPlan.ts](frontend/src/utils/entityDraftPlan.ts) / 移动端 [draft_units.dart](mobile/lib/shared/utils/draft_units.dart)，各 5 例单测）：失效引用按名字依次找 ①新原料的同名单位 ②全局同名单位，命中就**改指向**（只改两个引用字段），仍解析不了的行（含下游）才移除；web [entityDrafts.ts](frontend/src/utils/entityDrafts.ts) 用**部分更新 PUT**（后端 `EntityUnitOverrideUpdate` 是 `exclude_unset`，绝不回写 `conversion_factor`，否则老数据折算量会被悄悄改小）；两端提示区分「已改用同名单位」/「已移除」，ProductDetail 与「已保存」合并成一条。**根因②**：单位下拉的取数口径各处不同 —— web 商品/原料详情只取 mass+volume（**13 条**），web 草稿对话框/移动端/价格页取全部（**54 条**），`/units/` 的 limit 还分 100/200/无参；**修复②**：统一成「全部启用单位」（去掉 web 两处 `unit_type in (mass,volume)` 过滤，计数单位「个/颗/盒」本就是合法嵌套目标），各处 limit 统一 500，价格下拉补 `is_active !== false`；快速填写页仍用 `is_common` 子集（有意窄列表）。**踩坑**：草稿态判断「原引用属于哪个原料」不能用 `_selectedIngredient?.id` —— 搜索框打字时 `onChanged` 会先清空选中，`onSelected` 触发时已读不到旧原料，于是只能误删；改用专门的「最近一次选中的原料」字段（web 同理另存 `lastSelectedIngredientId`，别依赖可能被清空的 v-model）。编辑态用表单载入时记下的 id，所以没这个问题（两个测试正好暴露该不对称）。**验证**：移动端新增 2 例（草稿态改指向全局「颗」→ 落库 `weight_unit_id=49`、`override=null`；编辑态改指向 → 只 PUT 不 DELETE）+ 5 例纯函数；`flutter analyze` 0 issue、`flutter test` 654 通过 6 存量失败；web `test:utils` 48/48（新增 5 例）、`build` ✓、i18n 三语 + sources 2064 键、`npx tsc --noEmit` 无新增错误。**经验：①「引用失效」不等于「数据没用」——跨实体引用换绑时应先按名字改指向（新目标同名 > 全局同名），直接删是把「换了归属」误判成「不存在」；②判断「原来引用的是谁」必须用独立记录的状态，不能读会被输入过程改写的字段；③同一份数据的取数口径（类型过滤 + limit）要在所有端/所有页面写成同一条规则，否则就会出现「web 13 条、移动端 54 条」这种同一份数据的显示差异。** **补充（同日第八轮，用户实测 web 草稿态改指向后下拉显示 `u:49`、列表单位变成 g）**：①[EntityDraftUnitsDialog.vue](frontend/src/components/entities/EntityDraftUnitsDialog.vue) 里**还留着一个 mass+volume 过滤的 computed** `globalWeightUnits`（上一轮只改了商品/原料详情两处 `unitWeightUnitOptions`，漏了这个同名 computed）→ 候选里没有 `u:49`，Vuetify 的 v-select 找不到匹配项就把**内部串**原样画出来，列表也解析不到名字 → 落到兜底分支显示成 g；②显示层把「折算不出来」硬编码成克：草稿对话框 `unitLine()` 与两个详情页 `overrideWeightDisplay()` 在 `amounts == null` 时直接拼 `' g'`（体积才拼 `' mL'`），而引用计数单位「颗」本来就折算不到克（count 类）。**修复**：删掉那个 computed（`unitOptions` 直接用 `globalUnits` = 全部启用单位）、`unitLine()`/`overrideWeightDisplay()` 在折算不出来时显示**真正引用的单位名**（`颗 (颗)`）、三处下拉补「当前值不在候选里也要回显」的兜底项（编辑弹窗原来的 `#id` 兜底标题也改成单位名）。移动端没这个问题：`_resolveUnit` 对全局计数单位一样返回标签（缩写「颗」），显示层也没有把兜底写死成 g。**验证**：web `test:utils` 48/48、`build` ✓、i18n 三语（2064 键）✓；移动端本轮无改动（代码核对确认）。**经验：改「取数口径/兜底显示」时务必 grep 全量核实同类点——只改看得见的那两处必然漏掉一个同名 computed；下拉的当前值必须有回显兜底，否则框架会把内部串（`u:49`）画给用户；「折算不出来」不等于「单位是克」，显示层不要硬编码单位名。**
- 单位下拉同名跨来源重复（用户实测：包菜原料自定义了「颗 = 500 克」，下拉里同时出现「颗 (颗)」和「颗（继承自原料）」两条，应该合并）：**根因**：全局单位表里本来就有「颗/个/盒/把」这类计数单位（开发库 `颗` id=49、name==abbreviation），实体又按自己的口径定义了同名单位时，单位下拉只是把两个来源的选项拼起来，**只在同一来源内去重、从不跨来源按名字合并**（价格记录的单位下拉早就按名字合并过，所以只有「单位编辑」这条路径中招）；**修复**：按后端 `get_entity_override` 的优先级链（**实体覆盖 > 全局单位**），与实体自定义单位同名的全局项不再列出 —— 移动端 [entity_units_card.dart](mobile/lib/shared/widgets/entity_units_card.dart) `_weightUnitItems()` 先算 `entityNames`（本实体 + 继承）再跳过同名全局项（详情页与新增页草稿共用一个编辑页，一起生效）；web 新增纯函数 [unitOptions.ts](frontend/src/utils/unitOptions.ts) `withoutShadowedGlobals`（4 例单测）并接入商品详情、原料详情、新增商品/原料草稿对话框三处下拉构建。仅合并展示、不改数据（实体单位仍存 `weight_unit_override_id`，全局单位行照旧存在）。**验证**：移动端新增用例（全局「颗」+ 原料「颗」→ 只有「颗 (from ingredient)」、无「颗 (颗)」、其它全局项不受影响），`flutter analyze` 0 issue、`flutter test` 645 通过 6 存量失败；web `test:utils` 43/43、`build` 与 `npx tsc --noEmit` 无新增错误。详见 [FEATURE_新增商品页自定义单位与营养信息.md](agent_doc/FEATURE_新增商品页自定义单位与营养信息.md)。**经验：同一个下拉拼多个来源时必须按用户看得见的名字跨来源合并，合并方向遵循解析优先级链（更具体者胜出），且只合并展示不动数据。**
- 移动端单位下拉丢继承单位 + 换绑原料清理悬空单位（用户反馈：①移动端新增商品页，添加/修改单位里「单位」下拉带不出关联原料层面的自定义单位，全局单位正常；②换绑商品关联原料时，若商品自定义单位引用的单位在目标原料里不存在，应去掉这些单位并告知用户）：**根因**：①`EntityUnitEditPage._weightUnitItems()` 把全局单位与自定义/继承单位放进**同一个 `Set<int>` 去重**，而 `units`（全局）与 `entity_unit_overrides`（实体覆盖）是**两张表、id 空间重叠**（都从 1 开始）——全局单位先加入，撞车的原料自定义单位被 `continue` **静默丢弃**（web 选项值本来带 `u:`/`d:`/`i:` 前缀，所以没这个 bug）；②`_ensureDraftUnitReference()` 在 `catch` 后照样置 `_draftUnitsLoaded = true` 并缓存原料 id，一次网络抖动/鉴权竞态就让**本轮表单**再也带不出继承单位。**修复**：①移动端选项值改带来源前缀（`''` 默认克 / `u:<全局单位 id>` / `e:<自定义单位 id>`），新增 `_selectedGlobalUnitId` / `_selectedOverrideUnitId` 解析回 id（体积提示、si_factor、保存与自引用校验都改走解析），同一编辑页被详情页 `EntityUnitsCard` 复用，详情页同类隐患一并修好；②改为「必要数据都成功才缓存」（`_draftUnitsLoaded = globalsLoaded && inheritedLoaded`），失败项下次打开自动重试。**新功能**：新增 `unresolvableUnitIds(units, availableExternalIds)`（web [entityDraftPlan.ts](frontend/src/utils/entityDraftPlan.ts) / 移动端 [draft_units.dart](mobile/lib/shared/utils/draft_units.dart)）——引用既不在本商品自己的单位里、也不在目标原料的单位里即失效，**依赖失效单位的下游一并判失效**，自引用也算失效，指向全局单位的行不受影响；换绑关联原料且变更**真正落地**（管理员直写；普通用户走待审、可能被驳回，不动数据）后逐条 `DELETE /entities/product/{id}/units/{unitId}` 并把被移除的单位名告知用户（待审文案区分）；读取失败不动数据、单条失败不阻断其余、不影响保存。**验证**：移动端新增 3 例回归（继承单位与全局单位 id 撞车仍出现 / 继承加载失败第二次打开重试 / 换绑原料后引用失效的「箱」被删、「个」保留 + 提示），`flutter analyze` 0 issue，`flutter test` 全量通过（6 项存量失败：apple_map×3、locale_preferences×2、my_proposals×1）；web `check:i18n` + `check:i18n:sources` + `build` + `npx tsc --noEmit`（无新增错误）+ `test:utils` 39/39（新增 `unresolvableUnitIds` 4 例）；web 侧换绑清理挂在 [ProductDetail.vue](frontend/src/views/products/ProductDetail.vue) 保存基本信息处（仅管理员直写时执行）。详见 [FEATURE_新增商品页自定义单位与营养信息.md](agent_doc/FEATURE_新增商品页自定义单位与营养信息.md)。**经验：①两张表的 id 不能放进同一个去重集合——后加入的一方会被静默丢弃且毫无报错，选项值必须带来源前缀；②「加载失败」与「加载成功但为空」必须区分，把失败当已完成缓存会让一次抖动永久污染整个会话；③引用型数据的清理要先确认变更已落地（审批场景不能提前删），并做到读取失败不动数据、单条失败不阻断其余。** **补充（同日第五轮，用户实测新增态没清理）**：在「新增商品」里选包菜、加一条引用包菜独有单位「哈」的自定义单位，再换关联原料 —— 这条单位既没被去掉也没提示（web/移动端都是）。**根因**：上一轮清理只挂在**编辑商品保存**路径（`_isEdit` 分支 / `saveBasicInfo`），而新增态的单位是**本地草稿**，换原料时既没有 re-link 保存动作、也没有钩子检查草稿引用，草稿被原样落库成悬空引用。**修复**：新增态在**切换原料当下**就地清理草稿（草稿在本地、无服务端副作用）—— 移动端 `product_form_screen.dart` 新增 `_pruneDraftUnitsAfterIngredientChange()`（`onSelected` 里 `unawaited` 执行，用同一个 `unresolvableUnitIds(草稿, 新原料单位 id)` 判定，命中即丢弃并弹提示）；web [ProductsView.vue](frontend/src/views/data/ProductsView.vue) 在 `watch(selectedIngredient)` 里，仅当**目标原料确实变了**（新旧 id 不同且新值非空）时调 `pruneDraftUnitsForIngredient()` 丢弃 + `showMessage(..., 'warning')`。两处刻意取舍：**只在「选中了另一个原料」时触发**（移动端 `onChanged`、web 清空选择都会把选中置空，用户往往只是想重打，挂文本变化会误删刚填的草稿；重新选同一个原料时引用都能解析、不会误删）；**读取原料单位失败时什么都不动**（宁可留悬空引用也不误删）。编辑态仍保持**保存时**清理（服务端数据，用户可能取消编辑）。**验证**：移动端新增用例（新增态选原料 5 → 加「箱 = 12 哈」→ 换成没有「哈」的原料 6 → 弹出提示且草稿页显示「No custom units」、`箱` 消失），`flutter analyze` 0 issue、`flutter test` 全量通过；web `test:utils` 43/43、`build` ✓、`npx tsc --noEmit` 无新增错误。**经验：同一份数据有「草稿态」和「已落库态」两条路径时，校验/清理逻辑必须两条都挂；挂在输入/选择上的破坏性动作要只在「确实选中了另一个目标」时触发，才能既不漏、又不误删。** **补充（同日第六轮，用户实测「web 端删除时没有提示信息」）**：两个独立原因 —— ①**草稿态**：[ProductsView.vue](frontend/src/views/data/ProductsView.vue) 里根本没有 `showMessage`（该文件用 `const { notify } = useGlobalSnackbar()`），清理提示那行抛 `ReferenceError`，单位先被过滤掉了、提示永远不出现 → 改用 `notify(text, 'warning')`；②**落库态**：[ProductDetail.vue](frontend/src/views/products/ProductDetail.vue) 的 snackbar 是**单槽位**（`snackbar.value = {...}` 后一条覆盖前一条），清理警示紧接着被 `products.basicInfoSaved` 覆盖 → 改为把清理结果收进 `danglingNotice`，最后合并成一条 `basicInfoSavedDanglingUnitsRemoved`（含「已保存」+「已移除哪些单位」），无清理时才弹普通成功提示。**为什么没被拦住**：`.vue` 在本仓是工具盲区 —— `vite build` 只转译不查类型、`npx tsc --noEmit` 对 `.vue` 一律报 `Cannot find module`（不看内容）、仓库又没有 ESLint 配置（无 lint 脚本、依赖无 eslint）。**结论：在 `.vue` 里新增引用前必须先在文件里确认已定义/已导入（尤其 `showMessage` / `notify` 这类相邻文件命名相近的），改完尽量实机点一遍。** 验证：i18n 三语 + `check:i18n:sources`（2064 键）、`build` ✓、`test:utils` 43/43；新增标识符逐一 grep 确认定义位置（`notify`@362、`pruneDraftUnitsForIngredient`@629 在 `watch`@654 之前，无 TDZ）。
- 新增商品页内置「自定义单位 / 营养信息」（用户要求：新增商品时在同一个页面（移动端整页 / Web 对话框）给两个按钮进入对应编辑界面，填好后保存商品时才一并保存，不必先建商品再回头补录）：**根因/约束**：单位覆盖与营养都挂在商品 id 上（`POST /entities/product/{id}/units`、`POST /nutrition/products/{id}/nutrition`），新增时商品还不存在，`POST /products/entity` 也不接受这两类字段 —— 现有编辑器全依赖 `route.params.id`，无法复用；**方案**：编辑器改为「草稿只写本地数组」，商品创建成功拿到 id 后统一落库。**Web**：新增纯函数 [productDraftPlan.ts](frontend/src/utils/productDraftPlan.ts)（负数 id = 同批草稿、正数 = 关联原料单位；`planDraftUnitWrites` 拓扑分批 + 环检测、`draftChainReaches` 下拉防环、`draftUnitAmounts` 复用 `unitFactor.overrideAmounts`）与 [productDrafts.ts](frontend/src/utils/productDrafts.ts)（`persistProductDrafts` 按批 POST → 再 POST 营养，失败收成结构化 issue 不抛出；`buildDraftNotices` 翻译成提示），新增 [ProductDraftUnitsDialog.vue](frontend/src/components/products/ProductDraftUnitsDialog.vue) / [ProductDraftNutritionDialog.vue](frontend/src/components/products/ProductDraftNutritionDialog.vue)，在 [ProductsView.vue](frontend/src/views/data/ProductsView.vue) 与 [IngredientDetail.vue](frontend/src/views/ingredients/IngredientDetail.vue) 的**新增态**对话框接入（按钮带计数、`v-model:units/nutrients` 上提，关闭不丢草稿），三语各加 17 个 `products.draft*`/`deleteUnit`/`deleteNutrient` 键。**移动端**：新增 [draft_units.dart](mobile/lib/shared/utils/draft_units.dart)（同口径纯函数 + `removeDraftUnit` 删行清引用）、[entity_units_draft_screen.dart](mobile/lib/shared/screens/entity_units_draft_screen.dart)（草稿整页，`onChanged` 即时回写表单）、[product_draft_persist.dart](mobile/lib/features/products/services/product_draft_persist.dart)，把 `_UnitEditPage` 公开为 `EntityUnitEditPage`、`_unitDetailLine` 公开为 `entityUnitDetailLine`，`NutritionEditScreen` 新增 `allowUsda`（草稿态关掉 —— USDA 匹配直写服务端会打 `entityId=0`），[product_form_screen.dart](mobile/lib/features/products/screens/product_form_screen.dart) 新增两行入口 + 保存后落库并弹提示，三语 ARB 各加 11 键并 `flutter gen-l10n`。**验证**：Web `build` + `check:i18n` + `check:i18n:sources` + `test:utils` 35 通过；实机（Edge + 真实后端）确认两个按钮与提示渲染、进入单位草稿页添加「盒 = 220 g」后列表显示 `1盒 = 220 g`、关闭后按钮变「自定义单位（1）」（本会话桌面工具无法把合成点击送进 Vuetify 模态层，改 Tab/Enter 键盘驱动；未保存，未污染开发库）；移动端 `flutter analyze` 0 issue、`flutter test` 633 通过 6 存量失败（apple_map×3、locale_preferences×2、my_proposals×1，与基线一致）、`flutter test` 新增 3 例产品表单草稿用例通过；存量 `product_form_screen_test.dart` 别名用例因表单变长需 `ensureVisible` 后再点（非功能回归）。详见 [FEATURE_新增商品页自定义单位与营养信息.md](agent_doc/FEATURE_新增商品页自定义单位与营养信息.md)。**经验：①「商品创建成功」与「附加数据保存成功」是两个失败域——附加数据失败要逐条提示、不能回滚或报整单失败，否则用户会重复创建；②嵌套结构在「先编辑后落库」下必须拓扑分批 + id 映射，否则顺序错或把环发出去；③普通用户走提议分流时后端只回 `id=0` 占位骨架，依赖它的嵌套单位要显式跳过并提示；④任何「直写服务端」的侧路（USDA 匹配）都必须给开关，草稿态实体 id 还不存在。** **补充（同日第二轮，用户追加两点）**：①新增商品勾选「新建同名原料」时，附加数据仍写**商品层级**（新增移动端用例断言：新建原料 id=7、落库目标仍是 product/42）；②新增原料同样支持这两个入口，数据写**原料层级**（web [IngredientsView.vue](frontend/src/views/data/IngredientsView.vue) 添加原料对话框、移动端 [ingredient_form_screen.dart](mobile/lib/features/ingredients/screens/ingredient_form_screen.dart)）。为此把草稿工具实体中立化：[entityDraftPlan.ts](frontend/src/utils/entityDraftPlan.ts) / [entityDrafts.ts](frontend/src/utils/entityDrafts.ts)（`persistEntityDrafts(entityType, entityId, …)`，营养端点按类型选 products/ingredients）/ `frontend/src/components/entities/EntityDraft*Dialog.vue`（新增 `target` prop）/ [entity_draft_persist.dart](mobile/lib/shared/services/entity_draft_persist.dart)（`persist({required String entityType, …})`），文案「商品」改 `{target}` 占位（web `common.entityProduct/entityIngredient`、移动端 `productDraftTargetProduct/productDraftTargetIngredient`）三语同步并重新生成 l10n。**验证**：web build + check:i18n + check:i18n:sources + test:utils 35 通过、`npx tsc --noEmit` 无新增错误；移动端 analyze 0 issue、`flutter test` 637 通过 6 存量失败（新增 3 例原料表单草稿用例 + 1 例「新建同名原料仍写商品」用例）。**踩坑：`npm run build` 不做类型检查**——第一轮删除 `failedDraftIds` 声明时漏删 3 处引用（`failedDraftIds.add(...)`），build/i18n/单测全绿却会抛 `ReferenceError`；`vue-tsc@1.8` 与本仓 TS5 不兼容（`Search string not found: /supportedTSExtensions = .*(?=;)/`），改用 `npx tsc --noEmit -p tsconfig.json`（忽略 `*.vue` 无法解析等 137 条存量噪音）才能抓出此类问题。** **BUGFIX（用户实测）**：新增商品/原料时单位下拉「没有数据」，详情页加单位正常、移动端正常 —— 根因是 [EntityDraftUnitsDialog.vue](frontend/src/components/entities/EntityDraftUnitsDialog.vue) 用 `loadedFor = ref<number | null>(null)` 当「已加载哪个原料」的哨兵，`if (loadedFor.value === ingredientId) return`：新增时 `ingredientId` 就是 null → `null === null` 误判已加载，`/units/` 根本没请求（详情页不走该组件、移动端用独立布尔判定，所以都正常）。修复：「是否已加载」与「加载的是哪个原料」分成 `globalUnitsLoaded` 布尔 + `loadedIngredientId`，失败不置位、下次打开自动重试。**经验：缓存哨兵不要用可为 null 的业务值充当（null 常是合法取值）；「详情页正常、新增页不正常」先确认两边是否真的走同一组件/同一初始化路径，再怀疑取数口径。**
- VS Code 打不开 Flutter 运行调试（用户反馈：VS Code 里选中 launch.json 的 Flutter 配置起不来，终端 flutter run -d windows 同样起不来）：**复现**：用 VS Code 实际使用的 SDK（C:\opt\flutter_ori 3.44.8）跑 `flutter build windows --debug` → 107ms 报「generator : Visual Studio 17 2022 Does not match the generator used previously: Visual Studio 18 2026 / Unable to generate build files」；删掉 mobile/build/windows 后推进到 C++ 编译再报 flutter_secure_storage_windows 的「error C1083: 无法打开包括文件 atlstr.h」；带 VCToolsVersion=14.44.35207 重跑 94.7s 通过并产出 debug exe。**根因**：①mobile/build/windows/x64/CMakeCache.txt（2026-08-10）是用 "Visual Studio 18 2026"（C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools，MSVC 14.51）生成的，而现在 SDK 检测到的是 "Visual Studio 17 2022"（VS 2022 Community）→ CMake 拒绝在同一 build 目录换生成器，构建秒挂、调试会话连编译都进不去；②Flutter 生成的工程是 PlatformToolset=v143，MSBuild 按 Microsoft.VCToolsVersion.v143.default.txt 解析出 14.38.33130，而该工具集目录没有 atlmfc（未装 ATL），同一个 VS 安装里 14.44.35207 才有 ATL——8 月给 VS18 的 14.51 装的 ATL 现在用不上。**修复**：①删除 mobile/build/windows 让 CMake 用 VS17 重新生成；②.vscode/settings.json 的 dart.env 增加 "VCToolsVersion": "14.44.35207"（dart.env 会注入 Dart/Flutter 扩展启动的所有进程；终端/其他 shell 同样需要该变量，或给 VS2022 Community 的 v143 工具集装 ATL 组件）。**验证**：带该变量 `flutter build windows --debug` 94.7s 成功产出 build\windows\x64\runner\Debug\livecalc_mobile.exe；pub get 对 pubspec.lock 的改动已还原，git 工作区干净。**经验：①「打不开调试」先看构建日志——Flutter 调试依赖同一次构建，构建秒挂就是起不来；②CMake 缓存把生成器写死，切 VS/工具链必须删 build/windows，否则报的 generator mismatch 会把排查带偏；③v143 的实际工具集版本看 Microsoft.VCToolsVersion.v143.default.txt，不代表 Microsoft.VCToolsVersion.default.txt；④本机两个 Flutter SDK（flutter_ori 3.44.8 / flutter_flutter 3.41.10-ohos）互相踩，叠加 dart.offline: true 使每次启动的 pub get 静默降级 186 个包并改写 pubspec.lock。**详见 [BUGFIX_VSCode_Flutter调试打不开.md](agent_doc/BUGFIX_VSCode_Flutter调试打不开.md)。
- 移动端原料搜索下拉「完整词为空、短词有结果」（用户反馈：新增商品搜「牛奶」转圈结束无下拉，删掉「奶」保留「牛」后能显示「牛奶」，可稳定复现）：**根因**：`RawAutocomplete.optionsBuilder` 在中文 IME 组合结束时会对**同文本**再次回调（`composing` 变化，text 不变）；本次回调 `shouldUpdateOptions=false`，但仍会调用 `optionsBuilder`。旧实现每次都重开 300ms 防抖请求并取消在途 Future，于是第一次回调被第二次取消、第二次又因 `shouldUpdateOptions=false` 丢弃结果 → 转圈结束但无下拉。**修复**：三个远程 `Autocomplete<Ingredient>`（`product_form_screen.dart` 关联原料、`ingredient_detail_screen.dart` 合并目标、`blacklist_screen.dart` 黑名单原料）在相同 query 请求仍在途时直接复用同一 Future，不取消重开；并补 `product_form_autocomplete_repro_test.dart` 同文本 composing 清空回归用例。**验证**：`dart analyze`（改动文件）No issues found；`flutter test` 因本机已有 `flutter run` 持有工具锁未能实跑，需用户/后续在空闲时执行。详见 [BUGFIX_移动端IME重复组合态下拉为空.md](agent_doc/BUGFIX_移动端IME重复组合态下拉为空.md)。
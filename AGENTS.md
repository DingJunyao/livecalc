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
移动端扫码「命中本库条码却毫无反应」（服务端能力开关字段被当结果闸门）：详见 [BUGFIX_移动端扫码无反应.md](agent_doc/BUGFIX_移动端扫码无反应.md)
营养基准「每 X 单位」（含自定义单位，含缩放折算）/ 新建默认五项（能量随偏好、钠 mg）/ 空保存不记录（web + 后端 + 移动端）：详见 [FEATURE_营养基准与默认项.md](agent_doc/FEATURE_营养基准与默认项.md)
AI 一餐推荐（多道菜套餐保底主食 / AI 组合+规则降级 / 一句话偏好 / 整餐重搭+单道换 / 7天去重 / AI 使用策略层 BYOK+每日上限）：详见 [FEATURE_AI一餐推荐.md](agent_doc/FEATURE_AI一餐推荐.md)
试算页（一顿/一日搭配 / 菜谱+原料+商品条目 / 求值 vs 目标 / 成本 as-of 趋势 / 设为今日联动推荐 / 本地模式）：详见 [FEATURE_试算页.md](agent_doc/FEATURE_试算页.md)
AI 与机翻配置页打不开（`GET /admin/translation-config` 序列化丢掉 meal_plan / ai_policy 区块 + `_merge_default_config` 回滚存库策略）：详见 [BUGFIX_AI配置页白屏.md](agent_doc/BUGFIX_AI配置页白屏.md)
缺失 i18n 键（`plans.takeToPlanner` / `common.save` / `common.cancel` / `localErrors.planNotFound`；`check:i18n` 的 keys 模式只比语料间一致性、查不出）与本地模式方案条目求值 `ReferenceError`：详见 [BUGFIX_缺失i18n键与本地模式方案求值.md](agent_doc/BUGFIX_缺失i18n键与本地模式方案求值.md)
试算页添加条目五层连坑（模板调用未定义的 `searchRecipes` / `typeLabel`；v-autocomplete 默认 `return-object=false` 把 id 当对象用 → `recipe_id` 被 JSON 丢掉 → 400；`formatNumber(value, locale, options)` 参数位写错 → 渲染期 TypeError；**后端 `async` 引擎未 `await` + `Decimal / float` → 合计恒 0**）：详见 [BUGFIX_试算页添加条目报错.md](agent_doc/BUGFIX_试算页添加条目报错.md)
试算页二级页面缺返回按钮（参照菜谱详情）：详见 [BUGFIX_试算页二级页面返回按钮.md](agent_doc/BUGFIX_试算页二级页面返回按钮.md)
试算页独立路由（`/plans/new` + `/plans/:id`，二级页面可直达/刷新）与列表卡片增强（成本 / 营养素 / 30 天成本迷你图）：详见 [FEATURE_试算页独立路由与列表卡片.md](agent_doc/FEATURE_试算页独立路由与列表卡片.md)
试算页列表 NRV / 详情全部营养素（复用菜谱详情的营养来源组件）/ 各条目成本占比 / 成本走势价格区间 / 条目宽屏多列并可跳实体详情：详见 [FEATURE_试算页营养成分与成本分析.md](agent_doc/FEATURE_试算页营养成分与成本分析.md)

### 最新修复记录
- 试算页一轮六条（用户反馈：①列表三个营养素没间距；②要展示 NRV；③详情成本走势图经常不显示、切区间才有，且没有价格区间；④宽屏条目一行一个太浪费、改多列并点击跳详情；⑤详情要像菜谱详情那样展示全部营养素；⑥要像分析页展示各要素对成本/营养的贡献量及趋势）：**后端（keystone）**：新增 `services/nutrition_reference.py`（NRV 表 + 核心营养素表 + kJ→kcal + nrv_pct）；`meal_plan_service` 逐条目产出 `nutrient_values`（英文 key，能量统一 kcal）→ 汇总为与 `calculate_recipe_nutrition` **同形**的 `nutrition` 块（`per_serving_nutrition.core_nutrients`（含 nrp_pct）/`all_nutrients` + `ingredient_details[].nutrition_contribution`）；`plan_cost_trend` 补 `min_cost`/`max_cost`/`avg_cost`。**前端**：列表 `ga-x-3` 不生效 → 改 `style="gap"`（这就是没间距的原因）+ 每条附 `NRV x%`（取 all_nutrients[key].nrp_pct，模板不写中文常量否则 sources 检查报 Han text）；**走势图不显示的根因**是 `loading` 在 `finally` 才落下、`v-else` 里的 canvas 还不存在 → `renderTrend()` 拿到 null 静默 return（切区间时 DOM 已就绪所以「切一下才出来」），改为先落 loading → `await nextTick()` → 再求值/画图，并画成**平均线 + 价格区间带**；条目表改宽屏多列卡片，名称用真实 `<a>` + `@click.prevent` 跳 `/recipes/:id`、`/data/ingredients/:id`、`/data/products/:id`；复用 `CostProportionChart`（各条目成本占比）与 `NutritionSourceGrid`（全部营养素 + NRV + 来源）；本地模式同步产出同形 `nutrition`（新 `utils/nrv.ts`）与趋势 min/max。**验证**：后端 meal/plan 13 例 12 passed + 1 条既有顺序性失败（HEAD 基线同）；开发库副本只读实跑 NRV 16 项全出、区间 `min 101.11 / avg 104.44 / max 107.58`；前端 `build` ✓ / `check:i18n`+`sources` 2167 ✓ / `test:utils` 66 ✓ / `tsc` 137（135 基线 + 2 条 `.vue` 路由盲区）/ 模板 → 脚本标识符核对 ✓；未实机验证（需登录）。**取舍**：商品条目营养暂不计入（后端原本就没取自建营养）；营养素不随时间变化，所以给的是贡献量 + 成本趋势；复用组件标题仍是菜谱文案。详见 [FEATURE_试算页营养成分与成本分析.md](agent_doc/FEATURE_试算页营养成分与成本分析.md)。**经验：①`v-else` 里的图表容器必须在 `loading` 落下后再画，否则 ref 为 null、echarts 静默不画（表现=切一下才出来）；②模板里中文常量会被 `check:i18n:sources` 拦，改传英文 key；③让后端产出与详情接口**同形**的数据块，前端一行 `v-if` 就复用整套组件；④Vuetify 3.12 没有 `ga-x-*`，精确间距写 `style="gap"`。**追加一轮（用户实机五条）**：条目卡片改扁平样式对齐原料详情（`elevation=0` + title/divider，宽屏 4 列）、名称不再是链接、改整卡点击进详情（份数/数量区 `@click.stop`）、**区间带第二条系列改为 `max-min` 差值**（原来放 max，堆叠后成 `[min, min+max]`，平均值因此一直贴底）、`食材成本占比` 与 `成本走势` 宽屏 `md=6` 左右分列、新增「营养成分」表（全部营养素 + 含量 + NRV%，复用 `recipes.*` 文案 + 新键 `plans.nutrition`）并保留 `NutritionSourceGrid` 贡献环形图；顺带修上一轮把走势卡塞进 `v-col` 时漏掉的 `</v-card>`（`vite` 报 `Element is missing end tag`）。验证：`build` ✓ / `check:i18n`+`sources` 2168 ✓ / `test:utils` 66 ✓ / `tsc` 137 ✓。**
- 试算页二级页面独立路由 + 列表卡片增强（用户反馈：①「你说不是独立路由，那我怎么快速进入查看这个方案的详情」；②列表页要展示成本、营养素与迷你图，像原料详情一样）：**路由**：新增 `views/plans/PlanDetailView.vue`，`plans/new`（`plan-new`，必须排在 `:id` 前）+ `plans/:id`（`plan-detail`）共用；`PlansView.vue` 改为纯列表。详情页返回箭头 → `/plans`，标题 = 方案名/新建方案，右侧「设为今日 / 删除」（删除弹 `useConfirmDialog` 确认，新键 `plans.deleteConfirm` 三语），新建保存后 `router.replace('/plans/:id')`（刷新/分享落在同一方案）；「拿去试算」改推 `/plans/new`，草稿由详情页消费。**列表**：逐条并发 `evaluate`（成本/热量/蛋白质/脂肪）+ `cost-trend?days=30`（`SparklineBackground` 迷你图，仅非 0 时渲染），整卡 `@click` 进详情（不用 `v-card :to`，子按钮 `@click.stop` 拦不住锚点默认跳转），单条失败静默。**验证**：`build` ✓（PlanDetailView 独立 chunk）/ `check:i18n` ✓ / `sources` 2167 ✓ / `test:utils` 66 ✓ / `npx tsc --noEmit` 137 = 旧基线 135 + 2 条新增 `.vue` 路由模块解析盲区（同类存量 20+ 条）/ 模板 → 脚本标识符核对通过；**未实机验证**（`/plans` 需登录）。**已知缺口**：移动端试算列表仍是「名字 + 类型 + 条数」，没有成本/营养素/迷你图（仓库层 `evaluate`/`costTrend` 已具备）。详见 [FEATURE_试算页独立路由与列表卡片.md](agent_doc/FEATURE_试算页独立路由与列表卡片.md)。**经验：①模式式二级页面（同路由 `editing` 开关）无法刷新/收藏/直达，拆 `xxx/new` + `xxx/:id` 共用一个组件最省，注意 `new` 要排在 `:id` 前；②`v-card :to` 是 `<a>`，子按钮 `@click.stop` 拦不住默认跳转，整卡 JS `@click` 才安全；③列表逐条拉取要「单条 try/catch + 占位」。**
- 试算页二级页面（编辑 / 新增）缺返回按钮（用户反馈：参照菜谱详情加）：**修复**：`PlansView.vue` 的 AppBar 补 `v-btn icon="mdi-arrow-left"`（`v-if="editing"` → `closeEditor()` 回方案列表，不用 `router.back()` —— 编辑器只是 `/plans` 内的模式不是独立路由），标题改为「方案名 / 新建方案」，编辑态隐藏「+ 新建」（在编辑态点它等于静默丢弃草稿）；顺手修移动端 `PlannerEditScreen` 错误态 Scaffold 缺返回（补 `leading: AppBackButton()`，正常态本来就有）。**验证**：`build` ✓ / `check:i18n` ✓ / `sources` 2166 ✓ / `test:utils` 66 ✓ / `npx tsc --noEmit` 135（基线）/ 移动端 `flutter analyze` No issues found；未实机验证（`/plans` 需登录，浏览器会话 token 已失效）。详见 [BUGFIX_试算页二级页面返回按钮.md](agent_doc/BUGFIX_试算页二级页面返回按钮.md)。
- 试算页添加菜谱/原料/商品五层连坑（用户先后反馈：①`/plans` 编辑器三个下拉一输入就 `_ctx.searchRecipes is not a function`；②点选条目 → `POST /meal-plans/evaluate` 400「缺少对应实体 ID」（payload 里 **只有 `recipe_id` 键不存在**）；③选择菜谱即渲染报错 `format.ts:46 (locale || "").toLowerCase is not a function`；④前三层修完后「合计 vs 目标」**各项恒为 0**，改菜谱/份量/食材都不动）：**根因一层挡一层**：①模板 `:search` + `@update:search="v => searchRecipes(v)"` 但从未定义这三个函数（Vuetify 3 的 `search` 是 proxied model，一敲键就 emit）；②条目列表的 `typeColor()` / `typeLabel()` 也没定义；③把 v-autocomplete 选中值当**选项对象**用（`pick.value` / `pick.title`）—— 默认 `return-object=false`，`transformOut` 对外就是 `item.value`（id）→ `recipe_id: undefined` 被 JSON 丢掉；④`formatNumber(value, locale, options?)` 把 options 传到了 locale 位 （热量行又漏传 locale）；⑤**后端 `meal_plan_service._item_cost_nutrition()` 同步调用 `async def` 的 `calculate_recipe_cost` / `calculate_recipe_nutrition`**（coroutine 的 `.get()` 抛 AttributeError，被 `except Exception: logger.debug` 静默吞掉 → cost/nutrition 恒 None → 合计恒 0），叠上 `recipe_service:1215` 的 `Decimal / float`（试算传 `float(servings)`）TypeError。**修复**：三处改 `v-model:search` + 补 `:custom-filter="() => true"` + 三个 pick 改 `number | null` 并统一 `onPick()` + id 字段 `?? null` 兜底 + 补 `typeLabel` / `typeColor` + 六处 `formatNumber` 补 `localeStore.effectiveFormatLocale` + 后端四处改 `async def`/`await` （`/evaluate` 与方案来源餐渲染同步）+ `Decimal(str(...))` + 合计 `meal_type` 按条目分组推导且 `kind` 进 watch 依赖；顺手修移动端同款抄错徽标（`planner_screens.dart` 菜谱条目显示成「主食」`mealsRoleStaple`）。**验证**：后端 `pytest tests` 910 passed、失败 38 条与 HEAD 基线 39 条逐条一致**无新增**（基线用「临时换回 HEAD 版本再跑」取得）；开发库副本只读实跑：合计由全 0 → `104.44 CNY / 736.73 kcal`、趋势 30 天逐日非 0；新增 2 条回归测试在 HEAD 上确认失败；前端 `build` ✓ / `check:i18n` ✓ / `sources` 2166 ✓ / `test:utils` 66 ✓ / `tsc` 135（基线）/ 模板标识符核对 ✓ / 移动端 `flutter analyze` No issues found。详见 [BUGFIX_试算页添加条目报错.md](agent_doc/BUGFIX_试算页添加条目报错.md)。**经验：①一层错误挡一层，同一条链路（输入 → 选中 → 加进来 → 求值 → 渲染合计 → 保存）要连着走完；②payload「该有的键不存在」= `undefined` 被 JSON 丢掉、「键在但为 null」= 显式 null；③Vuetify 3 下拉默认 `return-object=false`，模型值是 `item-value`；④多参数工具函数的位置写错不报编译错；⑤`async def` 被当同步调用 + `except Exception: logger.debug` = 静默丢失（`RuntimeWarning: coroutine ... was never awaited` 是抓手）；⑥`Decimal / float` 硬报错；⑦测试只断言结构不断言数值 = 没测到（`assert "totals" in payload` 放过了「合计恒 0」）。**
- 缺失 i18n 键 + 组合模型 provider 下拉实时化 + 本地模式方案求值崩溃（用户反馈：①控制台 `[intlify] Not found 'plans.takeToPlanner' key in 'zh' locale messages`（MealCard.vue:131）；②「AI 与机翻设置」里「组合模型 provider」的选项应随上方 AI provider 的开启/关闭**实时变化**，而不是写死一份清单）：**根因①**：`plans.takeToPlanner` 三个语料文件里都没有（功能开发时只写了 `t()` 没补键）；`check:i18n`（keys 模式）**只比对三份语料之间的键树是否一致**，三份都缺同一键时照样通过，真正能查「源码用了但语料没有」的 `check:i18n:sources` 当时**本身就是红的**（`src/api/local/business/mealComposer.ts` 的提示词中文硬编码误报），真缺键被淹在失败输出里。完整跑一遍发现 4 处真缺失：`plans.takeToPlanner`、`common.save`（PlansView + ProfileView 保存按钮一直在显示键名）、`common.cancel`、`localErrors.planNotFound`（本地模式 `localError('planNotFound')` 动态键只有 sources 模式查得到）。**修复①**：三语齐补 4 个键；把 `mealComposer.ts` 写进 `sourceIgnorePaths`（内容是发给模型的提示词与只用于重试判定的校验反馈，非用户可见文案），并把 `handlers/meals.ts` 的中文重试后缀挪进该模块导出为 `RETRY_SUFFIX` → `check:i18n:sources` **由红转绿**（2163 键全通过）；**顺手修**：`handlers/meals.ts:382` 调用了 `mealPlans.ts` 里的**私有** `evaluateItem`（未导出未导入）→ 本地模式打开「方案来源」推荐餐卡必抛 `ReferenceError`，改为 `export` + `import`，并删掉同循环里未使用的 `store`（`tsc` 137→135 条，少的正是这两条）。**修复②**：`AiConfigView.vue` 的 `:items="MEAL_PROVIDERS"` 是写死四项，停用的 provider 照样能选，选了后端 `_global_ai_section()` 因 `enabled=false` 返回 `None` → 推荐**静默降级为规则组合**且页面毫无提示；改为 `enabledMealProviders`（白名单 ∩ **当前未保存的** `enabled` 勾选，本地模式再收窄到浏览器可直连且有 key 的 openai/anthropic，与 `enabledProviderOptions`/`resolveLocalAi` 同口径）+ `mealProviderItems`（当前已保存的选择若未启用仍保留一条并标注「（未启用）」，避免值被静默改掉）+ 未启用时的警示文案；新增 `adminAI.mealPlanProviderDisabled`（标点随语言自带）/`mealPlanProviderDisabledHint` 三语，`mealPlanProviderHint` 改为「只列出已启用的 provider」。**验证**：`check:i18n` ✓ / `check:i18n:sources` ✓（2163）/ `build` ✓ / `test:utils` 66 ✓ / `npx tsc --noEmit` 135 条（比基线少 2）；`.vue` 仍是盲区（`vue-tsc` 1.8 与 TS 5.x 不兼容，直接抛 `Search string not found: "/supportedTSExtensions = .*(?=;)/"`）。详见 [BUGFIX_缺失i18n键与本地模式方案求值.md](agent_doc/BUGFIX_缺失i18n键与本地模式方案求值.md) 与 [BUGFIX_AI配置页白屏.md](agent_doc/BUGFIX_AI配置页白屏.md)。**经验：①`check:i18n` 通过 ≠ 没有缺键——它只保证三份语料一致，不保证源码用的键存在；加文案后必须跑一次 `sources`；②长期红着的门禁等于没有门禁，真问题会淹在噪声里；③`localErrors.*` 这类动态拼出的键只有 sources 模式的 `localErrorPattern` 能查；④「选项要跟着开关实时变」的实现要连**当前已保存但已停用**的那一项一起考虑（保留 + 标注 + 警示），否则用户的值会凭空消失。**
- AI 与机翻配置页打不开（用户反馈：页面白屏，控制台 `Cannot read properties of undefined (reading 'allow_user_choice')` @ AiConfigView.vue:257 + render 报错）：**根因（四层追踪）**：DB 里 `translation_configs.config` **确实存了** `ai`/`machine`/`meal_plan`/`ai_policy` 四区块（开发库 `meal_plan.provider=openai`），但 `TranslationConfig.to_dict()` **硬编码只回 `{ai, machine}`** → GET `/admin/translation-config` 丢掉后两个区块 → 前端模板 `v-model="config.ai_policy.allow_user_choice"` / `config.meal_plan.provider` 渲染期抛 TypeError，整页白屏；同一个 `to_dict()` 还让 `ai_policy.get_policy()`/`get_meal_plan_cfg()` 永远读默认值（管理员保存的 BYOK/每日上限/推荐 provider **服务端从来读不到**）；外加 `_merge_default_config` 的两处坑（provider 整块替换丢默认字段；`if key not in merged` 判据对「默认里已存在的键」失效 → 每次 GET 把策略读成默认并**提交回写**，等于静默回滚）。**修复**：①`to_dict()` 返回整份配置（深拷贝 + `setdefault` 保证 ai/machine 仍在，翻译链路不受影响）；②新增 `_deep_merge()`，`_merge_default_config` 改为 `deepcopy(DEFAULT) ← 递归合并存库值`（存库值优先），PUT 也改为递归合并写入（旧前端只提交 ai/machine 时不再抹掉其它区块）；③前端新增 `utils/translationConfig.ts`（与后端逐字对齐的 `DEFAULT_TRANSLATION_CONFIG` + `deepMergeConfig` + `normalizeTranslationConfig`），`AiConfigView` 取回后归一化兜底；④本地模式 `api/local/handlers/admin.ts` 同款接口原来只写 ai/machine（**同样白屏**），改用同一份 util 并在写回时与存档合并。**无需数据库迁移**（数据本就在库里，丢的是序列化）。**验证**：后端新增 3 例（GET 带两区块 / 策略与 provider 存取往返 + 服务层读到存库值 / 旧客户端残缺 PUT 不丢区块与缺省字段）→ `pytest tests/test_usda_admin_api.py tests/models/test_usda_models.py` 12 passed；前端 `test:utils` 新增 4 例 → 66 passed，`build` ✓、`check:i18n` ✓、`npx tsc --noEmit` 无新增错误（137 条存量基线，48 条是 `.vue` 解析盲区）；开发库只读核对 `stored keys = [ai, ai_policy, machine, meal_plan]` 与 `to_dict()` 一致、`_merge_default_config` 保住 `openai`/deepseek base_url。详见 [BUGFIX_AI配置页白屏.md](agent_doc/BUGFIX_AI配置页白屏.md)。**经验：①JSON 列里有数据 ≠ API 有数据——加新顶层区块必须同步改 `to_dict()`，否则「前端崩 + 服务端读默认值」两个无日志 bug 一起发生；②「保留未知键」的 `key not in default` 判据救不了「默认里新增过的键」，表达「存库值优先」只能用递归合并；③PUT 整份替换遇到结构落后的客户端会永久丢数据，写侧也要合并；④前后端各有一份默认结构（云端 / 本地模式）时容易只改一边。**
- 试算页三端落地（阶段 3，用户确认继续）：**后端（679567a0）**：`meal_plans`（kind=meal|day，软删）+ `meal_plan_items`（recipe|ingredient|product 三选一 CheckConstraint；recipe 项 servings、原料/商品项 quantity+unit_id）+ `daily_recommendations.plan_id`（source='plan' 回链）；`meal_plan_service`：evaluate（recipe 项走菜谱成本/营养引擎带 servings 缩放；原料项加权价×单位换算×营养 reference 基准折算；商品项最新记录单价×换算）+ targets（day=每日目标、meal=×MEAL_RATIOS）+ plan_cost_trend（as-of 逐日：菜谱走区间趋势 avg 档、原料逐日加权价、商品最新价前向填充）；API `/meal-plans` CRUD/evaluate/cost-trend + `/meals/recommendations/set-plan`（meal 需 meal_type / day 设三餐；该餐无推荐时直接建 plan 来源行）；**响应兼容**：source='plan' 的餐渲染 `plan` 视图（方案名+条目明细+totals），换整餐后 source 翻回 AI/规则并清 plan_id；**刷新守卫放宽**：方案来源餐无 items 也允许刷新（旧守卫会拒绝）。**web（85491731）**：`/plans` 页（列表卡片 + 编辑器：三类搜索添加条目/份量数量编辑/一日分组/求值 vs 目标对比/echarts 成本趋势 30|90|365 天/保存/删除/设为今日）+ 侧栏导航 + 推荐卡「拿去试算」（MealCard emit → sessionStorage 草稿 → /plans 载入）；本地模式 IndexedDB `meal_plans` 单 store（items 内嵌，DB v5）+ handlers 同契约 + set-plan 写 meal_recommendations 行。**移动端（feat 4315a115→86a596f7）**：`features/planner/`（列表屏 + 编辑屏：CustomPainter 折线趋势、设为今日、三类条目添加），路由 `/plans`、`/plans/edit`，桌面侧栏 + 「更多」菜单入口（Wrap 换行已支持 6 项）。**验证**：后端 test_meal_plans_* 4 例 + 相关回归 14 全绿；web build ✓ / i18n ✓ / tsc 131；移动端 analyze 0 error / test 679 通过 6 存量失败。**⚠️ 存量库需执行 `backend/scripts/sql/20261015_meal_plans_sqlite.sql`（新表 create_all 可自动建，但 daily_recommendations.plan_id 列必须手工加）**。详见 [FEATURE_试算页.md](agent_doc/FEATURE_试算页.md)。**经验：①设计文档把阶段 3 的 plan_id 列推迟到阶段 3 迁移是对的——阶段 2 先行不背依赖；②SQLite 迁移脚本里 "group" 列名要加引号（保留字）；③python 批量改代码时锚点必须先验证唯一性——本次 `_plansTab` 插入吃掉了 `_favoritesTab` 定义（同锚点 `const _profileTab = _Tab(`），analyze 报 duplicate_definition 才发现；④测试里 set-plan 新建的 plan 来源行没有 items，会撞上刷新守卫「无 items = 暂无推荐」——方案来源餐要放宽该守卫。**
- AI 一餐推荐前端三端落地（2B web+本地 / 2C 移动端，用户确认继续）：**web 云端**：`MealCard` 重写为多道菜套餐卡（dishes 列表带 role 徽标 + 每道成本·热量 + 每道「换这道」swap 按钮 + 「换整餐」；AI 来源标 `mdi-creation`；理由/偏好脚注；封面取 staple 有图者；无 dishes 时回退单道兼容渲染），`DailyMealsView` 顶部一句话偏好输入（回车/应用按钮 → 当前餐整餐重搭使偏好生效），`stores/meals` 带 preferenceInput、`refreshMeal(mealType, recipeId?)`；**本地模式**：新 `business/mealComposer.ts`（与后端同契约：分类池/规则组合/staple 兜底/校验器/prompt 构建/浏览器直连 AI `aiComplete`），`handlers/meals.ts` 重写（dishes 行结构 + preference + refresh_count 5 次上限 + 单道换保 staple + 近 7 天去重；`meal_plan.provider` 仅浏览器可直连的 openai/anthropic，未配置/失败降级规则），删旧 `mealRecommender.ts`；**AI 配置页**：新增「餐食推荐（AI 组合）」面板（provider 白名单四选 + 超时）与「AI 使用策略」（默认方式/每日上限/允许自选/允许 BYOK/允许自定义端点/AI 标识 + 对外服务提示文案），`_merge_default_config` 已保留未知顶层键所以回写安全；**个人中心**：AI 设置卡（方式选择按 policy 过滤、BYOK 字段、密钥打码回显/清除、隐私说明），走 `/profile/ai-settings`；**移动端**：`RecommendedDish` 模型（role/reason）、`MealCard` 多道菜清单（role 徽标 + 每道换这道 swap + AI 星标 + 理由/偏好脚注 + 「换整餐」）、home 顶部偏好输入（应用 = 当前餐重搭）、repo/provider 带 preference 与 recipeId。**验证**：web build ✓ / check:i18n ✓ / sources 2093 / `tsc --noEmit` 131 条（低于基线 138，顺手清了旧 meals 代码的 6 个 unused-var）；移动端 `flutter analyze` 0 error（仅 1 条未触碰文件的既有 onReorder info）、`flutter test` **679 通过 / 6 存量失败**（基线一致）。**注意**：`Icons.swap_horizontal/lightbulb_on_outline/comment_quote_outlined` 均非 Flutter 内置名（正确名 `swap_horiz`/`lightbulb_outline`/`chat_bubble_outline`），analyze 会逐个报。详见 [FEATURE_AI一餐推荐.md](agent_doc/FEATURE_AI一餐推荐.md)。**经验：①响应加字段且保留旧字段的兼容别名，三端可以独立推进不互相阻塞；②本地模式复刻后端「组合器契约」时把校验器/规则/提示词做成同构 TS 版本，AI 降级行为与云端一致；③新聚合配置区块（meal_plan/ai_policy）依赖后端「默认合并保留未知顶层键」的修复，前端回写才不丢数据。**
- 移动端扫码无反应 + 营养「每 X 单位」基准 / 新建默认五项（用户一次反馈三条：①移动端添加价格时扫**一部分**商品条码（几个枕装奶、火腿肠）毫无反应；②新建原料/商品添加营养应默认带出能量 / 蛋白质 / 脂肪 / 碳水化合物 / 钠，能量默认 kJ（可改）、钠默认 mg，且**只点开没填就不记录**；③营养录入应能改「每 X 单位」的基准 —— 一直是每 100 g，可从自定义单位里选；每个营养素是否各带基准用户自己也在犹豫，本轮按整表一个基准做）：**根因①**：后端 `resolve_barcode` 在**本库命中**（`products.barcode` / `product_barcodes`）与**条码缓存命中**两条路径上提前 return，此时 `has_enabled_providers` 恒为 `false` —— 开发库实跑四条用户条码（伊利/夏进枕装奶、双汇/鸡肉火腿肠）全部是 `found=true source=local has_enabled_providers=false`；而移动端两个扫码入口**把该字段当「有没有结果」的闸门、先于 `found` 判断就早退**，于是「已建档商品扫码全被静默吞掉、未建档商品的条码反而正常弹新建对话框」（web 一直先判 `found`，故只有移动端中招）。**修复①（feat/mobile-app，c40445fe）**：判定改为只看 `found`，本库命中直接选中商品；商品表单区分「本库命中（提示已属于商品 X 且**不回填名称**，否则保存撞条码唯一校验）/ 外部命中（回填名称品牌）/ 未命中（提示可手动填写）」，ARB 两新键 + 两条回归测试。**②③方案**：基准字段（原料 `nutrition_data.reference_amount/reference_unit`、商品 `custom_nutrition_data` 顶层 `reference_amount/reference_unit`，与 USDA 匹配同字段）**此前表里有、写入链路根本没接** → 后端提议执行器落库基准 + 快照/回滚带上（原料）、端点 payload 写入（商品）、拆分为原料与导出导入一并带上、`reference_unit` 列 10→50（alembic + 三引擎 SQL）；**计算**改为基准先折算成**克当量**再算缩放（复用 `_convert_to_base`，支持 mL / 斤 / 自定义单位「1 袋 = 250 g」），单位解析不出来时退回「按克」旧口径不臆估；**两端 UI** 新增基准输入（候选 = 本实体**可折算**的自定义单位 + 全局质量/体积单位，web `utils/nutritionBasis.ts` / 移动端 `shared/utils/nutrition_basis.dart` 各一套纯函数 + 单测）与「（每 X 单位）」动态标题；新建（无数据）预填五项（能量随用户能量单位偏好、缺省 kcal —— 最初写死 kJ，同日用户追加改为跟随偏好 / 钠 mg），**空保存按「意图」分两种**：本来没数据 → 静默不记录（不发清空请求、不弹已保存）；本来有数据被清空 → 保持原有清空覆盖/「至少填一项」语义。**验证**：后端新增 `tests/test_nutrition_basis.py` 10 例；**等价性：开发库全部 565 个有营养数据的原料 × (100 g, 250 g, 1 斤) 新旧代码输出 sha256 完全一致**（存量全是 100 g，走 `unit=='g'` 短路分支逐位不变）；web `build` ✓ / `check:i18n` 三语一致 / sources 2084 / `test:utils` 52→62 ✓ / `npx tsc --noEmit` 归一化后与基线**逐条一致**（118 组）；移动端 `flutter analyze` 0 error（仅存量 onReorder deprecation info）、定向用例全绿（全量见提交记录）。**实机 GUI 验证待服务启动后补做**（本轮开发时 5173/8000 均未运行）。详见 [BUGFIX_移动端扫码无反应.md](agent_doc/BUGFIX_移动端扫码无反应.md) 与 [FEATURE_营养基准与默认项.md](agent_doc/FEATURE_营养基准与默认项.md)。**经验：①服务端的「能力开关」字段（has_enabled_providers）不能当「结果开关」用 —— 本地命中时它必然为 false，拿来当闸门会静默吞掉最常用的一条路径且毫无日志；②「表里早就有的字段」不等于功能已完成，要查 写入 → 读取 → 消费 三段是否都通；③数值口径变更必须先证等价（本次靠短路分支把存量 sha256 锁死）；④前端候选单位必须与后端**同一条解析链**过滤（折算不出来的自定义单位会让缩放退化成按克，选它等于埋雷）；⑤「点进来没填」与「删空已有数据」是两种意图，判据要在**打开编辑器那一刻**记下来；⑥给共享回调/仓库方法加参数，一次搜干净所有调用点与测试假实现（本轮 onSave 签名牵动 4 个 lib 文件 + 5 个测试文件）。**
- AI 一餐推荐后端重写（用户需求：一餐只推一道、没有主食不可用；要求 AI 组合 + 管理员/用户级推荐方法 + BYOK + 对外服务合规姿态）：**架构**：候选池收窄（午晚=主食/荤/素/水产/汤粥，早餐=早/主食/汤粥）+ 近 7 天去重放宽链 7→3→0 + 收藏加权（+0.1）→ 分类 top-K 短名单 → `meal_composer` 组合层（`LLMMealComposer` 走 Translator 四 provider 通道 + 校验器（≥1 staple/id∈短名单/午晚 staple 必须「主食」分类，失败回灌重试 1 次）→ `RuleMealComposer` 降级）→ 父表+子表落库；**存储**：`daily_recommendations` 加 reason/preference/source/refresh_count 删 recipe_id，新表 `daily_recommendation_items`/`user_ai_settings`（Fernet 加密 BYOK）/`ai_usage_events`；**策略层** `ai_policy.resolve_ai_credentials`（用户 method→全局默认→rule；`allow_custom_base_url` 默认关；每日 AI 上限按 system_ai 的 ok/fallback 计数、用户级 override 优先，超限自动降级 rule）+ `/profile/ai-settings` 端点（管理员可代理，key 只回显打码）；**刷新**：整餐重搭 + 单道换（换 staple 保 staple），5 次/餐/天上限改读 `refresh_count` 列（**修复旧「行数-1」口径从未生效的 bug**）；**响应兼容**：`recipe` 保留为 staple/首道别名 + 新增 `dishes[]`（旧前端不断）。**验证**：相关回归 57 项全绿（校验器 9 例 / 策略 3 例 / 端点 3 例 / 端到端 4 例：假 LLM 落库 system_ai+兼容别名+偏好快照、坏输出降级 fallback 事件、5 次上限、放宽链；真实 claude CLI 超时降级链路被意外端到端验证）。**⚠️ 存量库须手工执行 `backend/scripts/sql/20261015_recommendation_items_*.sql`（列变更 create_all 不覆盖，未执行前推荐接口 500）**；2B（web+本地）/2C（移动端）待做。详见 [FEATURE_AI一餐推荐.md](agent_doc/FEATURE_AI一餐推荐.md)。**经验：①测试走「API+后台线程+轮询」撞 StaticPool 单连接会读到未提交的中间 flush 状态——推荐逻辑一律服务层直调+假 LLM 注入；②批量 query.delete() 不触发 ORM cascade，删父行留孤儿 item，SQLite rowid 复用会让孤儿挂尸到新记录（同餐重复菜假象）；③共享内存库的跨测试残留三件套（AI 设置行/用量事件/当日推荐）必须在各测试文件公共准备里显式清空；④默认策略=claude_code 时测试默认拉起真实 CLI（每餐 120s 超时，全量 26 分钟的元凶），不测 AI 路径的用例要显式强制 rule；⑤「默认合并」函数必须保留未知顶层键，否则 PUT 回写静默丢新配置区块。**

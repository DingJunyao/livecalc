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

技术栈：Python + FastAPI

目录：`backend`，所有后端相关操作均在此目录下进行，并且使用虚拟环境。

开发时使用 `uv` 管理。

虚拟环境：根目录下的 `.venv` 下的环境。

所有后端的修改都必须确保无语法错误。

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
移动端试算页列表卡片补成本 / 营养素 / NRV / 30 天迷你图，条目可点进实体详情，求值餐次按分组推导：详见 [FEATURE_移动端试算页列表卡片与条目跳转.md](agent_doc/FEATURE_移动端试算页列表卡片与条目跳转.md)
移动端试算列表 FAB / 营养换行 / 详情去重与模块顺序 / 菜谱原料商品选择器 / 推荐偏好左置下拉：详见 [BUGFIX_移动端试算与推荐布局.md](agent_doc/BUGFIX_移动端试算与推荐布局.md)
趋势图外币未换汇（IDR 按原值参与加权）/ 移动端原料趋势「袋」按 1:1 折斤 / 营养把 quantity=NULL 当 0（quantity_range 按最大值 + 模糊量映射，与成本同口径）：详见 [BUGFIX_趋势图汇率与营养范围数量.md](agent_doc/BUGFIX_趋势图汇率与营养范围数量.md)
移动端历史价格原币误标展示币（原料/商品记录行 + 删除确认；新增 `formatMoneyWithConvert`，有效汇率才显示 `≈` 折算）：详见 [BUGFIX_移动端原币记录显示换汇.md](agent_doc/BUGFIX_移动端原币记录显示换汇.md)
移动端试算详情成本占比 / 营养溯源同条目配色不一致（统一用评估 `item_id` 配色）：详见 [BUGFIX_移动端试算详情配色一致.md](agent_doc/BUGFIX_移动端试算详情配色一致.md)
详情页趋势图「综合/按商家」切换（原料/商品各商家价格趋势对比；商家 chips 多选默认前 3 家，纯前端分组 + 同口径 as-of，无后端改动）：详见 [FEATURE_商家价格趋势对比.md](agent_doc/FEATURE_商家价格趋势对比.md)
快速填写商家下拉缺店（移动端 `GET /merchants` 不带参数 → 后端默认 limit=10 按创建时间倒序截断；Web 硬编码 limit=100 同类隐患；两端改按 total 翻页取全）：详见 [BUGFIX_快速填写商家下拉截断.md](agent_doc/BUGFIX_快速填写商家下拉截断.md)
移动端列表搜索状态残留（全局 provider 保留 `searchQuery`、页面重建后输入框为空 → 空框配旧结果且刷新清不掉；商品/原料/菜谱列表进入时按空关键词重置）：详见 [BUGFIX_移动端列表搜索状态残留.md](agent_doc/BUGFIX_移动端列表搜索状态残留.md)
趋势图只在真实记录日画点（原料/商品/菜谱成本/方案走势统一；菜谱与方案趋势由后端新增 `has_record`，前端 `symbolSize=0` 表示 as-of 携带日）：详见 [FEATURE_趋势图仅记录日画点.md](agent_doc/FEATURE_趋势图仅记录日画点.md)
原料趋势图显示替代/回退/从属折算价（与菜谱成本同一降级链 direct→fallback→name_match→recipe→contains；后端 `/ingredients/{id}/price-series`，前端虚线 + 区间带 + 「含替代/从属」开关默认开）：详见 [FEATURE_原料趋势替代从属折算.md](agent_doc/FEATURE_原料趋势替代从属折算.md)
移动端原料趋势折算价与各商家折算价（Flutter：折算虚线+区间带+「含替代/从属」开关；商家卡片紫色区分、区间、原直接价；每克→每斤）：详见 [FEATURE_移动端原料趋势折算与商家折算.md](agent_doc/FEATURE_移动端原料趋势折算与商家折算.md)
Web 价格记录图标去货币化（侧栏 + PWA 快捷方式 prices.png；`mdi-currency-cny` → `mdi-receipt-text-outline`，对齐移动端 `receipt_long`）：详见 [FEATURE_PWA快捷方式图标.md](agent_doc/FEATURE_PWA快捷方式图标.md)
商品/原料「关联与换算」（两两等式 `1 提 = 5 包` / `3 kg 鲜 = 1 kg 干`；单位与密度内展示；direct → entity_link → fallback → recipe → contains；本地模式）：详见 [FEATURE_商品原料关联与数量换算.md](agent_doc/FEATURE_商品原料关联与数量换算.md)

### 最新修复记录
- 移动端补原料趋势折算价与各商家折算价（用户反馈：本会话 web/后端需求在移动端没实现）：`ComputedPricePoint`（每克→每斤 ×500）+ `MerchantPrice` 新增 `source/chain/isDerived/区间/原直接价`；仓库 `getPriceSeries`、商家接口带 `include_relations`/`prefer_relations_when_stale`；provider 增加 `computedPoints/includeComputed`，`setIncludeComputed` 同时重取序列与商家价、切区间同步；`CostTrendChart` 加开关 + 紫色虚线/区间带 + tooltip 折算行；商家卡片折算行紫色浅底（不再置灰）、显示区间/来源/红字原直接价，高度 124→152。i18n 7 键三语 + gen-l10n。验证：`flutter analyze` 仅剩既有 1 条提示，新增 4 例模型测试 + 原料相关 31 passed。**[追加]** 用户指出开关没有文字提示、移动端没做「食材/商品在不同超市的价格趋势对比」：开关改为「开关 + 可见文字」整行可点；新增 `buildMerchantTrendSeries`（按 `merchantId` 分组各跑 as-of 序列、按记录日数降序）+ `priceRecordDays`；原料/商品 provider 存 `merchantSeries`/`chartRecordDays`；`CostTrendChart` 加「综合 / 按商家」ChoiceChip + 商家 FilterChip（默认前 3 家、至少留 1 家、切区间不重置手动选择）+ 多色均价线（只在该商家记录日画点）+ 逐商家 tooltip；综合模式也补记录日圆点。验证：`flutter analyze` No issues found；新增 3 例商家序列测试（共 7）→ 通过；原料+商品+recipes/widgets 132 passed。**[追加2]** 用户反馈胡萝卜无关系也显示「含替代/从属」、且「综合/按商家」要改成和区间一样的下拉：开关显隐改由 `_showComputedSwitch(state)` 决定（层级里出现 fallback/substitutable/contains/recipe，或已有非 direct 折算点）；两枚 ChoiceChip 改为标题栏 `DropdownButton<TrendViewMode>`（`merchant_mode_dropdown`），商家多选 chips 仅在按商家模式显示。验证：analyze 无问题、77 passed。**[追加3]** 用户反馈胡萝卜仍有折算线、且两个下拉字号不一致：根因是 `price-series` 每天都会返回（多为 direct），移动端把整段存进 `computedPoints` 并未过滤，图表把 direct 的 min/max 当折算区间画线；新增 `nonDirectComputedPoints()` 在 provider 与图表两处过滤（与 Web 一致），胡萝卜因此无折算线且开关也不出现；模式下拉去掉自定义 `labelMedium`，与区间下拉同用默认字号。验证：新增过滤测试（8 passed）、analyze 无问题。**[追加4]** 用户反馈按商家时商家开关挤在一行、看不出可拖动，要求改下拉：删除横向 chips，改为下拉触发器（`merchant_selector`：选中摘要 + 箭头）+ 底部勾选面板（`CheckboxListTile` + 色点 + 「完成」），至少保留 1 家，关闭即回写。验证：analyze 无问题、91 passed。**[追加5]** 按商家补区间带：Y 轴范围改用该商家 min/max，区间跨度日画同色 12% 透明度带，tooltip 追加 min~max；仍只在记录日画点。验证：analyze 无问题、8 passed。详见 [FEATURE_移动端原料趋势折算与商家折算.md](agent_doc/FEATURE_移动端原料趋势折算与商家折算.md)。

- 商品/原料「关联与换算」（用户明确重置旧包装组：入口太绕、只能同原料、结果看不懂；改为两两等式 + 单位与密度内展示）：新增 `entity_quantity_links`（product/ingredient 多态两端、数量+单位、note、软删）、`entity_link_service`（折克/因子/最新价）、提议执行器；`UnitConversionService.convert` 支持沿关联折克（提→包→箱→g）；成本链改为 direct → **entity_link** → fallback → recipe → contains（`_linked_cost_range_ppg` 同时看原料自身关联与原料下商品关联），各商家折算价补 link 行，source=`entity_link`；Web 新增 `EntityQuantityLinksSection`（商品/原料详情「单位与密度」内，行内等式 + 克重自检 + 对方最新价折合，商品页只读所属原料关联），价格表单合并关联单位与折合价；移动端新增同构 `EntityQuantityLinksSection`（详情页单位与密度卡内、搜索目标、等式预览、克重/价格参考）并把关联单位并入记价下拉；本地模式 IndexedDB v6 + CRUD + costCalculator link 层 + 导出导入按名字重映射；删除/合并有关联先要求解除。验证：后端新增 4 passed（含提→包→箱 1700g、干/鲜 0.02 元/g）、相关回归 70 passed；前端 build ✓、test:utils 70 ✓、check:i18n / sources ✓；移动端 `flutter analyze` No issues found、关联模型/单位名 24 passed。迁移/三引擎 SQL 已生成但**未执行**；后端需重启。详见 [FEATURE_商品原料关联与数量换算.md](agent_doc/FEATURE_商品原料关联与数量换算.md)。
- 移除「同名商品匹配」（用户要求：不需要 name_match，例如「鸡胸肉」不该匹配到别的原料下「鸡胸肉肠」的商品）：降级链统一为 direct → fallback（含 substitutable）→ recipe → contains，删除 `_name_match_cost_range_ppg()`，覆盖菜谱成本（单/区间）、原料折算序列与 `_relation_cost_range_ppg`、最新记录时间、按商家折算候选；回归改为 `test_relation_chain_has_no_name_match`（断言函数不存在、三层都无价时返回 None）。实跑鸡胸肉（id=39）6 家商家全部 direct、趋势 30 天全 direct。后端需重启调试会话。详见 [FEATURE_原料趋势替代从属折算.md](agent_doc/FEATURE_原料趋势替代从属折算.md)。
- Web 价格记录图标去货币化（用户要求：价格记录功能图标不能绑定特定货币，含 PWA 快捷方式图标，可参考移动端）：侧栏两处 `mdi-currency-cny`（人民币符号）改为 `mdi-receipt-text-outline`（收据 + 文字行，无货币符号；移动端价格页用的是 Material `receipt_long` / `receipt_long_outlined`）；`scripts/generate_pwa_shortcuts.py` 同步图标名后重跑 `uv run scripts/generate_pwa_shortcuts.py`，`frontend/public/shortcuts/prices.png` 由 ¥ 变为收据图标，其余 6 张 PNG 字节未变。验证：前端 `npm run build` 通过（50.30s，PWA precache 186 entries）。详见 [FEATURE_PWA快捷方式图标.md](agent_doc/FEATURE_PWA快捷方式图标.md)。
- 原料趋势图补替代/回退/从属折算价（用户要求：有回退/替代/从属关系时也显示计算后的结果，逻辑与菜谱成本一致，开关默认打开）：新增 `calculate_ingredient_price_series()` 逐日 as-of 跑与菜谱成本 1:1 的降级链（direct→fallback(含 substitutable)→name_match→recipe→contains），返回每克三档 + source + chain；接口 `GET /nutrition/ingredients/{id}/price-series?days=`（≤366，逐日链成本考量）。前端 `PriceTrendChart` 新增 `computedSeries` → 紫色虚线 + 低透明区间带 + 「含替代/从属」开关（默认开）+ tooltip 显示来源与链路（如「回退/替代关系（酱油 → 生抽）」）；`IngredientDetail` 按区间取数并过滤 direct 日避免与直接价重复。只读实跑：酱油→生抽、干红椒→干辣椒、中筋面粉→面粉、糖→白糖 全部 fallback；猪肉 30/30 天 name_match；有直接价者全 direct。新增回归 2 passed，前端 build + check:i18n 通过。本地模式无该接口（静默隐藏）。**[实机反馈修复]** 首版在 `/data/ingredients/14` 图表与最新价全空：①图表容器由 `v-if` 控制，首帧只有折算序列时容器不存在 → `onMounted` 的 initChart 拿不到 ref，之后 watch 只调 updateChart（`!chart` 直接 return）→ 永远无实例；改为统一 `renderOrInit()`（无实例且有 ref 则 init）覆盖所有 watch。②最新价卡片条件 `v-else-if="latestPrice"` 只认直接价，猪肉 0 条直接记录 → 整卡隐藏；改为 `latestPrice || latestComputedPoint`，无直接价时展示折算价 + `charts.computedPrice` 标签 + 区间 + 日期/来源链路。**[第二轮]** 用户指出猪肉不该恒定、要区间：③同名匹配命中了「从属子食材」的商品（猪肉→子食材猪肉末，3 条 6 月记录恒定 15.90）→ 新增 `_contains_descendant_ids()` 并在 name_match 里按 `Product.ingredient_id` 过滤后代商品，修复后走 contains（30 天 7 个变化点 11.73→11.85）；④从属聚合的 min/max 原按 strength 加权 → 子食材只有单一价时塌缩成一条线，改为跨子食材取极值（猪肉 5.80–29.90），avg 仍加权。tooltip 补区间行；新增 2 条回归。**注意：后端由 VS Code 调试进程启动、无 `--reload`，改 Python 必须重启调试会话才生效**。**[第三轮]** 用户反馈开关切回后图表消失 + tooltip 贴左：⑤容器 `v-if` 在关开关时被移除，但 ECharts 实例仍指向旧 DOM → 再打开时画在已脱离文档的 canvas 上；容器条件加 `|| hasComputed`，`renderOrInit()` 检测 `chart.getDom() !== chartRef.value` 时 dispose 重建；⑥从属链路很长 + 无 `confine` → tooltip 被容器裁切看起来「一直贴左」，加 `confine: true` + `max-width: 320px` + 链路截断 36 字符（商家模式同步）。**[第四轮]** 用户问「食用油(3) 为何无折算价」并选「超期优先关系、可切换」：⑦食用油有 6 月直接记录（>30 天）+ 4 个从属子食材，旧口径 direct 优先 → 恒定 6.59；新增 `prefer_relations_when_stale`（接口参数 + 图表开关「超期优先替代/从属」默认开）：直接价最近记录超 30 天且关系折算可用时改用关系结果，返回 `direct_ppg`/`direct_stale`，最新价卡片改以外折算价为主并提示原直接价；⑧name_match 还会命中「原料自己的商品」（食用油→同名商品）把旧价换 source，排除集合改为「自身 + contains 后代」。实跑：食用油开关后 contains ×30（5.99–14.33），猪肉两种开关一致。新增 2 条回归（超期优先、自身/后代排除）。**[收尾]** 用户要求只保留一个开关：删掉单独的「超期优先替代/从属」开关，统一由「含替代/从属」控制——开 = 显示折算 + 超期优先（请求带 `prefer_relations_when_stale`），关 = 不取折算数据、只看直接价；开关状态上提到父组件，切换即重新取数。**[第五轮]** 各商家价格也按关系折算：`latest-price-by-merchant` 新增 `include_relations`，按商家逐条补齐（直接价优先，缺失时 fallback → name_match（排除自身/后代）→ contains（子食材按 strength 加权、区间取极值）），行带 `source`/`chain`/`is_derived`；前端折算行显示来源标签 + 链路 + 区间，并与图表共用同一个开关（切换同时重取趋势与商家价）。实跑：猪肉 0→6 家（全 contains，9.15–20.88），食用油 3 家直接价不被覆盖。**[第五轮续]** 用户指出食用油 3 家直接价已过时、应显示折算价：新增 `prefer_relations_when_stale`——该商家直接价 `is_stale`（>30 天）且同商家有折算候选时，用折算行替换并带 `direct_price`/`direct_stale`（无候选则保留旧价）；前端折算行不再套「陈旧置灰」，改紫色浅底 + 左侧强调条 + 紫色来源文字（去掉 `v-chip`，避免 `.v-chip__content` 内边距影响小卡片排版），被替换行红字提示原直接价。实跑：食用油丹尼斯 6.59→6.29、梦之城 6.58→15.57、万达无子食材记录仍保留 6.58。详见 [FEATURE_原料趋势替代从属折算.md](agent_doc/FEATURE_原料趋势替代从属折算.md)。
- 趋势图只在真实记录日画点（用户要求：其他价格趋势图也要「有记录才画点」）：`PriceTrendChart` 主均价线与 `CostTrendAnalysis` 回退均价线改为逐点 `symbolSize`（`recorded`/`has_record === false` → 0，只连线）；原料/商品趋势在前端用记录日期集合标注，菜谱成本趋势与方案走势由后端新增 `has_record`——`_recipe_record_days` 一次查询取「菜谱直接食材对应商品」有记录的本地日期，`plan_cost_trend` 透传菜谱项并补散项记录日（按 UTC 日期对齐 daily key）。只读实跑：菜谱 3 的 30 天 = 31 点/8 个记录日，方案 1 = 30 点/10 个记录日。顺手把两个写死日期的 plan trend 老测试改成按当天生成（时间一过必挂）。验证：后端 11 passed（含新增 has_record 透传回归），前端 build 通过。移动端图表本无逐点圆点，未改。详见 [FEATURE_趋势图仅记录日画点.md](agent_doc/FEATURE_趋势图仅记录日画点.md)。
- 快速填写商家下拉缺「美道家万达广场店」（用户反馈：移动端下拉没有该店，要求检查 Web）：只读查库确认该店 `is_open=1`、`region_id=1951`，按 `created_at DESC` 排营业商家第 12 位；后端 `GET /merchants` 默认 `limit=10`，移动端快速填写请求不带任何参数 → 被截断（Web 传 `limit=100`，14 家全拿到，本次未复现，但同样只取一页有 >100 漏店隐患）。两端改为按 `total` 翻页取全（单页 100、最多 10 页兜底）。验证：Web `pnpm run build` 通过；`flutter analyze` No issues found；quick fill 3 tests passed。详见 [BUGFIX_快速填写商家下拉截断.md](agent_doc/BUGFIX_快速填写商家下拉截断.md)。
- 详情页趋势图新增「综合/按商家」对比（用户需求：对比同一食材/商品在不同超市的价格趋势）：数据层零改动——`/products` 返回的价格记录本身带 `merchant_id`/`merchant_name`，前端按商家分组后各跑一遍 `buildWeightedAsOfDailySeries`（组内沿用商品权重），综合口径不变。`PriceTrendChart` 新增 `comparisonSeries` prop：≥2 家时标题栏出现「综合/按商家」切换，商家模式渲染多选 chips（默认记录数最多的前 3 家，防线条过多）、每商家一条固定色板均价线、tooltip 逐行列出；区间切片 `sliceByFilter` 与主序列共用，`setOption(notMerge)` 防模式切换残留。后续追加：只在真实记录日画点（`recorded` 标记）、切换时间区间不重置商家勾选（走商家 id 集合签名判断）、**按商家区间带**（原料有多个关联商品时，商家序列用 `bandFromRecords` 取该商家当日各商品价 min/max，画淡色区间带并把区间写进 tooltip；实测库里 15 组「原料+商家」≥2 商品）。验证：`pnpm run build` ✓、`check:i18n` ✓。详见 [FEATURE_商家价格趋势对比.md](agent_doc/FEATURE_商家价格趋势对比.md)。
- 移动端列表搜索状态残留（用户反馈：商品列表搜索后离开再进入，输入框为空但仍是旧搜索结果，空关键词刷新也回不到全部）：`productListProvider` 全局常驻保留 `searchQuery`，列表页 `TextEditingController` 随页面重建清空，`initState` 的 `load()` 仍按旧关键词请求；空框时又无任何路径把 `''` 写回 state。商品、原料、菜谱三列表页进入时若 `state.searchQuery` 非空先 `setSearch('')` 再加载（筛选条件保留，因为界面有筛选徽标而搜索框无残留指示）。新增两个回归：商品列表预置残留关键词后挂载页面断言清空 + 以 null 关键词重查 + 恢复全部；菜谱 notifier 断言输入 400ms 后自动按关键词请求、清空后重载全部。`flutter analyze` No issues found，新增 2 项 + 相关既有全过。**复盘**：曾误判菜谱搜索不触发加载（只看到 `setSearch` 前两行，实际第 3-4 行有 400ms 防抖 + `loadRecipes()`），已纠正并删掉重置时重复的一行 `loadRecipes()`；结论必须读完整方法体。详见 [BUGFIX_移动端列表搜索状态残留.md](agent_doc/BUGFIX_移动端列表搜索状态残留.md)。
- 移动端试算详情配色一致（用户反馈：食材成本占比、营养贡献溯源中每个食材色块应一致）：后端评估营养溯源的 `ingredient_id` 实为方案条目 `item_id`，移动端成本占比却取菜谱/原料/商品实体 ID，两套标识导致取色不同。已改为成本占比同样读取 `detail.item_id`，缺失时两处同走灰色兜底；新增同色回归，`flutter analyze` No issues found，plan detail 2 tests passed。详见 [BUGFIX_移动端试算详情配色一致.md](agent_doc/BUGFIX_移动端试算详情配色一致.md)。
- 移动端历史价格原币误标展示币（用户报告：包菜原料一条 1250 IDR 在移动端显示 1250 CNY，Web 正常）：后端 `/products` 返回的 `price` 是记录原币值，并单独携带 `currency` / `exchange_rate`；Web 用 `PriceWithConvert` 显示原币并折算。移动端原料、商品详情历史行却把原值传给 `formatMoney(price, userCurrency)`。修复：新增 `formatMoneyWithConvert`，原料/商品记录行、价格列表删除确认统一显示 `1250 IDR ≈ 折算值`；汇率缺失/非法不折算。其余最新价、列表迷你图、商家价、成本/试算等货币口径检查为后端折算或已有原币+折算显示。验证：新增格式化、原料详情、商品详情、删除确认回归；`flutter analyze` No issues found，相关 Flutter 测试 17 passed。详见 [BUGFIX_移动端原币记录显示换汇.md](agent_doc/BUGFIX_移动端原币记录显示换汇.md)。
- 移动端试算列表对齐商品列表（用户最终要求）：卡片改为 CircleAvatar 类型图标 + 标题 + 标题下方完整标签与成本 + 右侧 Sparkline/操作图标；成本取消固定窄列，避免截断；高度固定 76。圆标短标签中文「餐/顿」、英文 `Meal/Day`、阿语「وجبة/يوم」，完整标签仍在标题下。设为今日保持图标。更新布局测试；Flutter analyzer No issues found，planner 相关 11 passed。详见 [BUGFIX_移动端试算与推荐布局.md](agent_doc/BUGFIX_移动端试算与推荐布局.md)。
- 移动端试算列表极简卡片（用户最终选择）：只保留类型标签、方案名称、成本迷你图、成本，以及设为今日/删除图标；移除项数、热量、蛋白质、脂肪、碳水和额外标题行。卡片固定高度从 240 降为 88，加载前后不跳动；「设为今日」改图标按钮并保留 tooltip。更新列表布局测试；Flutter analyzer No issues found，planner 相关 11 passed。详见 [BUGFIX_移动端试算与推荐布局.md](agent_doc/BUGFIX_移动端试算与推荐布局.md)。

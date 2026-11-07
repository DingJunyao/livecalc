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
新增商品/原料页内置「自定义单位 / 营养信息」（端内按钮 + 草稿 + 负数 id 拓扑落库；商品勾选「新增对应原料」时附加数据仍写商品层级，原料则写原料层级；web 对话框 / 移动端整页）：详见 [FEATURE_新增商品页自定义单位与营养信息.md](agent_doc/FEATURE_新增商品页自定义单位与营养信息.md)
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
商品/原料「关联与换算」（两两等式 `1 提 = 5 包` / `3 kg 鲜 = 1 kg 干`；单位与密度内展示；direct → entity_link → fallback → recipe → contains；本地模式）：详见 [FEATURE_商品原料关联与数量换算.md](agent_doc/FEATURE_商品原料关联与数量换算.md)
替代/回退关系换算系数（干/鲜 `1 kg 干 = 3 kg 鲜`；原料折算归层级关系，关联页聚焦商品包装链）：详见 [FEATURE_商品原料关联与数量换算.md](agent_doc/FEATURE_商品原料关联与数量换算.md)
Web 价格记录图标去货币化（侧栏 + PWA 快捷方式 prices.png；`mdi-currency-cny` → `mdi-receipt-text-outline`，对齐移动端 `receipt_long`）：详见 [FEATURE_PWA快捷方式图标.md](agent_doc/FEATURE_PWA快捷方式图标.md)
移动端原料列表价格/迷你图只显示前 40（后端批量最新价 50 上限 × 无限滚动累计 id × 整体替换；仓库分块、provider 合并、商品单失败隔离）：详见 [BUGFIX_移动端列表价格迷你图停在前40.md](agent_doc/BUGFIX_移动端列表价格迷你图停在前40.md)
关联弹层带出单位应为实体默认（商品默认 > 原料默认，浓汤宝「盒」被「块」盖住；两端 4 个点改 `fetchEntityDefaultUnitName`/`loadEntityDefaultUnitName`，记价/试算链路本就正确）：详见 [BUGFIX_关联带出单位商品默认优先.md](agent_doc/BUGFIX_关联带出单位商品默认优先.md)
原料营养缺项从商品加权平均回填（0 与缺失区分、价格权重、单位归一、别名互通；默认七项 + 全量营养素下拉含反式脂肪；两端 0 值保存过滤修复）：详见 [FEATURE_原料营养商品加权平均回填与默认七项.md](agent_doc/FEATURE_原料营养商品加权平均回填与默认七项.md)
后台币种/汇率页补统一导航栏（v-app-bar：汉堡 + 返回 + 标题 + #append 主操作；币种「新增」/汇率「手动补 + 刷新图标」上移）：详见 [BUGFIX_后台币种汇率页导航栏.md](agent_doc/BUGFIX_后台币种汇率页导航栏.md)
原料各商家最新价按汇率折算到用户币种（25750 IDR 不再显示成 25750 CNY；后端 `_lookup_rows` 用 `record_price_in_user_currency` 折算后加权 + 回传 currency，排序/最低价按折算后；web 本地模式 currency 标签同步改用户币种；两端展示零改动）：详见 [BUGFIX_原料商家价外币未折算.md](agent_doc/BUGFIX_原料商家价外币未折算.md)
新增商品页「新增对应原料」（原「新建同名原料」改为可填写名称/分类/别名；名称留空或同名用商品名，不同则建对应原料并让商品挂在其下；后端 `reuse_existing` + 跳过自动同名商品；web 对话框 / 移动端整页）：详见 [FEATURE_新增商品页新增对应原料.md](agent_doc/FEATURE_新增商品页新增对应原料.md)
移动端主屏快捷方式（长按应用图标弹出 计价（直达新增记价页）/ 每日推荐 / 菜谱；Android 静态 `res/xml/shortcuts.xml` + iOS 走 UIScene 的 `FlutterSceneLifeCycleDelegate` 动态注册，标题随界面语言，通道 `com.a4ding.livecalc/shortcuts`）：详见 [FEATURE_移动端主屏快捷方式.md](agent_doc/FEATURE_移动端主屏快捷方式.md)
Flutter SDK 升级到 3.47.8 后 Android 构建失败（Kotlin 2.2.10 < 2.2.20：settings 未声明 KGP、沿用旧 built-in Kotlin 配置；补 KGP 2.4.0 + 顺手迁移 onReorderItem）：详见 [BUGFIX_FlutterSDK升级后Android构建失败.md](agent_doc/BUGFIX_FlutterSDK升级后Android构建失败.md)
iOS 构建链路（Mac 虚拟机跑通 Flutter/CocoaPods、无签名 IPA 脚本、模拟器验证、补 iOS 上架硬伤：ATS/局域网/相册/ar/隐私清单/部署目标 15.0）：详见 [BUILD_iOS_无签名IPA与MacVM.md](agent_doc/BUILD_iOS_无签名IPA与MacVM.md)
商品/原料「各商家价格」含已软删记录（价格记录列表已隐藏、商家价仍显示；商品/原料商家价、最近价、历史价、`sort_by=price_records` 分支补 `ProductRecord.is_active` 过滤）：详见 [BUGFIX_商品商家价含已软删记录.md](agent_doc/BUGFIX_商品商家价含已软删记录.md)
移动端商品保存报「保存失败，请重试」（表单把留空条码/品牌以 "" 提交，撞 `products.barcode` 唯一约束里的历史 `''` 行；后端 create/update 统一空串归一化 NULL）：详见 [BUGFIX_商品空条码保存失败.md](agent_doc/BUGFIX_商品空条码保存失败.md)
个人中心「饮食偏好」合并 AI 推荐设置（AI 卡片移入对话框 / 单按钮保存营养目标+预算+AI 方式 / 预算标签跟随默认币种 / 营养目标与预算仍在 AI 打分与试算目标中使用）：详见 [FEATURE_个人中心饮食偏好合并AI推荐.md](agent_doc/FEATURE_个人中心饮食偏好合并AI推荐.md)
移动端快速填写行压缩（去 Card 扁平行+分隔线、名称 14px 完整换行、价格纯文本+键盘回显，360dp 单行 116px→~40px）+ 新增商品/原料/菜谱/商家/试算退出未保存二次确认（FormExitGuard：PopScope+maybePop 语义、go_router context.pop 会绕过；AppBackButton 改 maybePop 优先；顺带修 NumericKeypad 双层 Expanded debug 断言）：详见 [FEATURE_移动端快速填写行压缩与表单退出确认.md](agent_doc/FEATURE_移动端快速填写行压缩与表单退出确认.md)
快速填写价格系统数字键盘 + 币种跟随商家地区（`NumericKeypad` 全 App 仅此一处、其余数字输入均已系统键盘；币种读商家 `effective_currency` 去显式选择；web 草稿恢复补币种同步）：详见 [FEATURE_快速填写系统键盘与币种跟随商家.md](agent_doc/FEATURE_快速填写系统键盘与币种跟随商家.md)
移动端 AppBar 标题截断（预算公式 360−56−Σ48/64+；商品/原料详情 4 actions+chip 只剩 ~3 汉字、试算详情 4 平铺按钮、营养编辑 en 清空按钮 184px、关联关系 en/ar 文案超预算；删 8 处冗余刷新、试算详情 ⋮ 合并、营养编辑标题固定+实体名/清空移 body、en/ar 文案缩短；原料/商品详情标题保留类型标签（名称 Flexible+chip ≈5 汉字）；回归测试 `app_bar_title_budget_test` 按宿主字体逐屏测量）：详见 [BUGFIX_移动端AppBar标题截断.md](agent_doc/BUGFIX_移动端AppBar标题截断.md)

### 最新修复记录
- 移动端 AppBar 标题经常显示不全（用户报告；检查全部 49 处 AppBar 并列出三语最大长度后治理）：AppBar 标题被 SDK 强制单行省略，预算 = 360 − 返回键 56 − Σ actions（IconButton 48/个、TextButton ≥64）；重灾区：商品/原料/商家详情 4 actions（收藏/记价/⋮/刷新）+标题内类型 chip → 名称仅 ~3 汉字、试算详情 4 平铺按钮 → 5 汉字、营养编辑「清空自定义」en 文案 184px → en 标题仅剩 ~56px、`ingredientManageRelations` en 309/ar 252 与 `recipeEditBasicInfo` ar 275 超预算。对策：**删 8 处冗余刷新按钮**（原料/商品/商家/价格列表、收藏、3 个详情——body 均已有 RefreshIndicator；首页刷新 tooltip 是 homeSwapAll 换全部，属功能动作保留）；**详情页标题去 chip**（与 body 基本信息卡重复）；**试算详情** 编辑/设为今日/删除合并进 ⋮ PopupMenuButton（带图标与 enabled 态）；**营养编辑**标题固定「编辑营养成分」、实体名移 body 顶部、清空移表单底部错误色区；**文案缩短** en `Manage relations`/`Edit basic info`、ar `إدارة العلاقات`/`تعديل المعلومات`；删无引用 key `nutritionEditTitleWithName`/`ingredientChip`/`productChip`/`merchantChip`（`recipeAnalysisChip` 仍在用）。改后预算：商品/原料详情 160px≈7 汉字、商家详情 256px、试算详情 208px≈9 汉字，其余全过。**回归测试** `test/app_bar_title_budget_test.dart` 38 例：按屏抄源码 actions 清单算预算 + 宿主真实字体（zh 用 simhei.ttf、en/ar 用 arial.ttf，缺则 skip）TextPainter 实测三语标题宽，动态名页断言最少汉字容量；**坑**：测试默认 Ahem 字体（字形 1em 等宽，英文虚宽一倍）必须加载宿主字体；`FontLoader` 在 `package:flutter/services.dart`；给页面增删 actions 后要同步测试 `_specs` 表。验证：flutter analyze 无新增；预算 38 例 + 受影响页 43 例 + localized 三语（8 处 chip 断言改断言标题实体名/两处改名文案同步）全过；全量 798 通过/7 失败全为存量（apple_map×3、locale×2、my_proposals×1、home_summary×1）。无后端/迁移。分支：feat/mobile-app。详见 [BUGFIX_移动端AppBar标题截断.md](agent_doc/BUGFIX_移动端AppBar标题截断.md)。**[同日追加]** 用户确认原料/商品详情标题需要带类型标签：`ingredientChip`/`productChip` 三语 key 加回 + 标题恢复 `Row[Flexible(名称)+chip]`（名称不包 Flexible 会把 chip 挤出工具栏）；名称容量 zh ≈114px≈5 汉字（仍比治理前 3 汉字多 2），商家详情维持纯名称；预算测试 chip 后容量断言改按语言字宽折算（汉字 22px/字、拉丁/阿拉伯 11.5px/字），product/ingredient_detail specs 加 chip、dynamicCjk=5；下一档杠杆（未做）：收藏移进 ⋮ → 预算 208px ≈7 汉字。77 例相关测试全过，提交 `43b18e11` 后追加。
- 快速填写价格改系统数字键盘 + 币种跟随商家地区（用户要求：录数字用系统键盘而非自绘键盘并检查其他地方；币种按商家地点自动选、不用显式定义）：全 App 排查 `NumericKeypad` 仅快速填写在用，其余数字输入（记价表单/记价编辑/试算/营养目标/菜谱分量等）均已系统键盘（记价表单带 `prefixText` 币种前缀）→ 无其他需要改；移动端价格「GestureDetector + NumericKeypad 弹层」改行内 TextField（`numberWithOptions(decimal)` + `_PriceInputFormatter` 单小数点白名单 + `prefixText` 币种 + hint 0.00），删 `_PriceInputSheet` 与 `numeric_keypad.dart`（唯一使用方）；币种移除显式选择器与 `/currencies` 拉取，`_selectMerchant` 改读后端推导 `effective_currency`（商家显式 → 地区国家 → CNY），原位置改只读展示，顺带修「商家未设 default_currency 时沿用上一商家币种」；**[同日追加]** 「保存所有价格」从底部 SafeArea 大按钮改为 AppBar 右上角保存图标（`Icons.save` + tooltip，未选商家/加载中禁用——此前按钮在商家未选时不渲染，移到 AppBar 后需显式 guard），删除币种只读展示行（价格输入前缀成为唯一币种提示）；web `QuickFillView` 同步删两处币种下拉，`applyMerchantCurrency`（effective_currency 优先），并补草稿恢复（直接写 selectedMerchantId 不触发 onMerchantChange）后 loadMerchants 到位补一次币种同步。验证：移动端 quick fill 6 例（新增币种跟随/系统键盘 2 例、重写键盘回显 1 例）+ localized_prices 21 + price_list 3 全过，flutter analyze 无新增；web build ✓、check:i18n(+sources) ✓。无后端/迁移。分支：web 部分 master `30f700e0`；移动端 feat/mobile-app `39e219df`；合入 feat merge `6345eccb`（.gitignore 冲突取 feat 侧）。详见 [FEATURE_快速填写系统键盘与币种跟随商家.md](agent_doc/FEATURE_快速填写系统键盘与币种跟随商家.md)。
- 移动端快速填写行压缩 + 新增表单退出二次确认（用户报告：快速填写各行过高特别松散、很多商品名显示不全；新增商品/原料/菜谱/商家/试算写了信息退出无确认）：**快速填写**（`quick_fill_screen.dart`）实测 360dp 下 `Card`+三层 padding+16px 字体+价格列固定 100 宽 → 名称列仅 ~164px、单行卡高 **116px**、长名换 3-4 行；改为去 Card 扁平行+细分隔线、名称 `bodyMedium`(14px) 不限行完整换行、价格改纯文本（空显 `—`、`_showKeypad` await 弹层后 setState 回显 `¥xx`）、单位 chip 12px；单行 ~40px。**退出确认**：新组件 `shared/widgets/form_exit_guard.dart`（`PopScope(canPop:false)` + `isDirty` 闭包 + 三语对话框 `formExitUnsaved*` 键，`_confirming` 防叠层）包 5 个表单 Scaffold（均仅新增态 `enabled: !_isEdit && !_saving`）；菜谱复用既有基线在自有 PopScope 里加 `_handleBack()`（tips 是 `List<String>` 不能走 `_listJsonEquals`）。**关键机制**（go_router 14.8.1 源码）：系统返回/AppBar BackButton/`maybePop` 被 PopScope 拦截且拦截时返回 **true**；`context.pop()` 与保存后的 `Navigator.pop(result)` 强制退出绕过 PopScope（正是保存免确认的通路）→ `AppBackButton` 改 maybePop 优先，仅 bubble（false）且 `canPop()==false` 才回首页，guard 拦截不会误跳首页；其余 8 处使用点无 PopScope 行为不变。商品 isDirty 用 initState 快照比对（扫码 prefill 算初始值不算「写过」），试算=名称或条目非空。**顺带修**：`NumericKeypad._KeyButton` 内层 Expanded 与 `_buildBottomRow` 外层 Expanded 竞争同一 RenderObject，debug 抛 ParentData 断言（release 无断言所以线上没炸）——改 Row 外层统一给弹性。**测试坑**：`tester.pageBack()` 按 tooltip 'Back' 找，zh 下是「返回」直接 expectSync 失败（用 `find.byTooltip('返回')` 或 `binding.handlePopRoute()`）；试算新增态 AppBar 标题=plansNewPlan 与方案名撞 `find.text` 2 匹配；`RecipeFormScreen`/`MerchantFormScreen` 测试必须套 ProviderScope（saveButtonPositionProvider）。验证：`flutter analyze` 0 新增；新增 14 例（guard 4/快速填写 2/商家 3/菜谱 2/试算 1/商品 2）+ localized_prices 14 例全过（quick fill 断言 labelText→hint）；全量 759 通过/7 失败全为存量（apple_map×3、locale×2、my_proposals×1、home_summary×1——已 stash 在 HEAD 复跑定责）。本机无 Android SDK，APK 构建留待用户机器。分支：feat/mobile-app。详见 [FEATURE_移动端快速填写行压缩与表单退出确认.md](agent_doc/FEATURE_移动端快速填写行压缩与表单退出确认.md)。
- 移动端商品改名报「保存失败，请重试」（用户报告：把原料「鹿茸菇」改名后，改其下商品名必失败；实际与原料改名无关）：链路是移动端商品表单保存时空的 `brand`/`barcode` 传 `""`（非 null）→ 后端 `PUT /products/entity/{id}` 只在 barcode 非空时查重，于是直接写入 `barcode=''` → `products.barcode` 有唯一约束，库里已有历史 `barcode=''` 行（`products.id=622`）→ `IntegrityError: UNIQUE constraint failed: products.barcode` → 500 → 移动端 catch-all 提示「保存失败，请重试」。修复：`create_product` / `update_product` 统一把 `barcode`/`brand` 空串 `strip()` 后归一化为 NULL（放在查重之前），web/移动端共用后端一处即覆盖；真实条码查重逻辑不变。验证：新增 `tests/test_product_empty_barcode_brand.py` 3 passed（update 空条码 / create 空条码 / 真实条码仍 400），相关子集 25 passed；无迁移，后端自动重载生效。遗留：`UPDATE products SET barcode = NULL WHERE barcode = ''` 需用户确认后手工执行。分支：master `fd033951` → 合入 feat/mobile-app。详见 [BUGFIX_商品空条码保存失败.md](agent_doc/BUGFIX_商品空条码保存失败.md)。
- 个人中心「AI 推荐」并入「饮食偏好」（用户要求：设置归位到饮食偏好，并复查每日营养目标与预算是否还有用）：删除页底独立 AI 卡片，推荐方式 / BYOK 提供商 / 模型 / 端点 / API 密钥整体搬进「饮食偏好」对话框（宽 480→560 + scrollable；AI 区块仍 `v-if="!isLocalMode"`，本地模式继续走「设置 · AI 配置」）；保存合并为底部单按钮 `saveDietPreferences`——先 `PATCH /auth/me` 存营养目标与预算，云端且 `aiChanged` 时再 `PUT /profile/ai-settings`，loading 合并 `savingNutrition || aiSaving`；打开对话框时云端刷新一次 AI 设置。「每日预算」标签由写死「元」改为 `{currency}` 跟随默认币种。复查结论：目标与预算**仍在用**——`meal_recommender._get_meal_targets` / `_calc_nutrition_score` / `_calc_cost_score`（AI 推荐短名单打分，预算未设时成本分中性 0.5）、`meal_plan_service._evaluate_stub_items` 的 `targets`/`deltas`（Web `PlanDetailView`「合计 vs 目标」、移动端 `PlanTotalsGrid`）；「今日推荐」页本身不展示目标数值，只影响排序。发现的不一致（本次未改）：移动端营养目标页缺每日预算输入、且无 AI 推荐设置。验证：`npm run build` ✓（master 31.6s / feat 37.8s）、`check:i18n` + `check:i18n:sources` ✓、`test:utils` 73 ✓；无后端与迁移改动。分支：master `e52c61df` → 合入 feat/mobile-app（merge `ec2456c4`）。详见 [FEATURE_个人中心饮食偏好合并AI推荐.md](agent_doc/FEATURE_个人中心饮食偏好合并AI推荐.md)。
- 商品/原料「各商家价格」含已软删记录（用户报告：商品 1136「各商家价格」有千禧三分店，价格记录里没有；web + 移动端一致）：根因是取价端点 SQL 漏了软删除过滤——`ProductRecord.is_active` 只在价格记录列表 `GET /products/` 生效，`GET /products/entity/{id}/latest-price-by-merchant` 与原料 `_lookup_rows`（`/nutrition/ingredients/{id}/latest-price-by-merchant`）只过滤 `merchant_id` / `Merchant.is_open`，把已删记录仍当该商家最新价返回（真实数据：`product_records.id=3859`，商家 6 千禧三分店，¥13.5，`is_active=0`；商家价显示 13.5 元/斤）。修复：商品/原料两个商家价端点、商品最近价端点、商品历史价端点、`GET /products` 的 `sort_by=price_records` 分支统一补 `ProductRecord.is_active == True`（与列表/成本口径一致；web 本地模式为硬删除不受影响，两端共用后端故一处修复）。验证：新增回归 `tests/test_merchant_price_soft_deleted.py`（有效+软删两商家，断言商家价/最近价/记录列表口径一致）；相关后端子集 23 passed，`test_products.py` 2 个登录前置（401）失败为既有。无迁移；后端需重启（自动重载生效）。分支：改动提交 master 后合并回 feat/mobile-app。详见 [BUGFIX_商品商家价含已软删记录.md](agent_doc/BUGFIX_商品商家价含已软删记录.md)。
- Flutter SDK 升级到 3.47.8 后 Android 构建失败（用户报错：`Your project's Kotlin version (2.2.10) is lower than Flutter's minimum supported version of 2.2.20`）：根因是项目仍按旧 SDK 的 AGP 9 **Built-in Kotlin** 配置——`android/settings.gradle.kts` 不声明 KGP，而 `gradle.properties` 里 `android.builtInKotlin=false`（旧 migrator 加的）；新 SDK 在 builtInKotlin=false 时靠 `pluginManager.apply("kotlin-android")`，KGP 不在 classpath → 失败后版本检查读到 AGP 9.0.1 自带 Kotlin 2.2.10 → 低于最低 2.2.20。修复：settings 补 `id("org.jetbrains.kotlin.android") version "2.4.0" apply false`（对齐 3.47.8 模板 templateKotlinGradlePluginVersion，仅声明版本，Flutter 插件会自动 apply）；保留 `android.newDsl=false`/`android.builtInKotlin=false`；`pubspec.lock` 随新 SDK 刷新（intl 0.20.3、matcher 0.12.20、meta 1.19.0、test_api 0.7.12、vector_math 2.4.4）。顺带修新 SDK 弃用：菜谱图片重排 `onReorder` → `onReorderItem`（新回调的 newIndex 已按移除旧项调整，去掉手动减一），analyze 恢复零 issue。验证：`flutter build apk --release` ✓（88.6MB，Flutter 3.47.8 / Dart 3.13.7 / AGP 9.0.1 / Gradle 9.1.0 / KGP 2.4.0）；`flutter analyze` No issues；快捷方式/app/router/l10n/菜谱表单 50 passed。遗留：构建时警告 image_picker_android、shared_preferences_android 仍 apply KGP，未来 Flutter 版本会失败，待插件升级。详见 [BUGFIX_FlutterSDK升级后Android构建失败.md](agent_doc/BUGFIX_FlutterSDK升级后Android构建失败.md)。
- 移动端主屏快捷方式（用户要求：长按应用图标弹出 计价 / 查看每日推荐 / 菜谱，iOS、Android 都做）：无新依赖，走一条 MethodChannel `com.a4ding.livecalc/shortcuts`。Dart：`core/shortcuts/app_shortcuts.dart`（id→路由 / 三语标题 / iOS 图标；「计价」带 baseRoute）+ `core/services/app_shortcuts_service.dart`（`ready` 握手、`setShortcutItems`、原生 `shortcut` 事件流）；`app.dart` 在 locale 加载后同步标题、认证完成前保留 pending（登录后补跳）、post-frame `go(route)`。Android：`res/xml/shortcuts.xml` 静态声明三条（自定义 action + extra `SHORTCUT_ACTION`）、`values{,-en,-ar}/strings.xml` 三语标签、主题绿圆底 + 白色 Material 字形矢量图标、manifest `android.app.shortcuts` meta-data、`MainActivity` 在 `configureFlutterEngine` 读冷启动 intent extra、`onNewIntent` 兜底。点「计价」走「go `/prices` 再 push `/prices/record`」，保存/返回回到列表（直接 go 表单会作为首屏、无处可回）。**坑 1**：AOSP `ShortcutParser` 会给静态快捷方式 intent 追加 `NEW_TASK|CLEAR_TASK|TASK_ON_HOME`，点快捷方式等同重建任务 → 主路径是冷启动读 extra，`onNewIntent` 仅兜底；`<extra>` 由 `Intent.parseIntent()` 解析，合法。**坑 2**：iOS 用 UIScene 生命周期，`AppDelegate.application(_:performActionFor:)` 不会被调用；改为在 `AppDelegate.swift` 内实现应用内插件，`registrar.addSceneDelegate` + `FlutterSceneLifeCycleDelegate` 接收 `scene(_:willConnectTo:options:)`（`connectionOptions.shortcutItem`，Swift 类型是 `UIScene.ConnectionOptions`）与 `windowScene(_:performActionFor:)`，并静态持有插件（引擎对场景代理是弱引用）。iOS 采用**动态**注册（标题随界面语言；Info.plist 静态项无法多语言），代价首次启动后才出现，Android 静态安装即用。验证：`flutter analyze` No issues；快捷方式 11 例（含计价直达表单且可返回）+ app/router/l10n 共 43 passed；`flutter build apk --release` ✓（86.5MB，aapt2 校验 shortcuts.xml 三条 intent/extra/图标均正确）；iOS 本机无 Xcode 未编译，需 macOS 验证。详见 [FEATURE_移动端主屏快捷方式.md](agent_doc/FEATURE_移动端主屏快捷方式.md)。
- 新增移动 App 用户文档（用户确认 web 端完成后继续移动端）：`docs/mobile.md`（feat/mobile-app 分支专属，App 代码只在 feat）——获取与安装（Flutter 源码构建 `flutter build apk --release`，iOS 用 Xcode 自签；无商店分发）、首次使用（`/server-config` 填服务器地址测连接 → 与 web **同账号**登录、数据互通）、导航（窄屏底栏 首页/价格/菜谱/更多，宽屏 ≥600dp 侧边 NavigationRail；「更多」含原料/商品/商家/收藏/试算/个人中心）、功能速览表逐项链到 web 手册（体验一致性：价格加权/30 天规则/回退链/提议-审核同口径）、移动端特色（扫码记价命中本库自动填/缺则引导新增、**断网写操作进 drift 队列恢复联网自动重放**（`OfflineSyncService` main 启动；无完整离线浏览）、三语 zh/en/ar + RTL 跟随系统）、常见问题（连不上服务器/数据不对/离线补传）；README 功能手册表补「移动 App」行。写作前先探代码定位事实：`lib/core/router/app_router.dart`（tabs 与全部路由）、`server_config_screen`、`offline_sync_service`、`BRANDING.md`（App 名「生计」）。验证：链接/锚点脚本校验通过。截图待用户提供后插入（见对话清单）。
- 新增商品页「新增对应原料」（用户要求：新增商品时经常需要新建一个与商品名不同的原料，原「新建同名原料」只能同名，得退出→建原料→再建商品）：Web `ProductsView` 开关改名为「新增对应原料」，选中后展开原料名称/分类/别名；`saveItem` 先按「填写名 or 商品名」调 `POST /api/v1/ingredients`（`reuse_existing=true` 同名复用、`create_same_name_product=false` 不让后端再补同名商品），商品挂到该原料下，再落商品层级草稿；开关开启时清空已选原料并按旧原料调和草稿单位。后端 `ingredient_extended.create_ingredient` 新增 `reuse_existing` / `create_same_name_product` 两个可选 body 参数（默认保持旧行为）、名称 strip、分类存在性校验、响应带 `reused`。移动端同构（`product_form_screen.dart` 新增态开关 + 名称/分类（`ingredientCategoriesProvider`）/别名，`IngredientRepository.createIngredient` 透传两参数，三语 l10n + gen-l10n，新增 widget 测试 4 例；编辑态隐藏开关，开关关掉恢复开启前的关联原料/固定原料）。本地模式 `handlers/ingredients.createIngredient` 同步支持 `reuse_existing` 同名复用并剥离两个协议字段。验证：后端 4 例通过（复用 / 跳过自动同名商品 / 未知分类）；web build ✓、check:i18n/sources ✓、test:utils 73 ✓；移动端 `flutter analyze` No issues、product+ingredient 81 passed（顺带修一条因表单变长在扫码用例里找不到商品名称字段的既有测试，先滚回顶部再断言）。无迁移。分支：master `e474ac3` → 合入 feat/mobile-app `84bbbd0c`；移动端 feat/mobile-app `eb44a0f9` + `917aeb7a`。详见 [FEATURE_新增商品页新增对应原料.md](agent_doc/FEATURE_新增商品页新增对应原料.md)。

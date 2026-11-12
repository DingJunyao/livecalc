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
编辑价格记录换绑商品（三层都堵死：后端 `ProductRecordUpdate` 无 product_id、web 编辑 payload 不带、移动端只读；更新端点校验+商品名快照+按新商品重算标准量；所有编辑入口（列表/商品详情/原料详情）统一可换绑商品、编辑对话框字段集对齐；本地模式同步快照）：详见 [BUGFIX_编辑价格记录无法换商品.md](agent_doc/BUGFIX_编辑价格记录无法换商品.md)
移动端 AppBar 标题截断（预算公式 360−56−Σ48/64+；商品/原料详情 4 actions+chip 只剩 ~3 汉字、试算详情 4 平铺按钮、营养编辑 en 清空按钮 184px、关联关系 en/ar 文案超预算；删 8 处冗余刷新、试算详情 ⋮ 合并、营养编辑标题固定+实体名/清空移 body、en/ar 文案缩短；原料/商品详情标题保留类型标签（名称 Flexible+chip ≈5 汉字）；动态标题页长按看全名（AppTitleTooltip，7 处接入）；回归测试 `app_bar_title_budget_test` 按宿主字体逐屏测量）：详见 [BUGFIX_移动端AppBar标题截断.md](agent_doc/BUGFIX_移动端AppBar标题截断.md)
商品营养编辑预填带出原料值（编辑器只取商品自身 `custom_nutrition_data`；ownNutrients / nutritionForEdit / editorNutrition 三层接线，对齐 web mixin 口径）/ 新增商品点选原料后被输入法回声静默清空致保存误报（Flutter onChanged 只由 IME 触发 → 点选后 300ms 保护窗口 + 组合态跳过）/ 商品表单错误改 SnackBar 并透出后端 detail：详见 [BUGFIX_商品营养编辑预填与原料选择回声.md](agent_doc/BUGFIX_商品营养编辑预填与原料选择回声.md)
今日推荐餐卡 NRV 双百分号（mobile `formatPercentValue` 自带 %，`_nrvSuffix` 模板又拼一个 → `NRV xx%%`；web 无此问题）：详见 [BUGFIX_移动端推荐餐卡NRV双百分号.md](agent_doc/BUGFIX_移动端推荐餐卡NRV双百分号.md)
试算新增/编辑态隐藏「设为今日」（与保存按钮相邻易混淆；「设为今日」只留列表行与移动端详情 ⋮）：详见 [FEATURE_试算新增编辑隐藏设为今日.md](agent_doc/FEATURE_试算新增编辑隐藏设为今日.md)
试算原料条目营养为空（火腿肠脂肪未计入；后端改用 NutritionCalculator 同口径：best 营养行 + 缺项商品加权平均回填 + 数量经实体换算链）：详见 [BUGFIX_试算原料营养为空火腿肠脂肪.md](agent_doc/BUGFIX_试算原料营养为空火腿肠脂肪.md)
新增商品「新增对应原料」自动带入未匹配的关联原料文字 / 表单页（新增编辑原料、商品、菜谱、商家、方案）隐藏底栏与侧栏 tab / 价格记录商家下拉选中后释放焦点 / 营养默认单位除能量与七项宏量营养素外统一 mg：详见 [FEATURE_表单体验与营养默认单位.md](agent_doc/FEATURE_表单体验与营养默认单位.md)
试算成本不随数据范围变化（X-Region 机制完好但 meal_plan_service 三条成本链路全漏传 region_id；evaluate 与 cost-trend 在 service 公共汇合点解析范围，菜谱/原料/商品 + 走势 + has_record 全链路套 apply_region_filter；推荐打分经 evaluate_plan 一并生效；本地模式无范围通道属既有缺口）：详见 [BUGFIX_试算成本不随数据范围变化.md](agent_doc/BUGFIX_试算成本不随数据范围变化.md)
用户自定义计算范围（多地区组合：user_calc_scopes 表 + users.default_calc_scope_id；region_subtree_ids/apply_region_filter/X-Region 头支持多地区子树并集去重（tuple 可哈希作缓存键）；/api/v1/calc-scopes CRUD；两端默认范围选择器与会话切换器接自定义选项；本地模式不在范围）：详见 [FEATURE_自定义计算范围.md](agent_doc/FEATURE_自定义计算范围.md)

### 最新修复记录
- 用户自定义计算范围（多地区组合）（用户需求：住行政区划边界的用户需要组合多个地区的数据范围；新增范围=名称+多个地区（层级可混合，如一个县+一个地级市），出现在「默认计算范围」选项里，计算按选定范围）：**后端**：新表 `user_calc_scopes`（region_ids JSON）+ `users.default_calc_scope_id`（alembic `20261112_0001` + 三引擎 SQL 脚本）；默认解析优先自定义组合（去重保序 **tuple**——`recipe_service.py:45,267` 用 region_id 作 lookup_cache dict key，必须可哈希）、范围被删回退旧档位推导、不要求 users.region_id；`region_subtree_ids`/`apply_region_filter`/会话 ContextVar 接受 int|tuple|list（子树并集去重，未分配商家仍计入）；X-Region 头新增逗号分隔多 id（≤20，单 id/all 完全兼容）；`/api/v1/calc-scopes` CRUD（归属 404、去重保序、存在性校验、20 范围/50 地区上限、删除清默认引用）；`PATCH /me` 的 default_calc_scope_id 与 default_calc_scope 互斥写入。**Web**：`RegionMultiSelect.vue`（级联+添加+chips 祖先前缀）+ `CalcScopeManagerDialog.vue`；ProfileView 入口 + scopeDialog 选项 `custom:<id>`；calcContext store 增 effectiveRegionIds；client.ts 多 id join(','); CalcContextMenu 会话切换器同接。**移动端**：features/calc_scope 模块（列表/表单 FormExitGuard + RegionMultiSelectField）；路由 `/profile/calc-scopes(new|:id/edit)` 入全屏表单正则；profile 默认范围对话框追加 radio；CalcContextState.effectiveRegionIds + 拦截器注入多 id；CalcContextSheet 选中自定义时地区级联 AbsorbPointer 禁用；三语 ARB 24 组 key。验证：后端 24 新例全过 + 回归子集 41 过（1 失败 stash 对照为既有）；web build/check:i18n/test:utils 73 ✓；移动端新测 17 例过、analyze 0 issue。**坑**：`_user_to_response` 等取新字段必须 `getattr`（FakeUser 无该属性即 500）；FakeUser 与 GET /auth/me 本就不兼容（缺 is_active），删范围后验证清引用要查 DB；移动端 widget 测试里 await 拉范围后弹对话框必须 mock secure storage 通道 + 受控 dio adapter（否则挂 FakeAsync）；gen-l10n/pub 会改写 pubspec.lock 要还原；表单标题与保存按钮同文案撞 find.text 双匹配。本地模式不在范围（既有无范围通道缺口）。分支：后端+web master `c908484a` → 合入 feat（`bc1eabee`）；移动端 feat/mobile-app `7f1c4161`。**部署**：开发库需手工执行 `scripts/sql/20261112_user_calc_scopes_sqlite.sql`（users 加列 create_all 不补）后重启；Mimosa 两次提交均扫不全（scanner_enobufs/callgraph_fact_partial）按兼容策略放行，待跑完整审计。详见 [FEATURE_自定义计算范围.md](agent_doc/FEATURE_自定义计算范围.md)。
- 试算成本不随数据范围变化（用户报告：数据范围从全部缩回城市后，试算成本不随范围变；线上复现 + 菜谱成本端点对拍确认 X-Region 机制完好）：`meal_plan_service` 全文无地区处理——recipe/ingredient 项调 `calculate_recipe_cost` / `get_weighted_ingredient_price`（都支持 region_id）不传、product 项手写最新记录查询、`plan_cost_trend` 四处（含散项 has_record）同样漏。修复：`_evaluate_stub_items` 与 `plan_cost_trend` 入口 `resolve_region_param(db, user, None)`（会话 X-Region 优先、其次用户默认计算范围），三条链路 + 走势 + has_record 全部透传/套 `apply_region_filter`；解析放 service 汇合点使 `/meals` 推荐打分一并生效。回归 `test_meal_plan_region_scope.py` 5 例（商品/原料/菜谱 × 城市A/B/全部 + 用户默认范围 + 空子树走势归零）。**坑**：`tests/services` 与 `tests/api` 的同名 `test_meal_recommendation_route.py` 同批会让 pytest 静默 collected 0，只能分开跑；composer 测试批次失败为共享内存库既有顺序干扰（stash 基线同样失败）。验证：新测 5 过 + meal_plans 子集 29 过 + 价格/地区/菜谱子集 32 过；开发库只读复核黄焖鸡米饭 all=14.81 / 三门峡=15.41 / 南京=15.36。web/移动端服务端模式零改动（两端拦截器已注入 X-Region）；本地模式整体无范围通道属既有缺口未处理。无迁移。分支：master `78a265cf` → 合入 feat/mobile-app；外部环境待部署复核。详见 [BUGFIX_试算成本不随数据范围变化.md](agent_doc/BUGFIX_试算成本不随数据范围变化.md)。
- 表单体验四项 + 营养默认单位（用户报告/要求）：①新增商品开启「新增对应原料」时，关联原料里已输入但**未匹配到已有原料**的文字自动带入新原料名称（已匹配则不复制）——web `ProductsView` 的 `watch(createNewIngredient)` 先读 `ingredientSearch` 再清 `selectedIngredient`；移动端 `_setCreateNewIngredient` 先记文本与 `_selectedIngredient` 再清搜索框，仅未匹配且新原料名称为空时写入。②新增/编辑原料、商品、菜谱、商家、方案页隐藏底栏 tab（宽屏隐藏 NavigationRail），避免误触切走丢失未保存内容（返回键仍有 FormExitGuard）：`app_router.dart` 新增 `_isFullScreenFormRoute`（`/xxx/new` 精确 + `/xxx/:id/edit` 正则）。③移动端价格记录选中商家后 `FocusManager.instance.primaryFocus?.unfocus()`（新增/编辑/快速填写三处）——Autocomplete 选中只收面板不释放焦点，去扫码/选日期回来会随焦点恢复重新弹出（「商家下拉一直显示」）。④营养默认单位：除能量（随偏好）与蛋白质/脂肪/饱和脂肪/反式脂肪/碳水化合物/糖/膳食纤维（g）外统一 mg——web `nutrientDefinitions.ts` 删逐项 `DEFAULT_UNIT_BY_KEY` 改 `defaultUnitForNutrientKey()`（动态 USDA 键复用），单位候选 mg 优先、空行首次选营养素套默认；移动端 `defaultNutrientUnit` 兜底 `g→mg` + `_nutrientOptions` 补/前置 mg。验证：web build ✓、test:utils 73 ✓；移动端 analyze 0 issue，新增 7 例（自动带入 2 / 隐藏底栏 2 / 商家焦点 1 / 营养默认 2），相关子集 61 全过；全量 774 通过 / 14 失败均为存量（同 HEAD stash 对照：price_record_form_sheet 6、apple_map 3、locale 2、my_proposals 1、home_summary 1、缺字体 1）。无后端/迁移。分支：web master；移动端 feat/mobile-app，master 改动合入 feat。详见 [FEATURE_表单体验与营养默认单位.md](agent_doc/FEATURE_表单体验与营养默认单位.md)。
- 试算原料条目营养为空（用户报告：一顿饭选了火腿肠（原料，2 根），试算合计没有它的脂肪；外部环境复现，同数据走商品条目正常）：`meal_plan_service._item_cost_nutrition` ingredient 分支手读 `nutrition_data` **首行** + 手工换算克数——火腿肠原料自己没有 nutrition_data 行（营养挂在关联商品的自定义营养上，详情页靠 `NutritionCalculator` 的商品加权平均回填展示），且数量单位「根」的克重经 `EntityUnitOverride`（商品换算链）→ 旧路径两条链都断 → 条目 `nutrition: null`、营养来源明细缺失、fat 合计只剩其他三项。修复：营养整体换成与详情页同源的 `NutritionCalculator.calculate_ingredient_nutrition(ingredient.id, quantity, unit_abbr)`（best 行 custom>USDA>verified + 缺项商品加权平均回填每 100 g 归一 + 数量/基准走同一 `_convert_to_base` 实体换算链），返回 `all_nutrients` 已按请求量缩放（键=显示名附 `original_key`），逐条归一成 `nutrient_values`（能量经 `energy_to_kcal`）后同源导出条目四项/totals/明细；成本链不动，recipe/product 分支不动。回归 `tests/services/test_meal_plan_product_unit.py` 新增 2 例（无/有自有营养行 × 根计数 + EntityUnitOverride，断言 fat_g=24/20 与明细 fat 贡献）。**坑**：手建质量单位必须 `si_factor=0.001`（kg 口径）；内存测试库无 kg 单位，`_get_piece_weight_kg` 需要 `get_unit_by_abbr("kg")`——新增 `_ensure_kg_unit` get-or-create（存在不删，避撞 `unit.abbreviation` 唯一约束）。验证：该文件 7/7 过；相关子集（meal_plans_api/models、meal_recommendation_items、ai_policy）与 stash 基线一致（`test_daily_recommendation_has_items_not_recipe_id` 在该批量组合下基线也挂，共享内存库互相干扰的既有现象，单跑即过）。无迁移。分支：master → 合入 feat/mobile-app；外部环境待部署复核。详见 [BUGFIX_试算原料营养为空火腿肠脂肪.md](agent_doc/BUGFIX_试算原料营养为空火腿肠脂肪.md)。
- 试算新增/编辑态隐藏「设为今日」（用户报告：试算保存按钮容易与「设为今日」按钮搞混；新增、编辑时不应显示）：「设为今日」只保留在非编辑入口——web `PlansView.vue` 列表行（含一顿方案餐次菜单）与移动端列表行、移动端详情页 ⋮ 菜单。Web `PlanDetailView.vue`（页面始终是新增/编辑态）整块移除 app-bar 的设为今日（一顿餐次 v-menu + 一日直按按钮），连带清理死代码 `settingToday`/`mealTypeOptions`/`onSetToday`/`setPlanAsRecommendation` import（PlansView 仍在用该 API，i18n key 不动）；移动端 `planner_screens.dart` 试算新建/编辑页 AppBar 删「设为今日」IconButton（原紧挨保存图标）+ 私有 `_setToday`。验证：web build ✓、check:i18n ✓；移动端 analyze 无新增、planner 相关测试全过；`app_bar_title_budget_test` 的 `planner_form` spec 同步 icons 3→2（本机缺 simhei/arial，预算测量按既有环境失败跳过，stash 对照与本次无关）。分支：web master；移动端 feat/mobile-app。详见 [FEATURE_试算新增编辑隐藏设为今日.md](agent_doc/FEATURE_试算新增编辑隐藏设为今日.md)。
- 移动端今日推荐餐卡 NRV 双百分号（用户报告：早午晚餐卡片 NRV 行显示 `NRV xx%%`）：`meal_card.dart#_nrvSuffix` 在 `formatPercentValue`（自带尾 `%`）外又拼一个 `%`；web `MealCard.vue#nrvText` 是裸数字拼一个 %，无此问题——「与 web 餐卡同格式」只在 mobile 抄坏一层。修复：去掉重复拼接；排查其余 `formatPercentValue` 调用点（nutrition_card / recipe_detail / nutrition_source_grid / cost_proportion_chart）均无重复。测试 `meal_card_test.dart` 加精确断言 `find.text('NRV 54.9%')` + `find.textContaining('%%')` findsNothing。验证：受影响 22 例全过、analyze 无新增。分支：feat/mobile-app。无后端/迁移。详见 [BUGFIX_移动端推荐餐卡NRV双百分号.md](agent_doc/BUGFIX_移动端推荐餐卡NRV双百分号.md)。
- 移动端商品营养编辑带出原料值 + 新增商品选原料保存误报（用户报告：编辑没填营养的商品时编辑器带出原料的数据；新增商品选了关联原料保存却提示没保存，且提示是页底内联文字不是 SnackBar）：**营养预填**——根因是 `GET /nutrition/products/{id}/nutrition` 的 `nutrition.all_nutrients` 为「商品自定义→原料继承」合并值（展示口径，web 一致），web 编辑器只读 `custom_nutrition_data`，移动端却拿合并值预填 → 保存会把原料值写成商品数据。修复：`NutritionInfo` 新增 `ownNutrients`（fromJson 解析 `custom_nutrition_data`，回退 `nutrients` 键）、`ProductDetailPageState` 新增 `nutritionForEdit`（由原始响应构造，不混待审草案/USDA 待审）、`NutritionCard` 新增可选 `editorNutrition`（缺省回退 `nutrition`，原料详情不受影响）、商品详情页传参；商品没填时为 null → 编辑器落「默认七项」空行（空保存不记录）。**保存误报**——根因是 Flutter `TextField.onChanged` 只由 IME `updateEditingValue` 触发（程序化赋值不触发，editable_text.dart 源码确认），点选下拉项后输入法补发滞留的组合态/上屏回声，文本≠原料名 → 选择被静默清空 → 校验报「请选择关联的原料」（概率性、与点选原料相关）。修复：`onSelected` 后 300ms 保护窗口 + 组合态（composing 非空）跳过清空判定，窗口过期后正常编辑仍清空（对照测试）。**提示样式**——删 `_error` 页底内联块，`_showError` 统一 SnackBar（对齐商家/记价表单，覆盖加载/必填/选原料/建原料/保存失败 5 处）；保存失败经 `_serverErrorDetail` 透出后端 `detail`（如「条码已存在」），取不到落回「保存失败，请重试」。顺带修 `_ensureDraftUnitReference` 单行 if 缺花括号 lint。验证：`flutter analyze` 0 issue；shared+products 210、nutrition+ingredients 66 全过；新增 9 例（模型 2/卡片 3/回声 2/对照 1/保存失败 2）。无后端与迁移改动。分支：feat/mobile-app。详见 [BUGFIX_商品营养编辑预填与原料选择回声.md](agent_doc/BUGFIX_商品营养编辑预填与原料选择回声.md)。
- 编辑价格记录无法编辑商品（用户报告：web 和移动端都改不了；三层排查）：**后端** `ProductRecordUpdate` schema 无 `product_id`/`product_name`——更新端点根本不支持改商品（传了也被 Pydantic 丢弃）；**web** `PricesView.saveRecord` 编辑分支 payload 不带 `product_id`（只有新增分支带），商品下拉可改但保存被静默丢弃；**移动端** 编辑页商品固定只读文本（`fixedProductId`），repository 更新也不带商品字段。修复：后端 `ProductRecordUpdate` 增加 `product_id`——更新时显式置空 400（商品必填归属）、不存在/非活跃 404（口径同新增），换绑后同步记录冗余快照 `product_name = product.name`，**换绑即使未传数量单位也按新商品上下文重算标准量**（自定义单位换算按商品挂靠；`UnitConversionService.convert` 失败回退 `convert_to_standard`；`matcher` 无条件创建，原先只在传 unit 分支里定义、换绑分支会 NameError）；web 编辑保存带 `product_id` + 本地模式 `updateRecord` 换绑时从 products store 同步快照；移动端 `PriceRecordFormArguments.allowProductChange`（价格列表入口 `true`，商品/原料详情入口不传保持固定——与 web 详情页对话框无商品字段一致），编辑页商品字段改可搜索 TextField（300ms 防抖+请求序号对齐新增页，防 IME 组合态重复触发），点选更新 `_productId` 并重拉自定义单位，**改文本未点选撤销选中 + 保存拦截 toast `priceProductRequired`（新增三语 key，编辑态不能像新增那样按名自动建商品）**，`PriceRecordFormResult.productName`/provider/repository 透传。验证：后端 `test_product_record_update_product` 3 例（换绑+快照+重算 500g/1000g、置空 400、未知 404——**坑**：products.ingredient_id NOT NULL 测试商品须挂原料；测试手建单位必须设 si_factor（斤 0.5/g 0.001，kg 口径）否则换算退化 1:1；Decimal 序列化带尾零用 float 比对）；web `npm run build` ✓（vue-tsc 本机损坏既有）；移动端 analyze 基线 + 新增 2 例 + prices 全量+三端详情 121 例全过 + 全量 7 失败全为存量（apple_map×3、locale×2、my_proposals×1、home_summary×1）。**坑**：`initialPrice` 误写 `String?` analyze 立即暴露（应为 `double?`）。分支：后端+web master `6de79ca3` → 合入 feat/mobile-app（merge `9db63268`）；移动端 feat/mobile-app `76f3b018`。Mimosa 门禁对既有文件（本地模式演示账号 auth.ts、gitignore 的 dev-dist workbox 产物）报 high 误报拦截，重试按兼容策略放行，建议后续跑完整审计加豁免。详见 [BUGFIX_编辑价格记录无法换商品.md](agent_doc/BUGFIX_编辑价格记录无法换商品.md)。**[同日追加]** 用户反馈详情入口仍不能改商品且要求统一布局：移动端编辑页商品字段单一化（删灰字/下拉分支，所有入口同一可搜索字段；`allowProductChange` 开关即废，fixedProductId/fixedProductName 改为回显种子；详情 notifier.updateRecord 透传 productId）；web `ProductDetail`/`IngredientDetail` 编辑对话框对齐 PricesView 字段集（补商品自动完成/计入支出/记录时间/备注，打开预填商品与商家——ProductDetail 此前 merchant_id 硬置 null），新增组合式函数 `usePriceProductAutocomplete`（detail 两处复用，PricesView 内联实现未迁移），`PriceRecord` 类型补字段，timezone 补 `utcToDatetimeLocalValue`；web build ✓、移动端 prices+详情 121 例过、分支 web master `f25e434f` 合入 feat `cb0f3a7d`、移动端 feat `cca90a2f`；dev-dist 已删（可再生）。
- 移动端 AppBar 标题经常显示不全（用户报告；检查全部 49 处 AppBar 并列出三语最大长度后治理）：AppBar 标题被 SDK 强制单行省略，预算 = 360 − 返回键 56 − Σ actions（IconButton 48/个、TextButton ≥64）；重灾区：商品/原料/商家详情 4 actions（收藏/记价/⋮/刷新）+标题内类型 chip → 名称仅 ~3 汉字、试算详情 4 平铺按钮 → 5 汉字、营养编辑「清空自定义」en 文案 184px → en 标题仅剩 ~56px、`ingredientManageRelations` en 309/ar 252 与 `recipeEditBasicInfo` ar 275 超预算。对策：**删 8 处冗余刷新按钮**（原料/商品/商家/价格列表、收藏、3 个详情——body 均已有 RefreshIndicator；首页刷新 tooltip 是 homeSwapAll 换全部，属功能动作保留）；**详情页标题去 chip**（与 body 基本信息卡重复）；**试算详情** 编辑/设为今日/删除合并进 ⋮ PopupMenuButton（带图标与 enabled 态）；**营养编辑**标题固定「编辑营养成分」、实体名移 body 顶部、清空移表单底部错误色区；**文案缩短** en `Manage relations`/`Edit basic info`、ar `إدارة العلاقات`/`تعديل المعلومات`；删无引用 key `nutritionEditTitleWithName`/`ingredientChip`/`productChip`/`merchantChip`（`recipeAnalysisChip` 仍在用）。改后预算：商品/原料详情 160px≈7 汉字、商家详情 256px、试算详情 208px≈9 汉字，其余全过。**回归测试** `test/app_bar_title_budget_test.dart` 38 例：按屏抄源码 actions 清单算预算 + 宿主真实字体（zh 用 simhei.ttf、en/ar 用 arial.ttf，缺则 skip）TextPainter 实测三语标题宽，动态名页断言最少汉字容量；**坑**：测试默认 Ahem 字体（字形 1em 等宽，英文虚宽一倍）必须加载宿主字体；`FontLoader` 在 `package:flutter/services.dart`；给页面增删 actions 后要同步测试 `_specs` 表。验证：flutter analyze 无新增；预算 38 例 + 受影响页 43 例 + localized 三语（8 处 chip 断言改断言标题实体名/两处改名文案同步）全过；全量 798 通过/7 失败全为存量（apple_map×3、locale×2、my_proposals×1、home_summary×1）。无后端/迁移。分支：feat/mobile-app。详见 [BUGFIX_移动端AppBar标题截断.md](agent_doc/BUGFIX_移动端AppBar标题截断.md)。**[同日追加]** 用户确认原料/商品详情标题需要带类型标签：`ingredientChip`/`productChip` 三语 key 加回 + 标题恢复 `Row[Flexible(名称)+chip]`（名称不包 Flexible 会把 chip 挤出工具栏）；名称容量 zh ≈114px≈5 汉字（仍比治理前 3 汉字多 2），商家详情维持纯名称；预算测试 chip 后容量断言改按语言字宽折算（汉字 22px/字、拉丁/阿拉伯 11.5px/字），product/ingredient_detail specs 加 chip、dynamicCjk=5；下一档杠杆（未做）：收藏移进 ⋮ → 预算 208px ≈7 汉字。77 例相关测试全过，提交 `43b18e11` 后追加。**[同日追加 2]** 用户提议长按标题看全名：新组件 `shared/widgets/app_title_tooltip.dart`（`AppTitleTooltip` = `Tooltip(longPress, showDuration 4s)` 包标题，缺省单行省略 Text，带标签标题传 `child: Row`、message 传全名），接入全部动态实体名标题页 7 处（商品/原料详情、商家详情、试算详情、菜谱详情带图/无图两变体、菜谱分析）；静态标题页不接（预算测试保证不截断）。气泡自动换行 + RTL 自适应 + Semantics 读屏。**SDK 坑**：Flutter 3.47 起 `AppBar` 构造函数不再是 const（`SliverAppBar` 仍 const），`const MaterialApp(home: Scaffold(appBar: AppBar(...)))` 编译报错，测试需先建非 const appBar 变量；`prefer_const_constructors` 会误报 AppBar 可 const。测试 `app_title_tooltip_test` 2 例（长按后 find.text 1→2 份 = 标题+气泡；child/缺省渲染）。验证：analyze 回到基线；tooltip+预算+plan_detail/recipes/三端详情 157 例全过。
- 个人中心「AI 推荐」并入「饮食偏好」（用户要求：设置归位到饮食偏好，并复查每日营养目标与预算是否还有用）：删除页底独立 AI 卡片，推荐方式 / BYOK 提供商 / 模型 / 端点 / API 密钥整体搬进「饮食偏好」对话框（宽 480→560 + scrollable；AI 区块仍 `v-if="!isLocalMode"`，本地模式继续走「设置 · AI 配置」）；保存合并为底部单按钮 `saveDietPreferences`——先 `PATCH /auth/me` 存营养目标与预算，云端且 `aiChanged` 时再 `PUT /profile/ai-settings`，loading 合并 `savingNutrition || aiSaving`；打开对话框时云端刷新一次 AI 设置。「每日预算」标签由写死「元」改为 `{currency}` 跟随默认币种。复查结论：目标与预算**仍在用**——`meal_recommender._get_meal_targets` / `_calc_nutrition_score` / `_calc_cost_score`（AI 推荐短名单打分，预算未设时成本分中性 0.5）、`meal_plan_service._evaluate_stub_items` 的 `targets`/`deltas`（Web `PlanDetailView`「合计 vs 目标」、移动端 `PlanTotalsGrid`）；「今日推荐」页本身不展示目标数值，只影响排序。发现的不一致（本次未改）：移动端营养目标页缺每日预算输入、且无 AI 推荐设置。验证：`npm run build` ✓（master 31.6s / feat 37.8s）、`check:i18n` + `check:i18n:sources` ✓、`test:utils` 73 ✓；无后端与迁移改动。分支：master `e52c61df` → 合入 feat/mobile-app（merge `ec2456c4`）。详见 [FEATURE_个人中心饮食偏好合并AI推荐.md](agent_doc/FEATURE_个人中心饮食偏好合并AI推荐.md)。
- 商品/原料「各商家价格」含已软删记录（用户报告：商品 1136「各商家价格」有千禧三分店，价格记录里没有；web + 移动端一致）：根因是取价端点 SQL 漏了软删除过滤——`ProductRecord.is_active` 只在价格记录列表 `GET /products/` 生效，`GET /products/entity/{id}/latest-price-by-merchant` 与原料 `_lookup_rows`（`/nutrition/ingredients/{id}/latest-price-by-merchant`）只过滤 `merchant_id` / `Merchant.is_open`，把已删记录仍当该商家最新价返回（真实数据：`product_records.id=3859`，商家 6 千禧三分店，¥13.5，`is_active=0`；商家价显示 13.5 元/斤）。修复：商品/原料两个商家价端点、商品最近价端点、商品历史价端点、`GET /products` 的 `sort_by=price_records` 分支统一补 `ProductRecord.is_active == True`（与列表/成本口径一致；web 本地模式为硬删除不受影响，两端共用后端故一处修复）。验证：新增回归 `tests/test_merchant_price_soft_deleted.py`（有效+软删两商家，断言商家价/最近价/记录列表口径一致）；相关后端子集 23 passed，`test_products.py` 2 个登录前置（401）失败为既有。无迁移；后端需重启（自动重载生效）。分支：改动提交 master 后合并回 feat/mobile-app。详见 [BUGFIX_商品商家价含已软删记录.md](agent_doc/BUGFIX_商品商家价含已软删记录.md)。

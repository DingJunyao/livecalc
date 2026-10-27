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

### 最新修复记录
- Flutter SDK 升级到 3.47.8 后 Android 构建失败（用户报错：`Your project's Kotlin version (2.2.10) is lower than Flutter's minimum supported version of 2.2.20`）：根因是项目仍按旧 SDK 的 AGP 9 **Built-in Kotlin** 配置——`android/settings.gradle.kts` 不声明 KGP，而 `gradle.properties` 里 `android.builtInKotlin=false`（旧 migrator 加的）；新 SDK 在 builtInKotlin=false 时靠 `pluginManager.apply("kotlin-android")`，KGP 不在 classpath → 失败后版本检查读到 AGP 9.0.1 自带 Kotlin 2.2.10 → 低于最低 2.2.20。修复：settings 补 `id("org.jetbrains.kotlin.android") version "2.4.0" apply false`（对齐 3.47.8 模板 templateKotlinGradlePluginVersion，仅声明版本，Flutter 插件会自动 apply）；保留 `android.newDsl=false`/`android.builtInKotlin=false`；`pubspec.lock` 随新 SDK 刷新（intl 0.20.3、matcher 0.12.20、meta 1.19.0、test_api 0.7.12、vector_math 2.4.4）。顺带修新 SDK 弃用：菜谱图片重排 `onReorder` → `onReorderItem`（新回调的 newIndex 已按移除旧项调整，去掉手动减一），analyze 恢复零 issue。验证：`flutter build apk --release` ✓（88.6MB，Flutter 3.47.8 / Dart 3.13.7 / AGP 9.0.1 / Gradle 9.1.0 / KGP 2.4.0）；`flutter analyze` No issues；快捷方式/app/router/l10n/菜谱表单 50 passed。遗留：构建时警告 image_picker_android、shared_preferences_android 仍 apply KGP，未来 Flutter 版本会失败，待插件升级。详见 [BUGFIX_FlutterSDK升级后Android构建失败.md](agent_doc/BUGFIX_FlutterSDK升级后Android构建失败.md)。
- 移动端主屏快捷方式（用户要求：长按应用图标弹出 计价 / 查看每日推荐 / 菜谱，iOS、Android 都做）：无新依赖，走一条 MethodChannel `com.a4ding.livecalc/shortcuts`。Dart：`core/shortcuts/app_shortcuts.dart`（id→路由 / 三语标题 / iOS 图标；「计价」带 baseRoute）+ `core/services/app_shortcuts_service.dart`（`ready` 握手、`setShortcutItems`、原生 `shortcut` 事件流）；`app.dart` 在 locale 加载后同步标题、认证完成前保留 pending（登录后补跳）、post-frame `go(route)`。Android：`res/xml/shortcuts.xml` 静态声明三条（自定义 action + extra `SHORTCUT_ACTION`）、`values{,-en,-ar}/strings.xml` 三语标签、主题绿圆底 + 白色 Material 字形矢量图标、manifest `android.app.shortcuts` meta-data、`MainActivity` 在 `configureFlutterEngine` 读冷启动 intent extra、`onNewIntent` 兜底。点「计价」走「go `/prices` 再 push `/prices/record`」，保存/返回回到列表（直接 go 表单会作为首屏、无处可回）。**坑 1**：AOSP `ShortcutParser` 会给静态快捷方式 intent 追加 `NEW_TASK|CLEAR_TASK|TASK_ON_HOME`，点快捷方式等同重建任务 → 主路径是冷启动读 extra，`onNewIntent` 仅兜底；`<extra>` 由 `Intent.parseIntent()` 解析，合法。**坑 2**：iOS 用 UIScene 生命周期，`AppDelegate.application(_:performActionFor:)` 不会被调用；改为在 `AppDelegate.swift` 内实现应用内插件，`registrar.addSceneDelegate` + `FlutterSceneLifeCycleDelegate` 接收 `scene(_:willConnectTo:options:)`（`connectionOptions.shortcutItem`，Swift 类型是 `UIScene.ConnectionOptions`）与 `windowScene(_:performActionFor:)`，并静态持有插件（引擎对场景代理是弱引用）。iOS 采用**动态**注册（标题随界面语言；Info.plist 静态项无法多语言），代价首次启动后才出现，Android 静态安装即用。验证：`flutter analyze` No issues；快捷方式 11 例（含计价直达表单且可返回）+ app/router/l10n 共 43 passed；`flutter build apk --release` ✓（86.5MB，aapt2 校验 shortcuts.xml 三条 intent/extra/图标均正确）；iOS 本机无 Xcode 未编译，需 macOS 验证。详见 [FEATURE_移动端主屏快捷方式.md](agent_doc/FEATURE_移动端主屏快捷方式.md)。
- 新增商品页「新增对应原料」（用户要求：新增商品时经常需要新建一个与商品名不同的原料，原「新建同名原料」只能同名，得退出→建原料→再建商品）：Web `ProductsView` 开关改名为「新增对应原料」，选中后展开原料名称/分类/别名；`saveItem` 先按「填写名 or 商品名」调 `POST /api/v1/ingredients`（`reuse_existing=true` 同名复用、`create_same_name_product=false` 不让后端再补同名商品），商品挂到该原料下，再落商品层级草稿；开关开启时清空已选原料并按旧原料调和草稿单位。后端 `ingredient_extended.create_ingredient` 新增 `reuse_existing` / `create_same_name_product` 两个可选 body 参数（默认保持旧行为）、名称 strip、分类存在性校验、响应带 `reused`。移动端同构（`product_form_screen.dart` 新增态开关 + 名称/分类（`ingredientCategoriesProvider`）/别名，`IngredientRepository.createIngredient` 透传两参数，三语 l10n + gen-l10n，新增 widget 测试 4 例；编辑态隐藏开关，开关关掉恢复开启前的关联原料/固定原料）。本地模式 `handlers/ingredients.createIngredient` 同步支持 `reuse_existing` 同名复用并剥离两个协议字段。验证：后端 4 例通过（复用 / 跳过自动同名商品 / 未知分类）；web build ✓、check:i18n/sources ✓、test:utils 73 ✓；移动端 `flutter analyze` No issues、product+ingredient 81 passed（顺带修一条因表单变长在扫码用例里找不到商品名称字段的既有测试，先滚回顶部再断言）。无迁移。分支：master `e474ac3` → 合入 feat/mobile-app `84bbbd0c`；移动端 feat/mobile-app `eb44a0f9` + `917aeb7a`。详见 [FEATURE_新增商品页新增对应原料.md](agent_doc/FEATURE_新增商品页新增对应原料.md)。
- 新增移动 App 用户文档（用户确认 web 端完成后继续移动端）：`docs/mobile.md`（feat/mobile-app 分支专属，App 代码只在 feat）——获取与安装（Flutter 源码构建 `flutter build apk --release`，iOS 用 Xcode 自签；无商店分发）、首次使用（`/server-config` 填服务器地址测连接 → 与 web **同账号**登录、数据互通）、导航（窄屏底栏 首页/价格/菜谱/更多，宽屏 ≥600dp 侧边 NavigationRail；「更多」含原料/商品/商家/收藏/试算/个人中心）、功能速览表逐项链到 web 手册（体验一致性：价格加权/30 天规则/回退链/提议-审核同口径）、移动端特色（扫码记价命中本库自动填/缺则引导新增、**断网写操作进 drift 队列恢复联网自动重放**（`OfflineSyncService` main 启动；无完整离线浏览）、三语 zh/en/ar + RTL 跟随系统）、常见问题（连不上服务器/数据不对/离线补传）；README 功能手册表补「移动 App」行。写作前先探代码定位事实：`lib/core/router/app_router.dart`（tabs 与全部路由）、`server_config_screen`、`offline_sync_service`、`BRANDING.md`（App 名「生计」）。验证：链接/锚点脚本校验通过。截图待用户提供后插入（见对话清单）。
- 原料各商家最新价未按汇率折算（用户报告：移动端原料详情「蒜」最新价格卡里印尼超市显示 25750 CNY；要求一并检查 web 端）：根因在后端 `GET /nutrition/ingredients/{id}/latest-price-by-merchant` 的 `_lookup_rows`——`total_price = float(record.price)` 直接用**记录原币金额**参与同商家多商品权重加权（混币种时结果本身错），且响应行不回传 `currency`/`exchange_rate`，移动端 `MerchantPriceList` 按 `price.currency ?? userCurrency` 显示 → 原币面额标成 CNY；排序/最低价也按原币比较；同接口的关联/回退/从属折算行均由此派生同样中招。web 端确认**同样有问题**：`IngredientDetail.vue`/`MerchantPriceMatrix` 按 `formatMoney(mp.price, userCurrency)` 显示（原币标成用户币种）；web 本地模式 `normalizeRecordToJin` 本就折算但 `currency: r.currency` 标签错标原币。修复（数据层一处、两端展示零改动）：`_lookup_rows` 改 `record_price_in_user_currency(record)` 先折算到用户/会话币种再加权，响应行加 `"currency": get_user_default_currency(db, current_user)`，排序/最低价/min/max/total_cost 随之全部正确——原料商家行金额即用户币种，与页内加权综合价、趋势图同口径（商品端接口无此问题，保持原币+汇率两段式）；本地模式两处 handler `currency` 改 `LOCAL_USER_CURRENCY`/`DEFAULT_USER_CURRENCY`。移动端/web 云端/移动端菜谱分析格式化逻辑本就兼容，自动修复。验证：后端新增 2 例回归（IDR 25750×0.00044→11.33 且最低价标 CNY 行；混币种先折算再加权 10.93）+ 既有 6 例共 8 passed，相关子集 9 failed+9 errors 与未改动基线逐条一致（既有失败非本次引入）；web build ✓、test:utils 73 ✓。无迁移；后端需重启。分支：master `d7ef4d72` → 合入 feat/mobile-app。详见 [BUGFIX_原料商家价外币未折算.md](agent_doc/BUGFIX_原料商家价外币未折算.md)。
- 后台币种/汇率管理页补齐统一顶部导航栏（用户报告：这两页没有汉堡图标和后退按钮，与其他后台子页面不一致）：两页原本直接以 `<v-container fluid>` + 卡片标题开始，而其他子页面（UnitsView/InviteCodesView/UserManagementView/ProposalsView 等）标准结构是 `v-app-bar`（`v-app-bar-nav-icon` toggleSidebar + `mdi-arrow-left` goBack + `v-app-bar-title` + `#append` 主操作）。修复：`CurrencyAdminView` 加标准 app-bar，「新增币种」移入 `#append`（primary tonal + mdi-plus），卡片改 `rounded-lg`；`ExchangeRateAdminView` 加标准 app-bar，「手动补汇率」移入 `#append`，「立即刷新」改为 `#append` 刷新图标按钮（:loading + :title，参照 ProposalsView），卡片只留快照 alert；两页 script 补 `useMobileDrawerControl`/`useRouter`/`goBack`。无 i18n 新键、无后端改动。验证：`npm run build` 通过（49.85s，PWA precache 187 entries）。分支：master `ec681538` → 合入 feat/mobile-app（merge `f64ae040`）。详见 [BUGFIX_后台币种汇率页导航栏.md](agent_doc/BUGFIX_后台币种汇率页导航栏.md)。
- 用户文档全量对齐当前功能（用户要求：上次写文档时很多功能还没加上，重新检查并补齐，先改 web 端）：`docs/` 新增《试算》`planner.md`、《我的收藏》`favorites.md` 两篇 + README 索引行；`prices.md` 补多币种（原币 + 汇率 + ≈ 折算）、列表筛选（商家/原料分类/记录类型/日期区间）、「综合 / 按商家」切换、「含替代/从属」折算、只在记录日画点、各商家折算行；`concepts.md` 回退链改为 直接价→关联换算→可替代/层级（含换算系数）→半成品→子食材聚合（删除名称匹配）、B 节补换算系数与「关联与换算」、C 节补多币种、F 节补营养基准与商品加权回填；`ingredients.md` 补新建表单内置自定义单位与营养、详情区块（收藏/折算价/关联/换算系数）；`units-density.md` 补自定义单位嵌套与「关联与换算」节；`nutrition.md` 补基准每 X 单位、默认七项、0 值与空保存、商品回填；`profile.md` 补地区/币种/计算范围（含导航栏会话级切换）与语言格式（zh/en/ar + RTL）；`recommend.md` 补宫格排版与「拿去试算」；`local-mode.md` 功能表补试算/收藏/多币种/关联换算/多语言；`admin/admin-pages.md` 补币种与汇率管理；顺手修 `recipes.md`→`concepts.md#半成品菜谱` 坏锚点（原指向非标题加粗段）。验证：自写脚本检查用户手册全部相对链接与锚点（0 问题，plans/ 历史文档的既有坏链不属本次）；无代码改动。分支：master `2d41d62e` → 合入 feat/mobile-app（merge `89887e56`，`local-mode.md` 整文件行尾冲突经比对取 master 版）。**[截图已补]** 用户拍摄 15 张实拍图已插入对应文档（master `32f8b329` 合入 feat/mobile-app merge `15a89e14`）：试算列表 `plans_list.png` / 编辑页 `plans_edit.jpeg`、关联与换算区块 `entity_links.png` + 添加/编辑弹层 `entity_links_edit.jpeg`、外币记价表单与折算显示 `price_add_currency_1/2.png`、按商家趋势 `trend_merchant.png`、含替代/从属折算 `trend_computed.png`、今日推荐主图更新为新布局 `recommend_summary_grid.jpeg`（旧 `recommend_desktop.png` 引用替换、文件保留）、会话级地区/币种切换 `context_currency.png`、语言与格式 `profile_locale.png`、营养编辑默认七项 `nutrition_edit_defaults.png`、后台币种/汇率 `admin_currency.png`/`admin_exchange.png`；「记一笔价格」截图由用户更新为含币种/汇率字段的 `price_add.png`（旧 `price_add.jpeg` 引用替换、文件保留）。图片引用脚本校验：用户手册 99 处全部有效。仅**收藏聚合页**截图仍缺（`favorites.md` 暂无图）。
- 原料营养缺项从商品加权平均回填 + 默认七项 + 0 值保存（用户三条：①原料没有某营养素时从各商品营养**加权平均**带出（商品也没有就不加），必须区分「记录为 0」与「没有记录」——新增时 0 也要记进去；②新建默认带出能量/蛋白质/脂肪/饱和脂肪/碳水/糖/钠，能量单位随用户偏好、g 家族 g、其余 mg；③营养素下拉全量、七项置顶、含反式脂肪）。后端 `nutrition_calculator.py`：`_products_weighted_average_nutrients`（权重=商品价格权重默认 50；键存在含 0 才参与平均；g/克基准才归一到每 100 g，其他单位不折算；单位归一 kcal/g/μg/mg、换算不了的跳过；`sugar↔total_sugars` 等别名互通；原料无营养行时整表带出、商品也没有维持 404）；`NUTRIENT_NAMES` 补 sugar/trans_fat。0 值过滤修复：web 两个详情页保存 + `entityDrafts.ts` + 草稿计数、移动端编辑器 `_saveManual`/`_hadNutritionData` + `entity_draft_persist.dart` + 两表单页计数，全部 `>0` → `>=0`。编辑器：web `DEFAULT_NUTRIENT_KEYS` 七项 + `BASE_DEFS` 补 sugar/trans_fat + `orderNutrientDefsDefaultsFirst` 置顶（两详情页与草稿对话框）；移动端 `kDefaultNutrientLabels/Units` 七项 + `_nutrientOptions` 对齐 web 全量 + arb 三语 4 键。**大坑**：默认行 5→7 后 widget 测试 `ensureVisible(能量字段)` 会把基准行滚出 ListView 懒构建缓存 → `.first/.at(1)` 错位一行，测试须先 drag 回顶、删 ensureVisible、低处行断言用 `skipOffstage:false + findsWidgets`；硬编码中文 lint 白名单 `_canonicalNutrientHan` 补新标签。验证：后端新增 6 例 + basis 回归 10 例全过、`-k nutrition|recipe` 与基线对照零新增失败；web build/check:i18n/test:utils 73 ✓；移动端 analyze ✓、相关 33 项过、全量仅剩 7 个既有失败。分支：master `d78922c8`+`4f6cb306` 合入 feat/mobile-app（merge `7f2075bd`），移动端 `daaeacdd`；后端需重启调试会话。详见 [FEATURE_原料营养商品加权平均回填与默认七项.md](agent_doc/FEATURE_原料营养商品加权平均回填与默认七项.md)。
- 关联弹层带出单位用原料默认盖过商品默认（用户规则：不管在哪，商品的默认单位都优先于原料的默认单位；浓汤宝商品间建关联带出原料的「块」而非商品的「盒」）：根因是关联弹层取**单位列表第一项**，而商品自身单位按创建序 [块, 盒] 排列；正确的「商品自身默认 > 关联原料默认」函数（Web `fetchEntityDefaultUnitName`/移动端 `loadEntityDefaultUnitName`）只接了记价表单。全量排查：修复 Web `EntityQuantityLinksSection.vue`（openAdd/onTargetChange）与移动端 `entity_quantity_link_edit_page.dart`（当前侧/目标侧）4 个点，统一为「默认单位在候选里就用它，否则回退第一项」；记价页/快速记价/移动端记价表单/试算条目 4 处本就正确；营养基准、快速填写、粘贴导入、编辑预填不属此语义。验证：Web build ✓ + test:utils 73 ✓（vue-tsc 环境问题与本次无关）；flutter analyze ✓，关联页新增 2 例回归（浓汤宝盒优先、无默认回退），原整页测试须注入新增的 `defaultUnitLoader` 缝（否则真实 API 令 pumpAndSettle 超时）。分支：Web 修复提交 master `44147bf1` 合并回 feat/mobile-app；移动端 `9ac1b1ca`。详见 [BUGFIX_关联带出单位商品默认优先.md](agent_doc/BUGFIX_关联带出单位商品默认优先.md)。
- 移动端原料列表价格/迷你图只显示前 40 项（用户报告：无限滚动后 40 项之后这两个要素永远加载不出来）：后端 `GET /nutrition/ingredients/latest-price/batch` 限制单次最多 50 个 id（超出 400），移动端列表是无限滚动累计列表（Web 为页内分页不受影响），`_loadDetails` 把累计全部 id 一次发出且 `copyWith` 整体替换 map——第 3 页起（60 id）批量价必 400、整个详情加载中断，state 停在最后一次全部成功的第 2 页（40 项）。修复：①`IngredientRepository.getLatestPrices` 内部按 `latestPriceBatchChunkSize=50` 分块请求后合并、单块失败只丢该块（收藏页 100 个收藏 id 的同类调用一并受益）；②原料列表 `_loadDetails` 改为与已有 map 合并 + `_detailsSequence` 防竞态；③商品列表 `_loadDetails` 同类隐患——`Future.wait` 任一单项取价失败整轮作废，改为单商品失败只跳过自己 + 合并 + 防竞态。迷你图三接口无 id 上限、菜谱 batch-cost 走 POST body 无上限，均无需分块。验证：`flutter analyze` No issues found；新增回归 4 项（分块合并、单块失败、翻页合并、单商品失败隔离），原料+商品 78 项全过；全量仅剩 7 个既有失败（stash 对照基线一致）。详见 [BUGFIX_移动端列表价格迷你图停在前40.md](agent_doc/BUGFIX_移动端列表价格迷你图停在前40.md)。

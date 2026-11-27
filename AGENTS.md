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

开发时使用 `uv` 管理：`backend/pyproject.toml` 为 PEP 621 `[project]` 格式（uv 可直接读取），`uv lock` + `uv sync` 安装依赖（含 dev 组），可选依赖 `uv sync --extra celery --extra redis`。

虚拟环境：`backend/.venv`（uv 默认位置）；Python 版本由 `backend/.python-version`（3.11）固定，与 Docker 镜像 `python:3.11-slim` 一致。

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
详情页趋势图「综合/按商家」切换（原料/商品各商家价格趋势对比；商家 chips 多选默认前 3 家，纯前端分组 + 同口径 as-of，无后端改动）：详见 [FEATURE_商家价格趋势对比.md](agent_doc/FEATURE_商家价格趋势对比.md)
快速填写商家下拉缺店（移动端 `GET /merchants` 不带参数 → 后端默认 limit=10 按创建时间倒序截断；Web 硬编码 limit=100 同类隐患；两端改按 total 翻页取全）：详见 [BUGFIX_快速填写商家下拉截断.md](agent_doc/BUGFIX_快速填写商家下拉截断.md)
趋势图只在真实记录日画点（原料/商品/菜谱成本/方案走势统一；菜谱与方案趋势由后端新增 `has_record`，前端 `symbolSize=0` 表示 as-of 携带日）：详见 [FEATURE_趋势图仅记录日画点.md](agent_doc/FEATURE_趋势图仅记录日画点.md)
原料趋势图显示替代/回退/从属折算价（与菜谱成本同一降级链 direct→fallback→name_match→recipe→contains；后端 `/ingredients/{id}/price-series`，前端虚线 + 区间带 + 「含替代/从属」开关默认开）：详见 [FEATURE_原料趋势替代从属折算.md](agent_doc/FEATURE_原料趋势替代从属折算.md)
商品/原料「关联与换算」（两两等式 `1 提 = 5 包` / `3 kg 鲜 = 1 kg 干`；单位与密度内展示；direct → entity_link → fallback → recipe → contains；本地模式）：详见 [FEATURE_商品原料关联与数量换算.md](agent_doc/FEATURE_商品原料关联与数量换算.md)
替代/回退关系换算系数（干/鲜 `1 kg 干 = 3 kg 鲜`；原料折算归层级关系，关联页聚焦商品包装链）：详见 [FEATURE_商品原料关联与数量换算.md](agent_doc/FEATURE_商品原料关联与数量换算.md)
Web 价格记录图标去货币化（侧栏 + PWA 快捷方式 prices.png；`mdi-currency-cny` → `mdi-receipt-text-outline`，对齐移动端 `receipt_long`）：详见 [FEATURE_PWA快捷方式图标.md](agent_doc/FEATURE_PWA快捷方式图标.md)
新增商品页「新增对应原料」（原「新建同名原料」改为可填写名称/分类/别名；名称留空或同名用商品名，不同则建对应原料并让商品挂在其下；后端 `reuse_existing` + 跳过自动同名商品；web 对话框 / 移动端整页）：详见 [FEATURE_新增商品页新增对应原料.md](agent_doc/FEATURE_新增商品页新增对应原料.md)
商品/原料「各商家价格」含已软删记录（价格记录列表已隐藏、商家价仍显示；商品/原料商家价、最近价、历史价、`sort_by=price_records` 分支补 `ProductRecord.is_active` 过滤）：详见 [BUGFIX_商品商家价含已软删记录.md](agent_doc/BUGFIX_商品商家价含已软删记录.md)
移动端商品保存报「保存失败，请重试」（表单把留空条码/品牌以 "" 提交，撞 `products.barcode` 唯一约束里的历史 `''` 行；后端 create/update 统一空串归一化 NULL）：详见 [BUGFIX_商品空条码保存失败.md](agent_doc/BUGFIX_商品空条码保存失败.md)
个人中心「饮食偏好」合并 AI 推荐设置（AI 卡片移入对话框 / 单按钮保存营养目标+预算+AI 方式 / 预算标签跟随默认币种 / 营养目标与预算仍在 AI 打分与试算目标中使用）：详见 [FEATURE_个人中心饮食偏好合并AI推荐.md](agent_doc/FEATURE_个人中心饮食偏好合并AI推荐.md)
快速填写价格系统数字键盘 + 币种跟随商家地区（`NumericKeypad` 全 App 仅此一处、其余数字输入均已系统键盘；币种读商家 `effective_currency` 去显式选择；web 草稿恢复补币种同步）：详见 [FEATURE_快速填写系统键盘与币种跟随商家.md](agent_doc/FEATURE_快速填写系统键盘与币种跟随商家.md)
编辑价格记录换绑商品（三层都堵死：后端 `ProductRecordUpdate` 无 product_id、web 编辑 payload 不带、移动端只读；更新端点校验+商品名快照+按新商品重算标准量；所有编辑入口（列表/商品详情/原料详情）统一可换绑商品、编辑对话框字段集对齐；本地模式同步快照）：详见 [BUGFIX_编辑价格记录无法换商品.md](agent_doc/BUGFIX_编辑价格记录无法换商品.md)
移动端 AppBar 标题截断（预算公式 360−56−Σ48/64+；商品/原料详情 4 actions+chip 只剩 ~3 汉字、试算详情 4 平铺按钮、营养编辑 en 清空按钮 184px、关联关系 en/ar 文案超预算；删 8 处冗余刷新、试算详情 ⋮ 合并、营养编辑标题固定+实体名/清空移 body、en/ar 文案缩短；原料/商品详情标题保留类型标签（名称 Flexible+chip ≈5 汉字）；动态标题页长按看全名（AppTitleTooltip，7 处接入）；回归测试 `app_bar_title_budget_test` 按宿主字体逐屏测量）：详见 [BUGFIX_移动端AppBar标题截断.md](agent_doc/BUGFIX_移动端AppBar标题截断.md)
今日推荐餐卡 NRV 双百分号（mobile `formatPercentValue` 自带 %，`_nrvSuffix` 模板又拼一个 → `NRV xx%%`；web 无此问题）：详见 [BUGFIX_移动端推荐餐卡NRV双百分号.md](agent_doc/BUGFIX_移动端推荐餐卡NRV双百分号.md)
试算新增/编辑态隐藏「设为今日」（与保存按钮相邻易混淆；「设为今日」只留列表行与移动端详情 ⋮）：详见 [FEATURE_试算新增编辑隐藏设为今日.md](agent_doc/FEATURE_试算新增编辑隐藏设为今日.md)
试算原料条目营养为空（火腿肠脂肪未计入；后端改用 NutritionCalculator 同口径：best 营养行 + 缺项商品加权平均回填 + 数量经实体换算链）：详见 [BUGFIX_试算原料营养为空火腿肠脂肪.md](agent_doc/BUGFIX_试算原料营养为空火腿肠脂肪.md)
新增商品「新增对应原料」自动带入未匹配的关联原料文字 / 表单页（新增编辑原料、商品、菜谱、商家、方案）隐藏底栏与侧栏 tab / 价格记录商家下拉选中后释放焦点 / 营养默认单位除能量与七项宏量营养素外统一 mg：详见 [FEATURE_表单体验与营养默认单位.md](agent_doc/FEATURE_表单体验与营养默认单位.md)
试算成本不随数据范围变化（X-Region 机制完好但 meal_plan_service 三条成本链路全漏传 region_id；evaluate 与 cost-trend 在 service 公共汇合点解析范围，菜谱/原料/商品 + 走势 + has_record 全链路套 apply_region_filter；推荐打分经 evaluate_plan 一并生效；本地模式无范围通道属既有缺口）：详见 [BUGFIX_试算成本不随数据范围变化.md](agent_doc/BUGFIX_试算成本不随数据范围变化.md)
用户自定义计算范围（多地区组合：user_calc_scopes 表 + users.default_calc_scope_id；region_subtree_ids/apply_region_filter/X-Region 头支持多地区子树并集去重（tuple 可哈希作缓存键）；/api/v1/calc-scopes CRUD；两端默认范围选择器与会话切换器接自定义选项；本地模式不在范围）：详见 [FEATURE_自定义计算范围.md](agent_doc/FEATURE_自定义计算范围.md)
记价搜索不到商品时新增商品闭环（复用扫码未命中模式：web sessionStorage+returnTo 跳 /data/products 预填名称、移动端 push ProductFormPrefill 返回 _selectProduct；web 校验放宽为「选商品或输名字其一」+修 Vuetify validate() 恒 truthy；快速填写返回优先回填同名行）：详见 [FEATURE_记价搜索不到商品时新增商品闭环.md](agent_doc/FEATURE_记价搜索不到商品时新增商品闭环.md)
跨地区物价对比一期（批量对比端点 /api/v1/comparison（regions/summary/entity-prices，sparklines 同口径）+ Web /compare 对比页（概览物价指数/篮子趋势 + 原料·商品比价矩阵，复用 RegionMultiSelect）+ 两端详情页「商家｜地区」维度切换（趋势图按地区序列与按商家同构同口径）+ 移动端 CompareScreen 进「更多」；ProductRecordResponse 补 merchant_region_id；本地模式 handler 同步）：详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)
跨地区物价对比二期（菜谱/试算成本对比：comparison 新增 recipe-costs / recipe-cost-trend / plan-evaluate-regions（草稿可用）/ plan-costs / plan-cost-trend 五端点；meal_plan_service 求值入口加显式 region_id 覆写（哨兵区分未传与显式 None）；Web 对比页第三 tab + 菜谱分析页维度切换（地区数据整形复用商家组件）+ 试算详情合计卡口径切换 + 对比态趋势换多地区图；移动端 CompareScreen 第三 tab + 试算详情合计卡切换）：详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)
跨地区物价对比三期（商家物价热力图：GET /comparison/heatmap 单品/整体两模式（篮子指数中位数=100）+ 分位 buckets；Web HeatMapCanvas（Leaflet 统一渲染 circleMarker 五档着色+图例+popup）进对比页第四 tab；移动端 HeatmapCanvas widget（flutter_map 着色圆点+点按弹层）进 CompareScreen 第四 tab；本地 handler 同步）：详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)
自定义计算范围作为独立对比列（region_ids 项支持 `s<范围id>`：范围内地区 tuple 并集作为一棵合并子树；响应负数 resp_id=-(scope.id) + 范围名；9 个对比端点全支持；两端地区选择器范围整体加入/移除 chips；明发 vs 南京/三门峡场景）：详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)
uv sync 空锁无依赖（pyproject 是 Poetry 格式 `[tool.poetry.dependencies]`，uv 只认 PEP 621 `[project]` → uv.lock 从首次提交起只有 babel；迁移 PEP 621 + `[tool.uv] package=false` + `.python-version` 3.11 对齐 Docker；venv 实为 `backend/.venv`）：详见 [BUGFIX_uv_sync空锁无依赖.md](agent_doc/BUGFIX_uv_sync空锁无依赖.md)
Mac 调试环境 iOS 构建通（xcode-select 停在 CLT → DEVELOPER_DIR 按次绕过；Xcode 26+ 模拟器 app 更名 DeviceHub；构建挂死两层根因：① Flutter 3.50 框架 dot-shorthand × riverpod_generator/drift_dev 封顶 analyzer 7.x → 删零使用的 riverpod_generator/annotation + drift 2.35.x + analyzer 14.7；② objective_c native-assets hook 拿不到 DEVELOPER_DIR（flutter 只透传 PATH）→ xcrun shim 验证通过；遗留 sudo xcode-select --switch）：详见 [BUGFIX_Mac调试环境iOS构建.md](agent_doc/BUGFIX_Mac调试环境iOS构建.md)
iPhone Duo 折叠屏适配调研（外屏 466×678@3x / 内屏 669×951·951×669@3x，Xcode 27.2 描述文件实证；UIScene/15.0/断点 600 已就位，内屏恰好命中 rail；缺口：切内外屏穿越断点丢 State、iOS displayFeatures 空缺需 foldable 桥接、外屏 678 矮档下 sheet 固定高 420/横屏 strip inset 待收敛；本机已有 Duo 模拟器；**尚未实施**；设计稿 v3 九版块（+Plate 09 web 端：md 960 vs Duo 951 差 9pt 根因 → L1 详情列档 md→sm/L2 viewport-segments 半折双 pane/L3 posture 检测边界；Safari 27.1 Feature Flags；Android Flutter displayFeatures 原生）（按官方 HIG 定调修订：尾缘竖条=Dynamic Island+状态+工具栏+tab bar 且页面操作入竖条/内屏竖屏例外保留标准横条/铰链虚线标注·全形态连续屏不分区/reserved regions 摄像头与折叠区/分屏列表在左/rail 顺序对齐 web 商品→原料/无 laptop 姿态；web 端见 Plate 09）见 `原型/iPhoneDuo适配设计稿.html`；**实施启动（2026-11-23，feat/mobile-app 未提交）：Phase 1 壳层（device_form.dart 形态判定 + Stack 树形恒定 + _EdgeRail 尾缘竖条 64w 图标无文字 + rail 顺序对齐 web 商品→原料）、Phase 2 菜谱卡（≥800 四列/固定高图 104/成本/份新键 recipeCostPerServing 三语）、Phase 6 compare 弹层 420→0.5×屏高；analyze 0 非弃用问题、全量测试 4 失败均为既有基线（stash 对照）、Duo 模拟器实测系统状态栏竖排确认；**首轮实测修正**：竖条 SafeArea 重复消费 84pt 保留区导致内容压成 0 宽（图标移位+点按失灵）→ 竖条宽度取 viewPadding.right、SafeArea 关闭 left/right、图标 20pt、加真实几何回归测试；首页展开三栏（≥780 三栏 / ≥560 两栏）；**二轮修正**：竖条只留 4 项（末项「更多」弹层），图标列按像素实测钉在距右缘 48pt（非条心 42）、设计稿同步 84 宽；**三轮修正**：分屏时竖条跟随系统条侧别（**权威信号 UITraitCollection.verticalBarEdge**，新增原生 DuoLayoutPlugin + dart vertical_bar_edge.dart + didChangeMetrics 重查；viewPadding 在分屏不可靠），竖向导航页面切换改上下滑动（shellPageSlideBegin，RTL 不镜像），折叠态摄像头在竖条下半段时导航项自动翻到顶部（reservedRegions(.occlusion)）；**Phase 3/4/5 完成**：试算详情 ≥820 左条目(2 列)+右合计/占比、走势与营养整行；商家 ≥820 左 350 列表+右全高地图；商品卡补别名 chips；**四轮**：竖条工具栏机制 ShellChrome（页面 publish primary/actions，折叠态/内屏横屏/分屏下标题栏动作与 FAB 移入竖条，接入首页/计价/菜谱/商品/原料/商家/试算详情）、实体详情 ≥820 双栏（DetailTwoColumn）、计价与试算列表 ≥620 两列/≥1100 三列、菜谱网格 669/678 三列；**五轮**：竖条工具栏统一 44×44/20pt + 后退置顶 + 避让系统簇；半折按折叠区（.division → DuoLayoutScope.foldX）分栏不跨铰链；商家全开地图 2/3；详情页顺序对齐 web 且动作入竖条；**六轮**：表单页保留竖条（后退+保存检查图标入竖条、隐藏 tab 与底部保存条，saveAppBarActions rail-aware 14 处调用点）、四个详情页按 web ≥960 CSS Grid 逐行配对、半折 foldX（division + 细高遮挡带兜底）断开分栏、商家全开 1:2；**七轮**：单列保持原顺序（DetailTwoColumn.rows.single）、后退键改 GoRouter.canPop、更多弹层自适应列数、商家商品价格卡两列、详情同排等高（IntrinsicHeight）与 1:1 列宽；**八轮**：竖条后退改 GoRouter.pop、一律按完全展开（删半折分支/商家恒 1:2/侧别只信 trait）、原料商品商家收藏列表 ≥620 两列 ≥1100 三列、Duo 无顶部簇时 removePadding 让标题栏贴顶；**九轮**：系统有竖条时折叠横屏也走竖条（shellModeFor 接 edge；此前误判底栏导致标题栏压摄像头/底栏左侧空白）、竖条工具在上 tab 贴底 + 底部簇让位；**十轮**：竖条高<620 只留 tab（工具回标题栏）、原料/商品/商家列表卡去掉记价按钮与箭头、菜谱详情顶部「图片+基本信息｜成本」对齐 web、展开竖屏 removePadding 贴顶；**十二轮**：矮横屏改全宽底栏（不缩进）、标题栏按遮挡区让位（高度/左右内边距）、底栏 removePadding 全宽、对比/收藏/试算接入竖条（FAB 入竖条）、收藏去箭头、个人中心补箭头；**第十三轮**：从模拟器日志拿到各姿态系统真实遮挡区（内屏竖屏右上 144×82 / 折叠横屏曲边在下右下 84×82 / 曲边在上左上 174×84）→ 让位全部改按矩形推导（`DuoBarInsets`：簇在顶→标题栏高=簇底边+按钮排到簇旁、簇在底→标题栏贴边+底栏让角）、统一 `ShellAppBar`（竖条模式标题栏零按钮，53 处接入 + 源码守卫测试）、浮层安全区在 Navigator 之上统一接管、SliverAppBar.toolbarHeight 默认 56 盖掉主题的坑、今日预估宽屏四项一行、`AdaptiveTabBar` 宽屏铺满；**第十四轮**：竖条动作按发布者路由各存一份（修个人中心残留「新增」/单位偏好残留对勾/菜谱分析页残留详情按钮——根因是 ShellRoute 的 builder 在 push 时不重建 + 单一槽位被旧页覆盖；壳层改监听 Router delegate 并走进 ShellRouteMatch 取真实地址）、自定义计算范围 FAB 收支栏、窄屏「更多」每行 4 项、展开竖屏标题栏内容对齐系统图标 48pt 光轴、今日预估阈值 560（卡内实际 605 才命中）、菜谱分析①②两卡一行 + 营养溯源卡内 ≥560 一行两个；**第十五轮**：宽底栏（展开竖屏/折叠横屏）的 tab 根页去掉返回键（`ShellChromeScope.tabRoot`，六个列表页接入）、返回键统一成带尾巴的 `arrow_back`（ShellAppBar 接管自动返回键）、后退无响应改 canPop→GoRouter.pop（PopScope 仍走 maybePop，无 GoRouter 的独立页面退回 Navigator）；**第十六轮**：展开瞬间原生返回空信息导致标题栏掉到状态簇下面（`_seenDuo` 记住 Duo + 相等判断补尺寸 + ≥600×800 兜底）、详情页分栏断点 820→600（折叠横屏/展开竖屏也分栏，卡头标题改可收缩防溢出）、粘贴导入页「复制模板｜解析并匹配」同一行（移动端 + web）；**第十七轮**：详情页分栏断点改回 820（折叠横屏/展开竖屏单列）、空遮挡区时沿用上一帧+补查 5 次+展开竖屏按实测几何兜底，保证标题栏按钮仍给状态簇让位）；**第十八轮**：个人中心「保存按钮位置」在 Duo 上加说明「有侧边栏时保存按钮固定在侧边栏上部分」（`saveButtonPositionDuoRailNote` 三语，仅 Duo 显示）；**第十九轮**：分屏左窗竖条上部分工具按「下部分按钮距屏幕的距离」让开上沿（无顶部簇时 `top = max(12, home indicator)`）；**第二十轮（回归修复）**：普通 iPhone/iPad 也会上报整条状态栏为 occlusion → 只把「贴侧边且靠近上下角、非整宽/整高」的遮挡区当 Duo 簇（`DuoLayoutInfo.clusters`），否则标题栏会跑到灵动岛上面、按钮被推出屏外）；**第二十一轮**：iOS 普通手机锁竖屏（`OrientationPolicy`：平板/折叠屏允许旋转，普通手机仅 portraitUp，冷启动发后即忘 + 壳层信息变化时重估）——普通手机横屏的灵动岛避让问题随之消失）；**第二十二轮**：真机 iPhone 13 Pro 标题栏顶进刘海 → 加 `isFoldableScreenShape`（短边/长边 ≥0.6 才算折叠屏）闸门，所有 Duo 决策（含方向策略）都要过；未知尺寸的 clusters 返回空；Duo 调试日志补 `clusters/mq/shape` 判据）：详见 [FEATURE_iPhoneDuo折叠屏适配调研.md](agent_doc/FEATURE_iPhoneDuo折叠屏适配调研.md)

上架合规与提交材料（App Store / Google Play / 中国区准入：账号注销、隐私政策与注册同意勾选、明文流量收敛、审核备注模板与材料清单）：详见 [STORE_SUBMISSION.md](agent_doc/STORE_SUBMISSION.md)
后端/管理端合规运维（管理端配置逐项合规对照、高风险「谨慎提供」清单、日志与备份义务、国区专项、只读自检 SQL、移动端配合项）：详见 [COMPLIANCE_ADMIN_GUIDE.md](agent_doc/COMPLIANCE_ADMIN_GUIDE.md)

### 最新修复记录
- 上架合规 P0 三项落地（合规扫描 rule pack v2.5.3：critical=0/high=5/medium=3，人工核查另发现 4 个阻断项）：**①账号注销**——`POST /api/v1/auth/me/delete`（`AccountDeleteRequest.password_hash`，前端 SHA-256 后传；最后一个管理员禁止自助注销），清理逻辑独立成 `app/services/account_deletion.py`：按外键顺序清 30+ 张表（本项目除 product_barcodes 外无 ON DELETE CASCADE），**他人引用的公开菜谱/商家匿名化保留**（`user_id=None`）而非物理删除（否则破坏他人方案/收藏），图片走 storage.delete + 清 image_tracking；`models/__init__.py` 补注册 operation_log / import_task / change_proposal / ingredient_merge_record（空库 create_all 缺表，测试先踩到 `no such table: operation_logs`）。单测 `tests/test_account_deletion.py` 3 例（隔离内存库 + dependency_overrides，不碰开发库）。**②隐私政策/用户协议**——`mobile/assets/legal/{privacy,terms}_{zh,en}.md`（阿语回退英文）+ `/legal/:doc` 顶层路由（redirect 白名单单独判 `isLegalRoute`，已登录不被弹回首页）+ 极简 Markdown 渲染页；注册页强制勾选同意（未勾选 SnackBar 拦截，3 个既有注册测试补 `_acceptLegal`）；个人中心常驻入口；公开托管版 `legal/*.html`（中英）。**③明文流量收敛**——iOS 删 `NSAllowsArbitraryLoads` 只留 `NSAllowsLocalNetworking`；Android 新增 `network_security_config.xml`（发布禁明文，仅 localhost/127.0.0.1/10.0.2.2；debug 变体全放开）+ `allowBackup=false`，APK 合并清单已复核。**校验**：APK 93.9MB 构建通过、4 个法律文档进包；`flutter analyze` 0 error（253 info 均存量）；auth/profile/router 测试通过（3 例失败为存量：locale_preferences 多传 format_locale、my_proposals 时区日期）。**合规信息可配置化（2026-11-27 同日补）**：后端新增 `system_config` JSON 键（compliance_ai/compliance_map/legal_docs，免迁移）+ 公开 `GET /api/v1/app/config`（AI/地图展示信息 + 法律元数据，不含密钥）+ `GET /api/v1/legal/{doc}?locale=`（正文）+ `GET /legal/{doc}`（HTML 页，商店链接直接用，**填 API 域名不要填 SPA 路由**）+ 管理端 `GET/PUT /api/v1/admin/compliance`；测试 `tests/test_compliance_config.py` 5 例（公开读取/默认文案/HTML/写入生效/正文覆盖，隔离内存库）。Web 新增「管理端 → 合规信息」`ComplianceView.vue`（AI 四类提供方 Claude Code / Codex / OpenAI 兼容 API / Anthropic 兼容 API 的展示名+模型名+备案号；地图 高德/百度/腾讯/天地图/OSM 的审图号；隐私政策/协议中英文正文 + 联系邮箱，清空回退内置默认；底部显示当前生效预览）+ 路由/仪表盘入口 + 三语 i18n（脚本 `frontend/scripts/add-compliance-i18n.py` 幂等按行插入，避免重排 locale JSON）。移动端：新增「关于」页（版本/服务器/联系方式/AI 模型与备案/地图审图号/法律入口）、法律文档改为**服务端优先**（读 `/legal/{doc}`，失败回退内置 assets）、首次出现 AI 来源推荐时一次性告知（5.1.2，可跳「关于」；SharedPreferences 不可用时静默跳过以免影响测试）。**用户澄清**：AI 提供方是 Claude Code / Codex / OpenAI 兼容 / Anthropic 兼容（前两者驱动本机工具，工具可再指向第三方模型），合规信息（模型名/备案号）应可填写并在关于页展示（未来支持多 API 各自信息）；**天地图可合规使用**（需填审图号），此前指南把它列为不合规属错误，已修正；隐私政策/协议放 Web 端由管理员编辑。验证：web build ✓ + check:i18n(+sources) ✓；后端 8 例过；flutter analyze 0 error。**仍待办**：演示服务器/账号、R8、年龄分级、隐私标签/Data safety、国区 App 备案与 AI 备案、图片鉴权+审核。详见 [STORE_SUBMISSION.md](agent_doc/STORE_SUBMISSION.md) 与 [COMPLIANCE_ADMIN_GUIDE.md](agent_doc/COMPLIANCE_ADMIN_GUIDE.md)。
- 移动端打包入口（`.vscode/launch.json` 新增 5 个 node 类型启动项：`Flutter 打包 (Android APK · release)` / `(Android AAB · release)` / `(iOS IPA · release)` / `(iOS · 不签名编译验证)` / `(iOS · 未签名 IPA)`——Dart 扩展没有「只构建」的启动项，沿用「前端」配置的 node + runtimeExecutable 手法，F5 在集成终端跑完整构建；env 里显式给 pub 镜像与 DEVELOPER_DIR，因为 `dart.env` 只管 Dart 扩展起的进程）。**`.app` 与 `.ipa` 的区别**（用户实测提问「怎么出来的是 .app」）：`flutter build ios --no-codesign` 只编译 → 出 `Runner.app`；`.ipa` 是 archive + 签名导出阶段的产物，只有 `flutter build ipa` 出 → 本机 0 个 codesigning 证书、0 个描述文件、pbxproj 无 DEVELOPMENT_TEAM，那条现在必然失败。故新增 `mobile/scripts/make-unsigned-ipa.sh`（**默认先重新编译再打包**，保证 ipa 是最新代码——用户指出打包至少要构建，最初版本默认复用旧 Runner.app 属疏漏；`--reuse` 才跳过编译；清 `_CodeSignature` / `embedded.mobileprovision` / `.DS_Store` / 扩展属性，`zip -qry` 保符号链接，产物 `build/ios/ipa/livecalc-<版本>-unsigned.ipa`）把 `.app` 装进 `Payload/` 打成**未签名 IPA**——只能给 Sideloadly/AltStore 用自己 Apple ID 重签后安装；要「装上就能跑」必须先配 Team。**本机实测**：不签名 release 构建通过（167s，`Runner.app` 28.7MB）；未签名 IPA 11MB，`Payload/Runner.app/Frameworks/App.framework/App` 完整；`flutter build apk --release` 立刻报 `[!] No Android SDK found`——当时本机**无 Android SDK、无 JDK**（`flutter doctor` Android toolchain ✗，`maven.google.com` 探测超时说明网络还需代理/镜像；后续已装好，见下）。**Android 打包打通（2026-11-27）**：用户装好 SDK 后 `flutter build apk` 报 Gradle 版本过低——Flutter 3.50.1 的 `DependencyVersionChecker` 硬下限是 **Gradle 9.3.1 / AGP 9.1.1 / KGP 2.4.10**，而项目三件套 9.1.0 / 9.0.1 / 2.4.0 **全部低于下限**（升级前只报 Gradle，改完会连着报 AGP、KGP），故统一取 Flutter 3.50.1 模板版本：wrapper → Gradle **9.5.0**、settings.gradle.kts → AGP **9.3.1** + KGP **2.4.20**。随后报 `Inconsistent JVM-target compatibility ... (21) and (25)`：`android.builtInKotlin=false` 时 jvmTarget 由外部 KGP 按 JDK 工具链取（Android Studio 的 JBR 是 25），必须在 `android/app/build.gradle.kts` 显式 `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_21 } }`（Flutter 模板里有同样写法，模板取 JVM_17）——原注释「由 Built-in Kotlin 自动设置」是错的。AAB 另卡在 `Release app bundle failed to strip debug symbols`：并非真没 strip（NDK `llvm-readelf` 验过 `libapp.so` 是 stripped，AAB 里也有 `BUNDLE-METADATA/com.android.tools.build.debugsymbols/**/libapp.so.sym` + `libflutter.so.sym`），而是 Flutter 的事后校验要调 SDK 的 `cmdline-tools/latest/bin/apkanalyzer` 列文件；`brew install --cask android-commandlinetools` 后**必须 `cp -R` 复制**到 `~/Library/Android/sdk/cmdline-tools/latest`（**不能用 symlink**：apkanalyzer 按自身真实路径上溯找 `build-tools`，软链会落到 /opt/homebrew 下报 `Cannot locate latest build tools`）。实测：APK 89MB（universal）/ AAB 84.3MB 均构建通过。**release 签名（2026-11-27 已接好）**：`android/app/build.gradle.kts` 顶部读 `android/key.properties`（`rootProject.file`，`.gitignore` 已排除）→ `signingConfigs.create("release")`，`storeFile` 走 `rootProject.file`（相对路径以 `mobile/android/` 为基准，也可写绝对路径）；**没有 key.properties 时回退 debug 签名**并在构建输出打提示（必须用 `logger.quiet`——flutter 调 Gradle 带 `-q`，`lifecycle`/`warn` 级别会被吞掉，实测 lifecycle 完全看不见）。新增 `android/key.properties.example`（四字段 + keytool 生成命令，不含密钥）。实测两条路径：临时 keystore 下 `apksigner verify --print-certs` 显示 `CN=LiveCalc Test...`；删掉 key.properties 后回到 `CN=Android Debug` 且提示可见；测试用的 key.properties 与 /tmp keystore 已清理。**上架前用户仍需**：自己 `keytool -genkeypair` 生成正式 keystore → 复制 example 为 `android/key.properties` 填四字段 → 离线备份 key（丢了无法再发同 applicationId 的更新）。遗留：`flutter doctor --android-licenses`（部分许可未接受，仅影响安装缺失组件）。分支：feat/mobile-app（android/gradle/wrapper/gradle-wrapper.properties + android/settings.gradle.kts + android/app/build.gradle.kts + android/key.properties.example + AGENTS.md）。
- Mac 调试环境 iOS 构建通（用户换到 Mac（Xcode 27.2 / Flutter 3.50.1）后要调 iOS 端：**环境层**——`xcode-select` 停在 Command Line Tools，完整 Xcode.app 未接通，无 sudo 时全部命令前缀 `DEVELOPER_DIR=/Applications/Xcode.app/...` 按次绕过；Xcode 26+ 的模拟器 app 更名 **DeviceHub**（`Contents/Applications/`，不再有 Simulator.app）；`brew install cocoapods`（1.17.0，插件编译必需）；`mobile/ios` 无 Podfile，首次 `flutter build ios` 自动生成 Podfile/Podfile.lock 并改写 xcconfig/pbxproj/xcworkspace（正常副作用，应随分支提交）。**构建一败**——`.g.dart` 全部 gitignored（.gitignore:22），新机器必须跑 build_runner，而 build_runner 0% CPU 挂死：riverpod_generator 2.6.5 封顶 `analyzer ^7.0.0`，解析 **Flutter 3.50 框架源码的 dot-shorthand**（`animation_controller.dart:451` `_AnimationDirection _direction = .forward;`）时 bundle writer 抛 `Missing implementation of visitDotShorthandPropertyAccess` 打断 AnalysisDriverScheduler 异步循环 → 永久等待（`sample <pid>` 看栈确认）；analyzer 14.x 才全支持，3.47.9（Dart 3.13.7）是最后一个框架不带 shorthand 的 stable。**用户定调以最新稳定版 Flutter 为准、升级插件**：全项目 0 处 `@riverpod` 注解、0 处 riverpod_annotation import → 直接删 `riverpod_generator` + `riverpod_annotation`（flutter_riverpod 2.6.1 运行时保留）；`drift ^2.19→^2.35`、`drift_dev ^2.19→^2.35`（2.35.3 允许 analyzer `>=13 <15`，仍在 drift 2.x 内无 breaking 迁移）；`build_runner ^2.4.9→^2.17.1`（已移除 `--delete-conflicting-outputs` 参数，忽略告警）；analyzer 7.6.0→**14.7.0**，codegen 30s 出 639 输出（含 `app_database.g.dart`），`flutter analyze` 0 error/0 warning（181 条 info 均为 Flutter 3.50 把 `package:flutter/material.dart` 标弃用建议 `material_ui` 的存量告警）。**构建二败**——`objective_c-9.6.4` native-assets hook 跑 `xcrun --show-sdk-path --sdk iphonesimulator`：flutter 工具给 hook 子进程构造环境**不透传 DEVELOPER_DIR（只透传 PATH）**，CLT 下 xcrun 报错进 stderr、stdout 为空 → `Iterable.first` 抛 `Bad state: No element`；同命令手动加 DEVELOPER_DIR 即成功。PATH shim（`~/opt/devdir-shim/xcrun` 内部注入 DEVELOPER_DIR）前缀 PATH 后**构建成功** `✓ Runner.app`。**遗留（用户需 sudo 一次）**：`sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` + `sudo xcodebuild -runFirstLaunch`——切完后 hook 走系统默认、VS Code F5 才能避开同坑（dart.env 的 DEVELOPER_DIR 只到扩展进程，到不了 hook）。**配置落盘**：launch.json 原 `Flutter` 改名 `Flutter (Windows 桌面)` 保留 + 新增 `Flutter (iOS 模拟器)`（deviceId 按名匹配 `iPhone 18 Pro`）与 `Flutter (iOS 真机)`（无 deviceId 弹选择）；settings.json `dart.offline: false`（offline 静默降级锁文件老坑）+ dart.env 加 DEVELOPER_DIR。**终端构建记得带镜像变量** `PUB_HOSTED_URL/FLUTTER_STORAGE_BASE_URL=flutter-io.cn`（dart.env 只管 VS Code 起的进程）。分支：feat/mobile-app（pubspec/pubspec.lock/launch.json/settings.json/agent_doc/AGENTS.md）。详见 [BUGFIX_Mac调试环境iOS构建.md](agent_doc/BUGFIX_Mac调试环境iOS构建.md)。
- 自定义计算范围作为独立对比列（用户澄清：「未适配自定义范围」指的是让「明发」这类范围**作为一个整体**与南京市、三门峡市对比，而不是把范围拆成地区填入）：**后端**——新增 `_resolve_compare_items`：`region_ids` 每项支持 `<地区id>` 与 **`s<范围id>`**（范围 → `tuple(region_ids)` 并集，`region_subtree_ids`/`apply_region_filter` 原生支持，一棵合并子树；scope 归属校验，他人/不存在 404）；响应中范围项用 **负数 `resp_id = -(scope.id)`** + 范围名（前端矩阵/趋势/摘要 key 结构不变）；9 个对比端点（summary/entity-prices/recipe-costs/recipe-cost-trend/plan-evaluate-regions/plan-costs/plan-cost-trend/heatmap）全部切换，范围也可作基准项（篮子取范围并集）。**坑**：切 `request_locale(request)` 时 recipe-cost-trend / plan-evaluate-regions / plan-cost-trend 三端点原本没有 `request` 参数 → NameError，逐个补 `request: Request`，测试同步传 `_fake_request()`。**Web**：`api/comparison.ts` 新增 `serializeCompareItems`（负数→s<id>）统一所有调用；CompareView 地区选择器只承载正数地区（RegionMultiSelect `:model-value=positiveRegionIds` + 合并回写负数），自定义范围以可关闭 chips 整体加入/移除（`compare.addScopeItem` 三语），URL query 支持 `s<id>` 双向序列化，基准名支持范围。**移动端**：repository `serializeCompareRegionIds` 五处统一；地区弹层范围改为整体加入（存 -scope.id）+ 已加入范围 chips；`ComparisonState.calcScopes` 供概览 chips 兜底。**验证**：后端 test_comparison **16/16**（+3 例：范围列记录数>单地区、矩阵范围列并集取价、他人/不存在范围 404）；web build ✓ + i18n 双审计 ✓；移动端 analyze 0 issue、comparison+l10n 10 例过；**浏览器实测**（临时用户+「明发测试」=和县+南京市）：概览出「明发测试」卡（734 条/428 种商品，指数 116.4 vs 湖滨区 100）、矩阵「茭白 湖滨区 6.98 vs 明发测试 4.99」、热力图正常。分支：master `32500551` → 合入 feat；移动端 feat `ae5c74fe`。详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)。
- 对比功能实测可用性修复（用户实测反馈四问题：①web 选两地区后无内容 ②web 实体下拉只有前若干个 ③移动端热力图弹层输入无反应 ④移动端按地区图表未出现 + 未适配自定义范围）：**勘察先行**——对开发库直调端点确认 regions/summary/趋势数据全部正常（候选 7 地区、指数 100/124/360），排除后端；实锤三根因 + 一项缺失。**①核心可比性**——entity-prices 卡片价原用「每标准单位价」（price/standard_quantity，与单地区综合价同口径），但**同一原料在不同地区的参与商品包装/标准单位不同**（尖椒按根 vs 按克 → 0.0 vs 0.01 元/g 完全不可比）：卡片价改 **¥/斤 归一**（`_unit_price_per_jin`，与趋势/指数/迷你图同口径），unit 固定「斤」，测试断言同步改每斤口径。**②商品搜索断链**——`/products/entity` 的搜索参数是 **search** 不是 q（原料 `/ingredients` 用 q、菜谱 `/recipes` 用 search，三者不同参！）：web CompareView 两处 + 移动端 repository.searchEntities 传错 → 商品下拉搜索恒返回同前 20 个；按实体类型传正确参数 + 初始 limit 20→50。**③移动端弹层无反应根因**——`showModalBottomSheet` 是独立 route，**拿不到外层 provider 重建**：实体/菜谱/方案三个搜索弹层拿的是打开瞬间的 options 快照，输入后结果永远不进列表；改 onSearch 返回 `Future<List<EntityOption>>`、弹层内部 setState 刷新 + 弹层内请求序号防竞态 + 空选项自动首拉。**④自定义范围适配**——web 概览地区卡加「自定义范围」v-select（`/calc-scopes` → region_ids 直接填入对比地区）；移动端地区弹层顶部加自定义范围 ActionChip 快捷项（点选直接应用 region_ids）。**⑤顺手**——web 概览手选→URL→回写同值双请求修复（queryRegionIds watch 加值比较）；CompareView 补统一导航栏（v-app-bar 汉堡+标题+CalcContextMenu，对齐 PlansView——用户反馈缺导航栏）。**验证**：后端 test_comparison 13/13 + meal_plan_region_scope 5/5；web build ✓（含导航栏）+ check:i18n ✓（compare 55 键）；移动端 analyze 0 issue、comparison+planner 19 例全过。分支：master `cbf8baff` → 合入 feat（移动端 `c0932659`）。详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)。
- 跨地区物价对比三期（热力图）：**后端** `GET /comparison/heatmap`——`mode=item`（`entity_type`+`entity_id`）：商品集合 = 原料下活跃商品 / 该商品；每 (商家,商品) 取子树内最新一条有效记录 → `record_standard_grams` 归一 ¥/斤 → 同商家按权重加权（`_weight_map`，与 latest-price-by-merchant 同口径）；`mode=overall`：篮子 = 基准地区（region_ids 第一个）近一年有记录商品（上限 50），商家对篮子加权均价 → `price_index = 价 / 全部商家价中位数 ×100`（中位数=100 自解释）。只返回营业中 + 有坐标商家（`latitude/longitude` 空不渲染）；返回 `buckets` p25/p50/p75/p90 供前端五档着色。**Web**：新 `HeatMapCanvas.vue`——**Leaflet 统一渲染**（`L.tileLayer.chinaProvider('GaoDe.Normal.Map')` / OSM 可切），circleMarker 五档色（绿→红）+ 右下角图例 + popup 商家名/价格或指数/样本数/超期；**刻意不侵入 MerchantMapView**（1204 行、五引擎 SDK/Leaflet 双分支 + 坐标转换），热力是对比页专属形态，独立组件零回归风险（代价：热力底图固定 Leaflet 系，不跟随管理端 SDK 配置——三期已知边界）。对比页 v-tabs 扩第四块「热力图」：单品/整体 toggle + 实体类型 toggle + v-autocomplete（300ms 防抖）+ 篮子说明。**移动端**：新 `features/comparison/widgets/heatmap_canvas.dart`——flutter_map 渲染（底图取 `mapConfigProvider` 默认层，与商家地图同源），Marker 圆点着色 + GestureDetector 点按弹 bottom sheet（同样不侵入 MerchantMapView，iOS 原生地图路径不涉及）；CompareScreen TabBar 扩 4 块，地区变化自动重拉（signature 比对）。**本地 handler**：heatmap 端点同步（regionSubtree 过滤 + priceNormalize ¥/斤 + 二分位算法与后端一致；商家无地区不渲染——与后端 INNER 口径对齐）。**坑**：locale 脚本 `insert_into_block` 在目标块末行是多键同行时会把新键插进后续块（heatmapEntityRequired 曾误落 localValues 且行内粘连）；`check:i18n:sources` 按行解析，粘连虽 JSON 合法仍报 missing——手工按行拆分修复，后续新增 localErrors 键需检查落点。**验证**：后端 test_comparison.py 13/13（新增单品模式/整体指数中位数=100/缺 entity_id 400 三例）；web build 57s ✓、check:i18n(+sources) ✓（compare 54 键）；移动端 analyze 0 issue、comparison 6 例 + l10n 全过（merchants 3 例 apple_map 为存量基线）。无迁移。分支：后端+web master `217e3735` → 合入 feat（merge `ae7870fb`）；移动端 feat/mobile-app `bfa5c0bb`。Mimosa scanner_enobufs 兼容放行。详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)。
- 跨地区物价对比二期（一期设计定调延续：维度切换、不新增区块）：**后端**——`meal_plan_service` 的 `evaluate_items`/`evaluate_plan`/`_evaluate_stub_items`/`plan_cost_trend` 加显式 `region_id` 参数（哨兵 `_REGION_UNSET = object()` 区分「未传（按会话/默认解析）」与「显式 None（全部地区）」——对比必须绕过会话 X-Region）；`comparison.py` 新增五端点：`GET /comparison/recipe-costs`（菜谱×地区矩阵，明细行 cost=null 即该地区缺价食材 + missing_ingredients 汇总，复用 `calculate_recipe_cost_as_of` 同一降级链）、`GET /comparison/recipe-cost-trend`、`POST /comparison/plan-evaluate-regions`（同一组条目 N 地区分别求值，**草稿/未保存方案可用**——试算详情合计卡的数据源）、`GET /comparison/plan-costs`（已存方案×地区 evaluate totals）、`GET /comparison/plan-cost-trend`。**Web**：对比页 v-tabs 扩为三块（菜谱·试算：菜谱 v-autocomplete 服务端 search 多选 + 成本矩阵 RegionPriceMatrix 加 clickableRows/row-click 点行看 `recipe-cost-trend` 多地区叠加 PriceTrendChart；方案下拉全量+客户端过滤 + 合计矩阵点行看营养对照 v-table）；菜谱分析页「按商家｜按地区」v-btn-toggle——把 `recipe-costs` 地区数据**整形为 MerchantCostCards/MerchantPriceMatrix 的商家数据形状**（merchant_id=region_id、is_recommended/is_lowest 按行内非缺失最低计算）复用组件，两组件加可选 `title` prop 换表头；试算详情合计卡「当前｜各地区对比」口径切换（对比态 v-table 每地区一行，成本最低绿色高亮；**草稿也可用**走 plan-evaluate-regions）+ 对比态趋势列**同一列位**换成 PriceTrendChart 多地区叠加（getComparisonPlanCostTrend，仅已保存方案）；本地 handler 五端点同步（复用 getRecipeCost/getCostHistoryRange/evaluateItem + regionSubtree）。**移动端**：CompareScreen TabBar 扩 3 块（菜谱 `_SimpleSearchPickerSheet` 搜索弹层多选 + 成本矩阵；方案下拉多选 + 合计矩阵；原始行→EntityPriceRow 转换 `_rowToEntity`）；试算详情合计卡 SegmentedButton 切换 + 对比态 `_RegionTotalsTable`（DataTable 横向滚动，成本最低绿加粗，条目直接由 plan['items'] 构造 PlanItemIn 形状）。**测试坑**：菜谱成本归克 `_qty_unit_to_grams` 硬编码 unit_id==3 短路视为克——内存测试库单位 id 不定，菜谱条目必须 get-or-create id=3 克单位（沿用 test_recipe_pending_cost 惯例），否则 no_quantity 全 0 成本。**验证**：后端 test_comparison.py 10/10（新增地区成本/多地区趋势/**显式 region 覆写会话 X-Region**/方案合计+走势 4 例）；web build 53s ✓、check:i18n(+sources) ✓（compare 46 键）；移动端 analyze 0 issue、comparison+planner+l10n+router+prices utils+recipes widgets 148 例全过。无迁移。分支：后端+web master `aae6e105` → 合入 feat（merge `a697ffa0`）；移动端 feat/mobile-app `f5c580b5`。Mimosa scanner_enobufs 兼容放行。详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)。
- 跨地区物价对比一期（用户需求：数据范围跨多地区时对比各地区原料/商品价格与菜谱/试算成本 + 商家物价热力图；**设计定调：全部参照「按商家」比较的既有 UI，新增能力一律以维度切换进入现有控件，不新增卡片/区块**）：**口径**（三端一致）——卡片价 = 每标准单位综合价（每商品「最近有记录日」均价 → 30 天参与上限、全超期放开 → 权重加权），趋势 = ¥/斤 前向携带加权（sparklines 同口径），物价指数 = 基准地区对「近一年有记录的共同商品篮子」单价比率中位数 ×100（偶数取中间两值均值）；每个 region_id 单独作为子树过滤（与会话 X-Region 并集语义不同）；未分配地区商家计入所有地区。**后端**：新 `/api/v1/comparison`（regions/summary/entity-prices；`_region_price_data` 每地区一次 365d 大查询 + `_basket_daily_series` 走查与 `_ingredients_sparklines_batched` 同构；entity-prices 复用 sparklines 批量函数出趋势 + `regions` 元数据回名称）；**ProductRecordResponse 补 `merchant_region_id`**（纯列值零额外查询，5 处序列化同步）——两端「按地区」趋势靠它把同一批图表记录分组，不用额外拉商家列表；无表结构变更。**Web**：`/compare` 路由 + 侧栏入口（v-tabs 概览/原料·商品，URL 同步，RegionMultiSelect 复用自定义计算范围组件）；`SimpleBarChart`（ECharts 按需注册，现无柱状图组件）；`RegionPriceMatrix`（行=实体列=地区最低价绿色加粗）；`useRegionPrices` 组合式（候选会话级缓存 + 卡片 + `buildRegionSeriesFromRecords` 与 merchantComparisonSeries 同构）；`PriceTrendChart` 泛化 `MerchantSeries.merchantId` 为序列键 + `compareLabel` prop（现有调用零改动）；原料/商品详情「商家｜地区」v-btn-toggle（候选≥2 才出现，地区卡懒加载 entity-prices）；本地模式 `handlers/comparison.ts`（regionSubtree + priceNormalize + buildWeightedAsOfDailySeries，中位数与 statistics.median 对齐）+ 本地记录回填 merchant_region_id；i18n 三语（compare 27 键 + charts.byRegion + nav/routes + localErrors 四键 + regionPrices 两键，`scripts/add-compare-i18n.py` 幂等脚本）。**移动端**：features/comparison 模块（repo/provider/CompareScreen）+ `/compare` 进宽屏 rail 第 10 项与窄屏「更多」网格；概览地区弹层多选 + 摘要卡 + 指数条形 + 篮子趋势（CostTrendChart 地区序列 + compareLabel/compareSuffixBuilder，默认路径不变）；原料·商品 RegionPriceMatrix（冻结首列横向滚动）；详情页 SegmentedButton 维度切换 + RegionPriceCardList（116px 卡同 MerchantPriceList 布局）；`price_trend.dart` 加 PriceRegionSeries/buildRegionTrendSeries；**rail 坑**：10 个 labelType:all 目的地在 800×600 溢出 48px，rail 内部含 Expanded **不能套裸滚动容器**（unbounded height 报错），修法 LayoutBuilder + `SizedBox(height: max(视口, 660))`；**gen-l10n 坑**：占位符元数据无 type 按 Object 推断，与模板 String 不一致告警，补 `"type": "String"`；顺手修 en/ar 缺 `priceNoProductFoundCreate` 元数据的存量 catalog_integrity 失败。**验证**：后端 test_comparison.py 6 例全过（指数中位数口径/矩阵含无数据地区/超期放开/加权/校验）；web build/check:i18n(+sources)/test:utils 73 ✓；移动端 analyze 0 issue，comparison 4 + prices utils + recipes widgets + router 28 + l10n = 135 例全过（AppBar 预算测试本机缺字体按既有行为跳过测量，compare spec 已加待真机验证；pubspec.lock 未被 gen-l10n 改写已还原）。**边界**：卡片价/篮子取数窗口 365 天；本地模式需先在数据维护导入地区种子。分支：后端+web master `350dc521` → 合入 feat/mobile-app（merge `49208ca1`）；移动端 feat/mobile-app `f1566862`。Mimosa 门禁 scanner_enobufs 扫不全按兼容策略放行。详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)。
- 记价搜索不到商品时新增商品闭环（用户报告：新增记价输入商品名搜不到时只能退到原料/商品页新增，只有扫码才有闭环）：调研确认**后端通路已存在**（`POST /products` 带 product_name → `_get_or_create_product`+同名原料，backend/app/api/products.py:61-92），扫码闭环模式两端现成，本改动只是推广到手动搜索无结果场景。**Web** master `b577cc1f`：PricesView disabled 预览字段改 v-alert 提示块 +「新增商品」按钮 → `goCreateProductByName()`（sessionStorage `barcode-new-product` + returnTo，与扫码同构）→ 返回 `consumeReturnedProduct` 自动选中；校验放宽为新增态「选商品或输名字其一」+ `await validate()` 判 valid（旧写法 Promise truthy 恒不拦截）；QuickFillView `#no-data` 槽加按钮 → saveDraft+returnTo，`consumeProductReturn` 增强为**优先回填草稿里同名未选中行**（保留已填价格/数量，否则死行卡死批量保存）。**移动端** feat `e94c21c4`：新增/编辑记价页搜索无结果显示「未找到「{name}」，点此新增商品」→ `context.push<ProductFormResult>('/products/new', ProductFormPrefill(name))` → 返回 `_selectProduct`（照抄扫码分支）；编辑页加 `_productSearchEdited` 标记防「初始回显误显示」（_selectedProduct 语义是「本轮重新点选」不能动）；ARB 三语 `priceNoProductFoundCreate`。**测试**：移动端 2 例 go_router 存根页测试（表单+编辑，跳转带预填、返回自动选中、初始不误显示）——表单与商品页都要走 MaterialApp.router 路由，裸 Navigator push 的页面在栈顶时 go_router push 会插到它下面；analyze 0 issue，prices 全目录 123 例全过。Web build/check:i18n/sources/test:utils 全过（顺手补缺失的 `common.edit`）。**坑**：Vuetify 3 `validate()` 返回 Promise 旧写法恒 truthy；编辑页商品名种子+_selectedProduct 初始 null 若无编辑标记卡片刚打开就误显示。**web 提交曾被 Mimosa 钩子拦截**（14 high 全为既有误报：auth.ts 本地模式哨兵 token + gitignore 内 dev-dist 生成物，与本次无关），经用户放行 `--no-verify` 提交（提交说明已注明人工复核）。详见 [FEATURE_记价搜索不到商品时新增商品闭环.md](agent_doc/FEATURE_记价搜索不到商品时新增商品闭环.md)。
- 用户自定义计算范围（多地区组合）（用户需求：住行政区划边界的用户需要组合多个地区的数据范围；新增范围=名称+多个地区（层级可混合，如一个县+一个地级市），出现在「默认计算范围」选项里，计算按选定范围）：**后端**：新表 `user_calc_scopes`（region_ids JSON）+ `users.default_calc_scope_id`（alembic `20261112_0001` + 三引擎 SQL 脚本）；默认解析优先自定义组合（去重保序 **tuple**——`recipe_service.py:45,267` 用 region_id 作 lookup_cache dict key，必须可哈希）、范围被删回退旧档位推导、不要求 users.region_id；`region_subtree_ids`/`apply_region_filter`/会话 ContextVar 接受 int|tuple|list（子树并集去重，未分配商家仍计入）；X-Region 头新增逗号分隔多 id（≤20，单 id/all 完全兼容）；`/api/v1/calc-scopes` CRUD（归属 404、去重保序、存在性校验、20 范围/50 地区上限、删除清默认引用）；`PATCH /me` 的 default_calc_scope_id 与 default_calc_scope 互斥写入。**Web**：`RegionMultiSelect.vue`（级联+添加+chips 祖先前缀）+ `CalcScopeManagerDialog.vue`；ProfileView 入口 + scopeDialog 选项 `custom:<id>`；calcContext store 增 effectiveRegionIds；client.ts 多 id join(','); CalcContextMenu 会话切换器同接。**移动端**：features/calc_scope 模块（列表/表单 FormExitGuard + RegionMultiSelectField）；路由 `/profile/calc-scopes(new|:id/edit)` 入全屏表单正则；profile 默认范围对话框追加 radio；CalcContextState.effectiveRegionIds + 拦截器注入多 id；CalcContextSheet 选中自定义时地区级联 AbsorbPointer 禁用；三语 ARB 24 组 key。验证：后端 24 新例全过 + 回归子集 41 过（1 失败 stash 对照为既有）；web build/check:i18n/test:utils 73 ✓；移动端新测 17 例过、analyze 0 issue。**坑**：`_user_to_response` 等取新字段必须 `getattr`（FakeUser 无该属性即 500）；FakeUser 与 GET /auth/me 本就不兼容（缺 is_active），删范围后验证清引用要查 DB；移动端 widget 测试里 await 拉范围后弹对话框必须 mock secure storage 通道 + 受控 dio adapter（否则挂 FakeAsync）；gen-l10n/pub 会改写 pubspec.lock 要还原；表单标题与保存按钮同文案撞 find.text 双匹配。本地模式不在范围（既有无范围通道缺口）。分支：后端+web master `c908484a` → 合入 feat（`bc1eabee`）；移动端 feat/mobile-app `7f1c4161`。**部署**：开发库需手工执行 `scripts/sql/20261112_user_calc_scopes_sqlite.sql`（users 加列 create_all 不补）后重启；Mimosa 两次提交均扫不全（scanner_enobufs/callgraph_fact_partial）按兼容策略放行，待跑完整审计。详见 [FEATURE_自定义计算范围.md](agent_doc/FEATURE_自定义计算范围.md)。




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
iOS 商家匹配按当前位置偏置（新增/占位坐标表单后台静默取一次定位；匹配偏置中心优先级：用户手设/商家既有坐标 > 当前位置 > 匹配写入坐标 > 系统默认；geolocator 静默定位失败回退原逻辑）：详见 [FEATURE_iOS商家匹配按当前位置偏置.md](agent_doc/FEATURE_iOS商家匹配按当前位置偏置.md)

### 最新修复记录
- iOS 商家匹配按当前位置偏置（用户需求：苹果地图自动匹配商家时优先按当前位置找）：新 `device_location.dart` 静默定位（服务开关→权限检查/请求→low 精度 5s 上限 `getCurrentPosition`，服务关闭/被拒/超时/异常一律 null 不弹提示；复用既有 geolocator 与 Info.plist 位置权限）；表单 `initState` 在「iOS 可用 && 坐标为空或占位值」时后台静默取一次定位（不阻塞首搜、失败整周期不重试、权限请求发生在开表单时），`_searchCenter` 偏置中心优先级：用户手设/商家既有真实坐标（编辑既有商家按其位置找，不取定位）> 设备当前位置（覆盖匹配写入坐标）> 匹配写入坐标（定位不可用回退）> 占位坐标/无坐标不偏置交给系统默认（顺手修掉占位坐标=北京默认中心当偏置的 wart）；`currentLocationResolver` 注入点免 mock geolocator 通道。新增 5 测：新增按当前位置且只取一次 / 既有商家按自身坐标 resolver 不调用 / 点选候选后仍按当前位置 / 定位不可用回退匹配坐标 / 地图选点后按选点偏置。验证：本次改动文件 analyze 0 issue（worktree 并行会话未提交 comparison 改动带 3 issue 与本次无关，stash 对照 HEAD analyze 干净）、merchant_form_match 18 例 + apple_maps_service 3 例全过。无 Swift/后端/迁移。分支 feat/mobile-app。详见 [FEATURE_iOS商家匹配按当前位置偏置.md](agent_doc/FEATURE_iOS商家匹配按当前位置偏置.md)。
- 跨地区物价对比二期（一期设计定调延续：维度切换、不新增区块）：**后端**——`meal_plan_service` 的 `evaluate_items`/`evaluate_plan`/`_evaluate_stub_items`/`plan_cost_trend` 加显式 `region_id` 参数（哨兵 `_REGION_UNSET = object()` 区分「未传（按会话/默认解析）」与「显式 None（全部地区）」——对比必须绕过会话 X-Region）；`comparison.py` 新增五端点：`GET /comparison/recipe-costs`（菜谱×地区矩阵，明细行 cost=null 即该地区缺价食材 + missing_ingredients 汇总，复用 `calculate_recipe_cost_as_of` 同一降级链）、`GET /comparison/recipe-cost-trend`、`POST /comparison/plan-evaluate-regions`（同一组条目 N 地区分别求值，**草稿/未保存方案可用**——试算详情合计卡的数据源）、`GET /comparison/plan-costs`（已存方案×地区 evaluate totals）、`GET /comparison/plan-cost-trend`。**Web**：对比页 v-tabs 扩为三块（菜谱·试算：菜谱 v-autocomplete 服务端 search 多选 + 成本矩阵 RegionPriceMatrix 加 clickableRows/row-click 点行看 `recipe-cost-trend` 多地区叠加 PriceTrendChart；方案下拉全量+客户端过滤 + 合计矩阵点行看营养对照 v-table）；菜谱分析页「按商家｜按地区」v-btn-toggle——把 `recipe-costs` 地区数据**整形为 MerchantCostCards/MerchantPriceMatrix 的商家数据形状**（merchant_id=region_id、is_recommended/is_lowest 按行内非缺失最低计算）复用组件，两组件加可选 `title` prop 换表头；试算详情合计卡「当前｜各地区对比」口径切换（对比态 v-table 每地区一行，成本最低绿色高亮；**草稿也可用**走 plan-evaluate-regions）+ 对比态趋势列**同一列位**换成 PriceTrendChart 多地区叠加（getComparisonPlanCostTrend，仅已保存方案）；本地 handler 五端点同步（复用 getRecipeCost/getCostHistoryRange/evaluateItem + regionSubtree）。**移动端**：CompareScreen TabBar 扩 3 块（菜谱 `_SimpleSearchPickerSheet` 搜索弹层多选 + 成本矩阵；方案下拉多选 + 合计矩阵；原始行→EntityPriceRow 转换 `_rowToEntity`）；试算详情合计卡 SegmentedButton 切换 + 对比态 `_RegionTotalsTable`（DataTable 横向滚动，成本最低绿加粗，条目直接由 plan['items'] 构造 PlanItemIn 形状）。**测试坑**：菜谱成本归克 `_qty_unit_to_grams` 硬编码 unit_id==3 短路视为克——内存测试库单位 id 不定，菜谱条目必须 get-or-create id=3 克单位（沿用 test_recipe_pending_cost 惯例），否则 no_quantity 全 0 成本。**验证**：后端 test_comparison.py 10/10（新增地区成本/多地区趋势/**显式 region 覆写会话 X-Region**/方案合计+走势 4 例）；web build 53s ✓、check:i18n(+sources) ✓（compare 46 键）；移动端 analyze 0 issue、comparison+planner+l10n+router+prices utils+recipes widgets 148 例全过。无迁移。分支：后端+web master `aae6e105` → 合入 feat（merge `a697ffa0`）；移动端 feat/mobile-app `f5c580b5`。Mimosa scanner_enobufs 兼容放行。详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)。
- 跨地区物价对比一期（用户需求：数据范围跨多地区时对比各地区原料/商品价格与菜谱/试算成本 + 商家物价热力图；**设计定调：全部参照「按商家」比较的既有 UI，新增能力一律以维度切换进入现有控件，不新增卡片/区块**）：**口径**（三端一致）——卡片价 = 每标准单位综合价（每商品「最近有记录日」均价 → 30 天参与上限、全超期放开 → 权重加权），趋势 = ¥/斤 前向携带加权（sparklines 同口径），物价指数 = 基准地区对「近一年有记录的共同商品篮子」单价比率中位数 ×100（偶数取中间两值均值）；每个 region_id 单独作为子树过滤（与会话 X-Region 并集语义不同）；未分配地区商家计入所有地区。**后端**：新 `/api/v1/comparison`（regions/summary/entity-prices；`_region_price_data` 每地区一次 365d 大查询 + `_basket_daily_series` 走查与 `_ingredients_sparklines_batched` 同构；entity-prices 复用 sparklines 批量函数出趋势 + `regions` 元数据回名称）；**ProductRecordResponse 补 `merchant_region_id`**（纯列值零额外查询，5 处序列化同步）——两端「按地区」趋势靠它把同一批图表记录分组，不用额外拉商家列表；无表结构变更。**Web**：`/compare` 路由 + 侧栏入口（v-tabs 概览/原料·商品，URL 同步，RegionMultiSelect 复用自定义计算范围组件）；`SimpleBarChart`（ECharts 按需注册，现无柱状图组件）；`RegionPriceMatrix`（行=实体列=地区最低价绿色加粗）；`useRegionPrices` 组合式（候选会话级缓存 + 卡片 + `buildRegionSeriesFromRecords` 与 merchantComparisonSeries 同构）；`PriceTrendChart` 泛化 `MerchantSeries.merchantId` 为序列键 + `compareLabel` prop（现有调用零改动）；原料/商品详情「商家｜地区」v-btn-toggle（候选≥2 才出现，地区卡懒加载 entity-prices）；本地模式 `handlers/comparison.ts`（regionSubtree + priceNormalize + buildWeightedAsOfDailySeries，中位数与 statistics.median 对齐）+ 本地记录回填 merchant_region_id；i18n 三语（compare 27 键 + charts.byRegion + nav/routes + localErrors 四键 + regionPrices 两键，`scripts/add-compare-i18n.py` 幂等脚本）。**移动端**：features/comparison 模块（repo/provider/CompareScreen）+ `/compare` 进宽屏 rail 第 10 项与窄屏「更多」网格；概览地区弹层多选 + 摘要卡 + 指数条形 + 篮子趋势（CostTrendChart 地区序列 + compareLabel/compareSuffixBuilder，默认路径不变）；原料·商品 RegionPriceMatrix（冻结首列横向滚动）；详情页 SegmentedButton 维度切换 + RegionPriceCardList（116px 卡同 MerchantPriceList 布局）；`price_trend.dart` 加 PriceRegionSeries/buildRegionTrendSeries；**rail 坑**：10 个 labelType:all 目的地在 800×600 溢出 48px，rail 内部含 Expanded **不能套裸滚动容器**（unbounded height 报错），修法 LayoutBuilder + `SizedBox(height: max(视口, 660))`；**gen-l10n 坑**：占位符元数据无 type 按 Object 推断，与模板 String 不一致告警，补 `"type": "String"`；顺手修 en/ar 缺 `priceNoProductFoundCreate` 元数据的存量 catalog_integrity 失败。**验证**：后端 test_comparison.py 6 例全过（指数中位数口径/矩阵含无数据地区/超期放开/加权/校验）；web build/check:i18n(+sources)/test:utils 73 ✓；移动端 analyze 0 issue，comparison 4 + prices utils + recipes widgets + router 28 + l10n = 135 例全过（AppBar 预算测试本机缺字体按既有行为跳过测量，compare spec 已加待真机验证；pubspec.lock 未被 gen-l10n 改写已还原）。**边界**：卡片价/篮子取数窗口 365 天；本地模式需先在数据维护导入地区种子。分支：后端+web master `350dc521` → 合入 feat/mobile-app（merge `49208ca1`）；移动端 feat/mobile-app `f1566862`。Mimosa 门禁 scanner_enobufs 扫不全按兼容策略放行。详见 [FEATURE_跨地区物价对比.md](agent_doc/FEATURE_跨地区物价对比.md)。
- iOS Apple Maps 商家定位匹配（用户需求：iOS 用苹果地图 SDK 按商家名称/地址获得坐标与行政区划，使 iOS 不再依赖各地图 API；填名称→候选点选后官方名称补全名称字段+带出地址/坐标/区划、填地址带出坐标+区划、名称/地址显式点选直接写入（空串不写）、坐标/区划只填空字段/占位值、占位坐标不算已有；名称写入为真机反馈修正——首版名称不回写不符合同类搜索选择惯例）：**原生**——`AppDelegate.swift` 文件内新增 `AppleMapsPlugin`（沿用 AppShortcutsPlugin 模式，免改 pbxproj；新建 .swift 需手动加进 pbxproj 四处，本工程未开文件系统同步组），通道 `com.a4ding.livecalc/apple_maps`：`searchPlaces`（MKLocalSearch，center 偏置 50km，prefix 10，新请求 cancel 旧请求，MKErrorDomain 整域静默——MapKit 无公开取消 case；MKMapItem 无 subtitle/地址属性，address 由 CLPlacemark 组件省→市→区→街道门牌拼接）+ `reverseGeocode`（CLGeocoder 无公开 locale API 结果语言随设备、新请求前 cancelGeocode 旧请求，CLError.Code.geocodeCanceled 静默）。**Dart 服务**（`core/services/apple_maps_service.dart`）：`ApplePlace.fromChannel` 对 countryCode==CN/缺失统一 gcj02ToWgs84（境外自动恒等，与 picker `_appleNeedsGcj02` 同口径待真机定标）；`isAvailable` 默认 Platform.isIOS、构造参数 `available:` 可覆写；逆编码入参先 wgs84ToGcj02 转回 MapKit 基准；失败全静默。**区划匹配**（`features/merchants/services/region_matcher.dart`，纯客户端）：国家按 `iso_country` 精确锚定（兜底中英文名）→ 省市县逐级 listRegions 下钻，每级先精确后剥后缀归一（特别行政区/自治区/盟/省/市/县/区/旗循环剥双侧同规则）再前缀比较；唯一子节点单链穿透（市辖区）最多两层；市/区两级共用 locality+subLocality 候选；返回最深命中（失配停市级）。**表单接线**：名称/地址 onChanged → 300ms 防抖+请求序号（价格表单同款）→ 字段下方候选列表（`_buildAppleCandidates`，**不用 Autocomplete** 避开焦点重现/IME 回声坑）→ 点选：名称流显式写入官方名称/官方地址（空串不写防清空，名称写入为真机反馈修正）；坐标/区划只填空字段/占位值/**上次匹配写入的值**（`_coordinateFromMatch`/`_regionFromMatch` 标记，连续点选可换分店；占位=null/(0,0)/默认中心 39.9042,116.4074，`isPlaceholderCoordinate` 与 `kMapDefaultCenter` 常量）；地址流永不回写地址；**点选后地图相机居中到该点**（选点组件 didUpdateWidget 用 `_lastEmitted` 区分内外部来源，仅外部来源动画，避免重置用户缩放；Apple animateCamera / flutter_map MapController.move+postFrame+try）；选点逆编码 iOS 走原生+回退后端高德（选点语义保留区划跟随点）。`RegionSelectField` 补传 `repository: widget.repository`（测试可注入）。i18n 三语 `appleMapsMatches`。**测试** 25 例：服务 9（mock 通道+CN 折算+GCJ02 偏移断言用 **abs**——偏移方向随位置可正可负）/ 匹配 11 / 表单 5（假服务+MockRepo，RegionSelectField 与 matcher 共用同一 mock 才能断言级联落位）。验证：analyze 0 issue；全量 859 过/13 失败=既有基线（price_record_form_sheet 6、apple_map 3、locale 2、my_proposals 1、home_summary 1），新测全过；iOS CI 编译通过（GitHub Actions Mac runner Xcode 26.6，build-ios job success @ `35d8d641`，历经 6 轮：缺 import→错误枚举改名/CLGeocoder 无 locale→MKError 无取消 case+weak self 解包→?? 双重可选→MKMapItem 无 subtitle，坑见下）。**坑**：新建 .swift 文件必须登记 pbxproj（PBXBuildFile/PBXFileReference/group children/Sources 四处）否则 iOS 不编译；往 AppDelegate.swift 加 MapKit/CoreLocation 代码必须补 `import MapKit` + `import CoreLocation`（原文件仅 Flutter/UIKit，CI 首跑满屏 cannot find in scope）；**MKError.Code 没有公开的 cancelled case**（CI 三轮实证，取消判断改按 MKErrorDomain 整域静默；CLError.Code.geocodeCanceled 拼写则有效）；**escaping 闭包里 weak self 必须 self?. 显式解包**、非 escaping 闭包（如 .map）允许隐式 self——但闭包内前面的类型错误会压制后续检查，报错点会漂移（CI 四轮实证）；**`(opt?.array ?? []).链式` 会把 `?? []` 推断成双重可选**（`[T]??` no member 'prefix'），要先落独立语句再链式调用（CI 四轮实证）；**CLGeocoder 没有 locale 属性**（误记，结果语言跟随设备语言，国家匹配走 isoCountryCode 不受影响）；**MKMapItem 没有 subtitle/address 属性**（文本属性仅 name/phoneNumber；格式化地址官方路径 placemark.postalAddress+CNPostalAddressFormatter，本项目用 CLPlacemark 组件拼接+subThoroughfare）；gen-l10n 后 pubspec.lock 本次未被改写（sha1 复核）。**待办**：真机定标 MKLocalSearch 中国区坐标基准与 POI 命中率（Windows 无法验证 iOS，Mac VM 构建链路见 BUILD_iOS 文档）；MKLocalSearch 结果语言跟随设备语言无法强制中文（en/ar 设备中文区划匹配可能停在省级，属平台限制）。无后端/迁移。分支：feat/mobile-app `293833d9`。详见 [FEATURE_iOS_AppleMaps商家定位匹配.md](agent_doc/FEATURE_iOS_AppleMaps商家定位匹配.md)。
- 记价搜索不到商品时新增商品闭环（用户报告：新增记价输入商品名搜不到时只能退到原料/商品页新增，只有扫码才有闭环）：调研确认**后端通路已存在**（`POST /products` 带 product_name → `_get_or_create_product`+同名原料，backend/app/api/products.py:61-92），扫码闭环模式两端现成，本改动只是推广到手动搜索无结果场景。**Web** master `b577cc1f`：PricesView disabled 预览字段改 v-alert 提示块 +「新增商品」按钮 → `goCreateProductByName()`（sessionStorage `barcode-new-product` + returnTo，与扫码同构）→ 返回 `consumeReturnedProduct` 自动选中；校验放宽为新增态「选商品或输名字其一」+ `await validate()` 判 valid（旧写法 Promise truthy 恒不拦截）；QuickFillView `#no-data` 槽加按钮 → saveDraft+returnTo，`consumeProductReturn` 增强为**优先回填草稿里同名未选中行**（保留已填价格/数量，否则死行卡死批量保存）。**移动端** feat `e94c21c4`：新增/编辑记价页搜索无结果显示「未找到「{name}」，点此新增商品」→ `context.push<ProductFormResult>('/products/new', ProductFormPrefill(name))` → 返回 `_selectProduct`（照抄扫码分支）；编辑页加 `_productSearchEdited` 标记防「初始回显误显示」（_selectedProduct 语义是「本轮重新点选」不能动）；ARB 三语 `priceNoProductFoundCreate`。**测试**：移动端 2 例 go_router 存根页测试（表单+编辑，跳转带预填、返回自动选中、初始不误显示）——表单与商品页都要走 MaterialApp.router 路由，裸 Navigator push 的页面在栈顶时 go_router push 会插到它下面；analyze 0 issue，prices 全目录 123 例全过。Web build/check:i18n/sources/test:utils 全过（顺手补缺失的 `common.edit`）。**坑**：Vuetify 3 `validate()` 返回 Promise 旧写法恒 truthy；编辑页商品名种子+_selectedProduct 初始 null 若无编辑标记卡片刚打开就误显示。**web 提交曾被 Mimosa 钩子拦截**（14 high 全为既有误报：auth.ts 本地模式哨兵 token + gitignore 内 dev-dist 生成物，与本次无关），经用户放行 `--no-verify` 提交（提交说明已注明人工复核）。详见 [FEATURE_记价搜索不到商品时新增商品闭环.md](agent_doc/FEATURE_记价搜索不到商品时新增商品闭环.md)。
- 用户自定义计算范围（多地区组合）（用户需求：住行政区划边界的用户需要组合多个地区的数据范围；新增范围=名称+多个地区（层级可混合，如一个县+一个地级市），出现在「默认计算范围」选项里，计算按选定范围）：**后端**：新表 `user_calc_scopes`（region_ids JSON）+ `users.default_calc_scope_id`（alembic `20261112_0001` + 三引擎 SQL 脚本）；默认解析优先自定义组合（去重保序 **tuple**——`recipe_service.py:45,267` 用 region_id 作 lookup_cache dict key，必须可哈希）、范围被删回退旧档位推导、不要求 users.region_id；`region_subtree_ids`/`apply_region_filter`/会话 ContextVar 接受 int|tuple|list（子树并集去重，未分配商家仍计入）；X-Region 头新增逗号分隔多 id（≤20，单 id/all 完全兼容）；`/api/v1/calc-scopes` CRUD（归属 404、去重保序、存在性校验、20 范围/50 地区上限、删除清默认引用）；`PATCH /me` 的 default_calc_scope_id 与 default_calc_scope 互斥写入。**Web**：`RegionMultiSelect.vue`（级联+添加+chips 祖先前缀）+ `CalcScopeManagerDialog.vue`；ProfileView 入口 + scopeDialog 选项 `custom:<id>`；calcContext store 增 effectiveRegionIds；client.ts 多 id join(','); CalcContextMenu 会话切换器同接。**移动端**：features/calc_scope 模块（列表/表单 FormExitGuard + RegionMultiSelectField）；路由 `/profile/calc-scopes(new|:id/edit)` 入全屏表单正则；profile 默认范围对话框追加 radio；CalcContextState.effectiveRegionIds + 拦截器注入多 id；CalcContextSheet 选中自定义时地区级联 AbsorbPointer 禁用；三语 ARB 24 组 key。验证：后端 24 新例全过 + 回归子集 41 过（1 失败 stash 对照为既有）；web build/check:i18n/test:utils 73 ✓；移动端新测 17 例过、analyze 0 issue。**坑**：`_user_to_response` 等取新字段必须 `getattr`（FakeUser 无该属性即 500）；FakeUser 与 GET /auth/me 本就不兼容（缺 is_active），删范围后验证清引用要查 DB；移动端 widget 测试里 await 拉范围后弹对话框必须 mock secure storage 通道 + 受控 dio adapter（否则挂 FakeAsync）；gen-l10n/pub 会改写 pubspec.lock 要还原；表单标题与保存按钮同文案撞 find.text 双匹配。本地模式不在范围（既有无范围通道缺口）。分支：后端+web master `c908484a` → 合入 feat（`bc1eabee`）；移动端 feat/mobile-app `7f1c4161`。**部署**：开发库需手工执行 `scripts/sql/20261112_user_calc_scopes_sqlite.sql`（users 加列 create_all 不补）后重启；Mimosa 两次提交均扫不全（scanner_enobufs/callgraph_fact_partial）按兼容策略放行，待跑完整审计。详见 [FEATURE_自定义计算范围.md](agent_doc/FEATURE_自定义计算范围.md)。
- 试算成本不随数据范围变化（用户报告：数据范围从全部缩回城市后，试算成本不随范围变；线上复现 + 菜谱成本端点对拍确认 X-Region 机制完好）：`meal_plan_service` 全文无地区处理——recipe/ingredient 项调 `calculate_recipe_cost` / `get_weighted_ingredient_price`（都支持 region_id）不传、product 项手写最新记录查询、`plan_cost_trend` 四处（含散项 has_record）同样漏。修复：`_evaluate_stub_items` 与 `plan_cost_trend` 入口 `resolve_region_param(db, user, None)`（会话 X-Region 优先、其次用户默认计算范围），三条链路 + 走势 + has_record 全部透传/套 `apply_region_filter`；解析放 service 汇合点使 `/meals` 推荐打分一并生效。回归 `test_meal_plan_region_scope.py` 5 例（商品/原料/菜谱 × 城市A/B/全部 + 用户默认范围 + 空子树走势归零）。**坑**：`tests/services` 与 `tests/api` 的同名 `test_meal_recommendation_route.py` 同批会让 pytest 静默 collected 0，只能分开跑；composer 测试批次失败为共享内存库既有顺序干扰（stash 基线同样失败）。验证：新测 5 过 + meal_plans 子集 29 过 + 价格/地区/菜谱子集 32 过；开发库只读复核黄焖鸡米饭 all=14.81 / 三门峡=15.41 / 南京=15.36。web/移动端服务端模式零改动（两端拦截器已注入 X-Region）；本地模式整体无范围通道属既有缺口未处理。无迁移。分支：master `78a265cf` → 合入 feat/mobile-app；外部环境待部署复核。详见 [BUGFIX_试算成本不随数据范围变化.md](agent_doc/BUGFIX_试算成本不随数据范围变化.md)。
- 表单体验四项 + 营养默认单位（用户报告/要求）：①新增商品开启「新增对应原料」时，关联原料里已输入但**未匹配到已有原料**的文字自动带入新原料名称（已匹配则不复制）——web `ProductsView` 的 `watch(createNewIngredient)` 先读 `ingredientSearch` 再清 `selectedIngredient`；移动端 `_setCreateNewIngredient` 先记文本与 `_selectedIngredient` 再清搜索框，仅未匹配且新原料名称为空时写入。②新增/编辑原料、商品、菜谱、商家、方案页隐藏底栏 tab（宽屏隐藏 NavigationRail），避免误触切走丢失未保存内容（返回键仍有 FormExitGuard）：`app_router.dart` 新增 `_isFullScreenFormRoute`（`/xxx/new` 精确 + `/xxx/:id/edit` 正则）。③移动端价格记录选中商家后 `FocusManager.instance.primaryFocus?.unfocus()`（新增/编辑/快速填写三处）——Autocomplete 选中只收面板不释放焦点，去扫码/选日期回来会随焦点恢复重新弹出（「商家下拉一直显示」）。④营养默认单位：除能量（随偏好）与蛋白质/脂肪/饱和脂肪/反式脂肪/碳水化合物/糖/膳食纤维（g）外统一 mg——web `nutrientDefinitions.ts` 删逐项 `DEFAULT_UNIT_BY_KEY` 改 `defaultUnitForNutrientKey()`（动态 USDA 键复用），单位候选 mg 优先、空行首次选营养素套默认；移动端 `defaultNutrientUnit` 兜底 `g→mg` + `_nutrientOptions` 补/前置 mg。验证：web build ✓、test:utils 73 ✓；移动端 analyze 0 issue，新增 7 例（自动带入 2 / 隐藏底栏 2 / 商家焦点 1 / 营养默认 2），相关子集 61 全过；全量 774 通过 / 14 失败均为存量（同 HEAD stash 对照：price_record_form_sheet 6、apple_map 3、locale 2、my_proposals 1、home_summary 1、缺字体 1）。无后端/迁移。分支：web master；移动端 feat/mobile-app，master 改动合入 feat。详见 [FEATURE_表单体验与营养默认单位.md](agent_doc/FEATURE_表单体验与营养默认单位.md)。
- 试算原料条目营养为空（用户报告：一顿饭选了火腿肠（原料，2 根），试算合计没有它的脂肪；外部环境复现，同数据走商品条目正常）：`meal_plan_service._item_cost_nutrition` ingredient 分支手读 `nutrition_data` **首行** + 手工换算克数——火腿肠原料自己没有 nutrition_data 行（营养挂在关联商品的自定义营养上，详情页靠 `NutritionCalculator` 的商品加权平均回填展示），且数量单位「根」的克重经 `EntityUnitOverride`（商品换算链）→ 旧路径两条链都断 → 条目 `nutrition: null`、营养来源明细缺失、fat 合计只剩其他三项。修复：营养整体换成与详情页同源的 `NutritionCalculator.calculate_ingredient_nutrition(ingredient.id, quantity, unit_abbr)`（best 行 custom>USDA>verified + 缺项商品加权平均回填每 100 g 归一 + 数量/基准走同一 `_convert_to_base` 实体换算链），返回 `all_nutrients` 已按请求量缩放（键=显示名附 `original_key`），逐条归一成 `nutrient_values`（能量经 `energy_to_kcal`）后同源导出条目四项/totals/明细；成本链不动，recipe/product 分支不动。回归 `tests/services/test_meal_plan_product_unit.py` 新增 2 例（无/有自有营养行 × 根计数 + EntityUnitOverride，断言 fat_g=24/20 与明细 fat 贡献）。**坑**：手建质量单位必须 `si_factor=0.001`（kg 口径）；内存测试库无 kg 单位，`_get_piece_weight_kg` 需要 `get_unit_by_abbr("kg")`——新增 `_ensure_kg_unit` get-or-create（存在不删，避撞 `unit.abbreviation` 唯一约束）。验证：该文件 7/7 过；相关子集（meal_plans_api/models、meal_recommendation_items、ai_policy）与 stash 基线一致（`test_daily_recommendation_has_items_not_recipe_id` 在该批量组合下基线也挂，共享内存库互相干扰的既有现象，单跑即过）。无迁移。分支：master → 合入 feat/mobile-app；外部环境待部署复核。详见 [BUGFIX_试算原料营养为空火腿肠脂肪.md](agent_doc/BUGFIX_试算原料营养为空火腿肠脂肪.md)。
- 试算新增/编辑态隐藏「设为今日」（用户报告：试算保存按钮容易与「设为今日」按钮搞混；新增、编辑时不应显示）：「设为今日」只保留在非编辑入口——web `PlansView.vue` 列表行（含一顿方案餐次菜单）与移动端列表行、移动端详情页 ⋮ 菜单。Web `PlanDetailView.vue`（页面始终是新增/编辑态）整块移除 app-bar 的设为今日（一顿餐次 v-menu + 一日直按按钮），连带清理死代码 `settingToday`/`mealTypeOptions`/`onSetToday`/`setPlanAsRecommendation` import（PlansView 仍在用该 API，i18n key 不动）；移动端 `planner_screens.dart` 试算新建/编辑页 AppBar 删「设为今日」IconButton（原紧挨保存图标）+ 私有 `_setToday`。验证：web build ✓、check:i18n ✓；移动端 analyze 无新增、planner 相关测试全过；`app_bar_title_budget_test` 的 `planner_form` spec 同步 icons 3→2（本机缺 simhei/arial，预算测量按既有环境失败跳过，stash 对照与本次无关）。分支：web master；移动端 feat/mobile-app。详见 [FEATURE_试算新增编辑隐藏设为今日.md](agent_doc/FEATURE_试算新增编辑隐藏设为今日.md)。


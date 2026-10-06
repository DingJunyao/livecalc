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

### 最新修复记录
- 商家商品价陈旧沉底（stale_last 参数化）+ 菜谱价格提示合并 info 图标 + 移动端对齐（用户反馈：商家详情页商品价格一个月内有更新的放前面、灰显放后面；菜谱价格超期 tooltip 不明显，应与计算来源链一样带 info 按钮、两者可共用合并 tooltip；移动端 app 也要做）：后端 [/merchants/{id}/product-prices](backend/app/api/merchants.py) 新增 `stale_last` 参数（默认 false）——开启时 ORDER BY 首键 `is_stale ASC`（SQL 内 `(l.recorded_at < :stale_cutoff)` 计算，cutoff 用 SQLite TEXT 同格式字符串比较，PG/MySQL 下同字面量兼容 timestamp 列），`is_stale` 字段任何模式都返回；**快速填写页共用该端点，不传参保持用户上次填写顺序**（web QuickFillView 与 mobile quick_fill_screen 均未传参，行为不变）。web [MerchantDetail.vue](frontend/src/views/merchants/MerchantDetail.vue) 传 `stale_last=true`、灰显改用后端 is_stale 字段（前端不再自算阈值）；本地模式 [merchants.ts](frontend/src/api/local/handlers/merchants.ts) 同步参数化排序与字段。菜谱食材提示：web [RecipeIngredientCard.vue](frontend/src/components/recipes/RecipeIngredientCard.vue) 计算来源链与价格超期共用一个 info 图标、tooltip 两段合并（孤立的价格超期 tooltip 已移除）；移动端 [recipe_detail_screen.dart](mobile/lib/features/recipes/screens/recipe_detail_screen.dart) 同样合并（Tooltip message + 点击弹窗 `_showPriceInfo`），[recipe_repository.dart](mobile/lib/features/recipes/repositories/recipe_repository.dart) `CostBreakdownItem` 解析 `price_recorded_at` 并提供 `isPriceStale`（>30 天）；移动端商家详情 [merchant_detail_screen.dart](mobile/lib/features/merchants/screens/merchant_detail_screen.dart) 整行 `Opacity 0.5` 置灰、[merchant_product_price.dart](mobile/lib/features/merchants/models/merchant_product_price.dart) 解析 is_stale、[merchant_repository.dart](mobile/lib/features/merchants/repositories/merchant_repository.dart) 加 `staleLast` 参数（仅商家详情两处调用传 true）、l10n 新增 `recipePriceStaleTooltip`（zh/en/ar + gen-l10n）。验证：后端 py_compile、test_merchant_price_stale 4/4、SQL 双分支语法/行为脚本验证（内存库插新旧记录断言排序与 is_stale）；flutter analyze 0 issue、全量 flutter test 通过（4 个平台跳过为存量）；前端 vite build 通过。master 提交 32577d9、5a5ded5，feat/mobile-app 提交 b160943（merge 92249ed/8988331）。**经验：①web 与 app 共用的列表端点加排序要参数化，否则会静默改变快速填写页等隐含依赖方的顺序语义；②text() 原生 SQL 的 datetime 绑定参数在 SQLite 驱动下不可靠，用与存储格式一致的字符串（PG/MySQL 也能与 timestamp 列直接比较）；③商家详情测试用 FakeNotifier 覆写 load，未触达 repository mock，新增具名参数不必补 mocktail 匹配。**

- 价格图表与迷你图按真实日期分布 + 久未更新价格提示（用户反馈：商品/原料价格图表每天记录点等距、应随天数变化，迷你图同样；商家详情页超一个月未更新的记录加灰显；菜谱食材价格超一个月未更新时价格处 tooltip 提示更新时间）：ECharts 侧 [PriceTrendChart.vue](frontend/src/components/charts/PriceTrendChart.vue) X 轴 category→time（系列数据 [本地午夜时间戳, 值]，axisLabel/axisPointer formatter 接 timestamp，tooltip 仍用 params[2].dataIndex 回查），菜谱分析页 [CostTrendAnalysis.vue](frontend/src/components/recipes/CostTrendAnalysis.vue) 堆叠/回退两图同步改造；sparkline 后端 [sparklines.py](backend/app/api/sparklines.py) 商品/原料/菜谱三端点改为按本地日历日前向填充（`_forward_fill_daily`：每天一格、无记录日沿用前值、从首个有值日填到今天，久未更新呈长平尾），API 仍返回 number[] → 移动端零改动自动受益，本地模式 handler 与原料详情关联商品迷你图用共享 [sparkline.ts](frontend/src/utils/sparkline.ts) `buildDailySparklineSeries` 对齐；商家详情页 [MerchantDetail.vue](frontend/src/views/merchants/MerchantDetail.vue) 移动/桌面两种列表加 `price-record-stale` 置灰（[priceStaleness.ts](frontend/src/utils/priceStaleness.ts) `isRecordedAtStale` 30 天，与后端 `MERCHANT_PRICE_STALE_DAYS` 一致）；菜谱 /cost 明细新增 `price_recorded_at`（[recipe_service.py](backend/app/services/recipe_service.py) 新增 `_latest_price_recorded_at` 按 direct→fallback→name_match 链取实际计价记录集最新 recorded_at，`include_price_dates` 开关仅 /cost 端点开启避免批量路径开销；制作菜谱/子食材聚合推导价不标注），[RecipeIngredientCard.vue](frontend/src/components/recipes/RecipeIngredientCard.vue) 超 30 天时价格处 v-tooltip（三语言 `recipes.priceStaleTooltip`）。验证：vite build 通过（master 与 feat 分支各一次）、check:i18n 通过、py_compile + import OK、目标测试 6/7（1 个 HEAD 复跑确认为存量失败）。master 提交 951a7fa，feat/mobile-app merge fd8fe3a。**经验：①sparkline 等距的根因是后端只返回"有记录的日"序列 + 前端等距绘制，后端按日历日前向填充即可让 v-sparkline/移动端零改动获得时间分布；②ECharts time 轴时间戳必须按本地午夜解析（'YYYY-MM-DD' 裸字符串被 JS 按 UTC 解析，UTC 负时区下回显日期会漂移一天）；③tooltip formatter 的 params[i].dataIndex 在 time 轴下仍对应构造系列用的原数组索引；④vue-tsc 与项目 TS 版本不兼容直接崩溃（Search string not found），类型验证以 vite build + check:i18n 为准。**

- Flutter 构建警告清理（用户反馈：`flutter build apk` 报 package_info_plus 应用 KGP 的弃用警告；GitHub Action build-ios 报 actions node20 弃用）：迁移到 Flutter 3.44+ 的 Built-in Kotlin——[settings.gradle.kts](mobile/android/settings.gradle.kts) 与 [app/build.gradle.kts](mobile/android/app/build.gradle.kts) 移除 `org.jetbrains.kotlin.android` 声明和手动 `kotlin { jvmTarget }` 块（jvmTarget 由内置 Kotlin 自动设置），Java compileOptions 从 17 升到 21 对齐内置 Kotlin 默认 JVM Target（否则报 Inconsistent JVM Target Compatibility）；[pubspec.yaml](mobile/pubspec.yaml) 用 dependency_overrides 将传递依赖 package_info_plus 升到 ^10.2.2（10.2.0+ 支持内置 Kotlin），因 10.x 需 win32 ^6，同步把 flutter_secure_storage 从 ^9 升到 ^11.2.0（9.x 锁 win32 ^5）；[build-ios.yml](.github/workflows/build-ios.yml) checkout/upload-artifact v4→v5。验证：analyze 0 issue、debug APK 构建成功且 KGP 警告消失。feat/mobile-app 提交 5e8b0d5。**经验：①内置 Kotlin 默认 JVM Target 21，app 侧手写 Java 17 会与 compileDebugKotlin(21) 冲突；②内置 Kotlin 版本（当前 2.2.10）由 Flutter SDK 决定，"Kotlin 2.2.10 即将弃用"警告升级 Flutter 即可，应用侧无法配置；③flutter test 失败要先用 stash 在 HEAD 复跑确认是否为存量失败——本分支 locale format_locale、apple_map GCJ02 等 4-6 个失败为存量问题，与依赖升级无关。**
- 原料层级关系删除后仍显示修复（用户反馈：DELETE /ingredients/hierarchy/131 提示成功但列表还在）：DELETE 走治理执行器是**软删**（`is_active=False`，行仍在库），但层级关系的全部查询侧均未过滤 `is_active`，导致删除"成功"后 GET 仍返回。补齐查询侧过滤：[ingredient_hierarchy.py](backend/app/api/ingredient_hierarchy.py)（GET 关系 4 处 + create 同名查重，避免删后无法重建）、[ingredient_extended.py](backend/app/api/ingredient_extended.py)、[nutrition.py](backend/app/api/nutrition.py) 回退链、[recipes.py](backend/app/api/recipes.py) 回退链预加载、[recipe_service.py](backend/app/services/recipe_service.py) 回退/替代关系、[lookup_cache.py](backend/app/services/lookup_cache.py) `hierarchy_all`、[ingredient_matcher.py](backend/app/services/ingredient_matcher.py) 6 处、[ingredient_merger.py](backend/app/services/ingredient_merger.py) 合并去重、[models/mixins/__init__.py](backend/app/models/mixins/__init__.py)。**经验：软删字段在 AuditMixin 上，DELETE 端点提示"成功"不代表行为可见，接入软删时必须同步审计全部查询侧过滤；master 与 feat/mobile-app 分属不同 worktree（D:/code/live_calc 与 D:/code/live_calc.worktrees/master），跨分支带改动切换须走 stash。**已软删的 id=131 无需手动清理（不可见且可 revert 复活）。
- 移动端商家最新价显示记录日期并弱化陈旧记录（对齐 master dfbcc30 的 is_stale 后端字段；接手了一段来源不明的中断遗留工作树改动）：[merchant_price.dart](mobile/lib/shared/models/merchant_price.dart) 补 `isStale` 解析；[merchant_price_list.dart](mobile/lib/shared/widgets/merchant_price_list.dart) 卡片显示记录日期、陈旧记录半透明置灰 + outline 色 sparkline、不参与最低价徽标（防御复查 `isLowest && !isStale`）；修复遗留的 formatMoney 歧义导入（`app_formatters.dart hide formatMoney`，与 currency_fmt 重名）。**经验：本机（树莓派 arm64）Flutter SDK 此前装在 /tmp/flutter 已被清理，现已 git clone stable 至 `~/flutter`（官方无 arm64 Linux tar 包，clone 方式可用，Dart SDK arm64 自动下载），`mobile/android/local.properties` 的 flutter.sdk 指向 `~/flutter`；pub get 需带 `PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 否则 pubspec.lock 的镜像 URL 被改写；flutter 3.47 每次 pub get 会自动给 analysis_options.yaml 补排除段（工具行为，保留即可）。**验证：analyze 0 issue、全量 flutter test 通过（4 个平台相关跳过）。feat/mobile-app 提交 a9888b2
- 价格计算与图表查询性能优化（用户反馈：菜谱价格计算、菜谱/原料/商品图表特别慢、经常超时；实测根因是 90 天趋势逐天全量重算 + 无缓存重复查询，单菜谱 90 天趋势 5 万+ SQL/30s+）：新增请求级只读缓存 [lookup_cache.py](backend/app/services/lookup_cache.py)（挂 db.info，before_flush 自动失效，覆盖单位/override/密度/商品/层级/半成品反查/通用 memoize）；[price_region.py](backend/app/services/price_region.py) 地区子树缓存；[recipe_service.py](backend/app/services/recipe_service.py) 价格记录时间轴索引（`_price_timeline_index`：每商品/名称一次全量载入后内存选锚点，前向填充语义不变）+ 与 as_of 无关的结果缓存（回退链/份重/权重/币种）+ 消除 direct 层与 fallback 链的重复取数 + `Recipe`/`Ingredient` 查询改 db.get；[sparklines.py](backend/app/api/sparklines.py) 商品/原料 sparkline 批量化（一次 IN 查询内存分组）；`product_records` 补 `(product_id, recorded_at)` 复合索引（模型 + alembic 20261004_0001 + scripts/sql 三份脚本 + [main.py](backend/app/main.py) 启动幂等 `_ensure_price_query_indexes`）。**等价性验证：14 菜谱 × 2 region × 90 天共 28 次趋势计算，改造前后数值 JSON sha256 逐字节相同（零差异）；性能 886.4s/769,898 SQL → 4.6s/1,509 SQL（约 193 倍），单菜谱带 region 90 天 30s+ → 0.46s，sparkline 60 商品 0.30s → 0.01s。**详见 [PERF_价格计算与图表查询性能优化.md](agent_doc/PERF_价格计算与图表查询性能优化.md)
- iOS 本地未签名构建环境修复（本机直接 xcodebuild 报 `Module 'apple_maps_flutter' not found`，CI 正常）：项目 iOS 端为 SwiftPM+CocoaPods 混合，`apple_maps_flutter`/`flutter_secure_storage` 不支持 SPM 走 Pods，CI 靠 `flutter build ios --config-only`（内含 pod install）+ runner 预装 CocoaPods；本机无 pod 且跳过了 config-only 直接 xcodebuild。本机为 Intel VM，brew 无 x86_64 bottle（装 cocoapods 触发 llvm/rust 源码编译链，已中断并清理残留锁），系统 Ruby 2.6 在 Xcode 26 SDK 下缺头文件装不了原生扩展 → 改用 Homebrew 自带 portable-ruby 4.0.7 将 CocoaPods 1.17.0 装至 `~/.gem/pod-ruby`，经 wrapper `~/.local/bin/pod` 暴露（`.zshrc` 已有 `~/.local/bin` PATH）。此后按 CI 同步骤（pub get → build_runner → config-only → xcodebuild → Payload/zip）构建成功，产物 `mobile/build/ios/derived/Build/Products/Release-iphoneos/Runner.ipa`（未签名，AltServer 重签）。详见 [BUILD_iOS本地未签名构建与CocoaPods环境.md](agent_doc/BUILD_iOS本地未签名构建与CocoaPods环境.md)

- 移动端地图缩放/海外定位/记忆商家币种与 100g 单位修复（用户反馈：iOS 地图无法手动缩放；印尼定位偏移；新增价格记录复用记忆商家时币种仍为默认；需新增 100 g 且覆盖 web）：iOS AppleMap 嵌滚动容器时补充 `EagerGestureRecognizer`，商家地图与选点地图均可赢得 pinch 手势；移动端 WGS84↔GCJ02 仅在中国区域转换，雅加达等境外坐标原样使用 WGS84，Android 高德/腾讯瓦片同样受益；新增价格记录会话记忆商家初始化/异步回填时同步商家默认币种，手动改币种后不被覆盖；后端启动幂等补齐 `100g` 质量单位（si_factor=0.1）、UnitMatcher 支持 `100 g→100g`，web 本地 seed/backfill 与全部价格单位 fallback、商品/原料详情单位列表、移动端记录单位均补齐。`flutter analyze` 0 issue、全量 `flutter test` 432/432、前端构建通过、后端目标测试 2/2 与 py_compile 通过、diff check 通过。详见 [BUGFIX_移动端地图缩放海外定位价格币种与100g单位.md](agent_doc/BUGFIX_移动端地图缩放海外定位价格币种与100g单位.md)
- 币种/地区表述统一与用户信息编辑补齐（用户反馈：app 商家地区四下拉无竖向间距；app 用户信息编辑不完整；网页/app 币种列表应为「名称 代码」、选中后显示三字母；地区表述「国家/地区、省份、城市、区县」与「省级/地级/县级」需统一）：App [region_select_field.dart](mobile/lib/shared/widgets/region_select_field.dart) 级联下拉补 12px 竖向间距；[edit_account_screen.dart](mobile/lib/features/auth/screens/edit_account_screen.dart) 补齐「所在地区」四级级联 + 「修改密码（可选）」（sha256 提交 `PUT /auth/me/account`、改密沿用新 token），[user.dart](mobile/lib/features/auth/models/user.dart) 加 `regionId`；App 商家表单默认币种下拉展开「名称 代码」/收起三字母（`selectedItemBuilder`），个人中心币种列表改「名称 代码」、计算范围表述改省份/城市/区县；Web 商家表单两处（[MerchantsView.vue](frontend/src/views/data/MerchantsView.vue)/[MerchantDetail.vue](frontend/src/views/merchants/MerchantDetail.vue)）与个人中心默认币种 `v-select`/`v-autocomplete` 用 `#item`+`#selection` 插槽双显示，[ProfileView.vue](frontend/src/views/profile/ProfileView.vue) 地区标签/副标题/scopeOptions 与 [DataMaintenanceView.vue](frontend/src/views/admin/DataMaintenanceView.vue) chips 统一表述。验证：analyze 0 issue、全量 flutter test 426/426、前端构建通过。feat/mobile-app 提交 b5137e7、master 提交 3f20bc9（已合入）。经验：testWidgets 里 Dio 请求会**挂起**（AuthInterceptor 的 secure storage 平台通道无 mock 永不完成），需 mock `plugins.it_nomads.com/flutter_secure_storage` 通道 + 自定义 `HttpClientAdapter` 抛错走兜底。详见 [BUGFIX_币种地区表述统一与用户信息编辑补齐.md](agent_doc/BUGFIX_币种地区表述统一与用户信息编辑补齐.md)
- 商家列表筛选增加「显示其他地区的商家」（用户反馈：app 商家列表筛选没有该开关，web 有）：[merchant_list_screen.dart](mobile/lib/features/merchants/screens/merchant_list_screen.dart) 筛选底栏新增 SwitchListTile（副标题「含全部地区，不受计算范围限制」），列表与地图坐标请求均透传 `include_other_regions`（后端 `/merchants`、`/merchants/coordinates` 已支持）；[merchant_provider.dart](mobile/lib/features/merchants/providers/merchant_provider.dart) state/applyFilters/activeFilterCount/load 透传，[merchant_repository.dart](mobile/lib/features/merchants/repositories/merchant_repository.dart) search/getAllCoordinates 加参数；底栏控件增多矮屏溢出 → `isScrollControlled: true` + `SingleChildScrollView`（真实小屏 UX 修复）；收藏模式走客户端过滤（region 依赖后端子树计算，与 web 一致）。feat/mobile-app 提交 3820046。验证：analyze 0 issue、全量 419/419（新增开关保持 + include_other_regions=true 透传用例）。经验：mocktail `when` 未注册具名参数用方法默认值精确匹配，新增可选参数后必须补 `any(named: ...)`。详见 [BUGFIX_商家列表筛选显示其他地区.md](agent_doc/BUGFIX_商家列表筛选显示其他地区.md)

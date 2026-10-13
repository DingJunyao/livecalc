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

### 最新修复记录
- 商品「关联原料」星号与必填口径统一（用户反馈：商品管理基本信息里「关联原料」后面有星号，怀疑它和输入框必填项没区分开）：**根因**：这个星号不是 Vuetify 的必填标记——Vuetify 3.7 的 VTextField/VAutocomplete/VLabel 根本不处理 `required` prop（模板里成堆的 `required` 只是摆设），而是写死在翻译文案里 `products.linkedIngredient = "关联原料 *"`；于是①商品详情「基本信息」**只读列表**也显示「关联原料 *」（不是表单却带必填星号）②同一表单里真正必填的「商品名称」（DB `products.name`/`ingredient_id` 均 NOT NULL）反而没有星号。**修复**：`linkedIngredient` 去掉星号只用于只读展示（详情只读列表、待审提议字段标签），新增 `linkedIngredientRequired`/`nameRequired`（「关联原料 *」「商品名称 *」，三语）用于商品新增对话框与详情基本信息编辑表单；顺带把 feat 已有而 master 缺失的 `prices.units.hundredGrams` 带回 master（web 4 处在用）。**经验：①Vuetify 3 的 `required` 不显示星号，必填标记要么走 i18n 文案约定、要么统一走 rules，不能指望 prop；②同一个 i18n key 同时服务「只读展示」和「表单 label」时，改文案先 grep 全部消费点；③web 的标签星号约定已与移动端对齐（mobile 搜索类 label 带 `*`、展示类不带）。**
- 商品详情价格趋势「区间」改按记录口径（用户反馈：最新价格卡片区间 2.99-4.18，趋势图 tooltip 区间却是 3.78-3.78，同页两个区间对不上）：**根因**：商品详情趋势图与原料/后端迷你图共用 `buildWeightedAsOfDailySeries`，其 min/max 语义是「参与商品的价区间」；单商品视图里商品只有 1 个 → 当日多条记录先折成当日均价 → min=max=avg=3.7833，置信带退化成线；而卡片区间口径是「最近一次记录日的记录价 min/max（2.99/4.18）」。**修复**：`buildWeightedAsOfDailySeries` 加 opt-in `bandFromRecords`（区间按当日全部记录价 min/max，无记录日 as-of 沿用最近一次记录日区间；avg/count 语义不变，默认关闭，不影响原料详情/后端迷你图），商品详情 `chartData` 打开该开关。验证：`npm run test:utils` 18/18（新增开关开/关 2 用例）、真实数据复算（区间 2.99-4.18、avg 3.7833 携带到今天）、`npm run build` 通过。**经验：①同一个「区间」在不同粒度视图里语义不同——原料视图是「商品间」，商品视图必须是「记录间」，共享工具只能默认其一，opt-in 开关比让调用方自行重算安全；②「卡片与图表对不上」先把两处数字的口径各写成一句话再动代码；③置信带在只有 1 个聚合对象时必然退化成线，做图时要意识到。**
- 商品详情「最新价格」未按地区口径过滤（用户反馈：空心菜 277 卡片最新价 16.67 元/斤，但区间 2.99-4.18 元/斤；切「全部地区」才发现南京商家 10 元/3 把 = 16.67 元/斤的记录，湖滨区范围内没有）：**根因**：`GET /products/entity/{id}`（get_product）是商品/价格端点里唯一没接地区口径的——同文件 latest-price、latest-price-by-merchant 都走 `resolve_region_param + apply_region_filter`，同页面的价格记录列表、趋势图也按 `X-Region`/用户默认计算范围过滤，唯独详情端点查全表 → 卡片永远取全局最新一天；10 元/3 把经 piece_weight 折 0.6 斤 = 16.67 元/斤，正是被过滤掉的南京记录（2026-07-29），范围内最新一天是 2026-06-17（2.99/4.18/4.18 → 3.78 元/斤）。**修复**：get_product 补 `region_id` 参数并 `resolve_region_param`（会话 X-Region 优先），「取最新日期」与「最新一天记录」两处查询套 `apply_region_filter`，均价/单位折算/时区口径不变。验证：真实库直调（不过滤 16.667/07-29 → 市级·县级 3.7833/06-17）；新增 [test_product_detail_region_price.py](backend/tests/test_product_detail_region_price.py)（X-Region 市/县 → 3.0，无覆盖 → 10.0）通过，tests/api + entity 相关 72 项通过。**经验：①同页面多张卡片的地区口径必须由同一入口（resolve_region_param）落地，新端点漏接一层就会出现「卡片之间对不上」；②前端 `params: { region_id: null }` 会被 axios 丢弃，真正生效的是拦截器注入的 `X-Region` 头，排查地区问题先确认头有没有到端点；③本地模式 handler 支持 region_id ≠ 真的收到了它——`createLocalApi` 只透传 params，calc-context 不会自动进 query，本地模式地区过滤整体未接（另议）。**
- 价格趋势图「区间内无新记录则空白」修复（用户反馈：原料、商品价格趋势默认「月」，近一个月没有更新时图表空白显示「暂无价格历史数据」，切到有数据的区间再切回来又有图表；移动端同样）：**根因**：图表按 as-of 口径（每商品最近一次价向前携带 + 30 天参与上限、全超期放开）绘制，但取数按 `start_date` 下发（`/products?ingredient_id&start_date=...`），区间内没有记录时连「携带起点」都拿不到 → 序列为空；切到更宽区间后记录进了累积池，再切回窄区间由 PriceTrendChart 本地切片就正常——症状与用户描述完全对应。**修复**：①新增共享判断 [priceAsOf.ts](frontend/src/utils/priceAsOf.ts) `shouldLoadFullPriceHistory`（区间命中 0 条且池为空 → 回退「全量」），两个 web 详情页抽出 `fetchChartPriceRecords` 并接入；②[ProductDetail.vue](frontend/src/views/products/ProductDetail.vue) 图表口径从「按自然日分桶（只画有记录的日子）」改为逐日 as-of（与原料/后端同源），卡片「区间/记录数」改由 `latestRecordStats`（最近一次记录日）提供，不再从图表尾点推导；③移动端 [price_trend.dart](mobile/lib/features/prices/utils/price_trend.dart) 同步 as-of（`startDay`/`endDay`/`staleDays` 可注入、各商品等权），两个 provider `_loadChart` 区间取数为空时回退全量并用 `startDay` 截断序列。验收（真实库 + 运行中的后端 + 复算月视图切片）：原料 473 / 商品 142 近 30 天 0 条、全量 6/12 条 → 修复前 0 点，修复后 30 点且尾值 = 最近一次已知价（2.90 / 3.135）。验证：`npm run test:utils` 16/16、vite build 通过；`flutter analyze` 0 issue、`price_trend_test` 6/6、全量 flutter test 576 项 6 项存量失败（apple_map×3、locale_preferences×2、my_proposals×1）。详见 [BUGFIX_价格趋势区间无记录空白.md](agent_doc/BUGFIX_价格趋势区间无记录空白.md)。**经验：①「按区间取数」与「as-of 向前携带」天然冲突——携带依赖区间之前的记录，取数必须能覆盖到最近一次记录；②同一指标多端多处实现时，口径要连「取数」一起对齐，只对齐「计算」照样空白；③测试要覆盖「区间内没有任何记录」这一分支，否则只能等用户反馈。**
- Mobile search dropdown IME debounce fix: 300ms debounce + request sequence for product linked ingredient, blacklist, price product, paste import, ingredient merge, and recipe ingredient searches; fixed ReorderableListView onReorder compile blocker. See agent_doc/BUGFIX_mobile_search_ime_debounce.md. Verified: flutter analyze 0 issues, targeted widget tests pass, full flutter test 566 with 6 pre-existing failures (apple_map x3, locale_preferences x2, my_proposals x1), npm run build passes.
- （修订上一条）综合价「30 天上限 + 全部超期放开」并同步到菜谱成本（用户反馈：①原料 120「玉米」下所有商品更新时间都在 30 天前，页面直接显示不出价格 → 应放开；②菜谱成本也要套 30 天上限，同样全部超期时放宽）：新增共享 `ingredient_price_service.apply_stale_participation`（`fresh` 非空则剔除超期者，以空记录 + `meta.exclude_reason="stale"` 交给 `_aggregate_weighted`；`fresh` 为空则全部放开并返回 `relaxed=True`），接入 ①`get_weighted_ingredient_price`（菜谱成本 as_of/recent 统一，结果加 `stale_relaxed`）②`nutrition.get_ingredient_latest_price`（响应加 `stale_relaxed`）③`sparklines._ingredients_sparklines_batched`（逐日：新鲜集为空用全集）④前端 [priceAsOf.ts](frontend/src/utils/priceAsOf.ts)（每日 fresh/all 双累加，fresh 为空取 all，点带 `relaxed`）⑤本地模式 [nutrition.ts](frontend/src/api/local/handlers/nutrition.ts)。卡片在 `stale_relaxed` 时提示「商品价格均超过 30 天未更新，按各自最近一次已知价计算」（l10n 三语 `ingredients.staleRelaxed`）。**踩坑**：`apply_stale_participation` 直接用 `as_of_date`（可能 aware）比 naive `recorded_at` → `TypeError` 被端点吞成 500，`/recipes/{id}/cost` 全挂，已加 `_naive_utc` 统一后再比（as_of 由调用方传入时不可假定 naive）。实测：胡萝卜 0.98（relaxed=false，水果胡萝卜 stale）、玉米 10.67（relaxed=true，两商品最新记录 6-13/7-29）。验证：后端改/增 6 用例（成本口径 stale 排除 + 全超期放开、sparkline 放开、接口三场景）目标集 36 通过（4 个 `KeyError: access_token` 为存量登录夹具问题，feat 基线同现）；`test:utils` 15/15；vite build、check:i18n 通过。master 与本要点同批提交、随后 merge 到 feat/mobile-app。**经验：①「参与上限」这类过滤必须配「全被过滤掉」的兜底，否则数据整体陈旧时页面直接空白——过滤规则要成对设计；②同一规则要在所有口径落地（接口/迷你图/趋势图/成本/本地模式），漏一处就是新的「对不上」；③跨模块传 datetime 先统一 tz 再比较，aware/naive 相减的 `TypeError` 会被端点 try/except 吞成 500，只有跑成本类测试才会暴露。**
- 原料综合价加「30 天参与上限」（用户反馈：卡片 2.52 与图表 0.98/区间 0.79~1.18 完全对不上——图表数据按区间加载看不到 8 周前的水果胡萝卜，而接口把每商品最近价无限期携带；卡片区间/商品数又从图表尾点推导，平均值落在自己显示的区间外）：**规则**：参与综合价（综合最新价 / 原料 sparkline / 趋势图 avg 线 / 本地模式）的商品，最近一次价格须落在 `INGREDIENT_PRICE_STALE_DAYS=30` 天内，超期进 `excluded`（`reason=stale`，l10n「超期未更新（>30 天）」）；30 天对齐商家价（MERCHANT_PRICE_STALE_DAYS）与菜谱价格提示的陈旧口径。**改动**：`_aggregate_weighted` 支持 `meta.exclude_reason`；sparkline as-of 步进按「最近记录日+30 天」过期；前端 [priceAsOf.ts](frontend/src/utils/priceAsOf.ts) `buildWeightedAsOfDailySeries` 加 `staleDays`（默认 30，导出 `PRICE_STALE_DAYS`）、周视图取数自动放宽到 30 天（显示范围仍按所选区间切片）；卡片「区间/商品数」改取接口 `participants`（不再从图表尾点推导）。胡萝卜实测：综合最新价 0.98（胡萝卜 1.18 + 泥胡萝卜 0.788；水果胡萝卜 stale），sparkline 尾值 0.98 与卡片一致。**注意**：菜谱成本（mode=as_of）仍按「最近一次已知价」不套 30 天上限，与综合价存在已知口径差异（成本=按已知信息计价 vs 综合价=近 30 天在售代表价），是否同步另议。验证：后端用例改 3 个（60 天 stale 排除 / 29 天参与 / 权重 0 排除）+ sparkline 过期用例，目标集 26/27（1 失败为存量 i18n 断言）；`priceAsOf.test.ts` 6/6；vite build、check:i18n 通过。master 提交 bfd6cf6c，feat/mobile-app merge 0d082163。详见 [FEATURE_商品加权价格机制.md](agent_doc/FEATURE_商品加权价格机制.md) 补遗修订。**经验：①「同一数字多处展示」时所有展示位必须同源——卡片区间/商品数从图表尾点推导就是反例；②跨数据源聚合（接口全量 vs 前端区间加载）的参与者集合必须由显式规则（如 30 天上限）决定，不能依赖加载窗口；③「无限期向前携带」在多商品加权场景等于让陈旧高价永久主导综合价，携带必须配过期；④真实数据上线后第一件事是把各展示位数字对拍，对不上就是口径没对齐。**
- 原料「综合价」口径三处统一为「每商品最近价 as-of 加权」（用户反馈：原料胡萝卜下三个商品，综合最新价与价格趋势图只反映最新一笔泥胡萝卜的价格，应为三个商品加权）：**根因**：①`GET /nutrition/ingredients/{id}/latest-price` 仍保留最初实现的「先取全局最近 24h 滚动窗口、窗口为空才回退到全局最新一天」记录挑选逻辑——只要有任一商品在窗口内被记录，其余商品整段不参与加权（胡萝卜实测 ¥0.79/斤，而菜谱成本对同一原料算 ¥2.52/斤，差 3.2 倍）；设计意图的实现（`ingredient_price_service._collect_recent_records` + `mode="recent"`：每商品各自「最近有记录日」）早已写好但**全仓库零调用**（死代码）；②前端趋势图按自然日分桶、只让「当天有记录的商品」参与加权，没有把其他商品的最近价向前携带（胡萝卜近 30 天 10 个点里 8 个是单品价、水果胡萝卜整段消失）。**改法**：接口改「每商品取各自最近有记录日均价 → 按 price_weight（用户覆盖>全局>50）加权」，participants/excluded/mode 完整返回、latest_date 取参与者最新记录时间、商品查询补 `is_active`；`/sparklines/ingredients` 改逐日 as-of 加权（新增 `_fetch_carry_forward_seeds` 取窗口前最近一次记录作携带起点，序列=窗口起点→今天一格一天）；前端原料趋势图 avg 线新增共享工具 [priceAsOf.ts](frontend/src/utils/priceAsOf.ts) `buildWeightedAsOfDailySeries`（min/max/count 改为参与加权的商品价区间/商品数，[PriceTrendChart.vue](frontend/src/components/charts/PriceTrendChart.vue) 加 `countLabel`，卡片「记录数」→「商品数」，l10n 三语 `charts.productCount`）；本地模式 [nutrition.ts](frontend/src/api/local/handlers/nutrition.ts) `getLatestPrice`（原「全部历史记录平均」）与 [sparklines.ts](frontend/src/api/local/handlers/sparklines.ts) 对齐；移动端复用同端点零改动。**顺带修复两处存量**：③`_fetch_recent_records` 漏选 `standard_unit_id`（c55206a1 体积语义重构引入）→ `_unit_price_per_jin → record_standard_grams` 取列 AttributeError，被端点 try/except 吞成 500，`/sparklines/products|ingredients` 整体不可用（前端静默无迷你图）；④`_collect_recent_records`/`_price_timeline_index` 未过滤 `ProductRecord.is_active`，已软删的价格记录仍在参与成本/趋势日聚合。验证：后端新增 4 用例（三商品等权 2.00／60 天前记录仍参与／权重 0 排除／迷你图携带与 500 回归）12/12 通过，全量 pytest 50 失败经同 worktree 对照确认为存量 + 4 例沙箱内写 `backend/data/agent_mcp_config.json` 受限导致（非本次改动）；vite build（master 与 feat 各一次）、`npm run test:utils`（13/13）、check:i18n 通过。master 提交 ac9b400a，feat/mobile-app merge 5a18f9b9。详见 [FEATURE_商品加权价格机制.md](agent_doc/FEATURE_商品加权价格机制.md) 补遗。**经验：①同一指标存在多条计算路径时（接口内联逻辑／service 死代码／成本路径／前端自算／本地模式），必须按「该指标对用户承诺的语义」逐条对齐，接口内联的老分支最容易漏；②「最近 N 小时／最新一天」这类窗口口径会让数值随墙上时钟漂移、随记录顺序跳变，价格聚合应统一为 as-of（每商品最近价向前携带）；③软删字段必须审计所有取数路径——列表过滤了不代表成本/趋势过滤了；④`db.query(A.b, A.c)` 投影 Row 漏选字段不报错，直到 `row.字段` 被访问才 AttributeError，且被端点 try/except 吞成 500：这类「静默失败」要有端点级冒烟测试。**
- 体积语义相关四处存量问题清理（用户要求：上次自定义单位体积语义功能记录的存量问题也要改）：①/nutrition 单品接口 `_convert_to_base` 加 ingredient_id 实体上下文走 UnitConversionService（体积经密度链、count 经覆盖/piece_weight、支持体积语义覆盖），计数单位无单件重量数据时归 0（与 recipe_service 营养口径一致，原按"1单位=1克"→基准的 1%）；②废弃密度存储清理：recipe_service 营养 ml 分支改走 entity_densities 链（原查废弃 ingredient_densities 表、按 1.0 g/mL 兜底），ingredients.density 废弃列停止导出/导入回填/更新写路径/8 处 API 回显（列保留标记废弃，物理删列未做）；③ingredient_extended 旧换算端点原调用不存在的 convert_volume_to_weight/convert_weight_to_volume 命中即 500，改走统一 convert 入口 + ingredient_name 解析实体上下文，不可换算 400；④历史体积标准记录（standard_unit 为 ml）并入 ¥/斤：新增共享 record_standard_grams（price_aggregator，体积经密度折克、异常 1 g/mL 兜底）接入 recompute_summary/sparklines/nutrition 三处批量 sparkline（SQL 补选 standard_unit_id）/products_entity/merchants 共 5 个归一点。新增 6 测试共 12/12 通过；全量 pytest 30 失败经独立 worktree 挂 HEAD + 软链 dev DB 跑可疑子集对照全部定责为存量。master 提交 c55206a。**经验：①ingredient_price_service 是"元/标准单位"语义（下游二次转克），不在 ¥/斤 归一修复之列——改归一口径前先分清哪些消费方是终态口径哪些是中间态；②lookup_cache.unit_by_abbr 是精确匹配，"ml" 不命中缩写 "mL" 的行，跨 abbr 调 convert 一律走 unit_id 或用共享 helper；③后台对照任务的 git stash 会收走工作树改动、与主会话编辑并发冲突，基线对照一律用 git worktree 挂 HEAD + 软链 dev DB（.env 拷贝、data 软链），用完 worktree remove --force。**
- 自定义单位体积语义（用户反馈：自定义单位以克记录，牛奶/酱油一瓶的数值是体积，应支持定义质量还是体积；密度不易记录甚至靠 AI 填充）：**方案**：复用 entity_unit_overrides 已有 weight_unit_id 列（此前被所有消费方默认当克），允许指向体积单位（1瓶=500mL），折算质量经实体密度（entity_densities 链：自身>关联原料>水 1000 兜底），零表结构变更、存量数据行为不变。后端 [unit_conversion_service.py](backend/app/services/unit_conversion_service.py) 新增 `_convert_override_weight`（覆盖换算同类型 si、跨类型体积↔质量密度桥接）+ `_get_piece_weight_kg` 体积分支；[recipe_service.py](backend/app/services/recipe_service.py) 菜谱营养 count 分支体积覆盖经 convert 密度折克（原逻辑静默 ratio=0）；覆盖执行器校验 weight_unit_id 须 mass/volume。web 商品/原料详情单位表单加类型切换（质量 g/体积 mL）+ 生效密度折算提示行 + 列表 ≈g 展示（商品页补拉关联原料密度保证提示准确），密度对话框加常见液体预设 chips（水/牛奶/食用油/酱油/蜂蜜），审核端 [EntityUnitOverrideDiff.vue](frontend/src/components/proposals/EntityUnitOverrideDiff.vue) 用单位缩写替代裸 id；本地模式 [unitConverter.ts](frontend/src/api/local/business/unitConverter.ts) 共享 `resolveOverrideGramsPerUnit`（体积 wu 经密度、无密度水兜底、wu 解析 name 优先）统一接入 priceNormalize/costCalculator。l10n 三语 16 键。消费点全景与存量问题（/nutrition 单品接口 count 按 1 克、废弃 ingredient_densities、ingredient_extended 500、商家列表体积直出）见 [FEATURE_自定义单位体积语义与密度折算.md](agent_doc/FEATURE_自定义单位体积语义与密度折算.md)。验证：后端新增 [test_volume_weight_override.py](backend/tests/services/test_volume_weight_override.py) 6 用例（密度 515g/水兜底 500g/商品回退 257.5g/piece_weight 体积分支/质量回归/营养 278.1kcal），vite build + check:i18n 通过。master 提交 f4b4bc2，移动端 feat/mobile-app 提交 4c15d9e。**经验：①两端共享语义字段扩展前必须 grep 全部消费点——weight_unit_id 有 6 处各自独立实现（换算核心/count 兜底/价格聚合/成本/营养/审核 diff），漏一处即静默错数；②营养 count 分支 ratio=0 静默归零比错数更隐蔽，语义改动要改前改后数值对照；③本地模式三处独立实现对 weight 单位解析口径不一（si≤0.1 启发式 vs name 优先），统一 name 优先与后端字面读 id 一致。**

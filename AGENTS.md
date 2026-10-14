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
新增商品页内置「自定义单位 / 营养信息」（端内按钮 + 草稿 + 负数 id 拓扑落库，web 对话框 / 移动端整页）：详见 [FEATURE_新增商品页自定义单位与营养信息.md](agent_doc/FEATURE_新增商品页自定义单位与营养信息.md)
移动端搜索下拉防抖（商品关联原料 / 黑名单 / 价格商品 / 粘贴导入 / 原料合并 / 菜谱原料，300ms + 请求序号）：详见 [BUGFIX_mobile_search_ime_debounce.md](agent_doc/BUGFIX_mobile_search_ime_debounce.md)

### 最新修复记录
- 新增商品页内置「自定义单位 / 营养信息」（用户要求：新增商品时在同一个页面（移动端整页 / Web 对话框）给两个按钮进入对应编辑界面，填好后保存商品时才一并保存，不必先建商品再回头补录）：**根因/约束**：单位覆盖与营养都挂在商品 id 上（`POST /entities/product/{id}/units`、`POST /nutrition/products/{id}/nutrition`），新增时商品还不存在，`POST /products/entity` 也不接受这两类字段 —— 现有编辑器全依赖 `route.params.id`，无法复用；**方案**：编辑器改为「草稿只写本地数组」，商品创建成功拿到 id 后统一落库。**Web**：新增纯函数 [productDraftPlan.ts](frontend/src/utils/productDraftPlan.ts)（负数 id = 同批草稿、正数 = 关联原料单位；`planDraftUnitWrites` 拓扑分批 + 环检测、`draftChainReaches` 下拉防环、`draftUnitAmounts` 复用 `unitFactor.overrideAmounts`）与 [productDrafts.ts](frontend/src/utils/productDrafts.ts)（`persistProductDrafts` 按批 POST → 再 POST 营养，失败收成结构化 issue 不抛出；`buildDraftNotices` 翻译成提示），新增 [ProductDraftUnitsDialog.vue](frontend/src/components/products/ProductDraftUnitsDialog.vue) / [ProductDraftNutritionDialog.vue](frontend/src/components/products/ProductDraftNutritionDialog.vue)，在 [ProductsView.vue](frontend/src/views/data/ProductsView.vue) 与 [IngredientDetail.vue](frontend/src/views/ingredients/IngredientDetail.vue) 的**新增态**对话框接入（按钮带计数、`v-model:units/nutrients` 上提，关闭不丢草稿），三语各加 17 个 `products.draft*`/`deleteUnit`/`deleteNutrient` 键。**移动端**：新增 [draft_units.dart](mobile/lib/shared/utils/draft_units.dart)（同口径纯函数 + `removeDraftUnit` 删行清引用）、[entity_units_draft_screen.dart](mobile/lib/shared/screens/entity_units_draft_screen.dart)（草稿整页，`onChanged` 即时回写表单）、[product_draft_persist.dart](mobile/lib/features/products/services/product_draft_persist.dart)，把 `_UnitEditPage` 公开为 `EntityUnitEditPage`、`_unitDetailLine` 公开为 `entityUnitDetailLine`，`NutritionEditScreen` 新增 `allowUsda`（草稿态关掉 —— USDA 匹配直写服务端会打 `entityId=0`），[product_form_screen.dart](mobile/lib/features/products/screens/product_form_screen.dart) 新增两行入口 + 保存后落库并弹提示，三语 ARB 各加 11 键并 `flutter gen-l10n`。**验证**：Web `build` + `check:i18n` + `check:i18n:sources` + `test:utils` 35 通过；实机（Edge + 真实后端）确认两个按钮与提示渲染、进入单位草稿页添加「盒 = 220 g」后列表显示 `1盒 = 220 g`、关闭后按钮变「自定义单位（1）」（本会话桌面工具无法把合成点击送进 Vuetify 模态层，改 Tab/Enter 键盘驱动；未保存，未污染开发库）；移动端 `flutter analyze` 0 issue、`flutter test` 633 通过 6 存量失败（apple_map×3、locale_preferences×2、my_proposals×1，与基线一致）、`flutter test` 新增 3 例产品表单草稿用例通过；存量 `product_form_screen_test.dart` 别名用例因表单变长需 `ensureVisible` 后再点（非功能回归）。详见 [FEATURE_新增商品页自定义单位与营养信息.md](agent_doc/FEATURE_新增商品页自定义单位与营养信息.md)。**经验：①「商品创建成功」与「附加数据保存成功」是两个失败域——附加数据失败要逐条提示、不能回滚或报整单失败，否则用户会重复创建；②嵌套结构在「先编辑后落库」下必须拓扑分批 + id 映射，否则顺序错或把环发出去；③普通用户走提议分流时后端只回 `id=0` 占位骨架，依赖它的嵌套单位要显式跳过并提示；④任何「直写服务端」的侧路（USDA 匹配）都必须给开关，草稿态实体 id 还不存在。**
- VS Code 打不开 Flutter 运行调试（用户反馈：VS Code 里选中 launch.json 的 Flutter 配置起不来，终端 flutter run -d windows 同样起不来）：**复现**：用 VS Code 实际使用的 SDK（C:\opt\flutter_ori 3.44.8）跑 `flutter build windows --debug` → 107ms 报「generator : Visual Studio 17 2022 Does not match the generator used previously: Visual Studio 18 2026 / Unable to generate build files」；删掉 mobile/build/windows 后推进到 C++ 编译再报 flutter_secure_storage_windows 的「error C1083: 无法打开包括文件 atlstr.h」；带 VCToolsVersion=14.44.35207 重跑 94.7s 通过并产出 debug exe。**根因**：①mobile/build/windows/x64/CMakeCache.txt（2026-08-10）是用 "Visual Studio 18 2026"（C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools，MSVC 14.51）生成的，而现在 SDK 检测到的是 "Visual Studio 17 2022"（VS 2022 Community）→ CMake 拒绝在同一 build 目录换生成器，构建秒挂、调试会话连编译都进不去；②Flutter 生成的工程是 PlatformToolset=v143，MSBuild 按 Microsoft.VCToolsVersion.v143.default.txt 解析出 14.38.33130，而该工具集目录没有 atlmfc（未装 ATL），同一个 VS 安装里 14.44.35207 才有 ATL——8 月给 VS18 的 14.51 装的 ATL 现在用不上。**修复**：①删除 mobile/build/windows 让 CMake 用 VS17 重新生成；②.vscode/settings.json 的 dart.env 增加 "VCToolsVersion": "14.44.35207"（dart.env 会注入 Dart/Flutter 扩展启动的所有进程；终端/其他 shell 同样需要该变量，或给 VS2022 Community 的 v143 工具集装 ATL 组件）。**验证**：带该变量 `flutter build windows --debug` 94.7s 成功产出 build\windows\x64\runner\Debug\livecalc_mobile.exe；pub get 对 pubspec.lock 的改动已还原，git 工作区干净。**经验：①「打不开调试」先看构建日志——Flutter 调试依赖同一次构建，构建秒挂就是起不来；②CMake 缓存把生成器写死，切 VS/工具链必须删 build/windows，否则报的 generator mismatch 会把排查带偏；③v143 的实际工具集版本看 Microsoft.VCToolsVersion.v143.default.txt，不代表 Microsoft.VCToolsVersion.default.txt；④本机两个 Flutter SDK（flutter_ori 3.44.8 / flutter_flutter 3.41.10-ohos）互相踩，叠加 dart.offline: true 使每次启动的 pub get 静默降级 186 个包并改写 pubspec.lock。**详见 [BUGFIX_VSCode_Flutter调试打不开.md](agent_doc/BUGFIX_VSCode_Flutter调试打不开.md)。
- 移动端原料搜索下拉「完整词为空、短词有结果」（用户反馈：新增商品搜「牛奶」转圈结束无下拉，删掉「奶」保留「牛」后能显示「牛奶」，可稳定复现）：**根因**：`RawAutocomplete.optionsBuilder` 在中文 IME 组合结束时会对**同文本**再次回调（`composing` 变化，text 不变）；本次回调 `shouldUpdateOptions=false`，但仍会调用 `optionsBuilder`。旧实现每次都重开 300ms 防抖请求并取消在途 Future，于是第一次回调被第二次取消、第二次又因 `shouldUpdateOptions=false` 丢弃结果 → 转圈结束但无下拉。**修复**：三个远程 `Autocomplete<Ingredient>`（`product_form_screen.dart` 关联原料、`ingredient_detail_screen.dart` 合并目标、`blacklist_screen.dart` 黑名单原料）在相同 query 请求仍在途时直接复用同一 Future，不取消重开；并补 `product_form_autocomplete_repro_test.dart` 同文本 composing 清空回归用例。**验证**：`dart analyze`（改动文件）No issues found；`flutter test` 因本机已有 `flutter run` 持有工具锁未能实跑，需用户/后续在空闲时执行。详见 [BUGFIX_移动端IME重复组合态下拉为空.md](agent_doc/BUGFIX_移动端IME重复组合态下拉为空.md)。
- 自定义单位显示「1 个 = 200 g」变成 0.2 g（用户反馈：商品 665 设置「1 个 = 200 g」，保存后页面显示「= 0.2 g」，编辑时又正常 → 存储对、只有展示算错）：**根因**：`units.si_factor` 是「换算成 SI 基本单位」的因子而非「每单位多少 g/mL」——**质量基准 kg**（g=0.001、斤=0.5、kg=1，见 `backend/app/main.py` 建表注释）、**体积基准 L**（mL=0.001、L=1，见 `unit_conversion_service.py`「体积 si_factor 换算到 SI 基本单位 L（不是 m³）」），而两个详情页的列表显示直接 `数量 × si_factor` → 200×0.001=0.2（体积路径同样差 1000 倍：220 mL 会显示 ≈0.2 g；编辑弹窗的体积提示又假设「一定是 mL」，选 L 再差 1000 倍）；**为什么漏网**：两端单测夹具都把 `siFactor` 写成 `1`（服务端不存在这种值），错误公式乘 1 恰好通过，「1 个 = 200 g」「1 盒 = 220 mL（≈226.6 g）」全绿，真实数据一上就现形。**修复**：①web 新增纯函数模块 [unitFactor.ts](frontend/src/utils/unitFactor.ts)（`gramsPerGlobalUnit` 质量 `si×1000` g / 体积 `si×密度` g——L→m³ 的 ×0.001 与 kg→g 的 ×1000 恰好抵消；`millilitersPerGlobalUnit` 体积 `si×1000`；`overrideAmounts` 递归折算一条覆盖行的 `{grams, milliliters}`，visited 防环 + 深度 8、`weight_per_unit` 缺省按 1、未设重量单位按克，与后端 `resolve_override_amount` 同口径），新增 [unitFactor.test.ts](frontend/src/utils/unitFactor.test.ts) 9 例并**把夹具改成真实 si_factor**（g/mL=0.001、kg/L=1、斤=0.5），含用户场景、kg/斤/mL/L 叶子、嵌套 12 盒→2719.2 g、环/断裂/缺 si_factor 不臆估，并接入 `npm run test:utils`（18→27）；②两个详情页改用 `overrideAmounts`（体积行显示折算后 mL 与 g、不再把「个数」当 mL 打印；嵌套行显示引用单位名并在体积叶子后补「（≈ N g）」，新增 `unitChainVolumeDisplay` 三语、删除失效的 `unitVolumeOnlyDisplay`；弹窗体积提示改 `量 × si(L) × 密度`）；③移动端 `entity_units_card.dart` 的 `_resolveUnit`/`_volumeHint` 同一处错误一并修正、夹具同改真实 siFactor。**验证**：web `build` + `check:i18n` + `check:i18n:sources` + `test:utils` **27/27**，并在实机页面复核 `localhost:5173/data/products/665` 现显示「1个 = 200 g」；移动端 `flutter analyze` 0 issue、`flutter test` 617 通过 6 存量失败。另：web 本地（离线）模式的 `api/local/business/unitConverter.ts` 本来就是正确写法，本次显示层与它对齐。详见 [BUGFIX_自定义单位显示si_factor口径.md](agent_doc/BUGFIX_自定义单位显示si_factor口径.md)。**经验：①数值列的「单位语义」必须查权威出处（后端注释 + 既有正确实现）再写公式，`si_factor` 基准是 kg/L 还是 g/mL 会让结果差 1000 倍；②测试夹具要用真实量级——夹具写 `siFactor: 1` 时错误公式乘 1 也能通过，系统性错误被整片掩盖；③同一换算散落在 6 处（两个详情页 + 移动端卡片 + 两个弹窗提示）时改一处不够，必须集中成有单测的纯函数才能收敛；④「编辑时正常、列表不对」= 存储正确、展示层算错，先查展示层别动数据。**
- 移动端价格单位下拉「选不到自定义单位」+ 单位编辑体验（用户实机六条：①自定义单位在价格记录页下拉看不到；②改商品名后价格列表要手动刷新；③单位/密度编辑希望是整页而不是对话框；④换算系数多余，DB 都填 1；⑤「量」「单位」两框高度不等、名称要叫「量」「单位」、界面上那个「单重」多余；⑥商品自定义单位时单位下拉要继承其所属原料的单位）：**根因**：①**基准列表口径不一致**——移动端把「全局单位基准」写死成 12 项常量（`g,100g,kg,斤,个,ml,L,盒,袋,瓶,罐,包`），web 现拉 `/units/`（54 项）；用开发库 767 条真实 (商品,单位) 组合全量回放：49 条用了常量外的单位，**42 条移动端缺失而 web 有**（把/条/块/颗 以及 `mL`——常量是小写 `ml`，香油/香醋/牛奶等记录永远选不回来），`桶` 这种单位管理里新增的全局单位同样不在常量里（接口/原料回退本身没问题：239/239 商品都能解析到 `ingredient_id` 并取到原料覆盖）；②后端改名已同步快照列，但客户端列表是缓存，返回时没重拉；③④⑤是交互与语义收敛；⑥商品的单位覆盖此前只能引用「同一实体」的另一条覆盖，原料上定义的「盒」没法被该原料下商品的「箱 = 12 盒」引用。**修复**：①新增 `loadGlobalUnitNames()` 现拉全量单位作基准（失败回退旧常量），新增/编辑价格页都接；行解析放宽为 `unit_name ?? name`、跳过停用行、支持 `{items}` 包裹；请求失败改为 `dart:developer` 留痕（原 `catch (_)` 会把「关联原料那一跳」的所有单位静默吞掉）；快速填写每行也按该行商品并入自定义单位（按 productId 缓存、并发 4、失败回退常量）；②商品编辑保存且名字变了时，pop 前 `priceListProvider.notifier.loadRecords()`（web 端 `PricesView` 每次进入都重拉，无需改）；③单位/密度编辑 push 整页（覆盖底部导航），保存按钮遵循全局「保存按钮位置」本地设置；④表单去掉换算系数、保存固定发 `conversion_factor: 1`，**编辑老数据时把「系数 × 量」合并进「量」预填**（列表对历史非 1 系数仍按原值乘算），所以固定为 1 不会把重量改小；⑤标签改「量」「单位」（三语），**并移除「每单位量类型」手选**（量类型改由所选单位自动推导：全局单位看 `unit_type`、自定义单位看链上叶子单位类型、未选按克；「个」「盒」这类计数单位本就不属于质量或体积，让用户先选类型是多余的。移动端本来就只有推导、无此控件，顺手删掉三个已成死键的文案），两控件等高（移动端统一 56 高 + 同 contentPadding；web 统一 `density=comfortable + persistent-hint`，先前不等高是 Vuetify 默认 density 48 vs 56），下拉默认项改为「默认（克）」；⑥后端新增 `_find_referenced_override`（允许「同实体」或「商品 → 其关联原料」），执行器校验同步放宽（文案「只能引用同一实体（…）或其关联原料的自定义单位」），两端下拉合并「本商品 + 关联原料」两条来源、同名/同 id 本商品胜出、继承项标注「继承自原料」，**防环守卫与链解析都在合并表上走**（visited + 深度 8），因此 `1箱 = 12 盒` 在「盒」属于原料时也能正确显示与保存。**验证**：后端新增继承用例（2640 mL / 无关原料被忽略 / 端点 201 与 400）相关回归 79 项通过；web `build` + `check:i18n` + `check:i18n:sources` + `test:utils` 18/18；移动端 `flutter analyze` 0 issue、`flutter test` 617 通过 6 存量失败（apple_map×3、locale_preferences×2、my_proposals×1）。详见 [BUGFIX_移动端价格单位下拉与单位编辑体验.md](agent_doc/BUGFIX_移动端价格单位下拉与单位编辑体验.md)。**经验：①「下拉选不到某单位」先分清是实体自定义单位还是全局单位——两端基准列表一个硬编码一个现拉时症状一样，且硬编码端会因大小写（`ml` vs `mL`）永远选不回自己刚存的记录，基准列表必须与数据源同源；②静默 `catch (_)` 是这类问题的最大障碍（一跳失败静默删掉整类单位、日志全无），改成「只吞请求异常 + 留痕」才能下次直接定位；③去掉界面字段前先问「它承载的信息会不会丢」——系数移除后必须把 `系数 × 量` 折进「量」再保存；④继承要三处同时支持：解析（换算链）、校验（写入口）、防环（客户端 + 服务端），少一处就表现为「能选但保存失败」或「保存了但算错」。**
- 自定义单位嵌套 + 商品改名同步 + 保存按钮位置（用户一次反馈五件事：①移动端自定义「桶」后回到价格记录页，下拉里选不到；②改商品名后价格记录里仍是旧名；③移动端单位/密度要跳整页列表、右上角「完成」一点就退出；④自定义单位应「换算系数不填默认 1」且「单个重量拆成数值 + 单位」以支持嵌套（一盒奶 220 mL、一箱奶 12 盒）；⑤保存按钮统一右上角后用不惯，Web 对话框还出现上下两个保存按钮）：**根因**：①移动端价格页单位下拉是写死的 `priceRecordUnits` 常量（Web 有 loadEntityUnits，但只查商品自身、且只追加不重建，切商品会残留）；②`product_records.product_name` 是写入时快照列，改名只改 `products.name`（开发库实测 136/3410 行已不一致）；③维护界面是整页 + AppBar「完成」pop，用户把它当保存；④单位覆盖只有 `weight_per_unit × weight_unit_id`（固定 g/mL），没有任何列能引用同一实体的另一条自定义单位；⑤`34c1fa30` 把确认按钮搬到卡片标题行、又给底部 `v-card-actions` 加 `d-none d-md-flex`（只在 md 以下隐藏）→ 桌面端两个保存按钮；移动端右上角「保存」也不合部分用户习惯。**修复**：①移动端新增 [entity_unit_names.dart](mobile/lib/shared/utils/entity_unit_names.dart)（合并商品 + 关联原料的自定义单位，当前值不在列表时补到最前，防 DropdownButton 断言），新增/编辑价格页接入；Web 新增 [entityUnits.ts](frontend/src/utils/entityUnits.ts) 同口径并改为每次从全局单位基准重建 + 请求序号防竞态；②新增列 `weight_unit_override_id`（指向同一实体的另一条自定义单位；**不加 DB 外键**，导出带 `weight_unit_override_name`、导入按名字二次回填），换算统一到 `UnitConversionService.resolve_override_amount`（`1 单位 = conversion_factor(默认 1) × weight_per_unit × weight_unit`，环/深度>8/悬空引用不臆估），`convert`/`_get_piece_weight_kg`/菜谱营养 count 分支全部改走它；两端单位表单改「单个重量 = 数值 + 单位」（可选本实体其他自定义单位），列表显示 `1箱 = 12 盒` / `1盒 = 220 mL（≈227 g）`；③移动端 `EntityUnitsCard` 改成详情页内联列表 + 区块右上「添加」+ 行内编辑/删除，密度一实体一条（编辑 = 同 condition upsert），整页 `EntityUnitsScreen` 与路由删除；④`ProductExecutor`/`ProductMergeExecutor` 在改名/合并时同步 `product_records.product_name`（revert 按行还原），附三引擎幂等回填 SQL；⑤Web 25 个对话框统一「底部保存 + 标题行关闭(X)」；移动端新增本地设置 `mobile.save_button_position`（默认右上角）+ `saveAppBarActions`/`saveBottomBar` 一对 helper，作用于所有全屏表单。**验证**：后端新增 16 用例（嵌套链/密度折克/count 兜底/环/悬空/跨实体/菜谱营养 1468.4 kcal + 端点互斥与成环 400 + 改名同步与逐行回滚）；`tests/services + tests/api + test_products.py` 与基线逐项一致（9 failed/293 passed → 9 failed/302 passed，失败集合完全相同，均为沙箱临时目录/网络/登录夹具存量）；Web `npm run build` + `check:i18n` + `check:i18n:sources` + `test:utils` 18/18；移动端 `flutter analyze` 0 issue、`flutter test` 596 通过 6 存量失败（apple_map×3、locale_preferences×2、my_proposals×1）。详见 [FEATURE_自定义单位嵌套与保存按钮位置.md](agent_doc/FEATURE_自定义单位嵌套与保存按钮位置.md)。**经验：①「系数×重量」这类语义一旦要支持嵌套就必须有唯一解析入口，否则每加一层要改四处（本次统一到 resolve_override_amount）；②软删 + 导入重排行 id 的项目里不要给同表引用加 DB 外键，改应用层校验 + 名字冗余更稳；③快照列的维护要挂在唯一写入口（商品改名走提议执行器，管理员与普通用户同路径，改在端点里必漏一半）；④下拉选项要「基准重建」而不是追加，否则切换对象后残留；⑤两端对「右上角按钮」的默认预期不同——Web 固定底部保存 + 右上角关闭，移动端做成用户可选。**
- 商品「关联原料」星号与必填口径统一（用户反馈：商品管理基本信息里「关联原料」后面有星号，怀疑它和输入框必填项没区分开）：**根因**：这个星号不是 Vuetify 的必填标记——Vuetify 3.7 的 VTextField/VAutocomplete/VLabel 根本不处理 `required` prop（模板里成堆的 `required` 只是摆设），而是写死在翻译文案里 `products.linkedIngredient = "关联原料 *"`；于是①商品详情「基本信息」**只读列表**也显示「关联原料 *」（不是表单却带必填星号）②同一表单里真正必填的「商品名称」（DB `products.name`/`ingredient_id` 均 NOT NULL）反而没有星号。**修复**：`linkedIngredient` 去掉星号只用于只读展示（详情只读列表、待审提议字段标签），新增 `linkedIngredientRequired`/`nameRequired`（「关联原料 *」「商品名称 *」，三语）用于商品新增对话框与详情基本信息编辑表单；顺带把 feat 已有而 master 缺失的 `prices.units.hundredGrams` 带回 master（web 4 处在用）。**经验：①Vuetify 3 的 `required` 不显示星号，必填标记要么走 i18n 文案约定、要么统一走 rules，不能指望 prop；②同一个 i18n key 同时服务「只读展示」和「表单 label」时，改文案先 grep 全部消费点；③web 的标签星号约定已与移动端对齐（mobile 搜索类 label 带 `*`、展示类不带）。**
- 商品详情价格趋势「区间」改按记录口径（用户反馈：最新价格卡片区间 2.99-4.18，趋势图 tooltip 区间却是 3.78-3.78，同页两个区间对不上）：**根因**：商品详情趋势图与原料/后端迷你图共用 `buildWeightedAsOfDailySeries`，其 min/max 语义是「参与商品的价区间」；单商品视图里商品只有 1 个 → 当日多条记录先折成当日均价 → min=max=avg=3.7833，置信带退化成线；而卡片区间口径是「最近一次记录日的记录价 min/max（2.99/4.18）」。**修复**：`buildWeightedAsOfDailySeries` 加 opt-in `bandFromRecords`（区间按当日全部记录价 min/max，无记录日 as-of 沿用最近一次记录日区间；avg/count 语义不变，默认关闭，不影响原料详情/后端迷你图），商品详情 `chartData` 打开该开关。验证：`npm run test:utils` 18/18（新增开关开/关 2 用例）、真实数据复算（区间 2.99-4.18、avg 3.7833 携带到今天）、`npm run build` 通过。**经验：①同一个「区间」在不同粒度视图里语义不同——原料视图是「商品间」，商品视图必须是「记录间」，共享工具只能默认其一，opt-in 开关比让调用方自行重算安全；②「卡片与图表对不上」先把两处数字的口径各写成一句话再动代码；③置信带在只有 1 个聚合对象时必然退化成线，做图时要意识到。**
- 商品详情「最新价格」未按地区口径过滤（用户反馈：空心菜 277 卡片最新价 16.67 元/斤，但区间 2.99-4.18 元/斤；切「全部地区」才发现南京商家 10 元/3 把 = 16.67 元/斤的记录，湖滨区范围内没有）：**根因**：`GET /products/entity/{id}`（get_product）是商品/价格端点里唯一没接地区口径的——同文件 latest-price、latest-price-by-merchant 都走 `resolve_region_param + apply_region_filter`，同页面的价格记录列表、趋势图也按 `X-Region`/用户默认计算范围过滤，唯独详情端点查全表 → 卡片永远取全局最新一天；10 元/3 把经 piece_weight 折 0.6 斤 = 16.67 元/斤，正是被过滤掉的南京记录（2026-07-29），范围内最新一天是 2026-06-17（2.99/4.18/4.18 → 3.78 元/斤）。**修复**：get_product 补 `region_id` 参数并 `resolve_region_param`（会话 X-Region 优先），「取最新日期」与「最新一天记录」两处查询套 `apply_region_filter`，均价/单位折算/时区口径不变。验证：真实库直调（不过滤 16.667/07-29 → 市级·县级 3.7833/06-17）；新增 [test_product_detail_region_price.py](backend/tests/test_product_detail_region_price.py)（X-Region 市/县 → 3.0，无覆盖 → 10.0）通过，tests/api + entity 相关 72 项通过。**经验：①同页面多张卡片的地区口径必须由同一入口（resolve_region_param）落地，新端点漏接一层就会出现「卡片之间对不上」；②前端 `params: { region_id: null }` 会被 axios 丢弃，真正生效的是拦截器注入的 `X-Region` 头，排查地区问题先确认头有没有到端点；③本地模式 handler 支持 region_id ≠ 真的收到了它——`createLocalApi` 只透传 params，calc-context 不会自动进 query，本地模式地区过滤整体未接（另议）。**
- 价格趋势图「区间内无新记录则空白」修复（用户反馈：原料、商品价格趋势默认「月」，近一个月没有更新时图表空白显示「暂无价格历史数据」，切到有数据的区间再切回来又有图表；移动端同样）：**根因**：图表按 as-of 口径（每商品最近一次价向前携带 + 30 天参与上限、全超期放开）绘制，但取数按 `start_date` 下发（`/products?ingredient_id&start_date=...`），区间内没有记录时连「携带起点」都拿不到 → 序列为空；切到更宽区间后记录进了累积池，再切回窄区间由 PriceTrendChart 本地切片就正常——症状与用户描述完全对应。**修复**：①新增共享判断 [priceAsOf.ts](frontend/src/utils/priceAsOf.ts) `shouldLoadFullPriceHistory`（区间命中 0 条且池为空 → 回退「全量」），两个 web 详情页抽出 `fetchChartPriceRecords` 并接入；②[ProductDetail.vue](frontend/src/views/products/ProductDetail.vue) 图表口径从「按自然日分桶（只画有记录的日子）」改为逐日 as-of（与原料/后端同源），卡片「区间/记录数」改由 `latestRecordStats`（最近一次记录日）提供，不再从图表尾点推导；③移动端 [price_trend.dart](mobile/lib/features/prices/utils/price_trend.dart) 同步 as-of（`startDay`/`endDay`/`staleDays` 可注入、各商品等权），两个 provider `_loadChart` 区间取数为空时回退全量并用 `startDay` 截断序列。验收（真实库 + 运行中的后端 + 复算月视图切片）：原料 473 / 商品 142 近 30 天 0 条、全量 6/12 条 → 修复前 0 点，修复后 30 点且尾值 = 最近一次已知价（2.90 / 3.135）。验证：`npm run test:utils` 16/16、vite build 通过；`flutter analyze` 0 issue、`price_trend_test` 6/6、全量 flutter test 576 项 6 项存量失败（apple_map×3、locale_preferences×2、my_proposals×1）。详见 [BUGFIX_价格趋势区间无记录空白.md](agent_doc/BUGFIX_价格趋势区间无记录空白.md)。**经验：①「按区间取数」与「as-of 向前携带」天然冲突——携带依赖区间之前的记录，取数必须能覆盖到最近一次记录；②同一指标多端多处实现时，口径要连「取数」一起对齐，只对齐「计算」照样空白；③测试要覆盖「区间内没有任何记录」这一分支，否则只能等用户反馈。**

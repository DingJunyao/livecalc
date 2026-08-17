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

通常会打开浏览器调试。如有需要，可以使用 Chrome 开发者工具 MCP 查看页面情况，操作页面。由于一般情况下已经打开了页面，所以不要使用 Playwright。开发者在 Windows 下使用 Edge 浏览器，在 Linux 下使用 Chromium 浏览器。

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

注意：为了节约 token，即便用户要求记录到 CLAUDE.md，也要按照下面的索引记录。

定期清理最新修复记录，以减少 token 消耗。保留 10 条最近的修复记录。

### 不同分支的修改限制

目前有三个需要留意的分支：

- `master`: 主分支，包括 web 前端、后端
- `feat/local`：开发本地模式的分支
- `feat/mobile-app`：开发移动 App 的分支

注意：feat 分支只更改各自新增功能的问题和功能。比如：feat/local 只更改本地模式的功能和问题，feat/mobile-app 只更改移动端的功能和问题。如确有涉及到主分支上 web 前端、后端的问题，请更改到 master 分支修改，然后将修改合并到各 feat 分支。

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

本项目文档已模块化拆分，按需加载以提高性能。详细信息请查看 `./cc` 目录下的对应文件。

所有与 Claude Code 相关的文档，都放在 `./cc` 目录下。并且，在这里描述文档内容，以便索引。

如：部署说明：详见 [DEPLOYMENT.md](cc/DEPLOYMENT.md) 和 [QUICKSTART.md](cc/QUICKSTART.md)；开发时的规则，详见 [DEV_RULE.md](cc/DEV_RULE.md)

### 最新修复记录
- 移动端单位密度/层级图/连接池修复：单位密度页删除无意义右下角加号，添加单位保留页内表单；层级图对齐 Web 箭头语义（contains 父→子、fallback 子→父、substitutable 当前→关联），改受力布局并扩展可拖拽虚拟画布，修复节点挤出/关系方向异常；原料列表最新价改走批量接口，后端先在 master 新增 `GET /nutrition/ingredients/latest-price/batch`（一次最多 50 个 ID、复用一个 Session，提交 dc9b7ba）并合并回 feat/mobile-app，消除 20 个单原料请求叠加详情 9 请求导致的 SQLite QueuePool 45 连接耗尽。后端目标测试 2/2、py_compile 通过；移动端 analyze 0 issue、全量 flutter test 373/373、diff check 通过。详见 [BUGFIX_移动端单位密度层级图连接池.md](cc/BUGFIX_移动端单位密度层级图连接池.md)
- 移动端菜谱/价格/营养/层级反馈修复（用户 5 项跟进反馈闭环）：菜谱列表 FAB 仅保留加号图标；菜谱编辑拆为基本信息/原料/步骤/小贴士四块独立保存，创建仍整页提交，返回携带结果供来源页刷新；原料/商品“记录价格”统一进入 `/prices/record` 通用表单，支持原料自动匹配商品、限定搜索与商品锁定，补齐商家/计入支出/记录时间/备注等字段；原料详情层级卡片嵌入可缩放 `HierarchyGraph`，图与列表并存且中心为当前原料；营养编辑行改两行布局并展开下拉，修复 320px 窄屏右侧溢出。flutter test 370/370、analyze 0 issue、git diff --check 通过。详见 [BUGFIX_移动端菜谱价格营养层级反馈.md](cc/BUGFIX_移动端菜谱价格营养层级反馈.md)
- 移动端注册邀请码配置时序修复（用户反馈：注册页打开时无需邀请码，后台开启后 app 仍无输入框；注册失败被送回登录页且误报“用户名或密码错误”）：`authConfigProvider` 改 autoDispose，注册页打开、后台恢复、每 5 秒轮询以及提交前都刷新 `/auth/config`；提交前刚开启邀请码时拦截请求、显示输入框并提示“注册失败：服务器已开启邀请码注册”，POST 失败后再次刷新配置；注册错误改为独立映射后端 `detail`（如“注册失败：需要邀请码”）；路由守卫保留登录/注册页 loading，失败不再跳 splash/login，进入注册页清除旧登录错误。认证测试 22/22、全量 flutter test 365/365、analyze 0 issue。详见 [BUGFIX_移动端注册邀请码配置时序.md](cc/BUGFIX_移动端注册邀请码配置时序.md)
- 移动端维护功能与审核体验（用户 7 项反馈全闭环，对齐 web）：复杂维护表单全部整页化——新增营养 `/entities/:entityType/:entityId/nutrition`、单位密度 `/entities/:entityType/:entityId/units`、原料关系 `/ingredients/:id/hierarchy`、商家 `/merchants/new|:id/edit`、常用地点 `/profile/places/new|:id/edit`、价格记录 `/prices/record/edit`、菜谱 `/recipes/new|:id/edit` 路由，完成后按结果返回来源页并刷新；营养页补 USDA 搜索/详情/确认匹配（`UsdaRepository` + `MutationReviewResult`），原料关系列表旁增加可缩放层级关系图；菜谱补创建/编辑/发布/删除；服务器配置、登录、注册回车即提交，邀请码按服务器 `registration_require_invite_code` 显示/必填；原料/商品/商家/单位/密度/营养/USDA/菜谱增删改均区分 applied/pending，普通用户更新即使后端返回旧实体也提示待审核，删除 proposal pending 时保留本地数据。flutter test 361/361 全绿，analyze 0 issue。详见 [FEATURE_移动端维护功能与审核体验.md](cc/FEATURE_移动端维护功能与审核体验.md)
- 移动端原料商品表单页面化（用户反馈：别名被逗号/空格错误拆分、原料分类下拉为空、新增商品对话框路径报 `MouseTracker` 断言、复杂表单应独立成页）：新增 [alias_tags_field.dart](mobile/lib/shared/widgets/alias_tags_field.dart) 标签控件（输入后点击 + 添加，helper 避免桌面键盘说法、Chip 删除、分隔符保留原文）；新增 [ingredient_form_screen.dart](mobile/lib/features/ingredients/screens/ingredient_form_screen.dart) 与 [product_form_screen.dart](mobile/lib/features/products/screens/product_form_screen.dart)，路由 `/ingredients/new`、`/ingredients/:id/edit`、`/products/new`、`/products/:id/edit`；原料表单内部 watch 分类 Provider 修复直进页面分类为空，商品新增支持搜索选原料/原料详情固定原料，保存 `pop(true)` 后列表/详情/关联商品按来源刷新，删除四处旧表单对话框。仓库层补“清空分类提交 `category_id: null`”回归测试；后端显式 null 语义留 master 处理。flutter test 全量通过，analyze 仅 3 条既有 info，git diff --check 通过；MouseTracker 断言未稳定复现但新增商品已避开对话框路径。详见 [FEATURE_移动端原料商品表单页面化.md](cc/FEATURE_移动端原料商品表单页面化.md)
- 移动端地图图层首次加载修复（用户反馈：新增商家选点首次只有 OSM，先打开商家地图后再次新增才有高德/腾讯/OSM）：根因 = `MapConfigState` 初始兜底仅 OSM，配置只由商家列表异步加载，且 `MapPointPicker.initState` 固定读取瞬时状态、不响应后续配置到达；首次打开弹窗可操作不完整菜单。修复 [map_config_provider.dart](mobile/lib/features/merchants/providers/map_config_provider.dart) 并发合并/完成缓存，[map_point_picker.dart](mobile/lib/features/merchants/widgets/map_point_picker.dart) Android 自行触发加载并在配置完成前显示占位，商家列表/详情地图等待配置渲染；“我的地点”复用选点组件随之修复，iOS MapKit 分支不改。TDD 新增 4 处场景，flutter test 325/325 全绿；analyze 仅 3 条既有 info；Android APK 构建因本机无 Android SDK 阻塞，Windows debug build 通过。详见 [BUGFIX_移动端地图图层首次加载.md](cc/BUGFIX_移动端地图图层首次加载.md)
- 移动端菜谱详情原料行点击范围修复（用户反馈：特殊计算原料的 tooltip 实机上点击即跳转，看不到提示）：[recipe_detail_screen.dart](mobile/lib/features/recipes/screens/recipe_detail_screen.dart) `_buildIngredientRow` 三列原全包 `InkWell(onTap)`（名称/用量/价格任意点都跳原料详情）→ 对齐 web [RecipeIngredientCard.vue:91-136](frontend/src/components/recipes/RecipeIngredientCard.vue#L91-L136)：跳转仅限名称列（用量/价格改裸 Padding，Tooltip 保留——移动端默认 longPress 长按看提示）；chevron 从名称前移到名称后（对齐 web mdi-chevron-right）。analyze 0 issue + recipes 测试 68/68 全绿。详见 [BUGFIX_移动端菜谱详情原料行点击范围.md](cc/BUGFIX_移动端菜谱详情原料行点击范围.md)
- iOS MapKit 脚手架（设计见 [PLAN_ios_mapkit.md](cc/PLAN_ios_mapkit.md)，计划见 [PLAN_ios_mapkit_脚手架.md](cc/PLAN_ios_mapkit_脚手架.md)，用户反馈 iOS 地图栅格模糊 → 原生 MapKit）：①依赖 `apple_maps_flutter ^1.4.0`（pub get + analyze 0 新增 + Info.plist 权限 key 已存在）；②视角纯函数 [merchant_map_logic.dart](mobile/lib/features/merchants/widgets/merchant_map_logic.dart) `computeMapView`（focusPlace>selectedPoint>单点>多点重合>多点 bounds>默认）+ `centroid` + 常量，TDD 7 用例；③[merchant_map_view.dart](mobile/lib/features/merchants/widgets/merchant_map_view.dart) 删 `_singleCenter`/`_boundsFit` 改 `_decision()` 复用纯函数（坐标转换/flutter_map API 原样，view_test 全绿行为不变）；④iOS 商家地图 [apple_merchant_map.dart](mobile/lib/features/merchants/widgets/apple_merchant_map.dart) + iOS 选点 [apple_map_picker.dart](mobile/lib/features/merchants/widgets/apple_map_picker.dart)：AppleMap + 大头针 + 标准/卫星切换 + `_appleNeedsGcj02` 定标开关，`Platform.isIOS` 顶层分流，Android 一行不动。**执行修正**：apple_maps_flutter 用**自己的 LatLng**（非 latlong2，计划直传编译错）→ `import ... as apple` 别名 + `_toApple` 边界转换；`AnnotationId` 非 const；`_focusPlace` 缩放用 radiusKmToZoom 对齐 Android（计划固定 12.0）。**待真机定标**：GCJ02 方向、定位蓝点、selectedId 高亮、常用地点菜单。TDD 303/303 全绿（+7）+ analyze 0 新增（剩 5 预先存在）+ build windows 通过（162.4s）。iOS 构建留 build-ios.yml CI。经验：接包前先读 pub cache 源码确认类型归属（同名 LatLng 跨库冲突靠别名 import 解）。详见 [PLAN_ios_mapkit.md](cc/PLAN_ios_mapkit.md)
- 移动端五项问题修复（用户 5 项反馈全闭环，对齐 web）：①推荐页删「快捷入口」（[home_screen.dart](mobile/lib/features/home/screens/home_screen.dart) 删 QuickEntryGrid 引用 + 删 [quick_entry_grid.dart](mobile/lib/features/home/widgets/quick_entry_grid.dart) 文件）；②价格记录两处表单商家 `DropdownButtonFormField` → `Autocomplete<Merchant>` 文本筛选（[price_record_form_sheet.dart](mobile/lib/shared/widgets/price_record_form_sheet.dart)/[price_record_form_screen.dart](mobile/lib/features/prices/screens/price_record_form_screen.dart)，fieldViewBuilder addPostFrameCallback 同步内外 controller）——**I-1 stale id**：onChanged 改「_merchantId!=null 即清 id」（Autocomplete 程序化 `controller.text=m.name` 不触发 onChanged 是安全基础）+ M-1 预填不在列表则 id=null；③计价页卡片尾 chevron → `PopupMenuButton` 三点菜单编辑/删除（[price_list_screen.dart](mobile/lib/features/prices/screens/price_list_screen.dart)），provider 加 updateRecord（局部 map 更新不刷新保滚动位置）/deleteRecord（total 按实际移除数递减），merchantName 屏幕层反查 merchantListProvider 传入；④快速填写加粘贴导入（移植 web 独立全屏页 [paste_import_screen.dart](mobile/lib/features/prices/screens/paste_import_screen.dart) + [paste_price_parser.dart](mobile/lib/features/prices/utils/paste_price_parser.dart)）：复制模板→粘贴解析→四级自动匹配（商品主名→原料主名→商品别名→原料别名）→手动二分支(existing/newSame)→并发5导入→全成功才 pop savedIds；repository 加 autocomplete/addImportAlias；**C1** `_ImportRow` 持久 `searchController`（治 build 里 `new TextEditingController` 致光标跳末尾+泄漏；_releaseEditor 集中释放+_cancelEdit/_chooseExisting/_chooseNewSame/dispose 兜底）、**I1** `searchSeq` 序号守卫丢弃过期响应、**I2/I3** `_toInt(dynamic v) => (v as num?)?.toInt()` 替裸 `as int`（raw Map 字段若 double 抛 TypeError，而 TypeError 是 Error **不被 `on Exception` 接住**经 Future.wait 直接崩 _parse 红屏）；补 `_saveProductOrders`（`POST /merchants/{id}/product-orders` 对齐 web onPasteImported，spec MISSING）；⑤「更多」二级菜单 `Column>ListTile` → `Row>Expanded(_NavItem)` 横排胶囊（复用底栏 _NavItem 同款 secondaryContainer 圆角16，builder 外取 GoRouterState 做选中态绕开 Overlay 下 ctx 拿不到路由的坑，桌面 NavigationRail 不受影响）。Subagent-Driven 5 任务 + 每项 spec/质量双审 + 最终整轮审查 READY（5 项逐项确认 + app_router(④⑤)/price_record_form_sheet(②③)/merchantListProvider(②③)/quick_fill(④)/移动端↔web 5 项交叉影响全无冲突）。TDD 296/296 全绿 + analyze 0 新增（剩 5 预先存在）+ build windows 通过（40.1s，先 taskkill livecalc_mobile.exe 防 MSB3073 文件占用）。**经验**：Autocomplete 程序化赋值不触发 onChanged（stale-id 修复基础）；raw Map 未经 fromJson 类型转换必须 `(as num?)?.toInt()` 防 TypeError 静默崩溃；状态对象应持有持久 controller 而非 build 里 new（光标跳末尾+泄漏）。详见 [FEATURE_移动端五项问题修复.md](cc/FEATURE_移动端五项问题修复.md)
- 移动端标签页与计价入口重构（用户 3 项需求：底栏改版/启动时起始页/长按计价）：①底栏自绘重排——手机 4 项（推荐/计价/菜谱/**更多**汉堡）+ `showModalBottomSheet` 二级菜单（原料/商品/商家/我的），桌面 ≥600px `NavigationRail` 7 项全展示；选中态从精确全等改**路由前缀分组**（`_tabIndexFor`，详情页 /recipes/123 等也高亮所属 tab，`_Tab` 单一模型共享桌面/手机无漂移）；`_NavItem` 自绘（M3 选中胶囊+填充图标+w600 标签 + Semantics(selected/button/label + excludeSemantics 防读屏念两遍)）；②「我的」设置区加**启动时起始页**（推荐/计价/菜谱，SharedPreferences 键 `startup_page` 纯本地）：bootstrap **load 先于 checkAuth** + redirect 认证分支 `'/${...}'`（kStartupPages 值域密封无竞态窗口），**三路径统一**（自动登录/手动登录/注册成功均读配置）；③计价入口重排：FAB 加号修复（原错误指向 quick-fill）→ 新增全屏页 [price_record_form_screen.dart](mobile/lib/features/prices/screens/price_record_form_screen.dart) `/prices/record`（字段对齐 web 对话框、repository 构造注入、`push<bool>` + saved==true 刷新，FAB 与长按共用契约；initState 须 `Future.microtask` 包 merchantListProvider.load()——直接 load 抛 "modify provider while building"）；AppBar 加 `Icons.bolt` 快速填写入口（对齐 web mdi-lightning-bolt）。Subagent-Driven 7 任务 + 双审 + 最终审查，**审查抓 6 真问题全修**：stale `_selectedProduct`（选商品改名仍带旧 productId）、merchant 未 load、搜索竞态 `_searchSeq`、`_saving` 双击防重、注释被工具链转义成 `\uXXXX`（perl 修复时 shell 引号致正则退化误伤 10 处标识符，Python 纯 ASCII 脚本+先审计恢复）、Semantics 重复 label。TDD 231/231 全绿（+~30）+ analyze 0 新增 + build windows 通过（78s）。**计划自审教训**：测试 key 与实现 key 生成方式必须一致（`'tab-${route}'` 带 `/` 前缀 → 改 label `'tab-计价'`）；`const Scaffold(appBar: AppBar())` 编译错（AppBar 无 const 构造）；semantics 断言用 flagsCollection+Tristate 代替 matchesSemantics（合并节点带 InkWell 动作 flag 过严）。详见 [FEATURE_移动端标签页与计价入口重构.md](cc/FEATURE_移动端标签页与计价入口重构.md)

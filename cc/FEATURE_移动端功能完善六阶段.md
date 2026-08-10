# 移动端功能完善（英文中文化 + 设置/用户/地图对齐网页端）

用户 5 项反馈，6 阶段 TDD 全量实施，185/185 测试全绿（基线 161 + 新增 24）。

## 阶段 0：英文文案中文化（含系统级）

**系统级根因**：[app.dart](mobile/lib/app.dart) MaterialApp.router 未配置本地化 delegates → Material 内置组件（AppBar 返回按钮 tooltip「Back」、文本框长按菜单「Copy/Paste」）全英文。修复：`localizationsDelegates: GlobalMaterialLocalizations.delegates, supportedLocales: [zh_CN], locale: zh_CN`（pubspec 加 flutter_localizations）。页面级仅两处：[my_places_screen.dart](mobile/lib/features/profile/screens/my_places_screen.dart)「My Places/No Places/Saved locations...」→ 中文；[my_proposals_screen.dart](mobile/lib/features/profile/screens/my_proposals_screen.dart) 同 + _statusLabel Approved→已生效/Rejected→已驳回/Pending→待审。复查 grep（`(Text|title|labelText|...)[:=]"[A-Za-z]`）零残留。测试 [app_localizations_test.dart](mobile/test/app_localizations_test.dart) 断言 byTooltip('返回') 命中（防日后删 delegates）。

## 阶段 1：基础设施

- [user.dart](mobile/lib/features/auth/models/user.dart)：+nickname/nutritionGoals/dailyBudget/unitPreferences；`displayName`（nickname 空回退 username）；`avatarUrl`（storage key → `/api/v1/images/$key`，后端 307 重定向，Image.network 免 token）
- [auth_repository.dart](mobile/lib/features/auth/repositories/auth_repository.dart)：+updateMe(PATCH /auth/me)/updateAccount(PUT /auth/me/account)/uploadAvatar(POST /auth/me/avatar，**坑**：dio 全局 application/json，必须 Options Content-Type multipart/form-data 否则 422)
- [auth_provider.dart](mobile/lib/features/auth/providers/auth_provider.dart)：+refreshUser/applyUser
- [profile_repository.dart](mobile/lib/features/profile/repositories/profile_repository.dart)：getProposals 改 `scope=mine&limit=100`（后端**无 page 参数**）、+createPlace/updatePlace/deletePlace/setDefaultPlace/getUnits（**GET /units/ 带尾斜杠**，redirect_slashes=False 不带斜杠 404）
- [user_place.dart](mobile/lib/features/profile/models/user_place.dart)：+isDefault/viewRadiusKm

## 阶段 2：用户信息编辑 + 头像

[edit_account_screen.dart](mobile/lib/features/auth/screens/edit_account_screen.dart)（新建，全屏页）：头像 CircleAvatar 80px + ImagePicker → Android/iOS ImageCropper 1:1（Windows/Linux 跳过裁剪）→ uploadAvatar → refreshUser；表单 用户名/昵称/邮箱/手机（`^1[3-9]\d{9}$`）；保存只传**变化字段** → updateAccount → 有 token 则 saveTokens → applyUser；400 提取后端 detail toast。[profile_screen.dart](mobile/lib/features/profile/screens/profile_screen.dart) 用户卡片包 InkWell → push('/profile/account') + chevron + displayName + 头像。

## 阶段 3：设置页两功能

[unit_preferences_screen.dart](mobile/lib/features/profile/screens/unit_preferences_screen.dart)：能量 kcal/kJ 硬编码 + 质量/容积/记价（mass/volume/count）下拉；保存只传变化字段（null=清除）；`'${u.name}$abbr'` 且 `abbr != u.name` 才拼后缀（防「个（个）」）。[nutrition_goals_screen.dart](mobile/lib/features/profile/screens/nutrition_goals_screen.dart)：4 数字输入；**kJ 显示 ×4.184 取整、保存 ÷4.184 取整**（web useUserUnits）；范围 kcal 500-5000（kJ 2000-21000）/蛋白 10-300/碳水 50-600/脂肪 10-200；空输入存 null。[profile_screen.dart](mobile/lib/features/profile/screens/profile_screen.dart) 删「预算设置」。

## 阶段 4：我的地点 CRUD

[my_places_screen.dart](mobile/lib/features/profile/screens/my_places_screen.dart) 重写对齐 web UserPlacesView：kind **work 非 company**（旧 bug）+ 星标仅默认 + subtitle `'家 · 视野 5 km · 31.2304, 121.4737'`（`(viewRadiusKm ?? 5).round()` 防「5.0 km」）；PopupMenu 设为默认（非默认才 enabled）/编辑/删除（确认框）；FAB 对话框（名称/类型/视野 1-50km/地址/经纬度手填校验 ±90/±180）；403（地图关闭）→「地图功能已关闭，无法维护常用地点」。[profile_provider.dart](mobile/lib/features/profile/providers/profile_provider.dart) PlaceListNotifier + add/update/remove/setDefault。

## 阶段 5：我的提议详情

[proposal.dart](mobile/lib/features/profile/models/proposal.dart) 按真实后端形状重写（`{id, entity_type, entity_id, entity_label, action, payload, snapshot, status, review_note, created_at}`，**无 title 字段**——旧模型读 title 全 null 列表标题空白 bug）；`title` getter：entityLabel 非空用之否则 `'[#$id] $action $entityType'`。[my_proposals_screen.dart](mobile/lib/features/profile/screens/my_proposals_screen.dart)：_typeLabel/_actionLabel 中文化 + subtitle `'食材 · 新增 · 2026-08-01'` + 点击详情 dialog（状态 chip + 元信息 + 审核意见 + snapshot vs payload diff 表，键并集、before==after 跳过、null→'无'）。

## 阶段 6：地图三功能（底图切换 / 地点下拉 / 定位）

### 依赖与权限
- [pubspec.yaml](mobile/pubspec.yaml)：geolocator **^14.0.2**（^14.0.3 与 flutter_secure_storage ^9.2.2 冲突，降级解决）
- 四平台权限：AndroidManifest ACCESS_FINE/COARSE_LOCATION、Info.plist NSLocationWhenInUseUsageDescription、macOS DebugProfile/Release entitlements location=true

### GCJ02 转换（纯 Dart，web 1:1 移植）
[coordinate_transform.dart](mobile/lib/core/geo/coordinate_transform.dart)：`wgs84ToGcj02/gcj02ToWgs84`（a=6378245.0 变体、ee=0.006693421622965943、字面量 6336242.6562/6378245.0）；**高德/腾讯瓦片是 GCJ02、数据库存 WGS84，不转换偏移 ~481m**（上海实测 31.2304,121.4737 → 31.228454,121.478223）；`isGcj02Map` 仅 amap/tencent。[map_zoom.dart](mobile/lib/core/geo/map_zoom.dart)：radiusKmToZoom 抄 web（1→14/2→13/5→12/10→11/20→10/50→9/else 8）。

### 底图切换
[map_config_provider.dart](mobile/lib/features/merchants/providers/map_config_provider.dart)（新建）：amap（webrd0{s}.is.autonavi.com，subdomains 1-4，gcj02）/tencent（rt{s}.map.gtimg.com，0-2，gcj02）/osm（tile.openstreetmap.org，非 gcj02）；load() = GET /merchants/map-config 交集按常量表顺序、default_map ∈ 交集用之否则第一个、失败兜底仅 OSM（web 保守策略）。**坑**：const 默认值必须命名常量（`osmOnlyLayers`），不能 `[mapLayerOptions[2]]`（非 const 表达式）。[merchant_repository.dart](mobile/lib/features/merchants/repositories/merchant_repository.dart) +getMapConfig。

### MerchantMapView 改造（核心）
[merchant_map_view.dart](mobile/lib/features/merchants/widgets/merchant_map_view.dart) 新参数：mapConfig/places/currentPlaceId/onPlaceChanged/showControls/tileProvider（测试注入内存瓦片）。**坐标变换统一出口 `_toDisplay`**：GCJ02 底图过 wgs84ToGcj02、OSM 原样，**所有进 MarkerLayer/CircleLayer/move/fit/initialCenter/CameraFit 的坐标必须过它**（漏一处偏移几百米；initialCenter 也要转，flutter_map 6 首帧 bug 约束保留：初始视角只走 initialCenter/initialCameraFit，onMapReady 不 fit）。切底图 setState 换 _layer → urlTemplate 变化自动 reloadImages（6.2.1 已核实）。视角优先级：_focusPlace（地点坐标 + radiusKmToZoom）> _singleCenter > _boundsFit；didUpdateWidget 监听 currentPlaceId/places/mapConfig 变化 → _fitView。定位：isLocationServiceEnabled → check/requestPermission（denied/deniedForever 各自 toast）→ getCurrentPosition(accuracy high, timeLimit 10s) → 蓝点 18px 白边 + 5km 精度圈（0.12 alpha 实线，flutter_map 无虚线）；TimeoutException→「定位超时」；**再点清除蓝点回原视角**（web toggle 语义）。空态（无商家坐标）不显示控件。控件列：右上竖排 Material surface elevation 2（底图 PopupMenuButton + 地点 DropdownButton 含「全部商家」+ 定位 IconButton），**places 空时隐藏下拉**（web 同）。

### 数据层（列表页）
[merchant_list_screen.dart](mobile/lib/features/merchants/screens/merchant_list_screen.dart)：+`profileRepository` 构造注入（测试 mock）；_loadPlaces() = ProfileRepository.getPlaces + `_currentPlaceId` 初始化顺序 **SharedPreferences 'merchants_map_current_place_id'（与 web localStorage 键名一致）→ is_default → null（全部商家）**；切换 setInt/remove。

### 测试（新增 24）
coordinate_transform_test（**Python 独立计算参考值防移植笔误**：上海/北京 closeTo 1e-6；往返一致性单步近似逆**容差 1e-4**（固有误差 ~1e-5 度米级，web 不迭代））、map_zoom_test、map_config_provider_test（过滤 baidu/tianditu、default 回退、失败兜底 OSM）、merchant_map_view_test（**GeolocatorPlatform.instance = fake 覆写 4 方法**，Position 全 9 required 字段；切底图 marker point 断言 GCJ02 生效；`TileProvider.transparentImage` 内存瓦片消除网络噪音；下拉回调 + didUpdateWidget 聚焦用 StatefulBuilder setState 模拟父组件重建；定位蓝点出现/再点清除）、merchant_list_screen_test 扩展（setMockInitialValues 初始化顺序与持久化 4 用例；**mock 商家必须有坐标**否则地图空态无控件）。

## 经验汇总

- 系统级中文化一处配置（localizationsDelegates），比逐条改 tooltip 优雅
- 后端契约必须逐字段核对（proposals 无 title、units 尾斜杠、kind 是 work）
- 坐标转换必须**统一出口**，漏一处 = 偏移几百米
- 版本冲突降级解决（geolocator 14.0.3→14.0.2）而非升级 flutter_secure_storage（token 存储风险大）
- **本机 TLS 出口问题**：dist.nuget.org/api.nuget.org/pub.dev 直连失败（Invoke-WebRequest .NET TLS 栈失败）但 **curl.exe（schannel）能下 nuget.exe**；NuGet 源：腾讯镜像 `https://mirrors.cloud.tencent.com/repository/nuget-group/index.json` **实测 502** → 换**华为云** `https://repo.huaweicloud.com/repository/nuget/v3/index.json`（curl 200 + nuget.exe .NET 栈实测 145ms 装包成功；注意其 flatcontainer 基地址是定制路径 `.../artifactory/api/nuget/v3/nuget-remote/`，客户端经 index.json 自动解析无需手配）
- geolocator_windows 0.2.5 CMake 需 nuget.exe（FetchContent 下载会卡 816s 超时）→ 预装 nuget.exe 到 PATH 即跳过下载；**fetch 失败残留 `build/windows/x64/_deps/nuget-src/` 空目录必须删**，否则 CMake 误判已 populated 跳过下载又找不到包
- flutter_map widget 测试瓦片请求是噪音：注入 MemoryImage(TileProvider.transparentImage) provider 消除

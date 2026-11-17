# iOS 用 Apple Maps（MapKit）按名称/地址自动带出坐标与行政区划

## Context

移动端商家表单（`mobile/lib/features/merchants/screens/merchant_form_screen.dart`）：地址为自由文本、坐标靠地图点选、行政区划靠 4 级级联下拉；选点后回填区划走后端 `POST /merchants/geocode`（服务端高德 key）。全栈无「名称→坐标」正向搜索。

用户目标：iOS 上用系统自带 MapKit（即 Apple Maps SDK，`MKLocalSearch` POI 搜索 + `CLGeocoder` 逆编码，**无需任何 API key**、无新 pub 依赖、无需改 Info.plist、不需定位权限）：
- 填名称 → 带出**地址、坐标、行政区划**
- 填地址 → 带出**坐标、行政区划**
- **已有值的字段一律不覆盖**；坐标的**默认/占位值不算「已有」**（等于地图默认中心 `(39.9042, 116.4074)` 或 `(0,0)` 的坐标视为空，可被填充）
- iOS 选点→区划回填也切原生 CLGeocoder，后端高德 geocode 仅作失败回退 → iOS 端不依赖各地图 API

同名连锁店（蜜雪冰城等）候选多且默认排序可能在外市，不做静默自动填顶层结果；沿用本项目搜索惯例：输入停止 → 300ms 防抖+请求序号（BUGFIX_mobile_search_ime_debounce 同款模式）→ 字段下方出候选列表 → 用户点选 → 按规则带出。仅动 feat/mobile-app 分支 mobile/ 目录，无后端/迁移/web 改动。

## 实现

### 1. iOS 原生插件（Swift）
新文件 `mobile/ios/Runner/AppleMapsPlugin.swift`，仿 `AppDelegate.swift` 里现成的 `AppShortcutsPlugin` 注册模式。通道 `com.a4ding.livecalc/apple_maps`：
- `searchPlaces`：`{query, centerLat?, centerLng?, radiusMeters?}` → `MKLocalSearch.Request`（有 center 设 region 偏置）→ 数组，每项 `{name, address(subtitle 缺省时拼接 placemark 组件), latitude, longitude, administrativeArea, locality, subLocality, thoroughfare, countryCode}`，限 10 条；出错回 FlutterError。
- `reverseGeocode`：`{latitude, longitude}` → `CLGeocoder.reverseGeocodeLocation` → 同构 dict 或 null。
- `AppDelegate.swift` 的 `didInitializeImplicitFlutterEngine` 中与 AppShortcutsPlugin 并列注册。

### 2. Dart 服务层
新文件 `mobile/lib/core/services/apple_maps_service.dart`：MethodChannel 封装；`isAvailable` 默认 `Platform.isIOS`、`@visibleForTesting` 可覆写（Windows 宿主跑测试用）；模型 `ApplePlace`/`ApplePlacemark`；提供坐标占位判定 `isPlaceholderCoordinate(LatLng)`（等于 picker 的 `_defaultCenter` 常量 `(39.9042,116.4074)` 或 `(0,0)`，与 4 个 picker/map view 的 `_defaultCenter` 同源抽成公共常量）。**坐标基准**：MapKit 在中国返回 GCJ-02，`countryCode=='CN'` 或缺省的结果统一 `gcj02ToWgs84`（复用 `core/geo/coordinate_transform.dart`），与 `apple_map_picker.dart` 的 `_appleNeedsGcj02` 同口径（真机定标 TODO 同样适用，注释注明）。

### 3. 区划名称匹配（纯客户端，不动后端）
新文件 `mobile/lib/features/merchants/services/region_matcher.dart`：`matchRegionId(repository, {countryCode, administrativeArea, locality, subLocality})`。`listRegions(level:0)` 按 `iso_country` 匹配国家（已核实 API 返回 iso_country/name_en；中国节点 `name=中国/name_en=China/iso_country=CN`，不受设备语言影响）→ 逐级 `listRegions(parentId)` 下钻：level1 试 `administrativeArea`，level2/3 依次试 `locality`、`subLocality`；每级先精确、再后缀剥离归一（市/省/自治区/特别行政区/自治州/盟/地区）；失配返回 null（best-effort，仍可手动选）。

### 4. 商家表单接线（`merchant_form_screen.dart`）
- 「已有」判定助手：地址=非空白文本；坐标=`_coordinate != null && !isPlaceholderCoordinate(_coordinate)`；区划=`_regionId != null`。
- 名称/地址两个 TextField 的 `onChanged` → 300ms 防抖 + 请求序号守卫（iOS 且文本非空才搜，center 取 `_coordinate`）→ 各自候选列表（`_nameCandidates`/`_addressCandidates`）渲染在字段下方（紧凑列表，名称主标题+地址副标题，仅 iOS 且非空时显示）。纯 TextField + 自绘列表，不用 `Autocomplete`（避开本仓已记录的焦点重现/IME 回声坑）。程序化回填地址不触发 onChanged，无反馈循环。
- 点选候选（**只填空字段/占位值，已有值不覆盖**）：
  - 名称候选 → 地址空白则回填 Apple 地址串；坐标空或占位则设为 WGS84 结果（`MapPointPicker` 经 `initialValue` 自动更新）；区划空则 `matchRegionId(...)`（`RegionSelectField` 的 `didUpdateWidget` 联动级联回填）；清候选。
  - 地址候选 → 坐标、区划同上规则；地址**永不回写**（它是搜索源且已「有值」）。
- `_onMapChanged`（选点→区划）：iOS 先 `reverseGeocode`（入参经 `wgs84ToGcj02` 转回 MapKit 基准，避免区县级边界偏差）+ `matchRegionId`，失败/null 回退现有后端 `repository.geocode`；Android 路径不变。

### 5. i18n（zh/en/ar 三语 ARB）
新增少量 key：候选区标题（如「苹果地图匹配」）；搜索失败静默不弹错误。跑 `flutter gen-l10n`；**坑**：gen-l10n/pub 改写 `pubspec.lock` 要还原。

### 6. 测试（Windows 宿主可跑）
- `region_matcher_test.dart`：直辖市/省市县下钻、后缀剥离、非 CN、失配 null。
- `apple_maps_service_test.dart`：mock MethodChannel，验证参数编码、模型解析、CN 结果 GCJ02→WGS84、占位坐标判定。
- 表单 widget 测试：覆写 isAvailable + mock 通道/repository；输入名称→pump 防抖→候选出现→点选→空字段被填、已有字段未被覆盖；坐标为占位值时被覆盖、为真实值时保留；地址流不改地址文本。

### 7. 文档（AGENTS.md 记录要点规范）
新增 `agent_doc/FEATURE_iOS_AppleMaps商家名称定位.md`；AGENTS.md 索引加一行、最新修复记录裁到 10 条。

## 验证
1. `cd mobile && flutter analyze` 0 issue；`flutter test` 新增 3 个测试文件 + 商家表单既有用例全过；全量跑一遍确认无新增失败；检查 pubspec.lock 未被改写。
2. iOS 真机/模拟器行为（中国区坐标基准、POI 命中率、区划匹配率）Windows 无法验证——按 CN→GCJ02 折算实现并标注真机定标点，交由用户在 Mac VM 实测复核（参照 agent_doc/BUILD_iOS_无签名IPA与MacVM.md）。

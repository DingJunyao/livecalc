# FEATURE：iOS 用 Apple Maps（MapKit）按名称/地址匹配带出坐标与行政区划

## 背景

移动端商家表单（`mobile/lib/features/merchants/screens/merchant_form_screen.dart`）里地址是自由文本、坐标靠地图手动点选、行政区划靠 4 级级联下拉；选点后的行政区划回填走后端 `POST /merchants/geocode`（服务端存高德 key）。全栈原本没有「名称→坐标」正向搜索。

本次在 iOS 上改用系统自带 MapKit（即 iOS 的 Apple Maps SDK）：`MKLocalSearch` 做名称/地址→地点搜索，`CLGeocoder` 做坐标→行政区划逆编码。**无需任何地图服务 API key、无新 pub 依赖、无需改 Info.plist（不需要定位权限）**，iOS 端对地图服务的依赖降为零（后端高德 geocode 仅作失败回退）。

交互规则（用户指定）：
- 填名称 → 带出**地址、坐标、行政区划**
- 填地址 → 带出**坐标、行政区划**（地址本身是搜索源，永不回写）
- **已有值的字段一律不覆盖**；坐标的**占位值不算「已有」**（null、`(0,0)`、地图默认中心 `(39.9042,116.4074)` 可被覆盖）
- 同名连锁店候选多且默认排序可能在外市，不做静默自动填顶层结果：沿用本项目搜索惯例（输入停止 → 300ms 防抖 + 请求序号 → 字段下方候选列表 → 用户点选）

分支：feat/mobile-app（仅 mobile/ 目录，无后端/迁移/web 改动）。

## 原生层（iOS）

`mobile/ios/Runner/AppDelegate.swift` 末尾新增 `AppleMapsPlugin`（沿用 AppShortcutsPlugin 的文件内插件模式——本工程 pbxproj 未开文件系统同步组，新建 .swift 文件需要改 pbxproj，文件内零工程文件风险）。通道 `com.a4ding.livecalc/apple_maps`：

- `searchPlaces`：`{query, centerLat?, centerLng?, radiusMeters?}` → `MKLocalSearch.Request`（有 center 设 region 偏置 50km）→ `prefix(10)` 数组，每项 `{name, address(subtitle 优先，缺省拼 placemark 组件), latitude, longitude, country, countryCode, administrativeArea, locality, subLocality, thoroughfare}`。新请求前 cancel 旧请求；`MKError.cancelled` 静默回空，其余回 `FlutterError(searchFailed)`。
- `reverseGeocode`：`{latitude, longitude}` → `CLGeocoder.reverseGeocodeLocation` → 同构 dict 或 null；错误回 `FlutterError(reverseFailed)`。**固定 `locale = zh_CN`**：行政区划名称匹配走中文库（`AdministrativeRegion.name`），不受设备语言影响；国际地名只按 isoCountryCode 匹配国家，不受影响。

在 `didInitializeImplicitFlutterEngine` 中与 AppShortcutsPlugin 并列注册。

## Dart 服务层

`mobile/lib/core/services/apple_maps_service.dart`：

- `kMapDefaultCenter` 常量 + `isPlaceholderCoordinate(LatLng?)`（null/(0,0)/默认中心=占位）。后续应让 4 处 picker/map view 的私有 `_defaultCenter` 改引此常量（本次未动，避免扩散 diff）。
- `ApplePlace` 模型：`fromChannel` 解析原生 dict，**坐标统一折算 WGS84**——`countryCode=='CN'` 或缺失时过 `gcj02ToWgs84`（境外坐标不在 GCJ02 生效范围自动恒等）。与 `apple_map_picker.dart` 的 `_appleNeedsGcj02` 同口径，真机定标后一并调整。
- `AppleMapsService`：`isAvailable`（默认 `Platform.isIOS`，构造参数 `available:` 可覆写供测试）；`searchPlaces` 失败/不可用回空列表、`reverseGeocodeForWgs84` 失败回 null，全部静默降级；逆编码入参先 `wgs84ToGcj02` 转回 MapKit 基准（避免区县级边界偏差）。

## 区划名称匹配（纯客户端）

`mobile/lib/features/merchants/services/region_matcher.dart` 的 `matchRegionId(repository, {countryCode, country, administrativeArea, locality, subLocality})`：

- 国家锚：`listRegions(level: 0)` 按 `iso_country` 精确匹配（API 已返回该字段，中国节点 `name=中国/name_en=China/iso_country=CN`），兜底按 `country` 中英文名。
- 省 → 市 → 区县逐级 `listRegions(parentId:)` 下钻；省用 `administrativeArea`，市/区两级都用 `locality`+`subLocality` 两个候选（直辖市行政区划名称在两级之间位置不定）。
- 每级先精确匹配、再剥后缀归一（特别行政区/自治区/自治州/林区/地区/盟/省/市/县/区/旗循环剥，双侧同规则），最后归一名前缀比较（「新疆」命中「新疆维吾尔」）。
- 唯一子节点单链穿透（pca 数据里直辖市可能夹「市辖区」层），最多穿两层。
- **返回最深命中 id**（区县失配停在市级；currency 跟随地区仍有意义）；无国家锚或候选全空或接口异常返回 null，best-effort 不阻塞表单。

## 商家表单接线

`merchant_form_screen.dart`：

- 名称/地址 TextField `onChanged`（仅 `isAvailable` 时挂）→ 300ms 防抖 + 各自请求序号守卫（`price_record_form_screen.dart` 同款模式）→ 字段下方候选列表（`_buildAppleCandidates`：标题行 l10n `appleMapsMatches`「苹果地图匹配」+ ListTile 名称/地址副标题，maxHeight 200）。纯 TextField + 自绘列表，**不用 `Autocomplete`**（避开本仓已记录的焦点重现/IME 回声坑）。
- `_applyCandidate`：**只填空字段/占位值**——名称流回填地址（仅当前空白时；程序化赋值不触发 onChanged，无二次搜索循环）、坐标（`isPlaceholderCoordinate` 才填）、区划（`matchRegionId`，`_regionId != null` 直接跳过）；地址流同坐标/区划规则、地址永不回写。点选后清候选并作废在途请求序号。
- `_onMapChanged`（选点→区划）：iOS 先走 `reverseGeocodeForWgs84` + `matchRegionId`，失败/null 回退既有后端 `repository.geocode`（Android 路径不变）；选点语义保留「区划跟随点」（移动选点即意图变更区划，与匹配流的「不覆盖」规则不同）。
- `RegionSelectField` 补传 `repository: widget.repository`（与表单共用注入实例，测试可 mock；行为不变）。
- 构造参数新增 `appleMapsService`（默认 `AppleMapsService()`），测试注入假服务。

## i18n

三语 ARB 新增 `appleMapsMatches`（zh 苹果地图匹配 / en Apple Maps matches / ar مطابقة خرائط Apple）。搜索失败静默不弹错误。

## 测试

- `test/core/services/apple_maps_service_test.dart`（9 例）：mock MethodChannel；占位坐标判定；searchPlaces 参数透传、CN 折算/非 CN 原样、缺 countryCode 处理、原生报错静默；逆编码入参 GCJ02 化；不可用时不触通道。
- `test/features/merchants/services/region_matcher_test.dart`（11 例）：省市县链/直辖市扁平/市辖区单链穿透/后缀剥离/失配停市级/iso 优先/country 兜底/非 CN/无锚 null/全空 null/异常 null。
- `test/features/merchants/screens/merchant_form_match_test.dart`（5 例）：假服务 + MockRepo；名称流带出空字段；已有地址与真实坐标不覆盖；占位坐标被覆盖；地址流不回写地址；非 iOS 不出候选。

## 验证与已知限制

- `flutter analyze` 0 issue；三个新测试文件 25 例全过；全量测试与基线一致（存量失败与本次无关）。
- iOS CI 编译（GitHub Actions Mac runner，Xcode 26.6 / Release-iphoneos）：首跑失败——AppDelegate.swift 原本只 `import Flutter/UIKit`，新增 MapKit/CoreLocation 代码未补 import，报 MKLocalSearch/CLGeocoder/CLLocation/MKErrorDomain/kCLErrorDomain 等 cannot find in scope（闭包参数推断失败为连带）。修复：文件头补 `import CoreLocation` + `import MapKit`。
- **真机定标待办**（Windows 无法验证 iOS 行为）：① `MKLocalSearch` 中国大陆返回坐标是否 GCJ-02（当前按 CN→折算实现，与选点 `_appleNeedsGcj02` 同一待定标点）；② POI 命中质量与候选排序；③ 区划名称匹配率（Apple 对区县名的措辞，如「XX区」是否带后缀）。在 Mac VM/真机跑通后按结果调整折算开关。构建链路参照 [BUILD_iOS_无签名IPA与MacVM.md](BUILD_iOS_无签名IPA与MacVM.md)。
- MKLocalSearch 结果语言跟随设备语言（无 locale API）；en/ar 设备下中文区划匹配可能降级停在省级（国家仍按 isoCountryCode 命中）——逆编码路径已用 zh_CN locale 消除此问题，搜索路径无解属平台限制。

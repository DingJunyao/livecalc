# FEATURE: iOS 商家匹配按当前位置偏置

## 需求

iOS 维护商家时，用苹果地图 SDK 自动匹配（名称/地址输入 → 候选列表）优先根据设备当前位置查找匹配。

## 背景（原行为）

`merchant_form_screen.dart` 的名称/地址匹配把 `_coordinate`（当前选点/匹配写入）作为 `searchPlaces` 的偏置中心：

- 新增商家且尚未选点时 `center` 为 null，MKLocalSearch 无区域偏置，命中结果可能来自任何城市（连锁品牌名尤其明显）。
- 商家坐标为占位值（默认中心 39.9042,116.4074）时，会把北京默认中心当偏置（隐性 wart）。

## 实现（纯 Dart，无 Swift / 后端 / 迁移改动）

### 1. `core/services/device_location.dart`（新增）

`getCurrentLatLngSilently()`：静默定位——定位服务开关 → `checkPermission`（`denied` 时 `requestPermission`）→ `getCurrentPosition`（`LocationAccuracy.low` + 5s timeLimit，50km 偏置对精度要求很低）→ 返回 `LatLng`。定位服务关闭、权限被拒、超时、异常一律返回 null，不弹提示，由调用方回退。复用既有 geolocator 依赖；`NSLocationWhenInUseUsageDescription` 已在 Info.plist（MapLocateButton 早已配置）。

### 2. `merchant_form_screen.dart`

- `initState`：仅当 `_appleMaps.isAvailable && (_coordinate == null || isPlaceholderCoordinate(_coordinate))` 时，后台 `unawaited(_resolveCurrentLocation())` 静默取一次定位存 `_currentLocation`。**不阻塞首次搜索**（取到后用于后续匹配），失败保持 null 且本表单周期不再重试。权限请求因此发生在打开表单时（undetermined → 系统弹窗一次），拒绝则整周期回退原逻辑。
- `_searchCenter` getter（名称/地址两条流共用）按优先级：
  1. 用户手设/商家既有**真实**坐标（`!_coordinateFromMatch && _hasCoordinate`）——编辑既有商家按其自身位置找；
  2. 设备当前位置 `_currentLocation`——新增时优先按身边找（覆盖匹配写入的坐标，即「优先当前位置」）；
  3. 匹配写入的坐标（`_coordinateFromMatch`）——定位不可用时的回退锚点；
  4. 占位坐标/无坐标 → null 不偏置，交给系统默认（顺手修掉占位坐标当偏置的 wart）。
- 初始化取定位的门槛与优先级一致：只有初始态走不到优先级 1 的表单（新增/占位坐标）才取定位；既有商家编辑态不会触发权限弹窗。
- 注入点：`currentLocationResolver` 可选参数（默认 `getCurrentLatLngSilently`），测试注入固定值，不 mock geolocator 通道。

## 测试

`merchant_form_match_test.dart`：`_FakeAppleMaps` 补 `centers` 记录；新增 5 例——

1. 新增商家：名称匹配按当前位置偏置，且定位只取一次（二次搜索不重复取）；
2. 编辑既有商家：按商家坐标偏置，resolver 不被调用（`calls == 0`）；
3. 点选候选写入坐标后：再次匹配仍按当前位置偏置（当前位置 > 匹配写入坐标）；
4. 定位不可用（resolver 返回 null）：首搜不偏置，选候选后回退匹配写入坐标；
5. 地图选点后：匹配按选点坐标偏置，不用当前位置。

## 验证

- `flutter analyze`：本次改动文件 0 issue。worktree 存在并行会话未提交的 comparison 改动（compare_screen.dart 等 3 issue 属并行改动非存量），stash 对照 HEAD analyze 干净。
- `merchant_form_match_test.dart`（18 例）+ `apple_maps_service_test.dart`（3 例）21 例全过。
- Android / 非 iOS 不受影响：`isAvailable` 门槛在 onChanged 接线与 initState 取定位两处共同生效，不会触发权限弹窗。

## 边界与取舍

- 定位每次打开表单只取一次：不追踪移动中的刷新；`low` 精度 + 5s 上限足够 50km 偏置。
- 编辑既有商家（有真实坐标）永远按商家坐标偏置，不取当前位置——用户在修该商家本身。
- 新增表单中「点选候选写入坐标后再编辑」按当前位置偏置（用户明确要求优先当前位置）；异地录入连锁门店时靠文本匹配兜底（MKLocalSearch 文本命中不受区域偏置限制）。
- 无 Swift 改动：Dart 侧仍以 `centerLat/centerLng` 传偏置中心，`AppleMapsPlugin.searchPlaces` 原逻辑不变。

## 分支

feat/mobile-app（无后端/web 改动，无迁移）。

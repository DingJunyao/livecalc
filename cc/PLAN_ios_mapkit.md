# PLAN: 移动端 iOS 接入 MapKit（apple_maps_flutter）

> 日期：2026-08-11
> 分支：feat/mobile-app（仅移动端）
> 流程：用户反馈 iOS 地图丑 → brainstorming 设计 → 本文档（待实现）

## 背景与需求

移动端地图用 flutter_map 加载高德/腾讯**栅格瓦片**，在 iOS 高 DPI 屏上效果模糊、数据更新慢。根因：栅格瓦片分辨率锁死在瓦片源 scale，非矢量渲染，放大会糊。

不集成高德/百度/腾讯 SDK 的原因：商业授权费高，个人开发者用免费配额也有合规与法务骚扰风险。瓦片方案是绕开授权的最干净路径。

iOS 有免费的 MapKit（原生、矢量渲染、数据实时更新），可根治"丑"问题。Android 无统一免费原生地图（Google Maps 国内不可用，国产 SDK 有授权问题），保持 flutter_map 瓦片现状。

**关键事实（已查证）**：
- 原生 MapKit framework 无额度限制、完全免费（区别于 MapKit JS 网页版有日额度）。免费开发者账号（含不付费 Apple ID）照样用，不收费。
- MapKit 中国底图 = GCJ02（高德提供数据），不支持塞自定义瓦片。
- `apple_maps_flutter` 包基于 google_maps_flutter 改，iOS-only，最新 1.4.0（约 18 个月未更新，自标"开发者预览"）。

## 方案选型

**实现路径：apple_maps_flutter 包。**
- 备选 A：自写 Platform Views + 原生 MapKit（Swift）——完全可控、零停更依赖，但要写和维护 iOS 原生代码、工程量大，未选。
- 备选 B：vector_map_tiles 改善 flutter_map 清晰度——不解决数据更新，且国内需自搭源，不符合"用 MapKit"诉求，未选。
- 风险：包成熟度低。兜底：关键 bug 无人修则 fork 或退回自写原生。

**Marker：系统标准大头针降级**（不转图片还原药丸标签）。iOS 用原生大头针 + 名称标注，Android 仍药丸标签。各有原生味，不为统一而统一（药丸标签转图片是"为统一而统一"，YAGNI）。

**底图样式：保留标准/卫星切换。** iOS 去掉原高德/腾讯/OSM 切换菜单（MapKit 不支持自定义瓦片），改 MapKit mapType 标准/卫星二选一（零成本，卫星图看商家实际门面有用）。

## 关键设计

### 1. 架构与平台分支

原则：Android 现有 flutter_map 一行不动，iOS 新增 apple_maps_flutter 实现，运行时分流，不搞大重构。

三处组件（merchant_map_view 列表页 + 详情卡、map_point_picker 选点）各自这么组织：
1. 平台无关的业务逻辑（坐标点收集 `_points`、视角优先级 `_focusPlace > _singleCenter > _boundsFit`、坐标转换 `_toDisplay`/`_toWgs84`、定位状态机）提到共享 mixin，iOS/Android 两套 view 复用。现有逻辑搬家，不改行为。
2. 顶层 widget build 里 `Platform.isIOS` 分流：iOS → 新的 `_AppleMerchantMap`（apple_maps_flutter 包），Android → 现有 FlutterMap 原样。map_point_picker 同理。
3. 不用 conditional import（按 dart:io/html 分库，没法直接按 android/ios 平台分），运行时 `Platform` 判断更简单、风险低。

好处：Android 零回归，iOS 纯增量。

### 2. 坐标系处理 + 定位蓝点（GCJ02 的坑）

**坐标转换——复用，但方向要验证。** MapKit 中国底图是 GCJ02，和 flutter_map+高德瓦片同一套。iOS 上 Annotation/精度圈/Camera 坐标理论上和 Android 一样过 `_toDisplay`（WGS84→GCJ02），现有 [coordinate_transform.dart](../mobile/lib/core/geo/coordinate_transform.dart) 直接复用。

但「理论上」要打折——apple_maps_flutter 传给 MapKit 的坐标、点击地图 onTap 回调返回的坐标，到底是 WGS84 还是 GCJ02，iOS 版本/地区不同行为有差异，**不能想当然**。

**定位蓝点——照 Android 手动画，不用苹果原生 showsUserLocation。** 现有交互是「点定位按钮 → geolocator 拿一次 WGS84 → 移动视角 → 显示蓝点，再点清除」，离散触发非持续跟踪。iOS 照搬：geolocator WGS84 → 转 GCJ02 → 包的 Circle 画 5km 精度圈 + 蓝点。两边交互视觉一致，不踩苹果原生 userLocation 行为差异的坑。

### 3. 配置、错误处理、测试策略

**iOS 配置：** MapKit 是 iOS SDK 内置，CocoaPods 自动拉 apple_maps_flutter，不手动接 framework。Info.plist 定位权限 key（`NSLocationWhenInUseUsageDescription`）项目应已有（geolocator 在用），确认；老版 `io.flutter.embedded_views_preview` 是 Flutter <1.22 要求，现 3.x+ 默认支持 platform view，不需要（以实测为准）。[build-ios.yml](../.github/workflows/build-ios.yml) CI 要跑通 pod install 拉包。

**Android 零改动验证：** pubspec 加依赖后必须确认 Android 构建仍通过（包无 android 实现，理论无副作用，项目规矩是构建必须过——验一遍）。

**错误处理——轻量兜底：** platform view 基本和原生地图一样稳，不做自动 fallback（过度设计）。渲染异常时 log + 复用现有 EmptyState 显示错误占位。坐标偏移靠前置定标发现，非运行时错误。

**测试策略——回归保护重点在共享逻辑：** 视角计算、坐标转换、定位状态机提到 mixin 后照常单测断言不变（防 Android 回归护城河）。iOS 渲染部分：把「构造 Annotation 列表 / Camera 目标」提成纯函数单测，不碰平台；原生地图实际显示和 Marker 点击走真机验证。Android 现有测试全保留。

## 范围与边界

**做：** 三处地图组件 iOS MapKit 版（merchant_map_view 列表+详情、map_point_picker 选点），Android 三处不动。

**不做：**
- 地址搜索/地理编码（MapKit 有 CLGeocoder 但用户未提，YAGNI）
- Marker 聚合（apple_maps_flutter 包不支持，且当前商家量级用不上）
- iOS 渲染失败时自动 fallback 到 flutter_map（过度设计）

## 风险与待验证（实现时逐项过）

1. **GCJ02 坐标方向真机定标**（最大不确定性）——checklist：
   - 取已知 WGS84 点（天安门 39.9042, 116.4074）作 Annotation，看在 MapKit 上显示位置是否偏移
   - 若偏移：说明需 WGS84→GCJ02 转换（同 Android 高德瓦片）
   - 若不偏移：说明 MapKit 自动处理，不转换
   - 点击该位置，看 onTap 回调返回的坐标是 WGS84 还是 GCJ02，据此决定选点存储方向
2. **apple_maps_flutter 包成熟度**：关键 API（Annotation onTap、Circle、mapType、moveCamera、myLocation）逐个验证可用性；遇阻断性 bug 评估 fork/退回自写。
3. **Android 构建无副作用**：加依赖后 Android 编译/构建通过。
4. **Info.plist 配置**：定位权限 key 确认；embedded_views_preview 新版是否需要确认。
5. **build-ios.yml CI**：pod install 能拉到包，iOS 构建通过。

## 涉及文件（预估）

- **新增**：iOS 地图 widget（`_AppleMerchantMap` / `_AppleMapPicker`）、共享 mixin（视角/坐标/定位逻辑提取）、定标测试/纯函数单测
- **修改**：`merchant_map_view.dart`（顶层分流）、`map_point_picker.dart`（顶层分流）、`pubspec.yaml`（加 apple_maps_flutter 依赖）、`Info.plist`（权限 key）、`build-ios.yml`（验证）
- **不动**：Android flutter_map 实现逻辑、`coordinate_transform.dart`（复用）

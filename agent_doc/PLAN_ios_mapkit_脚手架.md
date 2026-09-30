# iOS MapKit 脚手架实现计划

> **For Claude:** REQUIRED SUB-SKILL: 用 superpowers:executing-plans / subagent-driven-development 逐任务执行。

**Goal:** 给移动端三处地图组件接入 iOS 原生 MapKit（apple_maps_flutter 包），iOS 显示矢量苹果地图 + 商家大头针 + 选点 + 标准/卫星切换；Android 一行不动。

**Architecture:** 顶层 widget `Platform.isIOS` 运行时分流——iOS 走新的 `_AppleMerchantMap`/`_AppleMapPicker`（apple_maps_flutter），Android 走现有 FlutterMap。视角计算提取为平台无关纯函数（WGS84 层面），iOS/Android 各自做坐标转换（GCJ02）+ 喂各自地图 API。

**Tech Stack:** Flutter 3.5 / flutter_map 6.1（Android）/ apple_maps_flutter 1.4.0（iOS）/ riverpod / latlong2。

---

## 关键约束（执行前必读）

1. **不 git commit**（项目 CLAUDE.md：未主动要求不执行 git 操作）。每个 Task 末尾不写 commit 步骤，留给用户。
2. **TDD 只应用于可单测部分**：视角纯函数（Task 2）。iOS widget（Platform View）在 host 测试环境 `Platform.isIOS == false` 不会被实例化，无法也不必单测——靠真机验证。
3. **Android 零回归**：现有 `merchant_map_view_test.dart` / `map_point_picker_test.dart` 全程跑绿作为回归护城河。重构后必须仍绿。
4. **坐标转换留定标开关**：iOS `_toDisplay` 先按「固定转 GCJ02」（同 Android 高德瓦片）实现，加 `// TODO(定标): 真机验证 MapKit 坐标方向` 标注。真机定标后可能要去掉转换——开关集中在 `_appleNeedsGcj02` 常量一处。
5. **iOS widget 文件会被 Android 编译**（dart 不区分平台），但运行时不实例化（Platform 分流）。只要 dart 语法 + apple_maps_flutter API 调用正确，analyze 即过。apple_maps_flutter 的 dart 代码 Android 可安全 import（native 部分只 iOS 加载）。
6. **构建验证**：`flutter analyze` + `flutter test` + `flutter build windows --debug`（项目通用验证构建，CLAUDE.md 提到先 taskkill 占用进程防 MSB3073）。

---

## Task 1: 接入 apple_maps_flutter 依赖 + iOS 权限配置

**Files:**
- Modify: `mobile/pubspec.yaml`（dependencies 加一行）
- Modify: `mobile/ios/Runner/Info.plist`（确认/补定位权限 key）

**Step 1: 加依赖**

`mobile/pubspec.yaml` 的 `dependencies:` 块（flutter_map 附近）加：

```yaml
  apple_maps_flutter: ^1.4.0
```

**Step 2: 安装依赖 + 验证 Android 无副作用**

Run:
```bash
cd mobile && flutter pub get
```
Expected: 依赖解析成功，无版本冲突。

Run:
```bash
cd mobile && flutter analyze
```
Expected: 通过，无因新依赖引入的错误（剩项目预先存在的 5 个不计）。

**Step 3: 确认 iOS 定位权限 key**

Read `mobile/ios/Runner/Info.plist`，确认含 `NSLocationWhenInUseUsageDescription`（geolocator 已在用，应已有）。若无则补：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>用于在地图上显示您的当前位置</string>
```

注：老版 `io.flutter.embedded_views_preview` 是 Flutter <1.22 要求，现 3.5+ 不需要，**不要加**。

**Step 4: 验证**

- `flutter pub get` 成功
- `flutter analyze` 无新增错误
- Info.plist 权限 key 存在

---

## Task 2: 提取视角计算纯函数 + TDD（防 Android 回归护城河）

**Files:**
- Create: `mobile/lib/features/merchants/widgets/merchant_map_logic.dart`
- Create: `mobile/test/features/merchants/widgets/merchant_map_logic_test.dart`
- Modify: `mobile/lib/features/merchants/widgets/merchant_map_view.dart`（Android 路径改用纯函数，行为不变）

**设计：** 把 `_MerchantMapViewState` 里平台无关的视角决策逻辑（`_points`、`_focusPlace`、`_singleCenter`、`_boundsFit` 的数据部分）提取为纯函数，**只算 WGS84 层面**（不做坐标转换）。坐标转换留给各平台 widget。

**Step 1: 写失败测试**

`mobile/test/features/merchants/widgets/merchant_map_logic_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/merchant_map_logic.dart';

void main() {
  group('computeMapView', () {
    test('无点：返回默认中心', () {
      final d = computeMapView(points: const []);
      expect(d.center, isNull);
      expect(d.useDefaultCenter, isTrue);
    });

    test('单点：中心=该点，zoom=点缩放', () {
      final p = const LatLng(31.23, 121.47);
      final d = computeMapView(points: [p]);
      expect(d.center, p);
      expect(d.zoom, kPointZoom);
      expect(d.useDefaultCenter, isFalse);
    });

    test('多点：center=null，提供 boundsPoints 供 fit/centroid', () {
      final pts = const [LatLng(31.20, 121.40), LatLng(31.30, 121.50)];
      final d = computeMapView(points: pts);
      expect(d.center, isNull);
      expect(d.boundsPoints, pts);
      expect(d.useDefaultCenter, isFalse);
    });

    test('focusPlace 优先级最高：覆盖 selectedPoint 与多点', () {
      final d = computeMapView(
        points: const [LatLng(31.2, 121.4), LatLng(31.3, 121.5)],
        focusPlace: const LatLng(30, 120),
        focusZoom: 13,
      );
      expect(d.center, const LatLng(30, 120));
      expect(d.zoom, 13);
    });

    test('selectedPoint 次优先：覆盖多点 bounds', () {
      final d = computeMapView(
        points: const [LatLng(31.2, 121.4), LatLng(31.3, 121.5)],
        selectedPoint: const LatLng(31.25, 121.45),
      );
      expect(d.center, const LatLng(31.25, 121.45));
      expect(d.zoom, kPointZoom);
    });

    test('多点重合：视为单点', () {
      const p = LatLng(31.2, 121.4);
      final d = computeMapView(points: const [p, p, p]);
      expect(d.center, p);
    });
  });

  group('centroid', () {
    test('多点质心', () {
      final c = centroid(const [LatLng(30, 120), LatLng(32, 122)]);
      expect(c.latitude, closeTo(31, 1e-9));
      expect(c.longitude, closeTo(121, 1e-9));
    });
  });
}
```

**Step 2: 运行测试验证失败**

Run: `cd mobile && flutter test test/features/merchants/widgets/merchant_map_logic_test.dart`
Expected: FAIL（merchant_map_logic.dart 不存在 / 函数未定义）。

**Step 3: 实现纯函数**

`mobile/lib/features/merchants/widgets/merchant_map_logic.dart`：

```dart
import 'package:latlong2/latlong.dart';

/// 视角缩放常量（从 merchant_map_view 既有魔法数提取，平台共享）。
const double kDefaultZoom = 11.0;
const double kPointZoom = 15.0;
const double kDefaultFocusZoom = 12.0;
const double kBoundsMaxZoom = 16.0;

/// 平台无关的视角决策（全部 WGS84，不含坐标转换）。
///
/// 各平台 widget 拿到此决策后，自行做 GCJ02 转换 + 喂各自地图 API：
/// - Android flutter_map：useDefaultCenter→initialCenter；center→initialCenter+zoom；
///   boundsPoints→CameraFit.bounds
/// - iOS apple_maps_flutter：center 或 centroid(boundsPoints)→CameraPosition(target, zoom)
class MapViewDecision {
  /// 单点中心（WGS84）。null 表示多点（用 [boundsPoints]）或默认。
  final LatLng? center;

  /// 多点边界点（WGS84）。单点/默认时为空。
  final List<LatLng> boundsPoints;

  final double zoom;

  /// 无任何有效点时为 true，调用方用默认中心。
  final bool useDefaultCenter;

  const MapViewDecision({
    this.center,
    this.boundsPoints = const [],
    this.zoom = kDefaultZoom,
    this.useDefaultCenter = false,
  });
}

/// 计算地图视角决策（优先级：focusPlace > selectedPoint > 单点 > 多点 bounds > 默认）。
///
/// [points] 为全部有效坐标（WGS84）。[selectedPoint] 为选中商家坐标。
/// [focusPlace]/[focusZoom] 为「常用地点」聚焦。
MapViewDecision computeMapView({
  required List<LatLng> points,
  LatLng? selectedPoint,
  LatLng? focusPlace,
  double? focusZoom,
}) {
  // 1. 常用地点聚焦（最高优先级）
  if (focusPlace != null) {
    return MapViewDecision(
      center: focusPlace,
      zoom: focusZoom ?? kDefaultFocusZoom,
    );
  }

  // 2. 选中商家
  if (selectedPoint != null) {
    return MapViewDecision(center: selectedPoint, zoom: kPointZoom);
  }

  // 3. 无点
  if (points.isEmpty) {
    return const MapViewDecision(useDefaultCenter: true);
  }

  // 4. 单点
  if (points.length == 1) {
    return MapViewDecision(center: points.first, zoom: kPointZoom);
  }

  // 5. 多点重合 → 视为单点
  if (_allSame(points)) {
    return MapViewDecision(center: points.first, zoom: kPointZoom);
  }

  // 6. 多点 bounds
  return MapViewDecision(boundsPoints: points, zoom: kDefaultZoom);
}

bool _allSame(List<LatLng> pts) {
  final first = pts.first;
  for (final p in pts.skip(1)) {
    if (p.latitude != first.latitude || p.longitude != first.longitude) {
      return false;
    }
  }
  return true;
}

/// 多点质心（WGS84）。iOS 多点视角用（apple_maps_flutter 无 bounds fit）。
LatLng centroid(List<LatLng> points) {
  final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
  final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
  return LatLng(lat, lng);
}
```

**Step 4: 运行测试验证通过**

Run: `cd mobile && flutter test test/features/merchants/widgets/merchant_map_logic_test.dart`
Expected: PASS（全绿）。

**Step 5: 重构 merchant_map_view（Android）复用纯函数，行为不变**

`mobile/lib/features/merchants/widgets/merchant_map_view.dart`：
- import `merchant_map_logic.dart`
- `_focusPlace` / `_singleCenter` / `_boundsFit` / `_buildOptions` 的数据计算改用 `computeMapView(...)`，但**坐标转换（_toDisplay）和 flutter_map 的 CameraFit/API 保持原样**。
- 常量 `_defaultZoom` / `_pointZoom` 改用 `kDefaultZoom` / `kPointZoom`（同值，只是统一来源）。

⚠️ 这步是机械重构，不改行为。关键是重构后 `merchant_map_view_test.dart` 全绿。

**Step 6: 回归验证**

Run: `cd mobile && flutter test test/features/merchants/widgets/merchant_map_view_test.dart`
Expected: PASS（现有用例全绿，证明 Android 路径无回归）。

Run: `cd mobile && flutter test`
Expected: 全量绿。

---

## Task 3: 平台分流 + iOS 商家地图骨架

**Files:**
- Create: `mobile/lib/features/merchants/widgets/apple_merchant_map.dart`（iOS 实现）
- Modify: `mobile/lib/features/merchants/widgets/merchant_map_view.dart`（顶层 build 分流）

**Step 1: 新建 iOS 商家地图 widget**

`mobile/lib/features/merchants/widgets/apple_merchant_map.dart`：

```dart
import 'dart:io' show Platform; // 仅 build 时判断，Android 编译安全（运行时不实例化）
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo/coordinate_transform.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../profile/models/user_place.dart';
import '../models/merchant.dart';
import '../providers/map_config_provider.dart';
import 'merchant_map_logic.dart';

/// iOS 原生 MapKit 版商家地图（仅 iOS 运行时实例化）。
///
/// 坐标转换：MapKit 中国底图为 GCJ02，Annotation/Circle 坐标过 [_toDisplay]。
/// TODO(定标): 真机验证 MapKit 传入/返回坐标方向，必要时翻转 _appleNeedsGcj02。
class AppleMerchantMap extends StatefulWidget {
  final List<Merchant> merchants;
  final int? selectedId;
  final List<LatLng> allCoordinates;
  final List<UserPlace> places;
  final int? currentPlaceId;
  final ValueChanged<int?>? onPlaceChanged;
  final bool showControls;

  const AppleMerchantMap({
    super.key,
    required this.merchants,
    this.selectedId,
    this.allCoordinates = const [],
    this.places = const [],
    this.currentPlaceId,
    this.onPlaceChanged,
    this.showControls = false,
  });

  @override
  State<AppleMerchantMap> createState() => _AppleMerchantMapState();
}

/// 定标开关：true=显示坐标需 WGS84→GCJ02（同 Android 高德瓦片）。
/// 真机定标后若 MapKit 自动处理则改 false。
const bool _appleNeedsGcj02 = true;

class _AppleMerchantMapState extends State<AppleMerchantMap> {
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);

  AppleMapController? _controller;
  MapType _mapType = MapType.standard;

  /// WGS84 → 显示坐标（GCJ02 底图转换，待定标）。
  LatLng _toDisplay(LatLng wgs) {
    if (!_appleNeedsGcj02) return wgs;
    final (lat, lng) = wgs84ToGcj02(wgs.latitude, wgs.longitude);
    return LatLng(lat, lng);
  }

  List<Merchant> get _validMerchants => widget.merchants
      .where((m) => m.latitude != null && m.longitude != null && m.latitude != 0)
      .toList();

  List<LatLng> get _points {
    if (widget.allCoordinates.isNotEmpty) return widget.allCoordinates;
    return [for (final m in _validMerchants) LatLng(m.latitude!, m.longitude!)];
  }

  (LatLng, double)? get _focusPlace {
    final id = widget.currentPlaceId;
    if (id == null) return null;
    for (final p in widget.places) {
      if (p.id == id) return (LatLng(p.latitude, p.longitude), 12.0);
    }
    return null;
  }

  LatLng? get _selectedPoint {
    final id = widget.selectedId;
    if (id == null) return null;
    for (final m in _validMerchants) {
      if (m.id == id) return LatLng(m.latitude!, m.longitude!);
    }
    return null;
  }

  CameraPosition get _initialCamera {
    final focus = _focusPlace;
    if (focus != null) {
      return CameraPosition(target: _toDisplay(focus.$1), zoom: focus.$2);
    }
    final decision = computeMapView(
      points: _points,
      selectedPoint: _selectedPoint,
    );
    if (decision.useDefaultCenter) {
      return const CameraPosition(target: _defaultCenter, zoom: kDefaultZoom);
    }
    final c = decision.center ?? centroid(decision.boundsPoints);
    return CameraPosition(target: _toDisplay(c), zoom: decision.zoom);
  }

  Set<Annotation> get _annotations => {
        for (final m in _validMerchants)
          Annotation(
            annotationId: AnnotationId('merchant-${m.id}'),
            icon: BitmapDescriptor.markerAnnotation,
            position: _toDisplay(LatLng(m.latitude!, m.longitude!)),
            infoWindow: InfoWindow(title: m.name),
            onTap: () => _showInfo(m),
          ),
      };

  void _showInfo(Merchant m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${m.name}${m.address == null || m.address!.isEmpty ? '' : '\n${m.address}'}')),
    );
  }

  void _onMapCreated(AppleMapController c) {
    _controller = c;
  }

  @override
  Widget build(BuildContext context) {
    if (_validMerchants.isEmpty) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: '暂无商家位置',
        subtitle: '商家缺少坐标信息时无法在地图显示',
      );
    }
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AppleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: _initialCamera,
          mapType: _mapType,
          annotations: _annotations,
          myLocationEnabled: false,
        ),
      ),
      if (widget.showControls)
        Positioned(
          top: 8,
          right: 8,
          child: _buildStyleSwitch(context),
        ),
    ]);
  }

  /// 标准/卫星切换（替代 Android 的底图切换菜单）。
  Widget _buildStyleSwitch(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: PopupMenuButton<MapType>(
        key: const ValueKey('apple-layer-switch'),
        tooltip: '切换底图样式',
        icon: const Icon(Icons.layers_outlined),
        onSelected: (v) => setState(() => _mapType = v),
        itemBuilder: (_) => const [
          PopupMenuItem(value: MapType.standard, child: Text('标准')),
          PopupMenuItem(value: MapType.satellite, child: Text('卫星')),
        ],
      ),
    );
  }
}
```

注：定位蓝点、常用地点菜单、selectedId 高亮、互斥逻辑等**留到定标后/后续完善**（脚手架范围外）。定位依赖坐标方向，留 TODO。

**Step 2: 顶层 merchant_map_view 加平台分流**

`mobile/lib/features/merchants/widgets/merchant_map_view.dart` 的 `build` 方法开头（在 `final markers = _validMerchants;` 之前）插入：

```dart
@override
Widget build(BuildContext context) {
  // iOS 走原生 MapKit（apple_maps_flutter），Android 走 flutter_map 瓦片。
  if (Platform.isIOS) {
    return AppleMerchantMap(
      merchants: widget.merchants,
      selectedId: widget.selectedId,
      allCoordinates: widget.allCoordinates,
      mapConfig: widget.mapConfig,
      places: widget.places,
      currentPlaceId: widget.currentPlaceId,
      onPlaceChanged: widget.onPlaceChanged,
      showControls: widget.showControls,
    );
  }
  // ... 现有 FlutterMap 实现原样保留 ...
```

文件顶部 import：
```dart
import 'dart:io' show Platform;
import 'apple_merchant_map.dart';
```

⚠️ `AppleMerchantMap` 少传了 `mapConfig`（iOS 不需要底图配置，但构造体留参数兼容）。按实际构造体调整。

**Step 3: 验证 analyze + Android 回归**

Run: `cd mobile && flutter analyze`
Expected: 无新增错误。

Run: `cd mobile && flutter test test/features/merchants/widgets/merchant_map_view_test.dart`
Expected: 全绿（测试环境 Platform.isIOS==false，走 Android 分支，不受影响）。

---

## Task 4: iOS 地图选点骨架

**Files:**
- Create: `mobile/lib/features/merchants/widgets/apple_map_picker.dart`（iOS 实现）
- Modify: `mobile/lib/features/merchants/widgets/map_point_picker.dart`（顶层分流）

**Step 1: 新建 iOS 选点 widget**

`mobile/lib/features/merchants/widgets/apple_map_picker.dart`：

```dart
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo/coordinate_transform.dart';

/// iOS 原生 MapKit 版选点组件（仅 iOS 运行时实例化）。回调返回 WGS84。
///
/// TODO(定标): 真机验证 onTap 返回坐标方向，必要时翻转 _appleNeedsGcj02。
class AppleMapPicker extends StatefulWidget {
  final LatLng? initialValue;
  final ValueChanged<LatLng>? onChanged;
  final double height;
  final double width;

  const AppleMapPicker({
    super.key,
    this.initialValue,
    this.onChanged,
    this.height = 240,
    this.width = double.infinity,
  });

  @override
  State<AppleMapPicker> createState() => _AppleMapPickerState();
}

const bool _appleNeedsGcj02 = true;
const LatLng _defaultCenter = LatLng(39.9042, 116.4074);

class _AppleMapPickerState extends State<AppleMapPicker> {
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);
  LatLng? _wgs;
  MapType _mapType = MapType.standard;

  @override
  void initState() {
    super.initState();
    _wgs = widget.initialValue;
  }

  LatLng _toDisplay(LatLng wgs) {
    if (!_appleNeedsGcj02) return wgs;
    final (lat, lng) = wgs84ToGcj02(wgs.latitude, wgs.longitude);
    return LatLng(lat, lng);
  }

  LatLng _toWgs84(LatLng display) {
    if (!_appleNeedsGcj02) return display;
    final (lat, lng) = gcj02ToWgs84(display.latitude, display.longitude);
    return LatLng(lat, lng);
  }

  void _onTap(LatLng pos) {
    final wgs = _toWgs84(pos);
    setState(() => _wgs = wgs);
    widget.onChanged?.call(wgs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wgs = _wgs;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          width: widget.width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(children: [
              AppleMap(
                initialCameraPosition: CameraPosition(
                  target: _toDisplay(wgs ?? _defaultCenter),
                  zoom: 12,
                ),
                mapType: _mapType,
                onTap: _onTap,
                annotations: wgs == null
                    ? {}
                    : {
                        Annotation(
                          annotationId: const AnnotationId('picked'),
                          icon: BitmapDescriptor.markerAnnotation,
                          position: _toDisplay(wgs),
                        ),
                      },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: theme.colorScheme.surface,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: PopupMenuButton<MapType>(
                    key: const ValueKey('apple-picker-layer-switch'),
                    tooltip: '切换底图样式',
                    icon: const Icon(Icons.layers_outlined, size: 20),
                    onSelected: (v) => setState(() => _mapType = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: MapType.standard, child: Text('标准')),
                      PopupMenuItem(value: MapType.satellite, child: Text('卫星')),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        if (wgs == null)
          Text('点击地图选择位置',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))
        else
          Text(
            '纬度: ${wgs.latitude.toStringAsFixed(6)} · 经度: ${wgs.longitude.toStringAsFixed(6)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
      ],
    );
  }
}
```

⚠️ 计划里 `_appleNeedsGcj02` 和 `_defaultCenter` 写了重复顶层占位，**实现时去掉重复声明**（保留类内 static const 一份即可）。此为计划草案瑕疵，执行时修正。

**Step 2: 顶层 map_point_picker 加平台分流**

`mobile/lib/features/merchants/widgets/map_point_picker.dart` 的 `build` 开头插入分流。由于 MapPointPicker 是 ConsumerStatefulWidget 且 build 内用了 mapConfig/layer，iOS 分流需在进入 FlutterMap 逻辑前 return：

```dart
@override
Widget build(BuildContext context) {
  if (Platform.isIOS) {
    return AppleMapPicker(
      initialValue: widget.initialValue,
      onChanged: widget.onChanged,
      height: widget.height,
      width: widget.width,
    );
  }
  // ... 现有 FlutterMap 实现原样保留 ...
```

顶部 import：
```dart
import 'dart:io' show Platform;
import 'apple_map_picker.dart';
```

**Step 3: 验证**

Run: `cd mobile && flutter analyze`
Run: `cd mobile && flutter test test/features/merchants/widgets/map_point_picker_test.dart`
Expected: 全绿（Platform.isIOS==false 走 Android 分支）。

---

## Task 5: 构建验证 + 文档收尾

**Step 1: 全量分析 + 测试**

Run:
```bash
cd mobile && flutter analyze
```
Expected: 0 新增（剩 5 个预先存在）。

Run:
```bash
cd mobile && flutter test
```
Expected: 全量绿（含 Task 2 新增 logic_test）。

**Step 2: Windows 构建验证（项目通用验证）**

```bash
# 先杀占用输出的调试进程（CLAUDE.md 已知坑，防 MSB3073）
taskkill //F //IM livecalc_mobile.exe 2>/dev/null || true
cd mobile && flutter build windows --debug
```
Expected: 构建通过。

注：iOS 构建验证（`flutter build ios`）需 macOS 环境，本机 Windows 无法跑。iOS 实际构建留给 [build-ios.yml](../../.github/workflows/build-ios.yml) CI 或用户真机。

**Step 3: 更新设计文档**

`cc/PLAN_ios_mapkit.md` 末尾加「脚手架完成情况」小节，记录：
- 已完成：依赖接入、视角纯函数提取、iOS 商家地图/选点骨架、平台分流
- 待定标：`_appleNeedsGcj02` 真机验证、定位蓝点、selectedId 高亮、常用地点菜单（iOS 版）

**Step 4: 更新 CLAUDE.md 最新修复记录**

加一条索引指向 `cc/PLAN_ios_mapkit.md`（设计）+ 脚手架进展（简短）。

---

## 风险与回退

| 风险 | 应对 |
|---|---|
| apple_maps_flutter 1.4.0 在项目 Flutter 3.5 / Dart 3.5 编译失败 | 降版本或评估替代；最坏退回自写 Platform View |
| apple_maps_flutter API 与计划假设不符（如 Annotation 参数名） | 执行时以 example 源码为准修正（Task 已附 example 出处） |
| iOS Platform View 在某些场景渲染异常 | 真机验证；EmptyState 占位兜底 |
| 坐标定标结果与「转 GCJ02」假设相反 | `_appleNeedsGcj02 = false` 一处翻转，全 iOS 路径自动适配 |
| Android 回归 | Task 2 的纯函数提取是唯一动 Android 的步骤，merchant_map_view_test 全绿即安全 |

## 不做的事（脚手架外，留定标后）

- iOS 定位蓝点 + 精度圈（依赖坐标方向）
- iOS selectedId 大头针高亮色 / 选中态
- iOS 常用地点菜单（places 下拉）
- 地址搜索 / 地理编码（CLGeocoder，YAGNI）
- GCJ02 真机定标（用户真机执行，写 checklist 在 PLAN_ios_mapkit.md）

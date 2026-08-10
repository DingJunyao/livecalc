import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:com_a4ding_livecalc/core/geo/coordinate_transform.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/merchant_map_view.dart';
import 'package:com_a4ding_livecalc/features/profile/models/user_place.dart';

/// 上海坐标：WGS84 (31.2304, 121.4737) → GCJ02 (31.228454, 121.478223)
const _shanghai = LatLng(31.2304, 121.4737);

/// 内存瓦片：消除测试里真实网络请求的噪音。
class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class _FakeGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      Position(
        latitude: 31.25,
        longitude: 121.5,
        timestamp: DateTime(2026, 8, 9),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

const _mapConfig = MapConfigState(
  layers: [amapLayer, tencentLayer, osmLayer],
  defaultId: 'amap',
);
const _places = [
  UserPlace(id: 1, name: '家', latitude: 31.2304, longitude: 121.4737,
      kind: 'home', isDefault: true, viewRadiusKm: 5),
  UserPlace(id: 2, name: '公司', latitude: 31.25, longitude: 121.5, kind: 'work'),
];

Future<void> pumpMap(
  WidgetTester tester, {
  List<Merchant> merchants = const [
    Merchant(id: 1, name: '盒马鲜生', latitude: 31.2304, longitude: 121.4737),
  ],
  MapController? controller,
  MapConfigState mapConfig = _mapConfig,
  List<UserPlace> places = _places,
  int? currentPlaceId,
  ValueChanged<int?>? onPlaceChanged,
  bool showControls = true,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 500,
          height: 300,
          child: MerchantMapView(
            merchants: merchants,
            controller: controller,
            mapConfig: mapConfig,
            places: places,
            currentPlaceId: currentPlaceId,
            onPlaceChanged: onPlaceChanged,
            showControls: showControls,
            tileProvider: _MemoryTileProvider(),
          ),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

/// 商家 MarkerLayer（最后一个 MarkerLayer）。
MarkerLayer merchantLayer(WidgetTester tester) =>
    tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).last;

void main() {
  late GeolocatorPlatform original;

  setUp(() {
    original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FakeGeolocator();
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
  });

  testWidgets('GCJ02 底图（高德默认）：商家标记与初始视角都被转换', (tester) async {
    final controller = MapController();
    await pumpMap(tester, controller: controller);

    final (expLat, expLng) = wgs84ToGcj02(_shanghai.latitude, _shanghai.longitude);
    final point = merchantLayer(tester).markers.single.point;
    expect(point.latitude, closeTo(expLat, 1e-6));
    expect(point.longitude, closeTo(expLng, 1e-6));
    // 初始视角同样转换（偏移量级上百米）
    final center = controller.camera.center;
    expect((center.latitude - _shanghai.latitude).abs(), greaterThan(0.001));
  });

  testWidgets('切底图到 OSM：标记回到 WGS84 原值', (tester) async {
    await pumpMap(tester);

    await tester.tap(find.byKey(const ValueKey('layer-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OSM'));
    await tester.pump(const Duration(milliseconds: 100));

    final point = merchantLayer(tester).markers.single.point;
    expect(point.latitude, closeTo(_shanghai.latitude, 1e-9));
    expect(point.longitude, closeTo(_shanghai.longitude, 1e-9));
  });

  testWidgets('地点下拉：含「全部商家」与地点名，选择后回调 + 视角移动', (tester) async {
    final controller = MapController();
    int? changedTo;
    await pumpMap(
      tester,
      controller: controller,
      currentPlaceId: 1,
      onPlaceChanged: (id) => changedTo = id,
    );

    await tester.tap(find.byKey(const ValueKey('place-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('全部商家'), findsWidgets);
    await tester.tap(find.text('公司').last);
    await tester.pumpAndSettle();

    expect(changedTo, 2);
    // 回调只是通知父组件，widget 的 currentPlaceId 仍为 1（家）：
    // 视角保持在家（GCJ02 转换后），聚焦移动由「currentPlaceId 变化」测试覆盖
    final (expLat, _) = wgs84ToGcj02(_shanghai.latitude, _shanghai.longitude);
    final center = controller.camera.center;
    expect(center.latitude, closeTo(expLat, 1e-6));
  });

  testWidgets('currentPlaceId 变化：地图聚焦到所选地点（坐标已 GCJ02 转换）', (tester) async {
    final controller = MapController();
    int? selected = 1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            height: 300,
            child: StatefulBuilder(builder: (ctx, setState) {
              return MerchantMapView(
                merchants: const [
                  Merchant(id: 1, name: '盒马鲜生', latitude: 31.2304, longitude: 121.4737),
                ],
                controller: controller,
                mapConfig: _mapConfig,
                places: _places,
                currentPlaceId: selected,
                onPlaceChanged: (id) => setState(() => selected = id),
                showControls: true,
                tileProvider: _MemoryTileProvider(),
              );
            }),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // 下拉选「公司」→ 父组件 setState → didUpdateWidget 聚焦
    await tester.tap(find.byKey(const ValueKey('place-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('公司').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    final (expLat, expLng) = wgs84ToGcj02(31.25, 121.5);
    final center = controller.camera.center;
    expect(center.latitude, closeTo(expLat, 1e-6));
    expect(center.longitude, closeTo(expLng, 1e-6));
  });

  testWidgets('定位：点按钮出蓝点并移动视角，再点清除', (tester) async {
    final controller = MapController();
    await pumpMap(tester, controller: controller);

    await tester.tap(find.byKey(const ValueKey('locate-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('current-location-marker')), findsOneWidget);
    // 定位点 (31.25, 121.5) 在高德底图上同样转换
    final (expLat, expLng) = wgs84ToGcj02(31.25, 121.5);
    final center = controller.camera.center;
    expect(center.latitude, closeTo(expLat, 1e-6));

    // 再点一次清除
    await tester.tap(find.byKey(const ValueKey('locate-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('current-location-marker')), findsNothing);
  });

  testWidgets('places 为空：隐藏地点下拉', (tester) async {
    await pumpMap(tester, places: const []);
    expect(find.byKey(const ValueKey('place-dropdown')), findsNothing);
  });

  testWidgets('showControls=false：不显示控件列', (tester) async {
    await pumpMap(tester, showControls: false);
    expect(find.byKey(const ValueKey('layer-switch')), findsNothing);
    expect(find.byKey(const ValueKey('locate-button')), findsNothing);
  });

  testWidgets('无商家坐标：显示空态，无控件', (tester) async {
    await pumpMap(tester, merchants: const []);
    expect(find.text('暂无商家位置'), findsOneWidget);
    expect(find.byKey(const ValueKey('layer-switch')), findsNothing);
  });
}

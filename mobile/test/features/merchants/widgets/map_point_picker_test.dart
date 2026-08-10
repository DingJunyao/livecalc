import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/geo/coordinate_transform.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/map_point_picker.dart';

class MockRepo extends Mock implements MerchantRepository {}

/// 内存瓦片：消除测试里真实网络请求的噪音。
class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

Future<void> pumpPicker(
  WidgetTester tester, {
  required MapConfigState mapConfig,
  LatLng? initialValue,
  ValueChanged<LatLng>? onChanged,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mapConfigProvider.overrideWith(
        (ref) => MapConfigNotifier(MockRepo().._stub(mapConfig)),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: MapPointPicker(
              initialValue: initialValue,
              onChanged: onChanged,
              tileProvider: _MemoryTileProvider(),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

extension on MockRepo {
  void _stub(MapConfigState cfg) {
    when(() => getMapConfig()).thenAnswer((_) async => {
          'available_maps': cfg.layers.map((l) => l.id).toList(),
          'default_map': cfg.defaultId,
          'map_enabled': true,
        });
  }
}

/// 默认视角是北京 (39.9042, 116.4074)，高德底图下中心点是 GCJ02 值。
const _mapConfig = MapConfigState(
  layers: [amapLayer, tencentLayer, osmLayer],
  defaultId: 'amap',
);

void main() {
  testWidgets('点击地图：高德底图下 onChanged 收到 WGS84（已逆转换）', (tester) async {
    LatLng? picked;
    await pumpPicker(tester, mapConfig: _mapConfig, onChanged: (v) => picked = v);

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(picked, isNotNull);
    // 点的是地图中心 = initialCenter = wgs84ToGcj02(北京)，逆转换后应回到 WGS84 北京
    final (expLat, expLng) = wgs84ToGcj02(39.9042, 116.4074);
    final (wLat, wLng) = gcj02ToWgs84(expLat, expLng);
    expect(picked!.latitude, closeTo(wLat, 1e-4));
    expect(picked!.longitude, closeTo(wLng, 1e-4));
    // 与真实 WGS84 北京接近（单步近似逆固有误差）
    expect(picked!.latitude, closeTo(39.9042, 1e-4));
    expect(picked!.longitude, closeTo(116.4074, 1e-4));
  });

  testWidgets('点击地图：OSM 底图下坐标原样（不转换）', (tester) async {
    const osm = MapConfigState(
      layers: [osmLayer],
      defaultId: 'osm',
    );
    LatLng? picked;
    await pumpPicker(tester, mapConfig: osm, onChanged: (v) => picked = v);

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(picked, isNotNull);
    expect(picked!.latitude, closeTo(39.9042, 1e-6));
    expect(picked!.longitude, closeTo(116.4074, 1e-6));
  });

  testWidgets('有初始值：显示标记与坐标文本', (tester) async {
    await pumpPicker(
      tester,
      mapConfig: _mapConfig,
      initialValue: const LatLng(31.2304, 121.4737),
    );

    expect(find.byIcon(Icons.location_pin), findsOneWidget);
    expect(find.textContaining('31.230400'), findsOneWidget);
    expect(find.textContaining('121.473700'), findsOneWidget);
  });

  testWidgets('无初始值：显示选点提示，无标记', (tester) async {
    await pumpPicker(tester, mapConfig: _mapConfig);

    expect(find.text('点击地图选择位置'), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsNothing);
  });

  testWidgets('切底图：标记保留、坐标不变', (tester) async {
    await pumpPicker(
      tester,
      mapConfig: _mapConfig,
      initialValue: const LatLng(31.2304, 121.4737),
    );

    await tester.tap(find.byKey(const ValueKey('picker-layer-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OSM').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.location_pin), findsOneWidget);
    expect(find.textContaining('31.230400'), findsOneWidget);
    expect(find.textContaining('121.473700'), findsOneWidget);
  });

  testWidgets('切底图到 OSM 后点击：onChanged 收到原样 WGS84', (tester) async {
    LatLng? picked;
    await pumpPicker(tester, mapConfig: _mapConfig, onChanged: (v) => picked = v);

    await tester.tap(find.byKey(const ValueKey('picker-layer-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OSM').last);
    await tester.pumpAndSettle();

    // PopupMenu 关闭后 overlay 清理还需额外帧，否则第一个 tap 会命中残留 barrier
    await tester.pump();
    await tester.pump();

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(picked!.latitude, closeTo(39.9042, 1e-6));
    expect(picked!.longitude, closeTo(116.4074, 1e-6));
  });
}

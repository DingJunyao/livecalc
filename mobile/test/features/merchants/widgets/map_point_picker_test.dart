import 'dart:async';
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
  // 先触发 load()：MapPointPicker 在 initState 读取 provider 状态，
  // 不 load 则永远是初始兜底（仅 OSM），高德/腾讯底图断言会静默走错路径
  final container = ProviderContainer(overrides: [
    mapConfigProvider.overrideWith(
      (ref) => MapConfigNotifier(MockRepo().._stub(mapConfig)),
    ),
  ]);
  await container.read(mapConfigProvider.notifier).load();
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
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
  testWidgets('auto-loads map config before exposing tile layers',
      (tester) async {
    final response = Completer<Map<String, dynamic>>();
    final repo = MockRepo();
    when(() => repo.getMapConfig()).thenAnswer((_) => response.future);
    final container = ProviderContainer(overrides: [
      mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapPointPicker(tileProvider: _MemoryTileProvider()),
          ),
        ),
      ),
    ));

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byKey(const ValueKey('picker-layer-switch')), findsNothing);

    response.complete({
      'available_maps': ['amap', 'tencent', 'osm'],
      'default_map': 'amap',
      'map_enabled': true,
    });
    await tester.pumpAndSettle();

    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
      amapLayer.urlTemplate,
    );
    await tester.tap(find.byKey(const ValueKey('picker-layer-switch')));
    await tester.pumpAndSettle();
    expect(find.text(amapLayer.label), findsOneWidget);
    expect(find.text(tencentLayer.label), findsOneWidget);
    expect(find.text(osmLayer.label), findsOneWidget);
  });

  testWidgets('点击地图：高德底图下 onChanged 收到 WGS84（已逆转换）', (tester) async {
    LatLng? picked;
    await pumpPicker(tester,
        mapConfig: _mapConfig, onChanged: (v) => picked = v);

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

  testWidgets('切底图到 OSM 后点击：onChanged 收到显示坐标原样（不逆转换）', (tester) async {
    LatLng? picked;
    await pumpPicker(tester,
        mapConfig: _mapConfig, onChanged: (v) => picked = v);

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

    // 切底图不移动视角：中心仍是高德时的 GCJ02 北京，OSM 下显示坐标即该位置的
    // WGS84 表示，点击原样返回（无逆转换）
    final (gcjLat, gcjLng) = wgs84ToGcj02(39.9042, 116.4074);
    expect(picked!.latitude, closeTo(gcjLat, 1e-6));
    expect(picked!.longitude, closeTo(gcjLng, 1e-6));
  });

  testWidgets('腾讯底图：TileLayer tms=true（TMS y 轴翻转）', (tester) async {
    const tencent = MapConfigState(
      layers: [tencentLayer],
      defaultId: 'tencent',
    );
    await pumpPicker(tester, mapConfig: tencent);

    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).tms,
      isTrue,
      reason: '腾讯瓦片 y 轴从南到北（TMS），不翻转则北半球显示南半球（如中国变印尼）',
    );
  });
}

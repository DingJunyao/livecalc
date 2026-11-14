import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/services/apple_maps_service.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class _MockRepo extends Mock implements MerchantRepository {}

/// 强制开启苹果地图匹配的假服务（不触 MethodChannel）。
class _FakeAppleMaps extends AppleMapsService {
  _FakeAppleMaps() : super();

  final searches = <String>[];
  List<ApplePlace> results = const [];

  @override
  bool get isAvailable => true;

  @override
  Future<List<ApplePlace>> searchPlaces(
    String query, {
    LatLng? center,
    double radiusMeters = 50000,
  }) async {
    searches.add(query);
    return results;
  }

  @override
  Future<ApplePlace?> reverseGeocodeForWgs84(
    double latitude,
    double longitude,
  ) async =>
      null;
}

const _fakePlace = ApplePlace(
  name: '蜜雪冰城（玄武路店）',
  address: '江苏省南京市玄武区玄武路1号',
  latitude: 32.04,
  longitude: 118.79,
  country: '中国',
  countryCode: 'CN',
  administrativeArea: '江苏省',
  locality: '南京市',
  subLocality: '玄武区',
  thoroughfare: '玄武路',
);

/// 内存瓦片：消除测试里真实网络请求的噪音。
class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

/// 商家表单苹果地图匹配：名称/地址输入 → 候选 → 点选按规则带出
/// （只填空字段/占位值，已有值不覆盖；地址流永不回写地址）。
void main() {
  late _MockRepo repo;
  late _FakeAppleMaps appleMaps;

  setUp(() {
    repo = _MockRepo();
    appleMaps = _FakeAppleMaps();
    appleMaps.results = const [_fakePlace];
    when(() => repo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': ['osm'],
          'default_map': 'osm',
          'map_enabled': true,
        });
    // 区划树（region_matcher 与 RegionSelectField 共用同一 mock）。
    final regionsByParent = <int?, List<Map<String, dynamic>>>{
      null: [
        {'id': 1, 'name': '中国', 'iso_country': 'CN', 'name_en': 'China'},
      ],
      1: [
        {'id': 10, 'name': '江苏省'},
      ],
      10: [
        {'id': 100, 'name': '南京市'},
      ],
      100: [
        {'id': 1000, 'name': '玄武区'},
        {'id': 1001, 'name': '鼓楼区'},
      ],
    };
    when(() => repo.listRegions(
          parentId: any(named: 'parentId'),
          level: any(named: 'level'),
        )).thenAnswer((invocation) async {
      final parentId = invocation.namedArguments[#parentId] as int?;
      return regionsByParent[parentId] ?? <Map<String, dynamic>>[];
    });
    when(() => repo.getRegion(1000)).thenAnswer((_) async => {
          'id': 1000,
          'level': 3,
          'ancestors': [
            {'id': 1, 'level': 0},
            {'id': 10, 'level': 1},
            {'id': 100, 'level': 2},
          ],
        });
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    Merchant? merchant,
    bool injectAppleMaps = true,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MerchantFormScreen(
                  merchant: merchant,
                  isAdmin: false,
                  repository: repo,
                  mapTileProvider: _MemoryTileProvider(),
                  appleMapsService: injectAppleMaps ? appleMaps : null,
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> typeAndSearch(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    await tester.enterText(find.widgetWithText(TextField, label), text);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('名称输入 → 候选 → 点选带出空地址/空坐标/空区划', (tester) async {
    await pumpForm(tester);

    await typeAndSearch(tester, '商家名称（可留空）', '蜜雪冰城');
    expect(appleMaps.searches, ['蜜雪冰城']);
    expect(find.text('苹果地图匹配'), findsOneWidget);
    expect(find.text('蜜雪冰城（玄武路店）'), findsOneWidget);

    await tester.tap(find.text('蜜雪冰城（玄武路店）'));
    await tester.pumpAndSettle();

    // 地址回填（候选清空后，仅地址 TextField 含该文本）。
    expect(find.widgetWithText(TextField, '江苏省南京市玄武区玄武路1号'),
        findsOneWidget);
    // 坐标带出（选点组件显示折算后 WGS84）。
    expect(find.textContaining('32.040000'), findsOneWidget);
    // 区划带出（级联下拉落到玄武区）。
    expect(find.text('玄武区'), findsOneWidget);
    // 候选列表已清空。
    expect(find.text('苹果地图匹配'), findsNothing);
  });

  testWidgets('名称流：已有地址与真实坐标不覆盖', (tester) async {
    await pumpForm(
      tester,
      merchant: const Merchant(
        id: 5,
        name: '原商家',
        address: '原地址',
        latitude: 31.23,
        longitude: 121.47,
      ),
    );
    await typeAndSearch(tester, '商家名称（可留空）', '蜜雪冰城');
    await tester.tap(find.text('蜜雪冰城（玄武路店）'));
    await tester.pumpAndSettle();

    // 地址保留原文；坐标保留原值。
    expect(find.widgetWithText(TextField, '原地址'), findsOneWidget);
    expect(find.widgetWithText(TextField, '江苏省南京市玄武区玄武路1号'),
        findsNothing);
    expect(find.textContaining('31.230000'), findsOneWidget);
    expect(find.textContaining('32.040000'), findsNothing);
  });

  testWidgets('名称流：占位坐标（默认中心）视为未有，会被覆盖', (tester) async {
    await pumpForm(
      tester,
      merchant: const Merchant(
        id: 6,
        name: '占位坐标商家',
        latitude: 39.9042,
        longitude: 116.4074,
      ),
    );
    expect(find.textContaining('39.904200'), findsOneWidget);

    await typeAndSearch(tester, '商家名称（可留空）', '蜜雪冰城');
    await tester.tap(find.text('蜜雪冰城（玄武路店）'));
    await tester.pumpAndSettle();

    expect(find.textContaining('39.904200'), findsNothing);
    expect(find.textContaining('32.040000'), findsOneWidget);
  });

  testWidgets('地址输入 → 候选 → 带出坐标/区划，地址本身不回写', (tester) async {
    await pumpForm(tester);

    await typeAndSearch(tester, '地址', '玄武区某路');
    expect(appleMaps.searches, ['玄武区某路']);
    expect(find.text('苹果地图匹配'), findsOneWidget);

    await tester.tap(find.text('蜜雪冰城（玄武路店）'));
    await tester.pumpAndSettle();

    // 地址保留用户输入（不回写候选地址）。
    expect(find.widgetWithText(TextField, '玄武区某路'), findsOneWidget);
    expect(find.widgetWithText(TextField, '江苏省南京市玄武区玄武路1号'),
        findsNothing);
    expect(find.textContaining('32.040000'), findsOneWidget);
    expect(find.text('玄武区'), findsOneWidget);
  });

  testWidgets('非 iOS 平台（默认服务）不出候选', (tester) async {
    await pumpForm(tester, injectAppleMaps: false);

    await tester.enterText(
      find.widgetWithText(TextField, '商家名称（可留空）'),
      '蜜雪冰城',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('苹果地图匹配'), findsNothing);
    expect(appleMaps.searches, isEmpty);
  });
}

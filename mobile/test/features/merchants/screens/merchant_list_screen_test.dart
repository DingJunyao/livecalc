import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant_coordinate.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_list_screen.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_form_screen.dart';
import 'package:com_a4ding_livecalc/features/nutrition/models/usda_models.dart';
import 'package:com_a4ding_livecalc/features/profile/models/user_place.dart';
import 'package:com_a4ding_livecalc/features/profile/repositories/profile_repository.dart';

class MockRepo extends Mock implements MerchantRepository {}

class MockProfileRepo extends Mock implements ProfileRepository {}

/// 内存瓦片：消除测试里真实网络请求的噪音。
class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

const _home = UserPlace(
  id: 1,
  name: '家',
  latitude: 31.2304,
  longitude: 121.4737,
  kind: 'home',
  isDefault: true,
  viewRadiusKm: 5,
);
const _office = UserPlace(
  id: 2,
  name: '公司',
  latitude: 31.25,
  longitude: 121.5,
  kind: 'work',
);

void main() {
  late MockRepo repo;
  late MockProfileRepo profileRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = MockRepo();
    when(() => repo.search(
          search: any(named: 'search'),
          includeClosed: any(named: 'includeClosed'),
          noPrice: any(named: 'noPrice'),
          includeOtherRegions: any(named: 'includeOtherRegions'),
          skip: any(named: 'skip'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const MerchantPage(
          items: [
            Merchant(
              id: 1,
              name: '盒马鲜生',
              latitude: 31.2304,
              longitude: 121.4737,
            ),
          ],
          total: 1,
        ));
    when(() => repo.getFavorites()).thenAnswer((_) async => const [
          Merchant(id: 1, name: '盒马鲜生', isOpen: true),
          Merchant(id: 2, name: '千禧量贩', isOpen: false),
        ]);
    when(() => repo.getAllCoordinates(
          search: any(named: 'search'),
          includeClosed: any(named: 'includeClosed'),
          includeOtherRegions: any(named: 'includeOtherRegions'),
        )).thenAnswer((_) async => []);
    when(() => repo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': ['osm'],
          'default_map': 'osm',
          'map_enabled': true,
        });
    when(() => repo.createMerchant(
          name: any(named: 'name'),
          address: any(named: 'address'),
          isOpen: any(named: 'isOpen'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer((_) async => const Merchant(id: 99, name: '新商家'));
    when(() => repo.updateMerchant(
          any(),
          isAdmin: any(named: 'isAdmin'),
          name: any(named: 'name'),
          address: any(named: 'address'),
          isOpen: any(named: 'isOpen'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer((_) async => const MerchantMutationResult(
          merchant: Merchant(id: 1, name: '盒马鲜生'),
          review: MutationReviewResult(
            applied: false,
            pending: true,
            message: '',
            raw: {},
          ),
        ));
    profileRepo = MockProfileRepo();
    when(() => profileRepo.getPlaces())
        .thenAnswer((_) async => [_home, _office]);
  });

  Future<void> pumpList(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/merchants',
      routes: [
        GoRoute(
          path: '/merchants',
          builder: (_, __) => MerchantListScreen(
            initialShowMap: true,
            profileRepository: profileRepo,
            merchantRepository: repo,
            mapTileProvider: _MemoryTileProvider(),
          ),
        ),
        GoRoute(
          path: '/merchants/new',
          builder: (_, state) {
            final args = state.extra;
            return MerchantFormScreen(
              isAdmin: args is MerchantFormArguments ? args.isAdmin : false,
              repository:
                  args is MerchantFormArguments ? args.repository : repo,
              mapTileProvider: args is MerchantFormArguments
                  ? args.mapTileProvider
                  : _MemoryTileProvider(),
            );
          },
        ),
        GoRoute(
          path: '/merchants/:id/edit',
          builder: (_, state) {
            final args = state.extra;
            return MerchantFormScreen(
              merchant: args is MerchantFormArguments ? args.merchant : null,
              isAdmin: args is MerchantFormArguments ? args.isAdmin : false,
              repository:
                  args is MerchantFormArguments ? args.repository : repo,
              mapTileProvider: args is MerchantFormArguments
                  ? args.mapTileProvider
                  : _MemoryTileProvider(),
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        merchantListProvider.overrideWith((ref) => MerchantListNotifier(repo)),
        mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('embedded map waits for map config before rendering layers',
      (tester) async {
    final response = Completer<Map<String, dynamic>>();
    when(() => repo.getMapConfig()).thenAnswer((_) => response.future);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        merchantListProvider.overrideWith((ref) => MerchantListNotifier(repo)),
        mapConfigProvider.overrideWith((ref) => MapConfigNotifier(repo)),
      ],
      child: MaterialApp(
        home: MerchantListScreen(
          initialShowMap: true,
          profileRepository: profileRepo,
          merchantRepository: repo,
          mapTileProvider: _MemoryTileProvider(),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byKey(const ValueKey('layer-switch')), findsNothing);

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
  });

  testWidgets('筛选弹窗：四个控件可切换，点确定后提交到 provider', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    final closedTile = find.widgetWithText(SwitchListTile, '显示已关闭商家');
    final favTile = find.widgetWithText(SwitchListTile, '仅看我的收藏');
    final regionTile = find.widgetWithText(SwitchListTile, '显示其他地区的商家');
    expect(tester.widget<SwitchListTile>(closedTile).value, isFalse);
    expect(tester.widget<SwitchListTile>(favTile).value, isFalse);
    expect(tester.widget<SwitchListTile>(regionTile).value, isFalse);

    // 开关切换后应保持打开，而不是被重建弹回原位
    await tester.tap(favTile);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<SwitchListTile>(favTile).value, isTrue);

    await tester.tap(closedTile);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<SwitchListTile>(closedTile).value, isTrue);

    await tester.tap(regionTile);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<SwitchListTile>(regionTile).value, isTrue);

    await tester.tap(find.text('未维护过价格'));
    await tester.pump();
    await tester.pump();
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '未维护过价格'),
    );
    expect(chip.selected, isTrue);

    // 底栏内容较高（矮视口内可滚动），先滚到「确定」再点
    await tester.ensureVisible(find.text('确定'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(MerchantListScreen)));
    final state = container.read(merchantListProvider);
    expect(state.includeClosed, isTrue);
    expect(state.favoritesOnly, isTrue);
    expect(state.noPrice, isTrue);
    expect(state.includeOtherRegions, isTrue);
    // 收藏模式下：显示已关闭 → 保留全部收藏；未维护过价格不参与收藏过滤（与网页一致）
    expect(state.items.map((m) => m.id), [1, 2]);
  });

  testWidgets('打开「显示其他地区的商家」：search 带 include_other_regions=true', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '显示其他地区的商家'));
    await tester.pump();
    await tester.ensureVisible(find.text('确定'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    verify(() => repo.search(
          search: any(named: 'search'),
          includeClosed: any(named: 'includeClosed'),
          noPrice: any(named: 'noPrice'),
          includeOtherRegions: true,
          skip: any(named: 'skip'),
          limit: any(named: 'limit'),
        )).called(1);
  });

  testWidgets('仅打开「显示已关闭商家」：重新走 search 接口并带上参数', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '显示已关闭商家'));
    await tester.pump();
    await tester.ensureVisible(find.text('确定'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    verify(() => repo.search(
          search: null,
          includeClosed: true,
          noPrice: false,
          skip: 0,
          limit: 20,
        )).called(1);
  });

  group('添加/编辑商家页面', () {
    Future<void> useTallViewport(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('添加商家：填名称 → 地图选点 → createMerchant 参数正确', (tester) async {
      await useTallViewport(tester);
      await pumpList(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('添加商家'), findsOneWidget);
      expect(find.byType(MerchantFormScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, '商家名称（可留空）'), '社区超市');
      await tester.tap(find.descendant(
          of: find.byType(MerchantFormScreen),
          matching: find.byType(FlutterMap)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('创建'));
      await tester.pump();
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      final captured = verify(() => repo.createMerchant(
            name: any(named: 'name'),
            address: any(named: 'address'),
            isOpen: any(named: 'isOpen'),
            latitude: captureAny(named: 'latitude'),
            longitude: captureAny(named: 'longitude'),
          )).captured;
      expect(captured[0], closeTo(39.9042, 1e-4));
      expect(captured[1], closeTo(116.4074, 1e-4));
      expect(find.text('已创建商家'), findsOneWidget);
    });

    testWidgets('只填国家/地区（不填名称）也能保存', (tester) async {
      await useTallViewport(tester);
      await pumpList(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(MerchantFormScreen), findsOneWidget);

      // 不填名称直接保存（只填地区场景：名称留空）
      await tester.ensureVisible(find.text('创建'));
      await tester.pump();
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      final captured = verify(() => repo.createMerchant(
            name: captureAny(named: 'name'),
            address: any(named: 'address'),
            isOpen: any(named: 'isOpen'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).captured;
      expect(captured.single, '');
      expect(find.text('已创建商家'), findsOneWidget);
    });

    testWidgets('编辑商家：已有坐标显示标记，重新选点保存', (tester) async {
      await useTallViewport(tester);
      await pumpList(tester);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.text('编辑商家'), findsOneWidget);
      expect(find.byType(MerchantFormScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      // 已有坐标 → 标记显示
      expect(
        find.descendant(
          of: find.byType(MerchantFormScreen),
          matching: find.byIcon(Icons.location_pin),
        ),
        findsOneWidget,
      );

      await tester.tap(find.descendant(
          of: find.byType(MerchantFormScreen),
          matching: find.byType(FlutterMap)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      verify(() => repo.updateMerchant(
            1,
            isAdmin: any(named: 'isAdmin'),
            name: any(named: 'name'),
            address: any(named: 'address'),
            isOpen: any(named: 'isOpen'),
            latitude: captureAny(named: 'latitude'),
            longitude: captureAny(named: 'longitude'),
          )).called(1);
      expect(find.text('已提交，待管理员审核'), findsOneWidget);
    });
  });

  group('地图常用地点', () {
    testWidgets('无记忆：默认选中「全部商家」', (tester) async {
      await pumpList(tester);

      // 未保存记忆时默认「全部商家」：按钮显示未选中文案
      expect(find.byTooltip('选择常用地点'), findsOneWidget);
    });

    testWidgets('有记忆：使用 SharedPreferences 选中的地点', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'merchants_map_current_place_id': 2});
      await pumpList(tester);

      // 公司：tooltip 显示选中地点
      expect(find.byTooltip('公司'), findsOneWidget);
    });

    testWidgets('有记忆：进入地图后镜头聚焦到记忆的地点', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'merchants_map_current_place_id': 2});
      await pumpList(tester);

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap).first);
      final center = map.mapController!.camera.center;
      // 公司 (31.25, 121.5)，OSM 底图不做坐标转换
      expect(center.latitude, closeTo(31.25, 1e-4));
      expect(center.longitude, closeTo(121.5, 1e-4));
    });

    testWidgets('有记忆（多商家）：镜头聚焦到记忆地点，不被 fit-all 覆盖', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'merchants_map_current_place_id': 2});
      // 覆盖 mock：多个商家 → 初始会 fit 全部，验证地点聚焦仍生效
      when(() => repo.search(
            search: any(named: 'search'),
            includeClosed: any(named: 'includeClosed'),
            noPrice: any(named: 'noPrice'),
            includeOtherRegions: any(named: 'includeOtherRegions'),
            skip: any(named: 'skip'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => const MerchantPage(
            items: [
              // 中点 (31.2, 121.2)，与记忆地点「公司」(31.25, 121.5) 区分开
              Merchant(id: 1, name: '商家A', latitude: 31.0, longitude: 121.0),
              Merchant(id: 2, name: '商家B', latitude: 31.4, longitude: 121.4),
            ],
            total: 2,
          ));
      when(() => repo.getAllCoordinates(
            search: any(named: 'search'),
            includeClosed: any(named: 'includeClosed'),
            includeOtherRegions: any(named: 'includeOtherRegions'),
          )).thenAnswer((_) async => const [
            MerchantCoordinate(id: 1, latitude: 31.0, longitude: 121.0),
            MerchantCoordinate(id: 2, latitude: 31.4, longitude: 121.4),
          ]);
      await pumpList(tester);

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap).first);
      final center = map.mapController!.camera.center;
      expect(center.latitude, closeTo(31.25, 1e-4));
      expect(center.longitude, closeTo(121.5, 1e-4));
    });

    testWidgets('切换地点：持久化到 SharedPreferences', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byKey(const ValueKey('place-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('公司').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('merchants_map_current_place_id'), 2);
    });

    testWidgets('切回全部商家：清除记忆', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'merchants_map_current_place_id': 2});
      await pumpList(tester);

      await tester.tap(find.byKey(const ValueKey('place-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部商家').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('merchants_map_current_place_id'), isNull);
    });
  });
}

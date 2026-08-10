import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_list_screen.dart';
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
          name: any(named: 'name'),
          address: any(named: 'address'),
          isOpen: any(named: 'isOpen'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer((_) async => const Merchant(id: 1, name: '盒马鲜生'));
    profileRepo = MockProfileRepo();
    when(() => profileRepo.getPlaces()).thenAnswer((_) async => [_home, _office]);
  });

  Future<void> pumpList(WidgetTester tester) async {
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
    await tester.pumpAndSettle();
  }

  DropdownButton<int?> placeDropdown(WidgetTester tester) => tester
      .widget<DropdownButton<int?>>(find.byKey(const ValueKey('place-dropdown')));

  testWidgets('筛选弹窗：三个控件可切换，点确定后提交到 provider', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    final closedTile = find.widgetWithText(SwitchListTile, '显示已关闭商家');
    final favTile = find.widgetWithText(SwitchListTile, '仅看我的收藏');
    expect(tester.widget<SwitchListTile>(closedTile).value, isFalse);
    expect(tester.widget<SwitchListTile>(favTile).value, isFalse);

    // 开关切换后应保持打开，而不是被重建弹回原位
    await tester.tap(favTile);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<SwitchListTile>(favTile).value, isTrue);

    await tester.tap(closedTile);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<SwitchListTile>(closedTile).value, isTrue);

    await tester.tap(find.text('未维护过价格'));
    await tester.pump();
    await tester.pump();
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '未维护过价格'),
    );
    expect(chip.selected, isTrue);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MerchantListScreen)));
    final state = container.read(merchantListProvider);
    expect(state.includeClosed, isTrue);
    expect(state.favoritesOnly, isTrue);
    expect(state.noPrice, isTrue);
    // 收藏模式下：显示已关闭 → 保留全部收藏；未维护过价格不参与收藏过滤（与网页一致）
    expect(state.items.map((m) => m.id), [1, 2]);
  });

  testWidgets('仅打开「显示已关闭商家」：重新走 search 接口并带上参数', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '显示已关闭商家'));
    await tester.pump();
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

  group('添加/编辑商家对话框', () {
    testWidgets('添加商家：填名称 → 地图选点 → createMerchant 参数正确', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('添加商家'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, '商家名称 *'), '社区超市');
      // 对话框自动滚到地图可见；OSM 底图点中心 = 北京，坐标原样
      // （页面地图 MerchantMapView 也在树里，须限定对话框范围）
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FlutterMap)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('保存'));
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

    testWidgets('编辑商家：已有坐标显示标记，重新选点保存', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.text('编辑商家'), findsOneWidget);
      // 已有坐标 → 标记显示
      expect(find.byIcon(Icons.location_pin), findsOneWidget);

      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FlutterMap)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      verify(() => repo.updateMerchant(
            1,
            name: any(named: 'name'),
            address: any(named: 'address'),
            isOpen: any(named: 'isOpen'),
            latitude: captureAny(named: 'latitude'),
            longitude: captureAny(named: 'longitude'),
          )).called(1);
      expect(find.text('已保存'), findsOneWidget);
    });
  });

  group('地图地点下拉', () {
    testWidgets('无记忆：默认地点（is_default）作为当前选中', (tester) async {
      await pumpList(tester);

      expect(placeDropdown(tester).value, 1); // 家 isDefault
      expect(find.text('家'), findsWidgets);
    });

    testWidgets('有记忆：SharedPreferences 优先于默认地点', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'merchants_map_current_place_id': 2});
      await pumpList(tester);

      expect(placeDropdown(tester).value, 2); // 公司，而非默认的家
    });

    testWidgets('切换地点：持久化到 SharedPreferences', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byKey(const ValueKey('place-dropdown')));
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

      await tester.tap(find.byKey(const ValueKey('place-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部商家').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('merchants_map_current_place_id'), isNull);
    });
  });
}

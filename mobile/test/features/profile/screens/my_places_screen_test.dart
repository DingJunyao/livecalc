import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/models/user_place.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/profile_provider.dart';
import 'package:com_a4ding_livecalc/features/profile/repositories/profile_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/my_places_screen.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/user_place_form_screen.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockMerchantRepository extends Mock implements MerchantRepository {}

/// 内存瓦片：消除测试里真实网络请求的噪音。
class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

const _home = UserPlace(
  id: 1,
  name: '家',
  address: '上海路 1 号',
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
  late MockProfileRepository mockRepo;
  late List<UserPlace> places;

  setUp(() {
    mockRepo = MockProfileRepository();
    places = [_home, _office];
    when(() => mockRepo.getPlaces()).thenAnswer((_) async => List.of(places));
    when(() => mockRepo.createPlace(any())).thenAnswer((inv) async => UserPlace(
          id: 99,
          name: (inv.positionalArguments[0] as Map)['name'] as String,
          latitude: 31.0,
          longitude: 121.0,
        ));
    when(() => mockRepo.updatePlace(any(), any()))
        .thenAnswer((inv) async => places.first);
    when(() => mockRepo.deletePlace(any())).thenAnswer((_) async {});
    when(() => mockRepo.setDefaultPlace(any())).thenAnswer((_) async => _home);
  });

  /// 对话框里点地图选点：点地图中心（对话框已自动滚到地图可见）。
  Future<void> pickOnMap(WidgetTester tester) async {
    await tester.tap(find.byType(FlutterMap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final merchantRepo = MockMerchantRepository();
    when(() => merchantRepo.getMapConfig()).thenAnswer((_) async => {
          'available_maps': ['osm'],
          'default_map': 'osm',
          'map_enabled': true,
        });
    final router = GoRouter(
      initialLocation: '/places',
      routes: [
        GoRoute(
          path: '/places',
          builder: (_, __) =>
              MyPlacesScreen(mapTileProvider: _MemoryTileProvider()),
        ),
        GoRoute(
          path: '/profile/places/new',
          builder: (_, state) => UserPlaceFormScreen(
            place: state.extra is UserPlaceFormArguments
                ? (state.extra! as UserPlaceFormArguments).place
                : null,
            mapTileProvider: _MemoryTileProvider(),
          ),
        ),
        GoRoute(
          path: '/profile/places/:id/edit',
          builder: (_, state) => UserPlaceFormScreen(
            place: state.extra is UserPlaceFormArguments
                ? (state.extra! as UserPlaceFormArguments).place
                : null,
            mapTileProvider: _MemoryTileProvider(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        placeListProvider.overrideWith((ref) => PlaceListNotifier(mockRepo)),
        mapConfigProvider
            .overrideWith((ref) => MapConfigNotifier(merchantRepo)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  /// 打开第 [index] 个条目的操作菜单并选择 [label]。
  Future<void> openMenu(WidgetTester tester, String label,
      {int index = 0}) async {
    await tester.tap(find.byTooltip('更多操作').at(index));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('列表渲染：类型标签、星标只在默认地点、work 图标', (tester) async {
    await pumpScreen(tester);

    expect(find.text('家'), findsWidgets);
    expect(find.text('公司'), findsWidgets);
    // 元信息行：类型 · 视野 · 坐标
    expect(
        find.textContaining('家 · 视野 5 km · 31.2304, 121.4737'), findsOneWidget);
    expect(find.textContaining('公司 · 视野 5 km · 31.2500, 121.5000'),
        findsOneWidget);
    // 星标只有默认地点一个；work → business 图标
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.business), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });

  testWidgets('新增流：FAB → 填表 → 地图选点 → createPlace 参数正确', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('添加地点'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, '名称（如：家、公司）'), '外婆家');
    // OSM 底图：点击地图中心 = 默认视角北京，坐标原样
    await pickOnMap(tester);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    final captured = verify(() => mockRepo.createPlace(captureAny())).captured;
    expect(captured.first, {
      'name': '外婆家',
      'kind': 'custom',
      'address': null,
      'latitude': closeTo(39.9042, 1e-4),
      'longitude': closeTo(116.4074, 1e-4),
      'view_radius_km': 5,
    });
    expect(find.text('已添加地点'), findsOneWidget);
  });

  testWidgets('删除流：菜单 → 确认框 → deletePlace', (tester) async {
    await pumpScreen(tester);

    await openMenu(tester, '删除');
    expect(find.text('确定删除「家」吗？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.deletePlace(1)).called(1);
  });

  testWidgets('删除取消不发请求', (tester) async {
    await pumpScreen(tester);

    await openMenu(tester, '删除');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    verifyNever(() => mockRepo.deletePlace(any()));
  });

  testWidgets('设为默认流（默认地点菜单项禁用）', (tester) async {
    await pumpScreen(tester);

    // 第一个（家）是默认地点：菜单里「设为默认」禁用
    await tester.tap(find.byTooltip('更多操作').first);
    await tester.pumpAndSettle();
    final disabled = tester
        .widget<PopupMenuItem<String>>(find.byWidgetPredicate((w) =>
            w is PopupMenuItem<String> && (w.child as Text?)?.data == '设为默认'))
        .enabled;
    expect(disabled, false);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 第二个（公司）设为默认
    await openMenu(tester, '设为默认', index: 1);
    verify(() => mockRepo.setDefaultPlace(2)).called(1);
  });

  testWidgets('未选点保存：提示请在地图上选择位置且不发请求', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, '名称（如：家、公司）'), '没选点');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('请在地图上选择位置'), findsOneWidget);
    verifyNever(() => mockRepo.createPlace(any()));
  });

  testWidgets('写操作 403 提示地图功能已关闭', (tester) async {
    when(() => mockRepo.createPlace(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/places'),
        response: Response(
          requestOptions: RequestOptions(path: '/places'),
          statusCode: 403,
          data: {'detail': '地图功能未启用'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    await pumpScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, '名称（如：家、公司）'), '新地点');
    await pickOnMap(tester);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('地图功能已关闭，无法维护常用地点'), findsOneWidget);
    // 对话框未关闭，可继续编辑
    expect(find.text('添加地点'), findsOneWidget);
  });
}

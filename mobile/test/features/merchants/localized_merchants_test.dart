import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant_coordinate.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_detail_screen.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_form_screen.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_list_screen.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/apple_map_picker.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/map_point_picker.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/merchant_map_view.dart';
import 'package:com_a4ding_livecalc/features/profile/models/user_place.dart';
import 'package:com_a4ding_livecalc/features/profile/repositories/profile_repository.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

const _storedMerchant = Merchant(
  id: 1,
  name: 'Stored Merchant',
  address: 'Stored address',
  latitude: 31.2304,
  longitude: 121.4737,
  createdAt: '2026-08-15T08:30:00+08:00',
);

const _osmMapConfig = MapConfigState(
  layers: [osmLayer],
  defaultId: 'osm',
  loaded: true,
);

class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class _SuccessfulGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;

  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      Position(
        latitude: 31.25,
        longitude: 121.5,
        timestamp: DateTime(2026, 8, 15),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

class _FakeProfileRepository extends ProfileRepository {
  @override
  Future<List<UserPlace>> getPlaces() async => const [];
}

class _FakeMerchantRepository extends MerchantRepository {
  @override
  Future<MerchantPage> search({
    String? search,
    bool includeClosed = false,
    bool noPrice = false,
    bool includeOtherRegions = false,
    int skip = 0,
    int limit = 20,
  }) async {
    return const MerchantPage(items: [_storedMerchant], total: 1);
  }

  @override
  Future<Merchant> getMerchant(int id) async => _storedMerchant;

  @override
  Future<List<Merchant>> getFavorites() async => const [_storedMerchant];

  @override
  Future<List<MerchantCoordinate>> getAllCoordinates({
    String? search,
    bool includeClosed = false,
    bool includeOtherRegions = false,
  }) async =>
      const [];

  @override
  Future<Map<String, dynamic>> getMapConfig() async => {
        'available_maps': ['osm'],
        'default_map': 'osm',
        'map_enabled': true,
      };

  @override
  Future<List<Map<String, dynamic>>> listRegions({
    int? parentId,
    int? level,
  }) async =>
      const [];

  @override
  Future<Map<String, dynamic>> getRegion(int id) async => const {};
}

class _StaticMerchantListNotifier extends MerchantListNotifier {
  _StaticMerchantListNotifier(super.repository) {
    state = state.copyWith(
      items: const [_storedMerchant],
      total: 1,
      hasMore: false,
    );
  }

  @override
  Future<void> load({bool loadMore = false}) async {}

  @override
  Future<void> loadFavorites() async {}
}

class _StaticMerchantDetailNotifier extends MerchantDetailPageNotifier {
  _StaticMerchantDetailNotifier(super.id) {
    state = state.copyWith(
      merchant: _storedMerchant,
      productPrices: const [],
      loading: false,
    );
  }

  @override
  Future<void> load() async {}
}

class _NoopMapConfigNotifier extends MapConfigNotifier {
  _NoopMapConfigNotifier({bool loaded = false})
      : super(_FakeMerchantRepository()) {
    state = state.copyWith(
      layers: const [osmLayer],
      defaultId: 'osm',
      loaded: loaded,
    );
  }

  @override
  Future<void> load() async {}
}

Future<void> _pumpLocalized(
  WidgetTester tester,
  Locale locale,
  Widget child, {
  bool mapReady = false,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  ApiClient.instance.updateBaseUrl('http://127.0.0.1:9');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        merchantListProvider.overrideWith(
          (ref) => _StaticMerchantListNotifier(_FakeMerchantRepository()),
        ),
        mapConfigProvider.overrideWith(
          (ref) => _NoopMapConfigNotifier(loaded: mapReady),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _assertMerchantFormLabels(
  WidgetTester tester,
  bool editing,
  String addTitle,
  String editTitle,
  String button,
  String nameLabel,
  String addressLabel,
  String openLabel,
  String defaultCurrencyLabel,
  String followRegionLabel,
  String locationLabel,
) async {
  expect(find.text(editing ? editTitle : addTitle), findsOneWidget);
  expect(find.text(nameLabel), findsOneWidget);
  expect(find.text(addressLabel), findsOneWidget);
  expect(find.text(openLabel), findsOneWidget);
  expect(find.text(defaultCurrencyLabel), findsOneWidget);
  expect(find.text(followRegionLabel), findsWidgets);
  expect(find.text(locationLabel), findsOneWidget);
  expect(find.text(button), findsOneWidget);
}

void main() {
  late GeolocatorPlatform originalGeolocator;

  setUp(() {
    originalGeolocator = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _SuccessfulGeolocator();
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
  });

  testWidgets('English merchant list and filters localize', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      MerchantListScreen(
        profileRepository: _FakeProfileRepository(),
        merchantRepository: _FakeMerchantRepository(),
      ),
    );

    expect(find.text('Merchants'), findsOneWidget);
    expect(find.text('Search merchants...'), findsOneWidget);
    expect(find.text('Stored Merchant'), findsWidgets);
    expect(find.text('Stored address'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Filter options'), findsOneWidget);
    expect(find.text('Show closed merchants'), findsOneWidget);
    expect(find.text('Show merchants from other regions'), findsOneWidget);
    expect(find.text('Includes all regions, unaffected by calculation scope'),
        findsOneWidget);
    expect(find.text('Favorites only'), findsOneWidget);
    expect(find.text('No maintained price'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('Arabic merchant list and filters localize', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      MerchantListScreen(
        profileRepository: _FakeProfileRepository(),
        merchantRepository: _FakeMerchantRepository(),
      ),
    );

    expect(find.text('المتاجر'), findsOneWidget);
    expect(find.text('ابحث عن المتاجر...'), findsOneWidget);
    expect(find.text('Stored Merchant'), findsWidgets);
    expect(find.text('Stored address'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('خيارات التصفية'), findsOneWidget);
    expect(find.text('عرض المتاجر المغلقة'), findsOneWidget);
    expect(find.text('عرض متاجر المناطق الأخرى'), findsOneWidget);
    expect(
      find.text('يشمل جميع المناطق ولا يتأثر بنطاق الحساب'),
      findsOneWidget,
    );
    expect(find.text('المفضلة فقط'), findsOneWidget);
    expect(find.text('لا يوجد سعر مُصان'), findsOneWidget);
    expect(find.text('موافق'), findsOneWidget);
  });

  testWidgets('English merchant detail localizes', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const MerchantDetailScreen(id: 1),
      extraOverrides: [
        merchantDetailPageProvider(1)
            .overrideWith((ref) => _StaticMerchantDetailNotifier(1)),
      ],
    );

    expect(find.text('Merchant'), findsOneWidget);
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Stored Merchant'), findsWidgets);
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Stored address'), findsOneWidget);
    expect(find.text('Business status'), findsOneWidget);
    expect(find.text('Open'), findsWidgets);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Product prices'), findsOneWidget);
    expect(
        find.text('This merchant has no product prices yet'), findsOneWidget);
  });

  testWidgets('Arabic merchant detail localizes', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const MerchantDetailScreen(id: 1),
      extraOverrides: [
        merchantDetailPageProvider(1)
            .overrideWith((ref) => _StaticMerchantDetailNotifier(1)),
      ],
    );

    expect(find.text('متجر'), findsOneWidget);
    expect(find.text('المعلومات الأساسية'), findsOneWidget);
    expect(find.text('الاسم'), findsOneWidget);
    expect(find.text('Stored Merchant'), findsWidgets);
    expect(find.text('العنوان'), findsOneWidget);
    expect(find.text('Stored address'), findsOneWidget);
    expect(find.text('حالة العمل'), findsOneWidget);
    expect(find.text('مفتوح'), findsWidgets);
    expect(find.text('الموقع'), findsOneWidget);
    expect(find.text('أسعار المنتجات'), findsOneWidget);
    expect(
      find.text('لا توجد أسعار منتجات لهذا المتجر بعد'),
      findsOneWidget,
    );
  });

  testWidgets('English merchant create and edit forms localize', (
    tester,
  ) async {
    final repository = _FakeMerchantRepository();
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      MerchantFormScreen(
        isAdmin: false,
        repository: repository,
        mapTileProvider: _MemoryTileProvider(),
      ),
    );
    await _assertMerchantFormLabels(
      tester,
      false,
      'Add merchant',
      'Edit merchant',
      'Create',
      'Merchant name (optional)',
      'Address',
      'Open',
      'Default currency',
      'Follow region',
      'Location (tap the map to choose, optional)',
    );

    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      MerchantFormScreen(
        merchant: _storedMerchant,
        isAdmin: true,
        repository: repository,
        mapTileProvider: _MemoryTileProvider(),
      ),
    );
    await _assertMerchantFormLabels(
      tester,
      true,
      'Add merchant',
      'Edit merchant',
      'Save',
      'Merchant name (optional)',
      'Address',
      'Open',
      'Default currency',
      'Follow region',
      'Location (tap the map to choose, optional)',
    );
  });

  testWidgets('Arabic merchant create and edit forms localize', (
    tester,
  ) async {
    final repository = _FakeMerchantRepository();
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      MerchantFormScreen(
        isAdmin: false,
        repository: repository,
        mapTileProvider: _MemoryTileProvider(),
      ),
    );
    await _assertMerchantFormLabels(
      tester,
      false,
      'إضافة متجر',
      'تعديل المتجر',
      'إنشاء',
      'اسم المتجر (اختياري)',
      'العنوان',
      'مفتوح',
      'العملة الافتراضية',
      'متابعة المنطقة',
      'الموقع (انقر على الخريطة للاختيار، اختياري)',
    );

    await _pumpLocalized(
      tester,
      const Locale('ar'),
      MerchantFormScreen(
        merchant: _storedMerchant,
        isAdmin: true,
        repository: repository,
        mapTileProvider: _MemoryTileProvider(),
      ),
    );
    await _assertMerchantFormLabels(
      tester,
      true,
      'إضافة متجر',
      'تعديل المتجر',
      'حفظ',
      'اسم المتجر (اختياري)',
      'العنوان',
      'مفتوح',
      'العملة الافتراضية',
      'متابعة المنطقة',
      'الموقع (انقر على الخريطة للاختيار، اختياري)',
    );
  });

  testWidgets('English map picker coordinates, prompt, and locate localize',
      (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 700,
            height: 340,
            child: MapPointPicker(
              initialValue: const LatLng(-31.2304, -121.4737),
              mapController: MapController(),
              tileProvider: _MemoryTileProvider(),
            ),
          ),
        ),
      ),
      mapReady: true,
    );

    final ltr = tester.widget<Directionality>(
      find.byKey(const ValueKey('picker-coordinate-ltr')),
    );
    expect(ltr.textDirection, TextDirection.ltr);
    final coordinateText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('picker-coordinate-ltr')),
        matching: find.byType(Text),
      ),
    );
    expect(coordinateText.data, contains('Latitude: -31.230400'));
    expect(coordinateText.data, contains('Longitude: -121.473700'));
    expect(
      coordinateText.data!.indexOf('Latitude: -31.230400'),
      lessThan(coordinateText.data!.indexOf('Longitude: -121.473700')),
    );
    expect(
        find.byTooltip('Locate and choose current location'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map-locate-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final locatedText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('picker-coordinate-ltr')),
        matching: find.byType(Text),
      ),
    );
    expect(locatedText.data, contains('Latitude: 31.250000'));
    expect(locatedText.data, contains('Longitude: 121.500000'));
  });

  testWidgets('Arabic map picker coordinates, prompt, and locate localize',
      (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 700,
            height: 340,
            child: MapPointPicker(
              initialValue: const LatLng(-31.2304, -121.4737),
              mapController: MapController(),
              tileProvider: _MemoryTileProvider(),
            ),
          ),
        ),
      ),
      mapReady: true,
    );

    final ltr = tester.widget<Directionality>(
      find.byKey(const ValueKey('picker-coordinate-ltr')),
    );
    expect(ltr.textDirection, TextDirection.ltr);
    final coordinateText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('picker-coordinate-ltr')),
        matching: find.byType(Text),
      ),
    );
    expect(coordinateText.data, contains('خط العرض: -31.230400'));
    expect(coordinateText.data, contains('خط الطول: -121.473700'));
    expect(
      coordinateText.data!.indexOf('خط العرض: -31.230400'),
      lessThan(coordinateText.data!.indexOf('خط الطول: -121.473700')),
    );
    expect(find.byTooltip('حدد الموقع الحالي واختره'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map-locate-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final locatedText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('picker-coordinate-ltr')),
        matching: find.byType(Text),
      ),
    );
    expect(locatedText.data, contains('خط العرض: 31.250000'));
    expect(locatedText.data, contains('خط الطول: 121.500000'));
  });

  testWidgets('English map picker prompt then tapped point is LTR', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 700,
            height: 340,
            child: MapPointPicker(
              mapController: MapController(),
              tileProvider: _MemoryTileProvider(),
            ),
          ),
        ),
      ),
      mapReady: true,
    );

    expect(find.text('Tap the map to choose a location'), findsOneWidget);
    expect(find.byKey(const ValueKey('picker-coordinate-ltr')), findsNothing);

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final directionality = tester.widget<Directionality>(
      find.byKey(const ValueKey('picker-coordinate-ltr')),
    );
    expect(directionality.textDirection, TextDirection.ltr);
    final coordinateText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('picker-coordinate-ltr')),
        matching: find.byType(Text),
      ),
    );
    expect(coordinateText.data, contains('Latitude: 39.904200'));
    expect(coordinateText.data, contains('Longitude: 116.407400'));
    expect(
      coordinateText.data!.indexOf('Latitude: 39.904200'),
      lessThan(coordinateText.data!.indexOf('Longitude: 116.407400')),
    );
  });

  testWidgets('Arabic map picker prompt then tapped point is LTR', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 700,
            height: 340,
            child: MapPointPicker(
              mapController: MapController(),
              tileProvider: _MemoryTileProvider(),
            ),
          ),
        ),
      ),
      mapReady: true,
    );

    expect(find.text('انقر على الخريطة لتحديد الموقع'), findsOneWidget);
    expect(find.byKey(const ValueKey('picker-coordinate-ltr')), findsNothing);

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final directionality = tester.widget<Directionality>(
      find.byKey(const ValueKey('picker-coordinate-ltr')),
    );
    expect(directionality.textDirection, TextDirection.ltr);
    final coordinateText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('picker-coordinate-ltr')),
        matching: find.byType(Text),
      ),
    );
    expect(coordinateText.data, contains('خط العرض: 39.904200'));
    expect(coordinateText.data, contains('خط الطول: 116.407400'));
    expect(
      coordinateText.data!.indexOf('خط العرض: 39.904200'),
      lessThan(coordinateText.data!.indexOf('خط الطول: 116.407400')),
    );
  });

  testWidgets('English Apple picker localization and locate LTR path', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            height: 340,
            child: AppleMapPicker(),
          ),
        ),
      ),
    );

    expect(find.text('Tap the map to choose a location'), findsOneWidget);
    expect(find.byTooltip('Switch map style'), findsOneWidget);
    expect(
        find.byTooltip('Locate and choose current location'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('apple-picker-layer-switch')));
    await tester.pumpAndSettle();
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Satellite'), findsOneWidget);
    await tester.tap(find.text('Standard').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('map-locate-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final directionality = tester.widget<Directionality>(
      find.byKey(const ValueKey('apple-picker-coordinate-ltr')),
    );
    expect(directionality.textDirection, TextDirection.ltr);
    final coordinateText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('apple-picker-coordinate-ltr')),
        matching: find.byType(Text),
      ),
    );
    expect(coordinateText.data, contains('Latitude: 31.250000'));
    expect(coordinateText.data, contains('Longitude: 121.500000'));
    expect(
      coordinateText.data!.indexOf('Latitude: 31.250000'),
      lessThan(coordinateText.data!.indexOf('Longitude: 121.500000')),
    );
  });

  testWidgets('Arabic Apple picker localization and locate LTR path', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            height: 340,
            child: AppleMapPicker(),
          ),
        ),
      ),
    );

    expect(find.text('انقر على الخريطة لتحديد الموقع'), findsOneWidget);
    expect(find.byTooltip('تبديل نمط الخريطة'), findsOneWidget);
    expect(find.byTooltip('حدد الموقع الحالي واختره'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('apple-picker-layer-switch')));
    await tester.pumpAndSettle();
    expect(find.text('قياسي'), findsOneWidget);
    expect(find.text('قمر صناعي'), findsOneWidget);
    await tester.tap(find.text('قياسي').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('map-locate-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final directionality = tester.widget<Directionality>(
      find.byKey(const ValueKey('apple-picker-coordinate-ltr')),
    );
    expect(directionality.textDirection, TextDirection.ltr);
    final coordinateText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('apple-picker-coordinate-ltr')),
        matching: find.byType(Text),
      ),
    );
    expect(coordinateText.data, contains('خط العرض: 31.250000'));
    expect(coordinateText.data, contains('خط الطول: 121.500000'));
    expect(
      coordinateText.data!.indexOf('خط العرض: 31.250000'),
      lessThan(coordinateText.data!.indexOf('خط الطول: 121.500000')),
    );
  });

  testWidgets('English map disabled state localizes', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            height: 300,
            child: MerchantMapView(
              merchants: [Merchant(id: 1, name: 'No coordinates')],
              mapConfig: _osmMapConfig,
            ),
          ),
        ),
      ),
    );

    expect(find.text('No merchant locations'), findsOneWidget);
    expect(
      find.text('Merchants without coordinates cannot be shown on the map'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('layer-switch')), findsNothing);
    expect(find.byKey(const ValueKey('locate-button')), findsNothing);
  });

  testWidgets('Arabic map disabled state localizes', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            height: 300,
            child: MerchantMapView(
              merchants: [Merchant(id: 1, name: 'No coordinates')],
              mapConfig: _osmMapConfig,
            ),
          ),
        ),
      ),
    );

    expect(find.text('لا توجد مواقع متاجر'), findsOneWidget);
    expect(
      find.text('لا يمكن عرض المتاجر بدون إحداثيات على الخريطة'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('layer-switch')), findsNothing);
    expect(find.byKey(const ValueKey('locate-button')), findsNothing);
  });
}

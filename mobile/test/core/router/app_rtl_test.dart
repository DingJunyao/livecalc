import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:com_a4ding_livecalc/core/router/app_router.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/map_config_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/map_point_picker.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/providers/price_provider.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/price_list_screen.dart';
import 'package:com_a4ding_livecalc/features/recipes/models/recipe_detail.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/merchant_price_matrix.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/nutrition_source_grid.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';
import 'package:com_a4ding_livecalc/shared/screens/nutrition_edit_screen.dart';
import 'package:com_a4ding_livecalc/shared/widgets/nutrition_card.dart';

class _PriceRepo extends PriceRepository {
  final List<PriceRecord> records;
  _PriceRepo({this.records = const []});

  @override
  Future<PriceRecordsResult> getRecords({
    String? search,
    int? merchantId,
    int? ingredientId,
    int? productId,
    String? recordTypes,
    String? startDate,
    String? endDate,
    int? limit,
    int page = 1,
    int pageSize = 20,
  }) async {
    return PriceRecordsResult(records: records, total: records.length);
  }
}

class _MerchantRepo extends MerchantRepository {
  @override
  Future<MerchantPage> search({
    String? search,
    bool includeClosed = false,
    bool noPrice = false,
    bool includeOtherRegions = false,
    int skip = 0,
    int limit = 20,
  }) async {
    return const MerchantPage(items: [], total: 0);
  }
}

class _MapRepo extends MerchantRepository {
  @override
  Future<Map<String, dynamic>> getMapConfig() async => {
        'available_maps': ['osm'],
        'default_map': 'osm',
        'map_enabled': true,
      };
}

class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

const _matrixIngredients = [
  RecipeIngredient(
    id: 10,
    ingredientId: 5,
    name: 'Egg',
    quantity: '100',
    unit: 'g',
  ),
];

const _matrixPrices = [
  MerchantPriceItem(
    recipeIngredientId: 10,
    ingredientId: 5,
    ingredientName: 'Egg',
    prices: [
      MerchantPriceRecord(
        merchantId: 1,
        merchantName: 'Market A',
        price: 3.0,
        totalCost: 3.5,
        isLowest: true,
      ),
    ],
  ),
];

GoRouter _shellRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (_, __, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('home page')),
          ),
          GoRoute(
            path: '/prices',
            builder: (_, __) => const Scaffold(body: Text('prices page')),
          ),
          GoRoute(
            path: '/recipes',
            builder: (_, __) => const Scaffold(body: Text('recipes page')),
          ),
          GoRoute(
            path: '/ingredients',
            builder: (_, __) => const Scaffold(body: Text('ingredients page')),
          ),
          GoRoute(
            path: '/products',
            builder: (_, __) => const Scaffold(body: Text('products page')),
          ),
          GoRoute(
            path: '/merchants',
            builder: (_, __) => const Scaffold(body: Text('merchants page')),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const Scaffold(body: Text('profile page')),
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpArabic(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Arabic shell mirrors the bottom navigation order',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _shellRouter(),
    ));
    await tester.pumpAndSettle();

    final homeX = tester.getCenter(find.text('الرئيسية')).dx;
    final moreX = tester.getCenter(find.text('المزيد')).dx;
    expect(homeX, greaterThan(moreX));
  });

  testWidgets('Arabic nutrition editor puts add action on the start edge',
      (tester) async {
    await _pumpArabic(
      tester,
      NutritionEditScreen(
        initialNutrients: const [],
        onSave: (_) async => null,
      ),
    );

    final addButton = find.text('إضافة عنصر غذائي');
    expect(addButton, findsOneWidget);
    expect(tester.getCenter(addButton).dx, greaterThan(400));
  });

  testWidgets('Arabic nutrition values align to the trailing edge',
      (tester) async {
    const nutrition = NutritionInfo(
      entityId: 1,
      nutrients: [
        NutrientEntry(
          key: 'energy',
          label: 'Energy',
          value: 120,
          unit: 'kcal',
          nrvPct: 12,
        ),
      ],
    );
    await _pumpArabic(
      tester,
      NutritionCard(
        nutrition: nutrition,
        loading: false,
        saving: false,
        entityType: 'ingredient',
        entityId: 1,
        onSave: (_) async => null,
      ),
    );

    final l10n =
        AppLocalizations.of(tester.element(find.byType(NutritionCard)));
    final nutrientRect = tester.getRect(find.text(l10n.nutritionNutrient));
    final quantityRect = tester.getRect(find.text(l10n.nutritionQuantity));
    final valueRect = tester.getRect(find.text('120 kcal'));
    expect(quantityRect.right, lessThanOrEqualTo(nutrientRect.left));
    expect(valueRect.right, lessThanOrEqualTo(nutrientRect.left));
    expect(quantityRect.center.dx, lessThan(400));
    expect(valueRect.center.dx, lessThan(400));
  });

  testWidgets('Arabic matrix prices align to the trailing edge',
      (tester) async {
    await _pumpArabic(
      tester,
      const MerchantPriceMatrix(
        ingredients: _matrixIngredients,
        prices: _matrixPrices,
        loading: false,
      ),
    );

    final ingredientRect = tester.getRect(find.text('Egg'));
    final priceRect = tester.getRect(find.text('3.5 CNY'));
    expect(priceRect.right, lessThan(ingredientRect.left));
  });

  testWidgets('Arabic price list keeps the menu on the trailing edge',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/prices',
      routes: [
        GoRoute(
          path: '/prices',
          builder: (_, __) => const PriceListScreen(),
        ),
        GoRoute(
          path: '/products/:id',
          builder: (_, __) => const Scaffold(body: Text('product page')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        priceListProvider.overrideWith(
          (ref) => PriceListNotifier(
            _PriceRepo(
              records: [
                const PriceRecord(
                  id: 1,
                  productId: 7,
                  productName: 'Tomato',
                  price: 6.88,
                  quantity: 500,
                  unit: 'g',
                  merchantId: 1,
                  merchantName: 'Market A',
                  recordedAt: '2026-09-01T10:00:00Z',
                ),
              ],
            ),
          ),
        ),
        merchantListProvider.overrideWith(
          (ref) => MerchantListNotifier(_MerchantRepo()),
        ),
      ],
      child: MaterialApp.router(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    final menuX = tester.getCenter(find.byIcon(Icons.more_vert)).dx;
    final productX = tester.getCenter(find.text('Tomato')).dx;
    expect(menuX, lessThan(productX));
  });

  testWidgets('Arabic chart and map keep numeric regions LTR', (tester) async {
    const nutrition = RecipeNutrition(
      totalCalories: 100,
      totalProtein: 7,
      totalFat: 0,
      totalCarbs: 0,
      perServingNutrients: {
        'protein': NutritionItem(
          value: 7,
          unit: 'g',
          nrpPct: 10,
          key: 'protein',
        ),
      },
      ingredientDetails: [
        IngredientNutritionDetail(
          recipeIngredientId: 1,
          ingredientId: 1,
          ingredientName: 'Egg',
          nutritionContribution: {
            '蛋白质': NutritionItem(value: 6, unit: 'g'),
          },
        ),
        IngredientNutritionDetail(
          recipeIngredientId: 2,
          ingredientId: 2,
          ingredientName: 'Tomato',
          nutritionContribution: {
            '蛋白质': NutritionItem(value: 1, unit: 'g'),
          },
        ),
      ],
    );
    await _pumpArabic(
      tester,
      const NutritionSourceGrid(nutrition: nutrition),
    );

    final bar = find.byKey(const Key('nrv_bar')).first;
    final surface = Theme.of(tester.element(bar)).colorScheme.surface;
    final segments = tester
        .widgetList<ColoredBox>(
          find.descendant(of: bar, matching: find.byType(ColoredBox)),
        )
        .where((widget) => widget.color != surface)
        .toList();
    expect(segments, isNotEmpty);
    final first = tester.getRect(find.byWidget(segments.first));
    final last = tester.getRect(find.byWidget(segments.last));
    expect(first.left, lessThan(last.left));

    final container = ProviderContainer(overrides: [
      mapConfigProvider.overrideWith((ref) => MapConfigNotifier(_MapRepo())),
    ]);
    addTearDown(container.dispose);
    await container.read(mapConfigProvider.notifier).load();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: MapPointPicker(
                initialValue: const LatLng(-31.2304, -121.4737),
                tileProvider: _MemoryTileProvider(),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final mapDirection = tester.widget<Directionality>(
      find.byKey(const ValueKey('picker-coordinate-ltr')),
    );
    expect(mapDirection.textDirection, TextDirection.ltr);
  });
}

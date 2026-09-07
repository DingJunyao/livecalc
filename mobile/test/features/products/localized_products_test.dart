import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient_category.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/barcode_lookup.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/providers/product_provider.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_detail_screen.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_list_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/widgets/loading_overlay.dart';

const _builtinCategory = IngredientCategory(
  id: 2,
  name: 'vegetables',
  displayName: '蔬菜',
);

const _customCategory = IngredientCategory(
  id: 99,
  name: 'custom-key',
  displayName: 'My Pantry Category',
);

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository({
    this.lookupCompleter,
  });

  final Completer<BarcodeLookupResult>? lookupCompleter;
  String? lastCreatedName;
  int? lastCreatedIngredientId;
  String? lastCreatedBarcode;

  @override
  Future<ProductPage> search({
    String? search,
    int? ingredientId,
    List<int>? ingredientIds,
    List<int>? ingredientCategoryIds,
    List<String>? brands,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
  }) async {
    return const ProductPage(items: [], total: 0);
  }

  @override
  Future<Product> getProduct(int id) async {
    return const Product(
      id: 12,
      name: 'Stored Product Name',
      ingredientId: 8,
      ingredientName: 'Stored Ingredient Name',
      brand: 'Stored Brand',
      barcode: '6901234567890',
      aliases: ['Stored alias'],
      tags: ['Stored tag'],
    );
  }

  @override
  Future<Product> createProduct({
    required String name,
    required int ingredientId,
    String? brand,
    String? barcode,
    List<String> aliases = const [],
    List<String> tags = const [],
  }) async {
    lastCreatedName = name;
    lastCreatedIngredientId = ingredientId;
    lastCreatedBarcode = barcode;
    return Product(id: 20, name: name);
  }

  @override
  Future<BarcodeLookupResult> lookupBarcode(String barcode) {
    final completer = lookupCompleter;
    if (completer == null) {
      throw StateError('Barcode lookup was not expected');
    }
    return completer.future;
  }
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
    return const MerchantPage(items: [], total: 0);
  }
}

class _StaticProductListNotifier extends ProductListNotifier {
  _StaticProductListNotifier() : super(_FakeProductRepository()) {
    state = state.copyWith(
      items: const [
        Product(
          id: 12,
          name: 'Stored Product Name',
          ingredientId: 8,
          ingredientName: 'Stored Ingredient Name',
          brand: 'Stored Brand',
        ),
      ],
      total: 1,
      hasMore: false,
    );
  }

  @override
  Future<void> load({bool loadMore = false}) async {}
}

class _StaticProductDetailNotifier extends ProductDetailPageNotifier {
  _StaticProductDetailNotifier(super.id) {
    state = const ProductDetailPageState(
      product: Product(
        id: 12,
        name: 'Stored Product Name',
        ingredientId: 8,
        ingredientName: 'Stored Ingredient Name',
        brand: 'Stored Brand',
        barcode: '6901234567890',
        aliases: ['Stored alias'],
        tags: ['Stored tag'],
      ),
    );
  }

  @override
  Future<void> load({int initialDays = 30, int? regionId}) async {}
}

Future<void> _pumpLocalized(
  WidgetTester tester,
  Locale locale,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  ApiClient.instance.updateBaseUrl('http://127.0.0.1:9');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ingredientCategoriesProvider.overrideWith((ref) async {
          return const [_builtinCategory, _customCategory];
        }),
        ingredientOptionsProvider.overrideWith((ref) async {
          return const [Ingredient(id: 8, name: 'Stored Ingredient Name')];
        }),
        merchantListProvider.overrideWith(
          (ref) => MerchantListNotifier(_FakeMerchantRepository()),
        ),
        ...overrides,
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
}

void main() {
  testWidgets('English product list and category filters localize', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const ProductListScreen(),
      overrides: [
        productListProvider.overrideWith(
          (ref) => _StaticProductListNotifier(),
        ),
      ],
    );

    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Search products...'), findsOneWidget);
    expect(find.text('Stored Product Name'), findsOneWidget);
    expect(find.text('Stored Brand'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Linked ingredient'), findsOneWidget);
    expect(find.text('Ingredient category'), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('Special conditions'), findsOneWidget);
    expect(find.text('No maintained price'), findsOneWidget);
    expect(find.text('Vegetables'), findsOneWidget);
    expect(find.text('My Pantry Category'), findsOneWidget);
  });

  testWidgets('Arabic product list and category filters localize', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const ProductListScreen(),
      overrides: [
        productListProvider.overrideWith(
          (ref) => _StaticProductListNotifier(),
        ),
      ],
    );

    expect(find.text('المنتجات'), findsOneWidget);
    expect(find.text('ابحث عن المنتجات...'), findsOneWidget);
    expect(find.text('Stored Product Name'), findsOneWidget);
    expect(find.text('Stored Brand'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('الفلاتر'), findsOneWidget);
    expect(find.text('المكوّن المرتبط'), findsOneWidget);
    expect(find.text('فئة المكوّن'), findsOneWidget);
    expect(find.text('العلامة التجارية'), findsOneWidget);
    expect(find.text('شروط خاصة'), findsOneWidget);
    expect(find.text('لا يوجد سعر مُصان'), findsOneWidget);
    expect(find.text('الخضروات'), findsOneWidget);
    expect(find.text('My Pantry Category'), findsOneWidget);
  });

  testWidgets('English product detail localizes labels and deletion copy', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const ProductDetailScreen(id: 12),
      overrides: [
        productDetailPageProvider.overrideWith(
          (ref, id) => _StaticProductDetailNotifier(id),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Product'), findsOneWidget);
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Latest price'), findsOneWidget);
    expect(find.text('No price data'), findsOneWidget);
    expect(find.text('Price records'), findsOneWidget);
    expect(find.text('Stored alias'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete product'));
    await tester.pumpAndSettle();
    expect(find.text('Delete product'), findsOneWidget);
    expect(find.text('Delete product "Stored Product Name"?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Arabic product detail localizes labels and deletion copy', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const ProductDetailScreen(id: 12),
      overrides: [
        productDetailPageProvider.overrideWith(
          (ref, id) => _StaticProductDetailNotifier(id),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('منتج'), findsOneWidget);
    expect(find.text('المعلومات الأساسية'), findsOneWidget);
    expect(find.text('أحدث سعر'), findsOneWidget);
    expect(find.text('لا توجد بيانات أسعار'), findsOneWidget);
    expect(find.text('سجلات الأسعار'), findsOneWidget);
    expect(find.text('Stored alias'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المنتج'));
    await tester.pumpAndSettle();
    expect(find.text('حذف المنتج'), findsOneWidget);
    expect(find.text('حذف المنتج "Stored Product Name"؟'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);
  });

  testWidgets('English product form validates and shows barcode lookup state', (
    tester,
  ) async {
    final lookup = Completer<BarcodeLookupResult>();
    final repository = _FakeProductRepository(lookupCompleter: lookup);
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      ProductFormScreen(
        fixedIngredient:
            const Ingredient(id: 8, name: 'Stored Ingredient Name'),
        repository: repository,
        scanner: (_) async => '6901234567890',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add product'), findsOneWidget);
    expect(find.text('Product name *'), findsOneWidget);
    expect(find.text('Linked ingredient'), findsOneWidget);
    expect(find.text('Stored Ingredient Name'), findsOneWidget);
    expect(find.text('Create ingredient with the same name'), findsOneWidget);
    expect(find.text('Barcode'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Product name is required'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product name *'),
      'Stored Product Name',
    );
    await tester.tap(find.byIcon(Icons.barcode_reader));
    await tester.pump();
    expect(find.byType(LoadingOverlay), findsOneWidget);
    expect(find.text('Looking up product information...'), findsOneWidget);

    lookup.complete(
      const BarcodeLookupResult(found: false, hasEnabledProviders: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoadingOverlay), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.lastCreatedName, 'Stored Product Name');
    expect(repository.lastCreatedIngredientId, 8);
    expect(repository.lastCreatedBarcode, '6901234567890');
  });

  testWidgets('Arabic edit form validates and shows barcode lookup state', (
    tester,
  ) async {
    final lookup = Completer<BarcodeLookupResult>();
    final repository = _FakeProductRepository(lookupCompleter: lookup);
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      ProductFormScreen(
        product: const Product(id: 12, name: 'Stored Product Name'),
        repository: repository,
        scanner: (_) async => '6901234567890',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعديل المنتج'), findsOneWidget);
    expect(find.text('اسم المنتج *'), findsOneWidget);
    expect(find.text('المكوّن المرتبط'), findsOneWidget);
    expect(find.text('Stored Ingredient Name'), findsOneWidget);
    expect(find.text('Stored Product Name'), findsOneWidget);
    expect(find.text('الرمز الشريطي'), findsOneWidget);
    expect(find.text('Stored alias'), findsOneWidget);
    expect(find.text('Stored tag'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم المنتج *'),
      '',
    );
    await tester.ensureVisible(find.text('حفظ'));
    await tester.tap(find.text('حفظ'));
    await tester.pump();
    expect(find.text('اسم المنتج مطلوب'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.barcode_reader));
    await tester.pump();
    expect(find.byType(LoadingOverlay), findsOneWidget);
    expect(find.text('جارٍ البحث عن معلومات المنتج...'), findsOneWidget);

    lookup.complete(
      const BarcodeLookupResult(found: false, hasEnabledProviders: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoadingOverlay), findsNothing);
  });
}

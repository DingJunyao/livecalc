import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_unit.dart';
import 'package:com_a4ding_livecalc/shared/models/merchant_price.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';
import 'package:com_a4ding_livecalc/shared/screens/entity_units_screen.dart';
import 'package:com_a4ding_livecalc/shared/screens/nutrition_edit_screen.dart';
import 'package:com_a4ding_livecalc/shared/screens/price_record_edit_screen.dart';
import 'package:com_a4ding_livecalc/shared/widgets/alias_tags_field.dart';
import 'package:com_a4ding_livecalc/shared/widgets/calc_context_menu_button.dart';
import 'package:com_a4ding_livecalc/shared/widgets/empty_state.dart';
import 'package:com_a4ding_livecalc/shared/widgets/error_display.dart';
import 'package:com_a4ding_livecalc/shared/widgets/loading_indicator.dart';
import 'package:com_a4ding_livecalc/shared/widgets/loading_overlay.dart';
import 'package:com_a4ding_livecalc/shared/widgets/merchant_price_list.dart';
import 'package:com_a4ding_livecalc/shared/widgets/nutrition_card.dart';
import 'package:com_a4ding_livecalc/shared/widgets/pending_change_banner.dart';
import 'package:com_a4ding_livecalc/shared/widgets/region_select_field.dart';

class _MockMerchantRepository extends Mock implements MerchantRepository {}

class _OfflinePriceRepository extends PriceRepository {
  @override
  ApiClient get client => throw StateError('Offline localized widget test');
}

void main() {
  Future<void> pumpLocalized(
    WidgetTester tester,
    Locale locale,
    Widget child, {
    Size size = const Size(800, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('common shared states localize English interface labels',
      (tester) async {
    const locale = Locale('en', 'US');
    await pumpLocalized(tester, locale, const LoadingIndicator());
    expect(find.text('Loading...'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      const Stack(children: [LoadingOverlay()]),
    );
    expect(find.text('Loading...'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      ErrorDisplay(message: 'Server response', onRetry: () {}),
    );
    expect(find.text('Server response'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      const EmptyState(icon: Icons.inbox_outlined, title: ''),
    );
    expect(find.text('Nothing here yet'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      const PendingChangeBanner(
        modifications: {'Server field'},
        deletions: {'Server unit'},
      ),
    );
    expect(
      find.text('Pending review: edit Server field, delete Server unit'),
      findsOneWidget,
    );
  });

  testWidgets('common shared states localize Arabic interface labels',
      (tester) async {
    const locale = Locale('ar');
    await pumpLocalized(tester, locale, const LoadingIndicator());
    expect(find.text('جارٍ التحميل…'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      const Stack(children: [LoadingOverlay()]),
    );
    expect(find.text('جارٍ التحميل…'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      ErrorDisplay(message: 'Server response', onRetry: () {}),
    );
    expect(find.text('Server response'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      const EmptyState(icon: Icons.inbox_outlined, title: ''),
    );
    expect(find.text('لا توجد بيانات بعد'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      const PendingChangeBanner(
        modifications: {'Server field'},
        deletions: {'Server unit'},
      ),
    );
    expect(
      find.text('في انتظار المراجعة: تعديل Server field، حذف Server unit'),
      findsOneWidget,
    );
  });

  testWidgets('common shared states keep Chinese labels unchanged',
      (tester) async {
    const locale = Locale('zh', 'CN');
    await pumpLocalized(tester, locale, const LoadingIndicator());
    expect(find.text('加载中...'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      ErrorDisplay(message: 'Server response', onRetry: () {}),
    );
    expect(find.text('重试'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      const EmptyState(icon: Icons.inbox_outlined, title: ''),
    );
    expect(find.text('暂无数据'), findsOneWidget);

    await pumpLocalized(
      tester,
      locale,
      const PendingChangeBanner(
        modifications: {'Server field'},
        deletions: {'Server unit'},
      ),
    );
    expect(
      find.text('待管理员审核：修改Server field、删除Server unit'),
      findsOneWidget,
    );
  });

  testWidgets('selection widgets localize labels and preserve server values',
      (tester) async {
    final repository = _MockMerchantRepository();
    when(() => repository.listRegions(
          parentId: any(named: 'parentId'),
          level: any(named: 'level'),
        )).thenAnswer((_) async => [
          {'id': 10, 'name': 'Server Region'},
        ]);

    await pumpLocalized(
      tester,
      const Locale('en', 'US'),
      RegionSelectField(
        key: const ValueKey('en-region'),
        value: null,
        onChanged: (_) {},
        repository: repository,
      ),
    );
    expect(find.text('Country/region'), findsOneWidget);
    expect(find.text('Select'), findsNWidgets(4));
    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    expect(find.text('Server Region'), findsOneWidget);
    await tester.tap(find.text('Server Region'));
    await tester.pumpAndSettle();

    await pumpLocalized(
      tester,
      const Locale('ar'),
      RegionSelectField(
        key: const ValueKey('ar-region'),
        value: null,
        onChanged: (_) {},
        repository: repository,
      ),
    );
    expect(find.text('البلد/المنطقة'), findsOneWidget);
    expect(find.text('اختر'), findsNWidgets(4));
    await tester.tap(find.text('اختر').first);
    await tester.pumpAndSettle();
    expect(find.text('Server Region'), findsOneWidget);
    await tester.tap(find.text('Server Region'));
    await tester.pumpAndSettle();

    await pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const AliasTagsField(
        label: 'Aliases',
        initialTags: ['Server alias'],
        onTagsChanged: _ignoreTags,
      ),
    );
    expect(find.text('Press + to add'), findsOneWidget);
    final englishAdd = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(englishAdd.message, 'Add');
    expect(find.text('Server alias'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Locale('ar'),
      const AliasTagsField(
        label: 'Aliases',
        initialTags: ['Server alias'],
        onTagsChanged: _ignoreTags,
      ),
    );
    expect(find.text('اضغط + للإضافة'), findsOneWidget);
    final arabicAdd = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(arabicAdd.message, 'إضافة');
    expect(find.text('Server alias'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const CalcContextMenuButton(),
    );
    final englishContext = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(englishContext.message, 'Region / calculation scope / currency');

    await pumpLocalized(
      tester,
      const Locale('ar'),
      const CalcContextMenuButton(),
    );
    final arabicContext = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(arabicContext.message, 'المنطقة / نطاق الحساب / العملة');
  });

  testWidgets('nutrition and merchant widgets localize static display labels',
      (tester) async {
    const nutrition = NutritionInfo(
      entityId: 1,
      nutrients: [
        NutrientEntry(
          key: 'energy',
          label: 'Server nutrient',
          value: 120,
          unit: 'kcal',
        ),
      ],
    );

    await pumpLocalized(
      tester,
      const Locale('en', 'US'),
      NutritionCard(
        nutrition: nutrition,
        loading: false,
        saving: false,
        entityType: 'ingredient',
        entityId: 1,
        onSave: (_) async => null,
      ),
    );
    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Server nutrient'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Locale('ar'),
      NutritionCard(
        nutrition: nutrition,
        loading: false,
        saving: false,
        entityType: 'ingredient',
        entityId: 1,
        onSave: (_) async => null,
      ),
    );
    expect(find.text('القيم الغذائية'), findsOneWidget);
    expect(find.text('تعديل'), findsOneWidget);
    expect(find.text('Server nutrient'), findsOneWidget);

    const prices = [
      MerchantPrice(
        merchantId: 1,
        merchantName: 'Server Merchant',
        price: 6.88,
        unit: 'kg',
        isLowest: true,
      ),
    ];

    await pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const MerchantPriceList(prices: prices, unit: 'kg'),
    );
    expect(find.text('Merchant prices'), findsOneWidget);
    expect(find.text('Lowest'), findsOneWidget);
    expect(find.text('Server Merchant'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Locale('ar'),
      const MerchantPriceList(prices: prices, unit: 'kg'),
    );
    expect(find.text('أسعار المتاجر'), findsOneWidget);
    expect(find.text('الأقل'), findsOneWidget);
    expect(find.text('Server Merchant'), findsOneWidget);
  });

  testWidgets('entity editors localize unit, nutrition, and price labels',
      (tester) async {
    await pumpLocalized(
      tester,
      const Locale('en', 'US'),
      EntityUnitsScreen(
        entityType: 'ingredient',
        entityId: 1,
        units: const [
          EntityUnit(id: 1, unitName: 'Server unit', isDefault: true),
        ],
        unmappedUnits: const [],
        densities: const [],
        onAddUnit: (_) async => null,
        onEditUnit: (_, __) async => null,
        onDeleteUnit: (_) async => null,
        onQuickAddUnmapped: (_) async => null,
        onAddDensity: (_) async => null,
        onDeleteDensity: (_) async => null,
      ),
    );
    expect(find.text('Units & densities'), findsOneWidget);
    expect(find.text('Save unit'), findsOneWidget);
    expect(find.text('Server unit'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await pumpLocalized(
      tester,
      const Locale('ar'),
      EntityUnitsScreen(
        entityType: 'ingredient',
        entityId: 1,
        units: const [
          EntityUnit(id: 1, unitName: 'Server unit', isDefault: true),
        ],
        unmappedUnits: const [],
        densities: const [],
        onAddUnit: (_) async => null,
        onEditUnit: (_, __) async => null,
        onDeleteUnit: (_) async => null,
        onQuickAddUnmapped: (_) async => null,
        onAddDensity: (_) async => null,
        onDeleteDensity: (_) async => null,
      ),
    );
    expect(find.text('الوحدات والكثافات'), findsOneWidget);
    expect(find.text('حفظ الوحدة'), findsOneWidget);
    expect(find.text('Server unit'), findsOneWidget);
    await tester.ensureVisible(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('حذف'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Locale('en', 'US'),
      NutritionEditScreen(
        initialNutrients: const [],
        onSave: (_) async => null,
      ),
      size: const Size(900, 1200),
    );
    expect(find.text('Edit nutrition'), findsOneWidget);
    expect(find.text('Nutrient'), findsWidgets);
    expect(find.text('Save'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Locale('ar'),
      NutritionEditScreen(
        initialNutrients: const [],
        onSave: (_) async => null,
      ),
      size: const Size(900, 1200),
    );
    expect(find.text('تعديل القيم الغذائية'), findsOneWidget);
    expect(find.text('العنصر الغذائي'), findsWidgets);
    expect(find.text('حفظ'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Locale('en', 'US'),
      PriceRecordEditScreen(
        arguments: const PriceRecordFormArguments(
          merchants: [],
          initialPrice: 6.88,
        ),
        priceRepository: _OfflinePriceRepository(),
      ),
      size: const Size(900, 1600),
    );
    expect(find.text('Edit price record'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);
    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await pumpLocalized(
      tester,
      const Locale('ar'),
      PriceRecordEditScreen(
        arguments: const PriceRecordFormArguments(
          merchants: [],
          initialPrice: 6.88,
        ),
        priceRepository: _OfflinePriceRepository(),
      ),
      size: const Size(900, 1600),
    );
    expect(find.text('تعديل سجل السعر'), findsOneWidget);
    expect(find.text('السعر'), findsOneWidget);
    expect(find.text('الوحدة'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
  });
}

void _ignoreTags(List<String> tags) {}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/core/i18n/app_formatters.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/providers/price_provider.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/paste_import_screen.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/price_list_screen.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/price_record_form_screen.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/quick_fill_screen.dart';
import 'package:com_a4ding_livecalc/features/prices/utils/paste_price_parser.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/screens/price_record_edit_screen.dart';

class _FakePriceRepository extends PriceRepository {
  _FakePriceRepository({
    this.seed = const [],
    this.failProductIds = const {},
  });

  final List<PriceRecord> seed;
  final Set<int> failProductIds;

  Exception? deleteError;
  Exception? createError;
  int deleteCalls = 0;
  int createCount = 0;
  double? lastPrice;
  double? lastQuantity;
  String? lastUnit;
  int? lastProductId;
  String? lastProductName;
  int? lastMerchantId;
  String? lastRecordType;
  final List<Map<String, dynamic>> createCalls = [];

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
    return PriceRecordsResult(records: seed, total: seed.length);
  }

  @override
  Future<void> deleteRecord(int id) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<PriceRecord> createRecord({
    int? productId,
    String? productName,
    required double price,
    double quantity = 1,
    String unit = '个',
    int? merchantId,
    int? ingredientId,
    String recordType = 'purchase',
    String? notes,
    DateTime? recordedAt,
    String currency = 'CNY',
  }) async {
    createCount++;
    lastPrice = price;
    lastQuantity = quantity;
    lastUnit = unit;
    lastProductId = productId;
    lastProductName = productName;
    lastMerchantId = merchantId;
    lastRecordType = recordType;
    createCalls.add({
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'product_id': productId,
      'product_name': productName,
      'merchant_id': merchantId,
      'record_type': recordType,
      'recorded_at': recordedAt,
    });
    if (createError != null) throw createError!;
    if (productId != null && failProductIds.contains(productId)) {
      throw Exception('forced import failure');
    }
    return PriceRecord.fromJson({
      'id': createCount,
      'product_id': productId ?? 0,
      'product_name': productName ?? '',
      'price': price,
      'original_quantity': quantity,
      'original_unit': unit,
      'record_type': recordType,
    });
  }

  @override
  Future<void> addImportAlias(int productId, String name) async {}
}

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository({
    this.searchItems = const [],
    this.autocompleteTable = const {},
  });

  final List<Product> searchItems;
  final Map<String, List<Map<String, dynamic>>> autocompleteTable;

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
    return ProductPage(items: searchItems, total: searchItems.length);
  }

  @override
  Future<List<Map<String, dynamic>>> autocomplete(String query,
      {int limit = 20}) async {
    return autocompleteTable[query] ?? const [];
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
    return const MerchantPage(
      items: [Merchant(id: 1, name: 'Fresh Market')],
      total: 1,
    );
  }
}

class _LocalApiAdapter implements HttpClientAdapter {
  const _LocalApiAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.endsWith('/merchants/1/product-prices')) {
      return _json({'items': <Object>[], 'total': 0});
    }
    if (path.endsWith('/merchants')) {
      return _json({
        'items': [
          {'id': 1, 'name': 'Fresh Market', 'default_currency': 'CNY'},
        ],
        'total': 1,
      });
    }
    if (path.endsWith('/currencies')) {
      return _json([
        {'code': 'CNY', 'name': 'Chinese yuan'},
      ]);
    }
    return _json(const <String, Object>{});
  }

  ResponseBody _json(Object data) => ResponseBody.fromString(
        jsonEncode(data),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

class _Copy {
  final String searchHint;
  final String priceListTitle;
  final String deleteTitle;
  final String deleteVerb;
  final String deleted;
  final String edit;
  final String filterTitle;
  final String allMerchants;
  final String recordType;
  final String purchase;
  final String comparison;
  final String confirm;
  final String addRecordTitle;
  final String merchant;
  final String productNameLabel;
  final String priceLabel;
  final String currency;
  final String quantityLabel;
  final String unitLabel;
  final String countExpense;
  final String recordedAt;
  final String notes;
  final String save;
  final String validPrice;
  final String quickFillTitle;
  final String selectMerchant;
  final String merchantSearchHint;
  final String noHistory;
  final String addProduct;
  final String newProductHint;
  final String productHeader;
  final String unitPrice;
  final String pasteTitle;
  final String copyTemplate;
  final String pasteTextLabel;
  final String parseAndMatch;
  final String linkExisting;
  final String searchProducts;
  final String linkIngredient;
  final String searchIngredients;
  final String createSame;
  final String cancel;
  final String errorComment;
  final String importAllTemplate;
  final String pasteCompleteTemplate;
  final String pasteFailedTemplate;
  final String summaryTemplate;
  final String deleteMessageTemplate;

  const _Copy({
    required this.searchHint,
    required this.priceListTitle,
    required this.deleteTitle,
    required this.deleteVerb,
    required this.deleted,
    required this.edit,
    required this.filterTitle,
    required this.allMerchants,
    required this.recordType,
    required this.purchase,
    required this.comparison,
    required this.confirm,
    required this.addRecordTitle,
    required this.merchant,
    required this.productNameLabel,
    required this.priceLabel,
    required this.currency,
    required this.quantityLabel,
    required this.unitLabel,
    required this.countExpense,
    required this.recordedAt,
    required this.notes,
    required this.save,
    required this.validPrice,
    required this.quickFillTitle,
    required this.selectMerchant,
    required this.merchantSearchHint,
    required this.noHistory,
    required this.addProduct,
    required this.newProductHint,
    required this.productHeader,
    required this.unitPrice,
    required this.pasteTitle,
    required this.copyTemplate,
    required this.pasteTextLabel,
    required this.parseAndMatch,
    required this.linkExisting,
    required this.searchProducts,
    required this.linkIngredient,
    required this.searchIngredients,
    required this.createSame,
    required this.cancel,
    required this.errorComment,
    required this.importAllTemplate,
    required this.pasteCompleteTemplate,
    required this.pasteFailedTemplate,
    required this.summaryTemplate,
    required this.deleteMessageTemplate,
  });

  String importAll(int count) =>
      importAllTemplate.replaceAll('{count}', '$count');

  String pasteComplete(int success, int fail) => pasteCompleteTemplate
      .replaceAll('{success}', '$success')
      .replaceAll('{fail}', '$fail');

  String pasteFailed(String items) =>
      pasteFailedTemplate.replaceAll('{items}', items);

  String summary(int matched, int unmatched, int invalid) => summaryTemplate
      .replaceAll('{matched}', '$matched')
      .replaceAll('{unmatched}', '$unmatched')
      .replaceAll('{invalid}', '$invalid');

  String deleteMessage(String name, String price) => deleteMessageTemplate
      .replaceAll('{name}', name)
      .replaceAll('{price}', price);
}

const _english = _Copy(
  searchHint: 'Search products...',
  priceListTitle: 'Price records',
  deleteTitle: 'Delete record',
  deleteVerb: 'Delete',
  deleted: 'Deleted',
  edit: 'Edit',
  filterTitle: 'Filter options',
  allMerchants: 'All merchants',
  recordType: 'Record type',
  purchase: 'Purchase',
  comparison: 'Comparison',
  confirm: 'Confirm',
  addRecordTitle: 'Add price record',
  merchant: 'Merchant',
  productNameLabel: 'Product name',
  priceLabel: 'Price',
  currency: 'Currency',
  quantityLabel: 'Quantity',
  unitLabel: 'Unit',
  countExpense: 'Include in spending',
  recordedAt: 'Recorded at',
  notes: 'Notes',
  save: 'Save',
  validPrice: 'Enter a valid price',
  quickFillTitle: 'Quick fill',
  selectMerchant: 'Select merchant',
  merchantSearchHint: 'Search or select a merchant',
  noHistory: 'No historical products yet',
  addProduct: 'Add product',
  newProductHint: 'New product',
  productHeader: 'Product',
  unitPrice: 'Unit price',
  pasteTitle: 'Paste price import',
  copyTemplate: 'Copy template',
  pasteTextLabel: 'Paste price text\n(one per line, format: name price[/unit])',
  parseAndMatch: 'Parse and match',
  linkExisting: 'Link an existing product',
  searchProducts: 'Search products...',
  linkIngredient: 'Link to ingredient',
  searchIngredients: 'Search ingredients...',
  createSame: 'Create same-named ingredient + product',
  cancel: 'Cancel',
  errorComment: 'Comment line',
  importAllTemplate: 'Import all ({count} records)',
  pasteCompleteTemplate: 'Import complete: {success} succeeded, {fail} failed',
  pasteFailedTemplate: 'Failed: {items}',
  summaryTemplate:
      'Matched {matched} · Pending {unmatched} · Unrecognized {invalid}',
  deleteMessageTemplate: 'Delete the price record for "{name}" ({price})?',
);

const _arabic = _Copy(
  searchHint: 'ابحث عن المنتجات...',
  priceListTitle: 'سجلات الأسعار',
  deleteTitle: 'حذف السجل',
  deleteVerb: 'حذف',
  deleted: 'تم الحذف',
  edit: 'تعديل',
  filterTitle: 'خيارات التصفية',
  allMerchants: 'كل المتاجر',
  recordType: 'نوع السجل',
  purchase: 'شراء',
  comparison: 'مقارنة',
  confirm: 'موافق',
  addRecordTitle: 'إضافة سجل سعر',
  merchant: 'المتجر',
  productNameLabel: 'اسم المنتج',
  priceLabel: 'السعر',
  currency: 'العملة',
  quantityLabel: 'الكمية',
  unitLabel: 'الوحدة',
  countExpense: 'احتسابه في الإنفاق',
  recordedAt: 'وقت التسجيل',
  notes: 'ملاحظات',
  save: 'حفظ',
  validPrice: 'يرجى إدخال سعر صالح',
  quickFillTitle: 'تعبئة سريعة',
  selectMerchant: 'اختيار المتجر',
  merchantSearchHint: 'ابحث عن متجر أو اختره',
  noHistory: 'لا توجد منتجات تاريخية بعد',
  addProduct: 'إضافة منتج',
  newProductHint: 'منتج جديد',
  productHeader: 'المنتج',
  unitPrice: 'سعر الوحدة',
  pasteTitle: 'لصق واستيراد الأسعار',
  copyTemplate: 'نسخ القالب',
  pasteTextLabel:
      'الصق نص الأسعار\n(سطر لكل عنصر، الصيغة: الاسم السعر[/الوحدة])',
  parseAndMatch: 'تحليل ومطابقة',
  linkExisting: 'ربط منتج موجود',
  searchProducts: 'ابحث عن المنتجات...',
  linkIngredient: 'ربط إلى مكوّن',
  searchIngredients: 'ابحث عن المكوّنات...',
  createSame: 'إنشاء مكوّن ومنتج بنفس الاسم',
  cancel: 'إلغاء',
  errorComment: 'سطر تعليق',
  importAllTemplate: 'استيراد الكل ({count} سجلات)',
  pasteCompleteTemplate: 'اكتمل الاستيراد: نجح {success} وفشل {fail}',
  pasteFailedTemplate: 'فشل: {items}',
  summaryTemplate:
      'تمت المطابقة {matched} · قيد المعالجة {unmatched} · غير معروف {invalid}',
  deleteMessageTemplate: 'حذف سجل السعر لـ "{name}" ({price})؟',
);

PriceRecord _record(
    {String name = 'Tomato', String? merchantName = 'Fresh Market'}) {
  return PriceRecord(
    id: 1,
    productId: 10,
    productName: name,
    price: 6.88,
    quantity: 500,
    unit: 'g',
    merchantId: 1,
    merchantName: merchantName,
    recordedAt: '2026-08-11T02:00:00Z',
  );
}

String _uiCode(Locale locale) =>
    locale.languageCode == 'en' ? 'en-US' : locale.languageCode;

void _useStore(Locale locale) {
  final original = localeSettingsStore.current;
  localeSettingsStore.update(LocaleSettings(uiLocale: _uiCode(locale)));
  addTearDown(() => localeSettingsStore.update(original));
}

void _installApiAdapter() {
  final api = ApiClient.instance;
  api.updateBaseUrl('https://example.test');
  final dio = api.dio;
  final original = dio.httpClientAdapter;
  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(storageChannel, (_) async => null);
  dio.httpClientAdapter = const _LocalApiAdapter();
  addTearDown(() => dio.httpClientAdapter = original);
  addTearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(storageChannel, null));
}

Future<void> _pumpLocalized(
  WidgetTester tester,
  Locale locale,
  Widget home, {
  List<Override> overrides = const [],
  Size size = const Size(800, 1800),
}) async {
  _useStore(locale);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
}

class _PushHost extends StatefulWidget {
  final Widget Function() builder;
  const _PushHost({required this.builder});

  @override
  State<_PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<_PushHost> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute<void>(builder: (_) => widget.builder()),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpForm(
  WidgetTester tester,
  Locale locale,
  _FakePriceRepository priceRepo,
  _FakeProductRepository productRepo,
) async {
  await _pumpLocalized(
    tester,
    locale,
    _PushHost(
      builder: () => PriceRecordFormScreen(
        priceRepository: priceRepo,
        productRepository: productRepo,
      ),
    ),
    overrides: [
      merchantListProvider.overrideWith(
        (ref) => MerchantListNotifier(_FakeMerchantRepository()),
      ),
    ],
    size: const Size(900, 2200),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _pumpPaste(
  WidgetTester tester,
  Locale locale,
  PasteImportScreen screen,
) async {
  await _pumpLocalized(
    tester,
    locale,
    _PushHost(builder: () => screen),
    size: const Size(900, 1800),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder _merchantField() => find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );

Finder _quickMerchantField() => find.descendant(
      of: find
          .byWidgetPredicate((w) => w is Autocomplete<Map<String, dynamic>>),
      matching: find.byType(TextField),
    );

void main() {
  test('paste parser returns stable machine-readable error keys', () {
    expect(parsePasteLine('').error, 'empty_line');
    expect(parsePasteLine('# note').error, 'comment_line');
    expect(parsePasteLine('only name').error, 'unrecognized_format');
    expect(parsePasteLine('Tomato 0').error, 'invalid_price');
  });

  test('all paste hint example lines parse', () async {
    for (final (name, locale) in [
      ('English', const Locale('en', 'US')),
      ('Chinese', const Locale('zh', 'CN')),
      ('Arabic', const Locale('ar')),
    ]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final lines = l10n.pricePasteHint.split('\n');
      expect(lines.length, 4, reason: name);
      for (final line in lines) {
        final parsed = parsePasteLine(line);
        expect(parsed.ok, isTrue, reason: '$name hint line: $line');
      }
    }
  });

  for (final (name, locale, copy) in [
    ('English', const Locale('en', 'US'), _english),
    ('Arabic', const Locale('ar'), _arabic),
  ]) {
    testWidgets('$name price list and delete flow localize', (tester) async {
      final repo = _FakePriceRepository(seed: [_record()]);
      _installApiAdapter();
      await _pumpLocalized(
        tester,
        locale,
        const PriceListScreen(),
        overrides: [
          priceListProvider.overrideWith(
            (ref) => PriceListNotifier(repo),
          ),
          merchantListProvider.overrideWith(
            (ref) => MerchantListNotifier(_FakeMerchantRepository()),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text(copy.priceListTitle), findsOneWidget);
      expect(find.text('Tomato'), findsOneWidget);
      final search = tester.widget<TextField>(find.byType(TextField));
      expect(search.decoration?.hintText, copy.searchHint);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.text(copy.filterTitle), findsOneWidget);
      expect(find.text(copy.merchant), findsWidgets);
      expect(find.text(copy.allMerchants), findsWidgets);
      expect(find.text(copy.recordType), findsOneWidget);
      expect(find.text(copy.purchase), findsOneWidget);
      expect(find.text(copy.comparison), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text(copy.edit), findsOneWidget);
      expect(find.text(copy.deleteVerb), findsOneWidget);
      await tester.tap(find.text(copy.deleteVerb));
      await tester.pumpAndSettle();
      expect(find.text(copy.deleteTitle), findsOneWidget);
      expect(
        find.textContaining(
            copy.deleteMessage('Tomato', formatMoney(6.88, 'CNY'))),
        findsOneWidget,
      );

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(copy.deleteVerb),
      ));
      await tester.pumpAndSettle();
      expect(find.text(copy.deleted), findsOneWidget);
      expect(repo.deleteCalls, 1);
    });

    testWidgets('$name record form validates and preserves submitted values', (
      tester,
    ) async {
      _installApiAdapter();
      final repo = _FakePriceRepository();
      final productRepo = _FakeProductRepository(
        searchItems: const [Product(id: 7, name: 'Tomato')],
      );
      await _pumpForm(tester, locale, repo, productRepo);

      expect(find.text(copy.addRecordTitle), findsOneWidget);
      expect(find.text(copy.merchant), findsOneWidget);
      expect(find.text(copy.productNameLabel), findsOneWidget);
      expect(find.text(copy.priceLabel), findsOneWidget);
      expect(find.text(copy.currency), findsOneWidget);
      expect(find.text(copy.quantityLabel), findsOneWidget);
      expect(find.text(copy.unitLabel), findsOneWidget);
      expect(find.text(copy.countExpense), findsOneWidget);
      expect(find.text(copy.recordedAt), findsOneWidget);
      expect(find.text(copy.notes), findsOneWidget);
      expect(find.widgetWithText(FilledButton, copy.save), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, copy.save));
      await tester.pump();
      expect(find.text(copy.validPrice), findsOneWidget);
      expect(repo.createCount, 0);

      await tester.enterText(
        find.widgetWithText(TextField, copy.productNameLabel),
        'Tomato',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Tomato'));
      await tester.pumpAndSettle();

      await tester.enterText(_merchantField(), 'Fresh');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fresh Market'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, copy.priceLabel),
        '12.34',
      );
      await tester.enterText(
        find.widgetWithText(TextField, copy.quantityLabel),
        '2.5',
      );
      await tester.tap(find.widgetWithText(FilledButton, copy.save));
      await tester.pumpAndSettle();

      expect(repo.createCount, 1);
      expect(repo.lastProductId, 7);
      expect(repo.lastMerchantId, 1);
      expect(repo.lastPrice, 12.34);
      expect(repo.lastQuantity, 2.5);
      expect(repo.lastUnit, '斤');
      expect(repo.lastRecordType, 'purchase');
      expect(find.byType(PriceRecordFormScreen), findsNothing);
    });

    testWidgets('$name edit fields keep dot-decimal text', (tester) async {
      _installApiAdapter();
      await _pumpLocalized(
        tester,
        locale,
        _PushHost(
          builder: () => const PriceRecordEditScreen(
            arguments: PriceRecordFormArguments(
              merchants: [Merchant(id: 1, name: 'Fresh Market')],
              initialPrice: 1234.5,
              initialQuantity: 2.5,
              initialUnit: '斤',
              initialRecordType: 'purchase',
              initialCurrency: 'CNY',
            ),
          ),
        ),
        size: const Size(900, 2200),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final price = tester.widget<TextField>(
        find.widgetWithText(TextField, copy.priceLabel),
      );
      final quantity = tester.widget<TextField>(
        find.widgetWithText(TextField, copy.quantityLabel),
      );
      expect(price.controller?.text, '1234.50');
      expect(quantity.controller?.text, '2.50');
      expect(find.text(copy.recordedAt), findsOneWidget);
    });

    testWidgets('$name quick fill labels localize and add a row',
        (tester) async {
      _installApiAdapter();
      await _pumpLocalized(tester, locale, const QuickFillScreen());
      await tester.pumpAndSettle();

      expect(find.text(copy.quickFillTitle), findsOneWidget);
      expect(find.text(copy.selectMerchant), findsOneWidget);
      expect(find.text(copy.currency), findsOneWidget);
      final merchant = tester.widget<TextField>(_quickMerchantField());
      expect(merchant.decoration?.hintText, copy.merchantSearchHint);

      await tester.enterText(_quickMerchantField(), 'Fresh');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fresh Market'));
      await tester.pumpAndSettle();
      expect(find.text(copy.noHistory), findsOneWidget);

      await tester.tap(find.text(copy.addProduct).first);
      await tester.pumpAndSettle();
      expect(find.text(copy.productHeader), findsOneWidget);
      expect(find.text(copy.unitPrice), findsOneWidget);
      final name = tester.widget<TextField>(
        find.widgetWithText(TextField, copy.productNameLabel),
      );
      expect(name.controller?.text, isEmpty);
      expect(name.decoration?.hintText, copy.newProductHint);
    });

    testWidgets('$name paste import preview localizes malformed rows', (
      tester,
    ) async {
      final priceRepo = _FakePriceRepository();
      final productRepo = _FakeProductRepository();
      await _pumpPaste(
        tester,
        locale,
        PasteImportScreen(
          merchantId: 7,
          historyProductNames: const [],
          priceRepository: priceRepo,
          productRepository: productRepo,
        ),
      );

      expect(find.text(copy.pasteTitle), findsOneWidget);
      expect(find.text(copy.recordedAt), findsOneWidget);
      expect(find.text(copy.copyTemplate), findsOneWidget);
      expect(find.text(copy.pasteTextLabel), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('paste-raw-text-field')),
        'Tomato 12.5\n# A comment',
      );
      await tester.tap(find.text(copy.parseAndMatch));
      await tester.pumpAndSettle();

      expect(find.text(copy.summary(0, 1, 1)), findsOneWidget);
      expect(find.textContaining(copy.errorComment), findsOneWidget);
      final priceText = formatNumber(
        12.5,
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      );
      expect(find.text(priceText), findsOneWidget);
      expect(find.text('${formatQuantity(1)} 斤'), findsOneWidget);

      await tester.tap(find.text('Tomato'));
      await tester.pumpAndSettle();
      expect(find.text(copy.linkExisting), findsOneWidget);
      expect(find.text(copy.searchProducts), findsOneWidget);
      expect(find.text(copy.linkIngredient), findsOneWidget);
      expect(find.text(copy.searchIngredients), findsOneWidget);
      expect(find.text(copy.createSame), findsOneWidget);
      expect(find.text(copy.cancel), findsOneWidget);
    });

    testWidgets('$name paste import reports partial success and failure', (
      tester,
    ) async {
      final priceRepo = _FakePriceRepository(failProductIds: {2});
      final productRepo = _FakeProductRepository(
        autocompleteTable: {
          'Good Product': [
            {'id': 1, 'name': 'Good Product', 'match_type': 'name'},
          ],
          'Bad Product': [
            {'id': 2, 'name': 'Bad Product', 'match_type': 'name'},
          ],
        },
      );
      await _pumpPaste(
        tester,
        locale,
        PasteImportScreen(
          merchantId: 7,
          historyProductNames: const [],
          priceRepository: priceRepo,
          productRepository: productRepo,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('paste-raw-text-field')),
        'Good Product 3\nBad Product 2',
      );
      await tester.tap(find.text(copy.parseAndMatch));
      await tester.pumpAndSettle();

      expect(find.text(copy.summary(2, 0, 0)), findsOneWidget);
      final importButton = find.byKey(const Key('paste-import-button'));
      await tester.ensureVisible(importButton);
      await tester.tap(importButton);
      await tester.pumpAndSettle();

      expect(priceRepo.createCount, 2);
      expect(find.byType(PasteImportScreen), findsOneWidget);
      expect(find.text(copy.pasteComplete(1, 1)), findsOneWidget);
      expect(find.text(copy.pasteFailed('Bad Product')), findsOneWidget);
      expect(priceRepo.createCount, 2);
      expect(priceRepo.createCalls[0]['price'], 3);
      expect(priceRepo.createCalls[1]['price'], 2);
    });
  }
}

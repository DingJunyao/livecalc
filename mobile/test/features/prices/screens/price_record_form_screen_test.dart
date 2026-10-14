import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/price_record_form_screen.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/barcode_lookup.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/utils/entity_unit_names.dart';
import 'package:com_a4ding_livecalc/shared/widgets/loading_overlay.dart';

class _FakePriceRepository extends PriceRepository {
  int createCount = 0;
  int? lastProductId;
  String? lastProductName;
  String? lastRecordType;
  String? lastNotes;
  double? lastPrice;
  double? lastQuantity;
  String? lastUnit;
  int? lastMerchantId;
  String? lastCurrency;
  DateTime? lastRecordedAt;

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
    lastCurrency = currency;
    lastProductId = productId;
    lastProductName = productName;
    lastRecordType = recordType;
    lastNotes = notes;
    lastPrice = price;
    lastQuantity = quantity;
    lastUnit = unit;
    lastMerchantId = merchantId;
    lastRecordedAt = recordedAt;
    return PriceRecord.fromJson({
      'id': 1,
      'product_id': productId ?? 0,
      'product_name': productName ?? '',
      'price': price,
      'original_quantity': quantity,
      'original_unit': unit,
      'record_type': recordType,
    });
  }
}

class _FakeProductRepository extends ProductRepository {
  final List<Product> items;
  int? lastIngredientId;
  _FakeProductRepository(this.items);

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
    lastIngredientId = ingredientId;
    return ProductPage(items: items, total: items.length);
  }
}

class _ScanLookupProductRepository extends ProductRepository {
  _ScanLookupProductRepository(this.completer);

  final Completer<BarcodeLookupResult> completer;

  @override
  Future<BarcodeLookupResult> lookupBarcode(String barcode) {
    return completer.future;
  }
}

class _FakeMerchantRepository extends MerchantRepository {
  _FakeMerchantRepository({this.merchantCurrency});

  final String? merchantCurrency;

  @override
  Future<MerchantPage> search({
    String? search,
    bool includeClosed = false,
    bool noPrice = false,
    bool includeOtherRegions = false,
    int skip = 0,
    int limit = 20,
  }) async {
    // 返回多个商家以便测 Autocomplete 过滤
    return MerchantPage(
      items: [
        Merchant(
          id: 1,
          name: '超市',
          defaultCurrency: merchantCurrency,
        ),
        const Merchant(id: 2, name: '便利店'),
      ],
      total: 2,
    );
  }
}

/// 表单页必须经 push 进入（保存时 pop 返回结果），用宿主按钮模拟。
class _FormHost extends StatelessWidget {
  final PriceRecordFormScreen form;
  const _FormHost({required this.form});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => form),
            ),
            child: const Text('打开表单'),
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    _FakePriceRepository? priceRepo,
    ProductRepository? productRepo,
    PriceRecordFormPrefill? prefill,
    Future<String?> Function(BuildContext)? scanner,
    Future<List<String>> Function(int productId, int? ingredientId)?
        unitNamesLoader,
    Future<List<String>> Function()? globalUnitNamesLoader,
    Future<String?> Function(int productId, int? ingredientId)?
        defaultUnitLoader,
    EntityUnitsRequest? entityUnitsRequest,
    double viewportHeight = 1400,
    String? merchantCurrency,
  }) async {
    // 表单整体超过默认 600 高视口，放大视口让底部保存按钮被构建。
    tester.view.physicalSize = Size(800, viewportHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        merchantListProvider.overrideWith(
          (ref) => MerchantListNotifier(
            _FakeMerchantRepository(merchantCurrency: merchantCurrency),
          ),
        ),
      ],
      // 裸 Scaffold 在测试环境缺 Directionality，需 MaterialApp 包裹
      // （与本仓库其他页面测试一致）。
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _FormHost(
          form: PriceRecordFormScreen(
            priceRepository: priceRepo ?? _FakePriceRepository(),
            productRepository: productRepo ?? _FakeProductRepository(const []),
            prefill: prefill,
            scanner: scanner,
            unitNamesLoader: unitNamesLoader,
            globalUnitNamesLoader: globalUnitNamesLoader,
            defaultUnitLoader: defaultUnitLoader,
            entityUnitsRequest: entityUnitsRequest,
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
  }

  testWidgets('记录价格单位包含 100g', (tester) async {
    await pumpForm(tester);

    final unitField = find.ancestor(
      of: find.text('单位'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(unitField);
    await tester.pumpAndSettle();
    await tester.tap(unitField);
    await tester.pumpAndSettle();
    expect(find.text('100g'), findsOneWidget);
  });

  testWidgets('选中商品后自定义单位出现在单位下拉里', (tester) async {
    // 用户反馈：在原料/商品详情自定义了「桶」，回到价格记录页下拉里选不到
    final product = Product.fromJson({
      'id': 42,
      'name': '食用油',
      'ingredient_id': 7,
    });
    int? requestedProductId;
    int? requestedIngredientId;

    await pumpForm(
      tester,
      productRepo: _FakeProductRepository([product]),
      prefill: PriceRecordFormPrefill(product: product, lockProduct: true),
      unitNamesLoader: (productId, ingredientId) async {
        requestedProductId = productId;
        requestedIngredientId = ingredientId;
        return const ['桶'];
      },
    );

    expect(requestedProductId, 42);
    expect(requestedIngredientId, 7);

    final unitField = find.ancestor(
      of: find.text('单位'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(unitField);
    await tester.pumpAndSettle();
    await tester.tap(unitField);
    await tester.pumpAndSettle();
    expect(find.text('桶'), findsOneWidget);
  });

  testWidgets('选中商品后，原料级自定义单位经真实 loadEntityUnitNames 进入下拉', (tester) async {
    // 端到端（无网络）：走 widget 内的真实 loadEntityUnitNames + 假请求缝，
    // 证明「自定义单位挂在关联原料上」时下拉里也能选到。
    final product = Product.fromJson({
      'id': 42,
      'name': '食用油',
      'ingredient_id': 7,
    });
    final requested = <String>[];

    await pumpForm(
      tester,
      productRepo: _FakeProductRepository([product]),
      entityUnitsRequest: (path) async {
        requested.add(path);
        return switch (path) {
          '/entities/product/42/units' => const <Object?>[
              {'unit_name': '商品自有单位', 'is_active': false},
            ],
          '/entities/ingredient/7/units' => const <Object?>[
              {'name': '桶'},
            ],
          _ => const <Object?>[],
        };
      },
    );

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '食用油');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '食用油'));
    await tester.pumpAndSettle();

    expect(requested, contains('/entities/product/42/units'));
    expect(requested, contains('/entities/ingredient/7/units'));

    final unitField = find.ancestor(
      of: find.text('单位'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(unitField);
    await tester.pumpAndSettle();
    await tester.tap(unitField);
    await tester.pumpAndSettle();

    expect(find.text('桶'), findsOneWidget);
    // is_active=false 的商品自有单位不出现
    expect(find.text('商品自有单位'), findsNothing);
  });

  testWidgets('全局单位接口作为下拉基准：不在硬编码常量里的单位可选', (tester) async {
    await pumpForm(
      tester,
      globalUnitNamesLoader: () async => const ['斤', '把', 'mL'],
    );

    final unitField = find.ancestor(
      of: find.text('单位'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(unitField);
    await tester.pumpAndSettle();
    await tester.tap(unitField);
    await tester.pumpAndSettle();

    expect(find.text('把'), findsOneWidget);
    expect(find.text('mL'), findsOneWidget);
  });

  testWidgets('渲染全部字段', (tester) async {
    await pumpForm(tester);

    expect(find.text('新增价格记录'), findsOneWidget); // AppBar
    expect(find.text('商家'), findsOneWidget);
    expect(find.text('商品名称'), findsOneWidget);
    expect(find.text('价格'), findsOneWidget);
    expect(find.text('币种'), findsOneWidget);
    expect(find.text('数量'), findsOneWidget);
    expect(find.text('单位'), findsOneWidget);
    expect(find.text('计入支出'), findsOneWidget);
    expect(find.text('记录时间'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '保存'), findsOneWidget);
  });

  testWidgets('prefills a product and searches within its ingredient', (
    tester,
  ) async {
    final repo = _FakePriceRepository();
    final productRepo = _FakeProductRepository(const [
      Product(id: 7, name: '番茄'),
    ]);
    await pumpForm(
      tester,
      priceRepo: repo,
      productRepo: productRepo,
      prefill: const PriceRecordFormPrefill(
        product: Product(id: 7, name: '番茄'),
        ingredientId: 5,
      ),
      viewportHeight: 2200,
    );

    final nameField = tester.widget<TextField>(
      find.widgetWithText(TextField, '商品名称'),
    );
    expect(nameField.controller?.text, '番茄');

    final nameFieldFinder = find.widgetWithText(TextField, '商品名称');
    await tester.enterText(nameFieldFinder, '');
    await tester.pump();
    await tester.enterText(nameFieldFinder, '番茄');
    await tester.pumpAndSettle();
    expect(productRepo.lastIngredientId, 5);
    await tester.tap(find.widgetWithText(ListTile, '番茄'));
    await tester.pumpAndSettle();

    final priceField = find.widgetWithText(TextField, '价格');
    await tester.enterText(priceField, '2.5');
    await tester.ensureVisible(find.widgetWithText(TextButton, '保存'));
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
    expect(repo.lastProductId, 7);
  });

  testWidgets('价格为空时提示且不保存', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pump();

    expect(find.text('请输入有效的价格'), findsOneWidget);
    expect(repo.createCount, 0);
  });

  testWidgets('搜索商品并选择后保存，携带 productId 与 purchase 类型', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(
      tester,
      priceRepo: repo,
      productRepo: _FakeProductRepository(const [
        Product(id: 7, name: '番茄'),
      ]),
    );

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '番茄')); // 搜索结果 ListTile
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
    expect(repo.lastProductId, 7);
    expect(repo.lastProductName, isNull);
    expect(repo.lastRecordType, 'purchase');
    expect(repo.lastPrice, 2.5);
    expect(repo.lastQuantity, 1);
    expect(repo.lastUnit, '斤');
    expect(repo.lastMerchantId, isNull);
    expect(repo.lastRecordedAt, isNotNull);
    // 保存成功 → pop 回宿主
    expect(find.byType(PriceRecordFormScreen), findsNothing);
  });

  testWidgets('选中商品后单位下拉切到该商品的默认单位', (tester) async {
    // 用户反馈：给商品/原料设了「默认单位」，维护价格选商品时下拉不会切过去
    final repo = _FakePriceRepository();
    final requested = <List<int?>>[];

    await pumpForm(
      tester,
      priceRepo: repo,
      productRepo: _FakeProductRepository(const [Product(id: 7, name: '番茄')]),
      globalUnitNamesLoader: () async => const ['斤', '个'],
      unitNamesLoader: (productId, ingredientId) async => const [],
      defaultUnitLoader: (productId, ingredientId) async {
        requested.add([productId, ingredientId]);
        return '箱';
      },
    );

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '番茄'));
    await tester.pumpAndSettle();

    expect(requested, [
      [7, null],
    ]);
    // 单位下拉当前值已切到默认单位「箱」
    expect(find.text('箱'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(repo.createCount, 1);
    expect(repo.lastUnit, '箱');
  });

  testWidgets('带着商品进入表单（商品详情/列表记价）时也套用默认单位', (tester) async {
    final repo = _FakePriceRepository();
    final product = Product.fromJson({
      'id': 42,
      'name': '食用油',
      'ingredient_id': 7,
    });

    await pumpForm(
      tester,
      priceRepo: repo,
      prefill: PriceRecordFormPrefill(product: product, lockProduct: true),
      globalUnitNamesLoader: () async => const ['斤', '个'],
      unitNamesLoader: (productId, ingredientId) async => const [],
      defaultUnitLoader: (productId, ingredientId) async =>
          productId == 42 ? '桶' : null,
    );

    expect(find.text('桶'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '价格'), '9');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(repo.lastUnit, '桶');
  });

  testWidgets('商品没有默认单位时保持原单位（不因读取结果改用户选择）', (tester) async {
    final repo = _FakePriceRepository();

    await pumpForm(
      tester,
      priceRepo: repo,
      productRepo: _FakeProductRepository(const [Product(id: 7, name: '番茄')]),
      globalUnitNamesLoader: () async => const ['斤', '个'],
      unitNamesLoader: (productId, ingredientId) async => const [],
      defaultUnitLoader: (productId, ingredientId) async => null,
    );

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '番茄'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(repo.lastUnit, '斤');
  });

  testWidgets('不选商品直接输新名字，保存携带 productName', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '新商品A');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '价格'), '3');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
    expect(repo.lastProductId, isNull);
    expect(repo.lastProductName, '新商品A');
  });

  testWidgets('关闭计入支出后保存为 price 类型', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.tap(find.text('计入支出'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastRecordType, 'price');
  });

  testWidgets('选择商品后改名再保存，不带旧 productId', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(
      tester,
      priceRepo: repo,
      productRepo: _FakeProductRepository(const [
        Product(id: 7, name: '番茄'),
      ]),
    );

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '番茄'));
    await tester.pumpAndSettle();

    // 改名后原选择被撤销，保存携带新名字而非旧 productId
    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄酱');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '价格'), '3');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
    expect(repo.lastProductId, isNull);
    expect(repo.lastProductName, '番茄酱');
  });

  testWidgets('商家 Autocomplete 显示并过滤已加载的商家', (tester) async {
    await pumpForm(tester);

    // 定位商家 Autocomplete<Merchant> 内的 TextField
    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );

    // 输入「超」触发过滤
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();

    // 浮层仅显示匹配的「超市」，不含「便利店」
    expect(find.text('超市'), findsOneWidget);
    expect(find.text('便利店'), findsNothing);
  });

  testWidgets('选中商家后保存，携带 merchantId', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');

    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
    expect(repo.lastMerchantId, 1);
  });

  testWidgets('不选商家（文本空）保存，merchantId 为 null', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastMerchantId, isNull);
  });

  testWidgets('选中商家后再编辑文本，merchantId 复位 null（防 stale id）', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');

    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市'));
    await tester.pumpAndSettle();

    // 选中后继续编辑文本（非空），_merchantId 应被清空
    await tester.enterText(merchantField, '超市X');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastMerchantId, isNull);
  });

  testWidgets('双击保存只创建一次（在途守卫）', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');
    // 两次 tap 之间不 pump：第一次同步置 _saving，第二次命中同一按钮
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.tap(
      find.widgetWithText(TextButton, '保存'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
  });

  testWidgets('新增保存后记住商家与计入支出，再次打开表单复用', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo, viewportHeight: 2200);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');

    // 选商家「超市」
    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市'));
    await tester.pumpAndSettle();

    // 关闭「计入支出」
    await tester.tap(find.text('计入支出'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
    expect(repo.lastMerchantId, 1);
    expect(repo.lastRecordType, 'price'); // 计入支出关闭 → record_type=price

    // 再次打开表单：商家名回填、计入支出保持关闭
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    final merchantField2 = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    final textField = tester.widget<TextField>(merchantField2);
    expect(textField.controller?.text, '超市');

    final sw = tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '计入支出'));
    expect(sw.value, isFalse);
  });

  testWidgets('复用记忆商家时同步带出商家默认币种', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(
      tester,
      priceRepo: repo,
      viewportHeight: 2200,
      merchantCurrency: 'IDR',
    );

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');
    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(repo.lastCurrency, 'IDR');

    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    final merchantField2 = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    final merchantText = tester.widget<TextField>(merchantField2);
    expect(merchantText.controller?.text, '超市');
    final priceField =
        tester.widget<TextField>(find.widgetWithText(TextField, '价格'));
    expect(priceField.decoration?.prefixText, 'Rp');
  });

  testWidgets('未记忆商家时再次打开表单为空，计入支出默认开启', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo, viewportHeight: 2200);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格'), '2.5');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastMerchantId, isNull);

    // 再次打开：商家空、计入支出默认开
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    final textField = tester.widget<TextField>(merchantField);
    expect(textField.controller?.text, isEmpty);

    final sw = tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '计入支出'));
    expect(sw.value, isTrue);
  });

  testWidgets('扫码查询期间显示加载覆盖层，查询完成弹窗打开前覆盖层消失', (tester) async {
    final lookupCompleter = Completer<BarcodeLookupResult>();
    final productRepo = _ScanLookupProductRepository(lookupCompleter);
    await pumpForm(
      tester,
      productRepo: productRepo,
      scanner: (_) async => '6901234567890',
    );

    await tester.tap(find.byIcon(Icons.barcode_reader));
    await tester.pump();

    // 查询进行中：显示加载覆盖层
    expect(find.byType(LoadingOverlay), findsOneWidget);

    // 查询完成但未找到本地商品：先收起覆盖层，再弹出「未找到本地商品」对话框
    lookupCompleter.complete(
      const BarcodeLookupResult(found: false, hasEnabledProviders: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoadingOverlay), findsNothing);
    expect(find.widgetWithText(AlertDialog, '未找到本地商品'), findsOneWidget);
  });
}

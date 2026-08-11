import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/price_record_form_screen.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';

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
  }) async {
    createCount++;
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
    return ProductPage(items: items, total: items.length);
  }
}

class _FakeMerchantRepository extends MerchantRepository {
  @override
  Future<MerchantPage> search({
    String? search,
    bool includeClosed = false,
    bool noPrice = false,
    int skip = 0,
    int limit = 20,
  }) async {
    // 返回多个商家以便测 Autocomplete 过滤
    return const MerchantPage(
      items: [
        Merchant(id: 1, name: '超市'),
        Merchant(id: 2, name: '便利店'),
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
    _FakeProductRepository? productRepo,
  }) async {
    // 表单整体超过默认 600 高视口，放大视口让底部保存按钮被构建。
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        merchantListProvider.overrideWith(
          (ref) => MerchantListNotifier(_FakeMerchantRepository()),
        ),
      ],
      // 裸 Scaffold 在测试环境缺 Directionality，需 MaterialApp 包裹
      // （与本仓库其他页面测试一致）。
      child: MaterialApp(
        home: _FormHost(
          form: PriceRecordFormScreen(
            priceRepository: priceRepo ?? _FakePriceRepository(),
            productRepository: productRepo ?? _FakeProductRepository(const []),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染全部字段', (tester) async {
    await pumpForm(tester);

    expect(find.text('新增价格记录'), findsOneWidget); // AppBar
    expect(find.text('商品名称'), findsOneWidget);
    expect(find.text('价格（¥）'), findsOneWidget);
    expect(find.text('数量'), findsOneWidget);
    expect(find.text('单位'), findsOneWidget);
    expect(find.text('商家'), findsOneWidget);
    expect(find.text('计入支出'), findsOneWidget);
    expect(find.text('记录时间'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
  });

  testWidgets('价格为空时提示且不保存', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
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

    await tester.enterText(find.widgetWithText(TextField, '价格（¥）'), '2.5');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
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

  testWidgets('不选商品直接输新名字，保存携带 productName', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '新商品A');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '价格（¥）'), '3');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
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
    await tester.enterText(find.widgetWithText(TextField, '价格（¥）'), '2.5');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
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
    await tester.enterText(find.widgetWithText(TextField, '价格（¥）'), '3');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
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
    await tester.enterText(find.widgetWithText(TextField, '价格（¥）'), '2.5');

    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
    expect(repo.lastMerchantId, 1);
  });

  testWidgets('不选商家（文本空）保存，merchantId 为 null', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格（¥）'), '2.5');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastMerchantId, isNull);
  });

  testWidgets('选中商家后再编辑文本，merchantId 复位 null（防 stale id）', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格（¥）'), '2.5');

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

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastMerchantId, isNull);
  });

  testWidgets('双击保存只创建一次（在途守卫）', (tester) async {
    final repo = _FakePriceRepository();
    await pumpForm(tester, priceRepo: repo);

    await tester.enterText(find.widgetWithText(TextField, '商品名称'), '番茄');
    await tester.enterText(find.widgetWithText(TextField, '价格（¥）'), '2.5');
    // 两次 tap 之间不 pump：第一次同步置 _saving，第二次命中同一按钮
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.tap(
      find.widgetWithText(FilledButton, '保存'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(repo.createCount, 1);
  });
}

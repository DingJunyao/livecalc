import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/screens/price_record_edit_screen.dart';

/// 价格列表编辑入口允许换绑商品：搜索选择已有商品后保存，
/// 结果带新 productId/productName；改文本未点选时保存被拦截。
void main() {
  /// 打开编辑页；返回取结果闭包（pop 后才有值）。
  Future<PriceRecordFormResult? Function()> pumpEditScreen(
    WidgetTester tester, {
    required List<Product> searchItems,
    List<Merchant> merchants = const [],
  }) async {
    PriceRecordFormResult? popped;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: TextButton(
                  onPressed: () async {
                    popped = await Navigator.of(ctx)
                        .push<PriceRecordFormResult>(MaterialPageRoute(
                      builder: (_) => PriceRecordEditScreen(
                        arguments: PriceRecordFormArguments(
                          merchants: merchants,
                          fixedProductId: 1,
                          fixedProductName: '苹果',
                          initialPrice: 5,
                          initialQuantity: 1,
                          initialUnit: '斤',
                          initialRecordType: 'purchase',
                          initialCurrency: 'CNY',
                        ),
                        productRepository:
                            _FakeProductRepository(searchItems),
                      ),
                    ));
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return () => popped;
  }

  testWidgets('初始商品名回显；搜索并点选另一商品后保存，结果带新商品', (tester) async {
    final getPopped = await pumpEditScreen(
      tester,
      searchItems: const [
        Product(id: 2, name: '梨'),
        Product(id: 3, name: '苹果汁'),
      ],
    );

    // 初始回显原商品名
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, '商品'),
    );
    expect(field.controller?.text, '苹果');

    // 改文本触发搜索（300ms 防抖）
    await tester.enterText(find.widgetWithText(TextField, '商品'), '梨');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('梨'), findsNWidgets(2)); // 输入框 + 建议项

    // 点选建议 → 保存 → 结果带新商品
    await tester.tap(find.text('梨').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    final popped = getPopped();
    expect(popped, isNotNull);
    expect(popped!.productId, 2);
    expect(popped.productName, '梨');
  });

  testWidgets('改了商品文本但未点选时，保存被拦截并提示选择商品', (tester) async {
    final getPopped = await pumpEditScreen(tester, searchItems: const []);

    await tester.enterText(find.widgetWithText(TextField, '商品'), '不存在的新品');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    // 未弹出（保存被拦），页面还在并出现「请选择商品」提示
    expect(getPopped(), isNull);
    expect(find.byType(PriceRecordEditScreen), findsOneWidget);
    expect(find.text('请选择商品'), findsOneWidget);
  });

  testWidgets('选中商家后删改文本不被还原成旧商家名（局部删除生效）', (tester) async {
    // 与 price_record_form_screen 同一份 fieldViewBuilder 同步逻辑：
    // postFrame 预填同步在 rebuild 后不得把用户编辑回退成旧商家名。
    await pumpEditScreen(
      tester,
      searchItems: const [],
      merchants: const [Merchant(id: 1, name: '超市')],
    );

    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Merchant>),
      matching: find.byType(TextField),
    );
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市'));
    await tester.pumpAndSettle();

    // 重新聚焦后模拟局部删除（updateEditingValue 与真机 IME 删除路径一致）
    await tester.tap(merchantField);
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: '超',
      selection: TextSelection.collapsed(offset: 1),
    ));
    await tester.pumpAndSettle(); // 让 rebuild 后的 postFrame 同步执行完

    expect(tester.widget<TextField>(merchantField).controller?.text, '超');
  });
}

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.items);

  final List<Product> items;

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
    bool favoritesOnly = false,
    bool favoritesFirst = false,
  }) async {
    final q = search?.trim() ?? '';
    return ProductPage(
      items:
          q.isEmpty ? items : items.where((p) => p.name.contains(q)).toList(),
      total: items.length,
    );
  }
}

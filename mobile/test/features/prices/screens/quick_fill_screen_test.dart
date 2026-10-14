import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant_product_price.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/quick_fill_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class _FakeMerchantRepository extends MerchantRepository {
  _FakeMerchantRepository(this.items);

  final List<MerchantProductPrice> items;

  @override
  Future<MerchantProductPricePage> getProductPrices(
    int id, {
    int skip = 0,
    int limit = 20,
    bool staleLast = false,
  }) async {
    return MerchantProductPricePage(items: items, total: items.length);
  }
}

MerchantProductPrice _historyRow({int productId = 7, String name = '食用油'}) =>
    MerchantProductPrice(
      productId: productId,
      productName: name,
      price: 9.9,
      recordedAt: '2026-10-01T00:00:00Z',
    );

void main() {
  Future<void> pumpQuickFill(
    WidgetTester tester, {
    required List<MerchantProductPrice> history,
    Future<List<String>> Function(int productId, int? ingredientId)?
        unitNamesLoader,
    Future<List<String>> Function()? globalUnitNamesLoader,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: QuickFillScreen(
        merchantRepository: _FakeMerchantRepository(history),
        merchantsLoader: () async => [
          {'id': 1, 'name': '超市'},
        ],
        unitNamesLoader: unitNamesLoader,
        globalUnitNamesLoader: globalUnitNamesLoader ?? () async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    // 选择商家 → 加载历史商品（行）→ 预取自定义单位
    final merchantField = find.descendant(
      of: find.byWidgetPredicate((w) => w is Autocomplete<Map<String, dynamic>>),
      matching: find.byType(TextField),
    );
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市').last);
    await tester.pumpAndSettle();
  }

  testWidgets('行的单位菜单包含该商品（含关联原料）的自定义单位，且排在全局单位前', (tester) async {
    final requested = <int>[];

    await pumpQuickFill(
      tester,
      history: [_historyRow(productId: 7, name: '食用油')],
      unitNamesLoader: (productId, ingredientId) async {
        requested.add(productId);
        // 真实 loadEntityUnitNames 会合并商品 + 关联原料，这里只验证屏幕接线
        return const ['桶'];
      },
      globalUnitNamesLoader: () async => const ['斤', '把'],
    );

    expect(requested, [7]);

    await tester.tap(find.byKey(const Key('quick-fill-unit-7')));
    await tester.pumpAndSettle();

    // 自定义单位「桶」+ 全局单位「把」都在菜单里
    expect(find.text('桶'), findsOneWidget);
    expect(find.text('把'), findsOneWidget);

    // 选中自定义单位后行内按钮同步显示（setState 生效）
    await tester.tap(find.text('桶').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('quick-fill-unit-7')),
        matching: find.text('桶'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('自定义单位加载失败 → 菜单回退兜底列表，不崩', (tester) async {
    await pumpQuickFill(
      tester,
      history: [_historyRow(productId: 8, name: '面粉')],
      unitNamesLoader: (productId, ingredientId) async {
        throw StateError('boom');
      },
      globalUnitNamesLoader: () async => const [],
    );

    await tester.tap(find.byKey(const Key('quick-fill-unit-8')));
    await tester.pumpAndSettle();

    // 兜底常量列表仍在（'箱' 只在 quickFillFallbackUnits 里）
    expect(find.text('箱'), findsOneWidget);
    // 当前单位「斤」一定在
    expect(find.text('斤'), findsWidgets);
  });

  testWidgets('无 productId 的手动行只给全局/兜底列表', (tester) async {
    await pumpQuickFill(
      tester,
      history: const [],
      unitNamesLoader: (productId, ingredientId) async => const ['桶'],
      globalUnitNamesLoader: () async => const ['斤', '把'],
    );

    // 空历史 → 点击「添加商品」手动加一行
    await tester.tap(find.widgetWithText(FilledButton, '添加商品'));
    await tester.pumpAndSettle();

    // 手动行没有 productId → key 为 'quick-fill-unit-'
    await tester.tap(find.byKey(const Key('quick-fill-unit-')));
    await tester.pumpAndSettle();

    expect(find.text('把'), findsOneWidget);
    expect(find.text('桶'), findsNothing);
  });
}

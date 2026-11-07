import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// 快速填写行 UI 压缩回归：行高收紧、长商品名完整可见、价格经系统数字键盘输入后行内回显。
void main() {
  Future<void> pumpQuickFill(
    WidgetTester tester, {
    required List<MerchantProductPrice> history,
  }) async {
    // 窄屏手机：360dp 宽，历史上名称列只剩 ~164px、行高达 116px
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: QuickFillScreen(
        merchantRepository: _FakeMerchantRepository(history),
        merchantsLoader: () async => [
          {'id': 1, 'name': '超市'},
        ],
        unitNamesLoader: (productId, ingredientId) async => const [],
        globalUnitNamesLoader: () async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    final merchantField = find.descendant(
      of: find
          .byWidgetPredicate((w) => w is Autocomplete<Map<String, dynamic>>),
      matching: find.byType(TextField),
    );
    await tester.enterText(merchantField, '超');
    await tester.pumpAndSettle();
    await tester.tap(find.text('超市').last);
    await tester.pumpAndSettle();
  }

  MerchantProductPrice row({required int id, required String name}) =>
      MerchantProductPrice(
        productId: id,
        productName: name,
        price: 9.9,
        recordedAt: '2026-10-01T00:00:00Z',
      );

  testWidgets('长商品名完整换行显示（不截断），行高显著收紧', (tester) async {
    const longName = '多美鲜Suki淡奶油250ml*12盒整箱装';
    await pumpQuickFill(
      tester,
      history: [row(id: 7, name: longName), row(id: 8, name: '鸡蛋')],
    );

    // 名称文本完整排版：所需宽度不超过可用宽度（无水平裁切）
    final RenderParagraph paragraph =
        tester.renderObject<RenderParagraph>(find.text(longName));
    expect(paragraph.textSize.width, lessThanOrEqualTo(paragraph.size.width));

    // 单行短名行高收紧（含分隔线）：明显低于旧 Card 布局的 ~116px
    final shortNameFinder = find.text('鸡蛋');
    final paddingFinder = find.ancestor(
      of: shortNameFinder,
      matching: find.byType(Padding),
    );
    final Size rowSize = tester.getSize(paddingFinder.first);
    expect(rowSize.height, lessThan(56));

    // 整行（名称+价格+单位）渲染无溢出异常
    expect(tester.takeException(), isNull);
  });

  testWidgets('价格用系统数字键盘（TextField）输入，行内实时回显且拦截多个小数点', (tester) async {
    await pumpQuickFill(tester, history: [row(id: 7, name: '鸡蛋')]);

    // 价格字段：带货币前缀的 TextField（系统键盘），不再是自定义 NumericKeypad 弹层
    final priceFieldFinder = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.prefixText == '¥',
    );
    expect(priceFieldFinder, findsOneWidget);
    final field = tester.widget<TextField>(priceFieldFinder);
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );

    await tester.enterText(priceFieldFinder, '12.5');
    await tester.pumpAndSettle();
    expect(find.text('¥'), findsOneWidget);
    expect(find.text('12.5'), findsOneWidget);

    // 第二个小数点被输入格式化拦截
    await tester.enterText(priceFieldFinder, '12.5.5');
    await tester.pumpAndSettle();
    expect(field.controller!.text, '12.5');
  });
}

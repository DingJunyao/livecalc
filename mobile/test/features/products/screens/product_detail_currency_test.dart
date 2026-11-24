import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/providers/product_provider.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_detail_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class _StaticProductDetailNotifier extends ProductDetailPageNotifier {
  _StaticProductDetailNotifier(super.id) {
    state = const ProductDetailPageState(
      product: Product(id: 12, name: 'Cabbage'),
      records: [
        PriceRecord(
          id: 1,
          productId: 12,
          productName: 'Cabbage',
          price: 1250,
          quantity: 1,
          unit: '颗',
          currency: 'IDR',
          exchangeRate: 0.1,
          recordedAt: '2026-10-18T00:00:00Z',
        ),
      ],
    );
  }

  @override
  Future<void> load({int initialDays = 30, int? regionId}) async {}
}

void main() {
  testWidgets('product records keep native currency and show conversion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productDetailPageProvider.overrideWith(
            (ref, id) => _StaticProductDetailNotifier(id),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProductDetailScreen(id: 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1,250 IDR'), findsOneWidget);
    expect(find.textContaining('125 CNY'), findsOneWidget);
    expect(find.textContaining('1,250 CNY'), findsNothing);
  });

  testWidgets('展开竖屏（669×951）单列布局不溢出', (tester) async {
    tester.view.physicalSize = const Size(669, 951);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productDetailPageProvider.overrideWith(
            (ref, id) => _StaticProductDetailNotifier(id),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProductDetailScreen(id: 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 不分栏：基本信息在上、最新价格在下
    final basic = tester.getRect(find.text('基本信息').first);
    final latest = tester.getRect(find.text('最新价格').first);
    expect(latest.top, greaterThan(basic.bottom));
    expect(tester.takeException(), isNull);
  });
}

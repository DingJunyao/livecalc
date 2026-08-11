import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/providers/price_provider.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/price_list_screen.dart';

class _FakePriceRepository extends PriceRepository {
  int getRecordsCalls = 0;

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
    getRecordsCalls++;
    return const PriceRecordsResult(records: [], total: 0);
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
    return const MerchantPage(items: [], total: 0);
  }
}

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    _FakePriceRepository? repo,
  }) async {
    final priceRepo = repo ?? _FakePriceRepository();
    final router = GoRouter(
      initialLocation: '/prices',
      routes: [
        GoRoute(
          path: '/prices',
          builder: (_, __) => const PriceListScreen(),
        ),
        GoRoute(
          path: '/prices/record',
          builder: (_, __) => Scaffold(
            body: Builder(
              builder: (ctx) => Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('保存并返回'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('取消返回'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/prices/quick-fill',
          builder: (_, __) => const Scaffold(body: Text('快速填写页')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        priceListProvider.overrideWith(
          (ref) => PriceListNotifier(priceRepo),
        ),
        merchantListProvider.overrideWith(
          (ref) => MerchantListNotifier(_FakeMerchantRepository()),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('FAB 打开新增价格记录页（而非快速填写）', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('快速填写页'), findsNothing);
    expect(find.text('保存并返回'), findsOneWidget);
  });

  testWidgets('AppBar 闪电按钮进入快速填写', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.bolt));
    await tester.pumpAndSettle();

    expect(find.text('快速填写页'), findsOneWidget);
  });

  testWidgets('新增页保存返回后刷新列表', (tester) async {
    final repo = _FakePriceRepository();
    await pumpList(tester, repo: repo);
    final callsAfterLoad = repo.getRecordsCalls;

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();

    expect(repo.getRecordsCalls, callsAfterLoad + 1);
  });

  testWidgets('新增页取消返回不刷新列表', (tester) async {
    final repo = _FakePriceRepository();
    await pumpList(tester, repo: repo);
    final callsAfterLoad = repo.getRecordsCalls;

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消返回'));
    await tester.pumpAndSettle();

    expect(repo.getRecordsCalls, callsAfterLoad);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/providers/price_provider.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/price_list_screen.dart';
import 'package:com_a4ding_livecalc/shared/screens/price_record_edit_screen.dart';

class _FakePriceRepository extends PriceRepository {
  _FakePriceRepository({this.seed = const []});

  final List<PriceRecord> seed;
  int getRecordsCalls = 0;

  int updateCalls = 0;
  Exception? updateError;

  int deleteCalls = 0;
  Exception? deleteError;

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
    return PriceRecordsResult(records: seed, total: seed.length);
  }

  @override
  Future<void> updateRecord(
    int id, {
    required double price,
    required double quantity,
    required String unit,
    int? merchantId,
  }) async {
    updateCalls++;
    if (updateError != null) throw updateError!;
  }

  @override
  Future<void> deleteRecord(int id) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
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

PriceRecord _seedRecord({
  int id = 1,
  int productId = 10,
  String productName = '番茄',
  double price = 6.88,
  double quantity = 500,
  String unit = 'g',
  int? merchantId = 1,
  String? merchantName = '盒马鲜生',
}) =>
    PriceRecord(
      id: id,
      productId: productId,
      productName: productName,
      price: price,
      quantity: quantity,
      unit: unit,
      merchantId: merchantId,
      merchantName: merchantName,
      recordedAt: '2026-08-11T10:00:00Z',
    );

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
          path: '/prices/record/edit',
          builder: (_, state) => state.extra is PriceRecordFormArguments
              ? PriceRecordEditScreen(
                  arguments: state.extra! as PriceRecordFormArguments,
                )
              : const PriceRecordEditScreen(
                  arguments: PriceRecordFormArguments(merchants: []),
                ),
        ),
        GoRoute(
          path: '/prices/quick-fill',
          builder: (_, __) => const Scaffold(body: Text('快速填写页')),
        ),
        // 整卡点击跳商品详情的兜底路由（测试里不真正点卡片，但提供以免 go_router 报错）
        GoRoute(
          path: '/products/:id',
          builder: (_, __) => const Scaffold(body: Text('商品详情')),
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

  // ---- 编辑/删除入口（Task ③）----

  testWidgets('记录卡片尾部有三点菜单（PopupMenuButton）', (tester) async {
    final repo = _FakePriceRepository(seed: [_seedRecord()]);
    await pumpList(tester, repo: repo);

    // 卡片渲染出来了
    expect(find.text('番茄'), findsOneWidget);
    // 三点菜单图标存在
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    // 旧的 chevron_right 不再存在
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('点三点菜单弹出「编辑」「删除」两个选项', (tester) async {
    final repo = _FakePriceRepository(seed: [_seedRecord()]);
    await pumpList(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('点「删除」→ 确认对话框 → 确认后调用 deleteRecord 且卡片消失', (tester) async {
    final repo = _FakePriceRepository(seed: [_seedRecord()]);
    await pumpList(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // 弹出菜单中的「删除」项（此刻 AlertDialog 未显示，只有弹层有「删除」）
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    // 确认对话框出现（带记录信息）
    expect(find.text('删除记录'), findsOneWidget);
    expect(find.text('确定删除「番茄」¥6.88 的记录吗？'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('取消')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('删除')),
      findsOneWidget,
    );

    // 还未调用 deleteRecord
    expect(repo.deleteCalls, 0);

    // 点对话框内的「删除」按钮（AlertDialog descendant，与菜单项文案相同故限定）
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('删除'),
    ));
    await tester.pumpAndSettle();

    // deleteRecord 被调用一次
    expect(repo.deleteCalls, 1);
    // 卡片已消失
    expect(find.text('番茄'), findsNothing);
    // 提示已删除
    expect(find.text('已删除'), findsOneWidget);
  });

  testWidgets('点「删除」→ 取消则不删除', (tester) async {
    final repo = _FakePriceRepository(seed: [_seedRecord()]);
    await pumpList(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    // 此刻只有弹层有「删除」
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('取消'),
    ));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 0);
    // 卡片仍在
    expect(find.text('番茄'), findsOneWidget);
  });

  testWidgets('点「编辑」→ 打开整页表单且预填商品名可见', (tester) async {
    final repo = _FakePriceRepository(seed: [_seedRecord()]);
    await pumpList(tester, repo: repo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('编辑').last);
    await tester.pumpAndSettle();

    expect(find.byType(PriceRecordEditScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('编辑价格记录'), findsOneWidget);
    expect(find.text('番茄'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
  });
}

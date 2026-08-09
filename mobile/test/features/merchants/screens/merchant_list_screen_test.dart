import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/screens/merchant_list_screen.dart';

class MockRepo extends Mock implements MerchantRepository {}

void main() {
  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
    when(() => repo.search(
          search: any(named: 'search'),
          includeClosed: any(named: 'includeClosed'),
          noPrice: any(named: 'noPrice'),
          skip: any(named: 'skip'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const MerchantPage(
              items: [Merchant(id: 1, name: '盒马鲜生')],
              total: 1,
            ));
    when(() => repo.getFavorites()).thenAnswer((_) async => const [
          Merchant(id: 1, name: '盒马鲜生', isOpen: true),
          Merchant(id: 2, name: '千禧量贩', isOpen: false),
        ]);
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        merchantListProvider.overrideWith((ref) => MerchantListNotifier(repo)),
      ],
      child: const MaterialApp(home: MerchantListScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('筛选弹窗：三个控件可切换，点确定后提交到 provider', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    final closedTile = find.widgetWithText(SwitchListTile, '显示已关闭商家');
    final favTile = find.widgetWithText(SwitchListTile, '仅看我的收藏');
    expect(tester.widget<SwitchListTile>(closedTile).value, isFalse);
    expect(tester.widget<SwitchListTile>(favTile).value, isFalse);

    // 开关切换后应保持打开，而不是被重建弹回原位
    await tester.tap(favTile);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<SwitchListTile>(favTile).value, isTrue);

    await tester.tap(closedTile);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<SwitchListTile>(closedTile).value, isTrue);

    await tester.tap(find.text('未维护过价格'));
    await tester.pump();
    await tester.pump();
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '未维护过价格'),
    );
    expect(chip.selected, isTrue);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MerchantListScreen)));
    final state = container.read(merchantListProvider);
    expect(state.includeClosed, isTrue);
    expect(state.favoritesOnly, isTrue);
    expect(state.noPrice, isTrue);
    // 收藏模式下：显示已关闭 → 保留全部收藏；未维护过价格不参与收藏过滤（与网页一致）
    expect(state.items.map((m) => m.id), [1, 2]);
  });

  testWidgets('仅打开「显示已关闭商家」：重新走 search 接口并带上参数', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '显示已关闭商家'));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    verify(() => repo.search(
          search: null,
          includeClosed: true,
          noPrice: false,
          skip: 0,
          limit: 20,
        )).called(1);
  });
}

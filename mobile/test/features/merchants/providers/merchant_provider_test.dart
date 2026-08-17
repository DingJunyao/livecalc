import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/models/merchant.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';

class MockRepo extends Mock implements MerchantRepository {}

void main() {
  late MockRepo repo;
  late MerchantListNotifier notifier;

  setUp(() {
    repo = MockRepo();
    notifier = MerchantListNotifier(repo);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('默认列表走 search 接口，且不包含已关闭商家', () async {
    when(() => repo.search(
          search: any(named: 'search'),
          includeClosed: any(named: 'includeClosed'),
          noPrice: any(named: 'noPrice'),
          skip: any(named: 'skip'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const MerchantPage(
          items: [
            Merchant(id: 1, name: '盒马鲜生'),
            Merchant(id: 3, name: '大润发'),
          ],
          total: 2,
        ));

    await notifier.load();
    await settle();

    expect(notifier.state.items.map((m) => m.id), [1, 3]);
    verify(() => repo.search(
          search: null,
          includeClosed: false,
          noPrice: false,
          skip: 0,
          limit: 20,
        )).called(1);
  });

  test('仅看收藏：默认排除已关闭商家，且不再请求 search 接口', () async {
    when(() => repo.getFavorites()).thenAnswer((_) async => const [
          Merchant(id: 1, name: '盒马鲜生', isOpen: true),
          Merchant(id: 2, name: '千禧量贩', isOpen: false),
          Merchant(id: 3, name: '大润发', isOpen: true),
        ]);

    notifier.applyFilters(favoritesOnly: true);
    await settle();

    expect(notifier.state.items.map((m) => m.id), [1, 3]);
    expect(notifier.state.total, 2);
    verifyNever(() => repo.search(
          search: any(named: 'search'),
          includeClosed: any(named: 'includeClosed'),
          noPrice: any(named: 'noPrice'),
          skip: any(named: 'skip'),
          limit: any(named: 'limit'),
        ));
  });

  test('仅看收藏 + 显示已关闭：保留全部收藏', () async {
    when(() => repo.getFavorites()).thenAnswer((_) async => const [
          Merchant(id: 1, name: '盒马鲜生', isOpen: true),
          Merchant(id: 2, name: '千禧量贩', isOpen: false),
          Merchant(id: 3, name: '大润发', isOpen: true),
        ]);

    notifier.applyFilters(favoritesOnly: true, includeClosed: true);
    await settle();

    expect(notifier.state.items.map((m) => m.id), [1, 2, 3]);
    expect(notifier.state.total, 3);
  });

  test('仅看收藏 + 搜索：按名称/地址过滤', () async {
    when(() => repo.getFavorites()).thenAnswer((_) async => const [
          Merchant(id: 1, name: '盒马鲜生', isOpen: true),
          Merchant(id: 2, name: '千禧量贩', isOpen: false),
          Merchant(id: 3, name: '大润发', isOpen: true),
        ]);

    notifier.applyFilters(favoritesOnly: true);
    await settle();
    notifier.setSearch('盒马');
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(notifier.state.items.map((m) => m.id), [1]);
    expect(notifier.state.total, 1);
  });

  test('仅看收藏：分页加载更多', () async {
    final favs = List.generate(25, (i) => Merchant(id: i + 1, name: '商家$i'));
    when(() => repo.getFavorites()).thenAnswer((_) async => favs);

    notifier.applyFilters(favoritesOnly: true);
    await settle();
    expect(notifier.state.items.length, 20);
    expect(notifier.state.total, 25);
    expect(notifier.state.hasMore, isTrue);

    await notifier.load(loadMore: true);
    await settle();
    expect(notifier.state.items.length, 25);
    expect(notifier.state.hasMore, isFalse);
  });
}

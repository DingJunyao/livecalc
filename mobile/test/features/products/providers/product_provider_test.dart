import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/providers/product_provider.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/shared/models/latest_price.dart';

class _FakeProductRepository extends ProductRepository {
  final searches = <String?>[];
  bool failNextSearch = false;

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
    searches.add(search);
    if (failNextSearch) {
      failNextSearch = false;
      throw Exception('network error');
    }
    const all = [Product(id: 1, name: '???'), Product(id: 2, name: '??')];
    if (search == null || search.isEmpty) {
      return const ProductPage(items: all, total: 2);
    }
    final filtered = all.where((p) => p.name.contains(search)).toList();
    return ProductPage(items: filtered, total: filtered.length);
  }
}

/// id=1 的商品取价永远失败，其余正常；分页各 2 条。
class _FlakyPriceRepository extends ProductRepository {
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
    final items = [
      for (var i = 0; i < limit; i++)
        Product(id: skip + i + 1, name: 'p${skip + i + 1}'),
    ];
    return ProductPage(items: items, total: 40);
  }

  @override
  Future<LatestPriceInfo> getLatestPrice(int id, {int? regionId}) async {
    if (id == 1) throw Exception('price lookup failed');
    return LatestPriceInfo.fromJson(
      {'average_price': id.toDouble(), 'unit': '斤'},
    );
  }

  @override
  Future<Map<int, List<double>>> getSparklines(List<int> ids) async => const {};
}

void main() {
  test('clearing product search refreshes immediately and drops stale results',
      () async {
    final repository = _FakeProductRepository();
    final notifier = ProductListNotifier(repository);

    await notifier.load();
    expect(notifier.state.items.map((p) => p.id), [1, 2]);

    notifier.setSearch('???');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(notifier.state.items.map((p) => p.id), [1]);

    repository.failNextSearch = true;
    notifier.setSearch('');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repository.searches.last, isNull);
    expect(notifier.state.items, isEmpty);
    expect(notifier.state.searchQuery, '');
  });

  test('a failing product price does not wipe details of the other items',
      () async {
    final notifier = ProductListNotifier(_FlakyPriceRepository());

    await notifier.load();
    await Future<void>.delayed(Duration.zero);
    // id=1 取价失败只跳过自己，本页其余 19 项照常展示
    expect(notifier.state.latestPrices.containsKey(1), isFalse);
    expect(notifier.state.latestPrices.length, 19);

    await notifier.load(loadMore: true);
    await Future<void>.delayed(Duration.zero);

    // 翻页后合并：失败的 1 缺席，上一页的 2–20 与本页的 21–40 并存；
    // 若某次单项失败作废整轮（旧行为），这里会是空 map。
    expect(notifier.state.latestPrices.containsKey(1), isFalse);
    expect(notifier.state.latestPrices.length, 39);
    expect(notifier.state.latestPrices[2]?.price, 2.0);
    expect(notifier.state.latestPrices[40]?.price, 40.0);
  });
}

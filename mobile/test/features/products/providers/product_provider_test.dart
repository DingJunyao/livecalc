import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/providers/product_provider.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';

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
}

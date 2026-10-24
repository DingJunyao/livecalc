import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/shared/models/latest_price.dart';

class _SlowSearchRepository extends IngredientRepository {
  final Completer<IngredientPage> slowSearch = Completer<IngredientPage>();

  @override
  Future<IngredientPage> search({
    String? search,
    List<int>? categoryIds,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
    bool favoritesOnly = false,
    bool favoritesFirst = false,
  }) async {
    if (search == null || search.isEmpty) {
      return const IngredientPage(
        items: [
          Ingredient(id: 1, name: 'all ingredient'),
          Ingredient(id: 2, name: 'another ingredient'),
        ],
        total: 2,
      );
    }

    return slowSearch.future;
  }

  @override
  Future<Map<int, LatestPriceInfo>> getLatestPrices(List<int> ids) async =>
      const {};

  @override
  Future<Map<int, List<double>>> getSparklines(List<int> ids) async =>
      const {};
}

/// 模拟批量价「只有后一半 id 成功」（分块中前一块失败被仓库吞掉）。
class _PartialBatchRepository extends IngredientRepository {
  @override
  Future<IngredientPage> search({
    String? search,
    List<int>? categoryIds,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
    bool favoritesOnly = false,
    bool favoritesFirst = false,
  }) async {
    final items = [
      for (var i = 0; i < limit; i++)
        Ingredient(id: skip + i + 1, name: 'ingredient ${skip + i + 1}'),
    ];
    return IngredientPage(items: items, total: 60);
  }

  @override
  Future<Map<int, LatestPriceInfo>> getLatestPrices(List<int> ids) async {
    return {
      for (final id in ids.skip(ids.length ~/ 2))
        id: LatestPriceInfo.fromJson(
          {'average_price': id.toDouble(), 'unit': '斤'},
        ),
    };
  }

  @override
  Future<Map<int, List<double>>> getSparklines(List<int> ids) async =>
      const {};
}

void main() {
  test('clearing a search cannot be overwritten by an older search response', () async {
    final repository = _SlowSearchRepository();
    final notifier = IngredientListNotifier(repository);

    notifier.setSearch('old');
    // Trigger the debounced old request, but keep its response pending.
    await Future<void>.delayed(const Duration(milliseconds: 450));

    notifier.setSearch('');
    // Trigger and finish the request for the cleared search.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(notifier.state.searchQuery, '');
    expect(notifier.state.items.length, 2);

    repository.slowSearch.complete(
      const IngredientPage(
        items: [Ingredient(id: 3, name: 'stale result')],
        total: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.searchQuery, '');
    expect(notifier.state.items.length, 2);
  });

  test('loading more pages keeps prices of already loaded ingredients',
      () async {
    final notifier = IngredientListNotifier(_PartialBatchRepository());

    await notifier.load();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.latestPrices.length, 10);

    await notifier.load(loadMore: true);
    await Future<void>.delayed(Duration.zero);

    // 合并语义：上一页的 11–20 与本页的 21–40 并存；
    // 若整体替换，11–20 的价会随本页请求只含 21–40 而丢失。
    expect(notifier.state.latestPrices.length, 30);
    expect(notifier.state.latestPrices[11]?.price, 11.0);
    expect(notifier.state.latestPrices[40]?.price, 40.0);
  });
}

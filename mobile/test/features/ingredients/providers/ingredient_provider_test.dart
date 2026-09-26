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
}

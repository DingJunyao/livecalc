import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/recipes/models/recipe_summary.dart';
import 'package:com_a4ding_livecalc/features/recipes/providers/recipe_provider.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';

class _FakeRecipeRepository extends RecipeRepository {
  final searches = <String?>[];

  @override
  Future<RecipePage> getRecipes({
    String? search,
    List<String>? categories,
    List<String>? difficulties,
    List<int>? ingredientIds,
    List<String>? conditions,
    int page = 1,
    int pageSize = 20,
    bool favoritesOnly = false,
    bool favoritesFirst = false,
  }) async {
    searches.add(search);
    const all = [
      RecipeSummary(id: 1, name: '红烧肉'),
      RecipeSummary(id: 2, name: '清蒸鱼'),
    ];
    final items = (search == null || search.isEmpty)
        ? all
        : all.where((r) => r.name.contains(search)).toList();
    return RecipePage(items: items, total: items.length);
  }

  @override
  Future<Map<int, RecipeCostInfo>> getRecipesBatchCost(List<int> ids,
      {int? regionId}) async {
    return const {};
  }
}

void main() {
  test('菜谱搜索输入后防抖触发加载，清空后回到全部', () async {
    final repository = _FakeRecipeRepository();
    final notifier = RecipeListNotifier(repository);

    await notifier.loadRecipes();
    expect(notifier.state.recipes.length, 2);
    expect(repository.searches.last, isEmpty); // 初始无关键词

    // 输入关键词：防抖 400ms 后应自动发起请求
    notifier.setSearch('红烧');
    expect(notifier.state.searchQuery, '红烧');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repository.searches.last, '红烧');
    expect(notifier.state.recipes.map((r) => r.id), [1]);

    // 清空关键词：同样自动重新加载全部（空串等价于不过滤）
    notifier.setSearch('');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repository.searches.last, isEmpty);
    expect(notifier.state.recipes.length, 2);

    notifier.dispose();
  });
}

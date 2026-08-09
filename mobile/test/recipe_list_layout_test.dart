import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/recipes/models/recipe_summary.dart';
import 'package:com_a4ding_livecalc/features/recipes/providers/recipe_provider.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_list_screen.dart';

class _FakeRecipeRepository extends RecipeRepository {
  final List<RecipeSummary> items;
  _FakeRecipeRepository(this.items);

  @override
  Future<RecipePage> getRecipes({
    String? search,
    List<String>? categories,
    List<String>? difficulties,
    List<int>? ingredientIds,
    List<String>? conditions,
    int page = 1,
    int pageSize = 20,
  }) async {
    return RecipePage(items: items, total: items.length);
  }

  @override
  Future<Map<int, RecipeCostInfo>> getRecipesBatchCost(List<int> ids) async {
    return {};
  }
}

Widget _wrap(List<RecipeSummary> items) {
  return ProviderScope(
    overrides: [
      recipeListProvider.overrideWith(
        (ref) => RecipeListNotifier(_FakeRecipeRepository(items)),
      ),
    ],
    child: const MaterialApp(home: RecipeListScreen()),
  );
}

void main() {
  testWidgets('单个结果靠左而不是居中', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap([
      RecipeSummary(id: 1, name: '测试菜谱'),
    ]));
    await tester.pumpAndSettle();

    final card = find.byType(Card);
    expect(card, findsOneWidget);
    final topLeft = tester.getTopLeft(card);
    final centerX = 800 / 2;
    expect(topLeft.dx, lessThan(centerX - 100),
        reason: '单卡片应靠左，dx=${topLeft.dx} 不应接近屏幕中心 $centerX');
  });

  testWidgets('两个结果在同一行，左侧对齐', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap([
      RecipeSummary(id: 1, name: '测试菜谱A'),
      RecipeSummary(id: 2, name: '测试菜谱B'),
    ]));
    await tester.pumpAndSettle();

    final cards = find.byType(Card);
    expect(cards, findsNWidgets(2));
    final first = tester.getTopLeft(cards.first);
    final second = tester.getTopLeft(cards.last);
    expect(first.dx, lessThan(second.dx));
    expect(first.dy, second.dy);
  });

  testWidgets('宽屏下 4 个卡片同一行且靠左', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap([
      RecipeSummary(id: 1, name: '测试菜谱A'),
      RecipeSummary(id: 2, name: '测试菜谱B'),
      RecipeSummary(id: 3, name: '测试菜谱C'),
      RecipeSummary(id: 4, name: '测试菜谱D'),
    ]));
    await tester.pumpAndSettle();

    final cards = find.byType(Card);
    expect(cards, findsNWidgets(4));
    final yPositions = cards.evaluate().map((e) {
      final rect = tester.getRect(find.byWidget(e.widget));
      return rect.top;
    }).toSet();
    expect(yPositions.length, 1, reason: '1400px 宽下 4 个卡片应在同一行');
  });

  testWidgets('宽屏下单结果仍靠左', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap([
      RecipeSummary(id: 1, name: '测试菜谱'),
    ]));
    await tester.pumpAndSettle();

    final single = find.byType(Card);
    expect(single, findsOneWidget);
    final topLeft = tester.getTopLeft(single);
    expect(topLeft.dx, lessThan(700 - 100),
        reason: '宽屏下单结果应靠左，dx=${topLeft.dx}');
  });
}

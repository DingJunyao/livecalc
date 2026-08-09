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

/// 网格左边缘 = 页面 padding 12（靠左的对齐标志）
/// 修复前：SingleChildScrollView 内容不满一行时收缩到内容宽度，
/// 被 RefreshIndicator 居中显示，卡片 dx 会落在屏幕中央附近。
const _gridLeft = 12.0;

void main() {
  testWidgets('单个结果靠左而不是居中', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const [
      RecipeSummary(id: 1, name: '测试菜谱'),
    ]));
    await tester.pumpAndSettle();

    final card = find.byType(Card);
    expect(card, findsOneWidget);
    final topLeft = tester.getTopLeft(card);
    expect(topLeft.dx, _gridLeft,
        reason: '单卡片应靠左，dx=${topLeft.dx} 应为 $_gridLeft');
  });

  testWidgets('两个结果在同一行，左侧对齐', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const [
      RecipeSummary(id: 1, name: '测试菜谱A'),
      RecipeSummary(id: 2, name: '测试菜谱B'),
    ]));
    await tester.pumpAndSettle();

    final cards = find.byType(Card);
    expect(cards, findsNWidgets(2));
    final first = tester.getTopLeft(cards.first);
    final second = tester.getTopLeft(cards.last);
    expect(first.dx, _gridLeft,
        reason: '第一行首个卡片应靠左，dx=${first.dx}');
    expect(first.dx, lessThan(second.dx));
    expect(first.dy, second.dy);
  });

  testWidgets('宽屏下 4 个卡片同一行且靠左', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const [
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
    expect(tester.getTopLeft(cards.first).dx, _gridLeft,
        reason: '首行卡片应靠左');
  });

  testWidgets('宽屏下单结果仍靠左', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const [
      RecipeSummary(id: 1, name: '测试菜谱'),
    ]));
    await tester.pumpAndSettle();

    final single = find.byType(Card);
    expect(single, findsOneWidget);
    final topLeft = tester.getTopLeft(single);
    expect(topLeft.dx, _gridLeft,
        reason: '宽屏下单结果应靠左，dx=${topLeft.dx} 应为 $_gridLeft');
  });

  testWidgets('第二行不满时新行卡片仍靠左（2 列 3 个）', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const [
      RecipeSummary(id: 1, name: '测试菜谱A'),
      RecipeSummary(id: 2, name: '测试菜谱B'),
      RecipeSummary(id: 3, name: '测试菜谱C'),
    ]));
    await tester.pumpAndSettle();

    final cards = find.byType(Card);
    expect(cards, findsNWidgets(3));
    final third = tester.getTopLeft(cards.at(2));
    expect(third.dx, _gridLeft,
        reason: '第二行仅 1 个卡片时应靠左，dx=${third.dx} 应为 $_gridLeft');
    expect(third.dy, greaterThan(tester.getTopLeft(cards.first).dy),
        reason: '第三卡片应位于第二行');
  });

  testWidgets('超宽屏 6 列下 1 个菜谱仍靠左', (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const [
      RecipeSummary(id: 1, name: '测试菜谱'),
    ]));
    await tester.pumpAndSettle();

    final card = find.byType(Card);
    expect(card, findsOneWidget);
    final topLeft = tester.getTopLeft(card);
    expect(topLeft.dx, _gridLeft,
        reason: '超宽屏单结果应靠左，dx=${topLeft.dx} 应为 $_gridLeft');
  });
}

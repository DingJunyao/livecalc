import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_hierarchy_screen.dart';

void main() {
  testWidgets('hierarchy maintenance is a full page with graph and form',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: IngredientHierarchyScreen(
        ingredientId: 8,
        ingredientName: '猪肉',
        hierarchyData: const IngredientHierarchyData(),
        isAdmin: true,
        onAdd: (_) async => null,
        onUpdateStrength: (_, __) async => null,
        onDelete: (_) async => null,
      ),
    ));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '关联原料关系'), findsOneWidget);
    expect(find.text('关系图'), findsOneWidget);
    expect(find.text('关系列表'), findsOneWidget);
    expect(find.text('搜索关联原料 *'), findsOneWidget);
    expect(find.text('关系类型'), findsOneWidget);
  });
}

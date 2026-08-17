import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/widgets/hierarchy_graph.dart';
import 'package:com_a4ding_livecalc/shared/models/hierarchy_relation.dart';

void main() {
  testWidgets('hierarchy graph renders center, first and second level nodes',
      (tester) async {
    const data = IngredientHierarchyData(
      childRelations: [
        HierarchyRelation(
          id: 1,
          parentId: 8,
          parentName: '猪肉',
          childId: 9,
          childName: '五花肉',
          relationType: 'contains',
        ),
      ],
      expandedRelations: [
        ExpandedIngredientRelations(
          ingredientId: 9,
          ingredientName: '五花肉',
          childRelations: [
            HierarchyRelation(
              id: 2,
              parentId: 9,
              parentName: '五花肉',
              childId: 10,
              childName: '去皮五花肉',
              relationType: 'contains',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: HierarchyGraph(
          ingredientId: 8,
          ingredientName: '猪肉',
          hierarchyData: data,
        ),
      ),
    ));

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('猪肉'), findsOneWidget);
    expect(find.text('五花肉'), findsOneWidget);
    expect(find.text('去皮五花肉'), findsOneWidget);
  });

  test('graph edge directions follow the web hierarchy semantics', () {
    final layout = buildHierarchyGraphLayout(
      ingredientId: 8,
      ingredientName: '猪肉',
      hierarchyData: const IngredientHierarchyData(
        parentRelations: [
          HierarchyRelation(
            id: 1,
            parentId: 10,
            parentName: '肉类',
            childId: 8,
            childName: '猪肉',
            relationType: 'fallback',
          ),
        ],
        childRelations: [
          HierarchyRelation(
            id: 2,
            parentId: 8,
            parentName: '猪肉',
            childId: 11,
            childName: '羊肉',
            relationType: 'substitutable',
          ),
        ],
      ),
      size: const Size(360, 420),
    );

    final fallback = layout.edges.singleWhere(
      (edge) => edge.relationType == 'fallback',
    );
    final substitutable = layout.edges.singleWhere(
      (edge) => edge.relationType == 'substitutable',
    );

    expect(fallback.sourceId, 8);
    expect(fallback.targetId, 10);
    expect(substitutable.sourceId, 8);
    expect(substitutable.targetId, 11);
  });

  test('graph nodes remain inside the canvas and can be separated by panning',
      () {
    final children = List.generate(
      10,
      (index) => HierarchyRelation(
        id: index + 1,
        parentId: 8,
        parentName: '猪肉',
        childId: 20 + index,
        childName: '原料$index',
        relationType: 'contains',
      ),
    );

    final layout = buildHierarchyGraphLayout(
      ingredientId: 8,
      ingredientName: '猪肉',
      hierarchyData: IngredientHierarchyData(childRelations: children),
      size: const Size(720, 600),
    );

    expect(layout.nodes.length, 11);
    for (final node in layout.nodes.values) {
      expect(node.position.dx, inInclusiveRange(44, 676));
      expect(node.position.dy, inInclusiveRange(20, 580));
    }
  });
}

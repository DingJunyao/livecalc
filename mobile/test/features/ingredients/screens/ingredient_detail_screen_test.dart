import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_detail_screen.dart';
import 'package:com_a4ding_livecalc/features/ingredients/widgets/hierarchy_graph.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/shared/models/hierarchy_relation.dart';

class _FakeIngredientDetailNotifier extends IngredientDetailPageNotifier {
  _FakeIngredientDetailNotifier(super.id);

  @override
  Future<void> load({int initialDays = 30, int? regionId}) async {
    state = const IngredientDetailPageState(
      ingredient: Ingredient(id: 8, name: '番茄'),
      hierarchy: IngredientHierarchyData(
        childRelations: [
          HierarchyRelation(
            id: 1,
            parentId: 8,
            parentName: '番茄',
            childId: 9,
            childName: '圣女果',
            relationType: 'substitutable',
          ),
        ],
      ),
    );
  }
}

class _FakeMerchantRepository extends MerchantRepository {
  @override
  Future<MerchantPage> search({
    String? search,
    bool includeClosed = false,
    bool noPrice = false,
    bool includeOtherRegions = false,
    int skip = 0,
    int limit = 20,
  }) async {
    return const MerchantPage(items: [], total: 0);
  }
}

void main() {
  testWidgets('ingredient detail embeds the hierarchy graph', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientDetailPageProvider.overrideWith(
            (ref, id) => _FakeIngredientDetailNotifier(id),
          ),
          merchantListProvider.overrideWith(
            (ref) => MerchantListNotifier(_FakeMerchantRepository()),
          ),
        ],
        child: const MaterialApp(home: IngredientDetailScreen(id: 8)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HierarchyGraph), findsOneWidget);
    expect(find.text('层级关系'), findsOneWidget);
    expect(find.text('番茄'), findsAtLeastNWidgets(1));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/features/entities/repositories/entity_repository.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_quantity_link.dart';
import 'package:com_a4ding_livecalc/shared/widgets/entity_quantity_link_edit_page.dart';

class _FakeEntityRepository extends EntityRepository {
  final calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> searchQuantityLinkTargets(
    String targetType,
    String query,
  ) async {
    calls.add('search:$targetType:$query');
    return [
      {'id': 2, 'name': '单包', 'ingredient_id': null},
      {'id': 3, 'name': '整箱', 'ingredient_id': null},
    ];
  }

  @override
  Future<EntityWriteResult<EntityQuantityLink>> createQuantityLink(
    String entityType,
    int entityId, {
    required String toType,
    required int toId,
    required double fromQuantity,
    required String fromUnit,
    required double toQuantity,
    required String toUnit,
    String? note,
    bool isAdmin = true,
  }) async {
    calls.add('create:$toType:$toId:$fromQuantity:$fromUnit:$toQuantity:$toUnit');
    return EntityWriteResult(
      value: EntityQuantityLink.fromJson({
        'id': 1,
        'current': {
          'type': entityType,
          'id': entityId,
          'name': '五连包',
          'quantity': fromQuantity,
          'unit': fromUnit,
        },
        'other': {
          'type': toType,
          'id': toId,
          'name': '单包',
          'quantity': toQuantity,
          'unit': toUnit,
        },
        'other_per_current': 5,
        'current_per_other': 0.2,
        'resolvable': true,
      }),
      pending: false,
    );
  }
}

void main() {
  testWidgets('关联维护是整页、单位下拉，选择目标后收起', (tester) async {
    final repo = _FakeEntityRepository();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: EntityQuantityLinkEditPage(
            repository: repo,
            entityType: 'product',
            entityId: 1,
            entityName: '五连包',
            unitNamesLoader: (type, id, ingredientId) async =>
                type == 'product' && id == 1 ? ['提'] : ['包'],
            globalUnitNamesLoader: () async => ['kg'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加关联'), findsOneWidget);
    expect(find.text('提'), findsOneWidget);

    await tester.tap(find.text('选择商品/原料'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('单包'), findsOneWidget);

    await tester.tap(find.text('单包'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('单包'), findsOneWidget);
    expect(find.text('包'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(repo.calls, contains('search:product:'));
  });
}

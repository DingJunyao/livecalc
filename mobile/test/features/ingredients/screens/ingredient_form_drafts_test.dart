import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/entities/repositories/entity_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_unit.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';
import 'package:com_a4ding_livecalc/shared/screens/entity_units_draft_screen.dart';
import 'package:com_a4ding_livecalc/shared/services/entity_draft_persist.dart';

class _FakeIngredientRepository extends IngredientRepository {
  @override
  Future<Ingredient> createIngredient({
    required String name,
    int? categoryId,
    List<String> aliases = const [],
  }) async =>
      Ingredient(id: 11, name: name);
}

class _FakeEntityRepository extends EntityRepository {
  @override
  Future<List<Map<String, dynamic>>> listGlobalUnits() async => [
        {
          'id': 1,
          'name': 'gram',
          'abbreviation': 'g',
          'unit_type': 'mass',
          'si_factor': 0.001,
        },
      ];
}

class _RecordingPersister extends EntityDraftPersister {
  String? entityType;
  int? entityId;
  List<EntityUnit> units = const [];
  List<NutrientEntry> nutrients = const [];

  _RecordingPersister() : super(isAdmin: true);

  @override
  Future<EntityDraftPersistResult> persist({
    required String entityType,
    required int entityId,
    List<EntityUnit> units = const [],
    List<NutrientEntry> nutrients = const [],
  }) async {
    this.entityType = entityType;
    this.entityId = entityId;
    this.units = units;
    this.nutrients = nutrients;
    return EntityDraftPersistResult(
      unitsCreated: units.length,
      nutrientsSaved: nutrients.length,
    );
  }
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required _RecordingPersister persister,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ingredientCategoriesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IngredientFormScreen(
                    repository: _FakeIngredientRepository(),
                    entityRepository: _FakeEntityRepository(),
                    draftPersister: persister,
                  ),
                ),
              ),
              child: const Text('open-form'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-form'));
  await tester.pumpAndSettle();
}

/// 点表单里的草稿入口（可能在 ListView 折叠区外，先滚动到可见）。
Future<void> _tapDraftTile(WidgetTester tester, String label) async {
  final tile = find.widgetWithText(ListTile, label);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('新增原料页提供自定义单位与营养信息入口', (tester) async {
    await _pumpForm(tester, persister: _RecordingPersister());

    expect(find.text('Custom units'), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
    expect(
      find.text(
          'Fill in here; everything is saved together when you save the ingredient'),
      findsOneWidget,
    );
  });

  testWidgets('单位草稿在原料保存时一并写原料层级', (tester) async {
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ingredient name'),
      'Flour',
    );

    await _tapDraftTile(tester, 'Custom units');
    expect(find.byType(EntityUnitsDraftScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Unit name *'), 'bag');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '500');
    await tester.tap(find.text('Save unit'));
    await tester.pumpAndSettle();

    expect(find.text('bag'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Custom units (1)'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(persister.entityType, 'ingredient');
    expect(persister.entityId, 11);
    expect(persister.units.map((unit) => unit.unitName).toList(), ['bag']);
    expect(persister.units.first.weightPerUnit, 500);
  });

  testWidgets('营养草稿在原料保存时一并写原料层级', (tester) async {
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ingredient name'),
      'Flour',
    );

    // 草稿模式必须关掉 USDA 段（匹配会直接写服务端）
    await _tapDraftTile(tester, 'Nutrition');
    expect(find.text('USDA'), findsNothing);

    final dropdown = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Protein').last);
    await tester.pumpAndSettle();
    final valueField = find.byType(TextField).first;
    await tester.ensureVisible(valueField);
    await tester.pumpAndSettle();
    await tester.enterText(valueField, '12');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Nutrition (1)'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(persister.entityType, 'ingredient');
    expect(persister.entityId, 11);
    expect(persister.nutrients.length, 1);
    expect(persister.nutrients.first.value, 12);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/entities/repositories/entity_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_unit.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';
import 'package:com_a4ding_livecalc/shared/screens/entity_units_draft_screen.dart';
import 'package:com_a4ding_livecalc/shared/services/entity_draft_persist.dart';

class _FakeProductRepository extends ProductRepository {
  @override
  Future<Product> createProduct({
    required String name,
    required int ingredientId,
    String? brand,
    String? barcode,
    List<String> aliases = const [],
    List<String> tags = const [],
  }) async =>
      Product(id: 42, name: name);
}

class _FakeIngredientRepository extends IngredientRepository {
  @override
  Future<IngredientPage> search({
    String? search,
    List<int>? categoryIds,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
  }) async {
    final q = (search ?? '').trim();
    return IngredientPage(
      items: [const Ingredient(id: 5, name: 'Milk powder')]
          .where((item) => q.isEmpty || item.name.contains(q))
          .toList(),
      total: 1,
    );
  }

  /// 「新建同名原料」路径会先建原料（id 故意与商品不同，用于断言落库层级）。
  @override
  Future<Ingredient> createIngredient({
    required String name,
    int? categoryId,
    List<String> aliases = const [],
  }) async =>
      Ingredient(id: 7, name: name);
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

  @override
  Future<List<EntityUnit>> listUnits(String entityType, int entityId) async =>
      const [];

  @override
  Future<List<EntityDensity>> listDensities(
    String entityType,
    int entityId,
  ) async =>
      const [];
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
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(
                    repository: _FakeProductRepository(),
                    ingredientRepository: _FakeIngredientRepository(),
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

Future<void> _selectIngredient(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Search and select a linked ingredient *'),
    'Milk',
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(ListTile),
          matching: find.text('Milk powder'),
        )
        .first,
  );
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
  testWidgets('新增商品页提供自定义单位与营养信息入口', (tester) async {
    await _pumpForm(tester, persister: _RecordingPersister());

    expect(find.text('Custom units'), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.text('Fill in here; everything is saved together when you save the product'),
        findsOneWidget);
  });

  testWidgets('单位草稿在商品保存时一并落库', (tester) async {
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await _selectIngredient(tester);

    await _tapDraftTile(tester, 'Custom units');
    expect(find.byType(EntityUnitsDraftScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Unit name *'),
      'box',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '200');
    await tester.tap(find.text('Save unit'));
    await tester.pumpAndSettle();

    // 草稿列表已出现该单位，返回后计数同步到商品表单
    expect(find.text('box'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Custom units (1)'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(persister.entityType, 'product');
    expect(persister.entityId, 42);
    expect(persister.units.map((unit) => unit.unitName).toList(), ['box']);
    expect(persister.units.first.weightPerUnit, 200);
  });

  testWidgets('营养草稿在商品保存时一并落库', (tester) async {
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await _selectIngredient(tester);

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
    await tester.enterText(valueField, '10');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Nutrition (1)'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(persister.entityType, 'product');
    expect(persister.entityId, 42);
    expect(persister.nutrients.length, 1);
    expect(persister.nutrients.first.value, 10);
  });

  testWidgets('勾选「新建同名原料」时草稿仍写商品层级（不写新建的原料）', (tester) async {
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');

    // 打开「新建同名原料」，此时不选关联原料
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    await _tapDraftTile(tester, 'Custom units');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Unit name *'),
      'box',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '200');
    await tester.tap(find.text('Save unit'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    // 原料被创建为 id=7，但草稿落库目标是 product / 42
    expect(persister.entityType, 'product');
    expect(persister.entityId, 42);
    expect(persister.units.length, 1);
  });
}

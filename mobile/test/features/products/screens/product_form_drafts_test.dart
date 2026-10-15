import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/entities/repositories/entity_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/nutrition/models/usda_models.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_unit.dart';
import 'package:com_a4ding_livecalc/shared/models/nutrition.dart';
import 'package:com_a4ding_livecalc/shared/utils/nutrition_basis.dart';
import 'package:com_a4ding_livecalc/shared/screens/entity_units_draft_screen.dart';
import 'package:com_a4ding_livecalc/shared/services/entity_draft_persist.dart';

class _FakeProductRepository extends ProductRepository {
  int? updatedIngredientId;

  /// 编辑态会拉「我的权重」：不 fake 会打真实接口，测试里会一直转圈。
  @override
  Future<MyWeightInfo> getMyWeight(int productId) async => const MyWeightInfo(
        productId: 0,
        effectiveWeight: 50,
        globalWeight: 50,
        source: 'global',
      );

  @override
  Future<void> setMyWeight(int productId, int weight) async {}

  @override
  Future<void> deleteMyWeight(int productId) async {}

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

  @override
  Future<Product> getProduct(int id) async => Product(
        id: id,
        name: 'Milk',
        ingredientId: 5,
        ingredientName: 'Milk powder',
      );

  @override
  Future<ProductMutationResult> updateProduct(
    int id, {
    required bool isAdmin,
    String? name,
    int? ingredientId,
    String? brand,
    String? barcode,
    List<String>? aliases,
    List<String>? tags,
  }) async {
    updatedIngredientId = ingredientId;
    return ProductMutationResult(
      product: Product(id: id, name: name ?? ''),
      review: const MutationReviewResult(
        applied: true,
        pending: false,
        message: '',
        raw: {},
      ),
    );
  }
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
    bool favoritesOnly = false,
    bool favoritesFirst = false,
  }) async {
    final q = (search ?? '').trim();
    const items = [
      Ingredient(id: 5, name: 'Milk powder'),
      Ingredient(id: 6, name: 'Cheese'),
    ];
    return IngredientPage(
      items: items.where((item) => q.isEmpty || item.name.contains(q)).toList(),
      total: 2,
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
  /// 模拟一次网络抖动：第一次拉关联原料单位失败，之后成功。
  bool failIngredientUnitsOnce = false;

  /// 编辑态：商品现有的自定义单位与两个原料各自的单位。
  List<EntityUnit> productUnits = const [];
  List<EntityUnit> ingredient5Units = const [
    EntityUnit(id: 77, unitName: '盒', weightPerUnit: 220, weightUnitId: 1),
  ];
  List<EntityUnit> ingredient6Units = const [];
  final List<int> deletedUnitIds = [];

  @override
  Future<List<Map<String, dynamic>>> listGlobalUnits() async => [
        {
          'id': 1,
          'name': 'gram',
          'abbreviation': 'g',
          'unit_type': 'mass',
          'si_factor': 0.001,
        },
        // 全局单位表里本来就有计数单位「颗」（name == abbreviation）
        {
          'id': 49,
          'name': '颗',
          'abbreviation': '颗',
          'unit_type': 'count',
          'si_factor': 1,
        },
      ];

  @override
  Future<List<EntityUnit>> listUnits(String entityType, int entityId) async {
    // 关联原料（id=5）自带一个自定义单位「盒」，商品草稿的单位下拉应能继承到它
    if (entityType == 'product') return productUnits;
    if (entityType == 'ingredient' && entityId == 5) {
      if (failIngredientUnitsOnce) {
        failIngredientUnitsOnce = false;
        throw Exception('network glitch');
      }
      return ingredient5Units;
    }
    if (entityType == 'ingredient' && entityId == 6) return ingredient6Units;
    return const [];
  }

  @override
  Future<EntityWriteResult<void>> deleteUnit(
    String entityType,
    int entityId,
    int unitId,
  ) async {
    deletedUnitIds.add(unitId);
    return const EntityWriteResult<void>(value: null, pending: false);
  }

  /// 记录改指向（编辑态调和会 PUT 引用字段）
  final List<({int id, int? weightUnitId, int? weightUnitOverrideId})>
      updatedUnits = [];

  @override
  Future<EntityWriteResult<EntityUnit>> updateUnit(
    String entityType,
    int entityId,
    int unitId, {
    String? unitName,
    double? conversionFactor,
    double? weightPerUnit,
    Object? weightUnitId,
    Object? weightUnitOverrideId,
    bool? isDefault,
    bool isAdmin = true,
  }) async {
    updatedUnits.add((
      id: unitId,
      weightUnitId: weightUnitId as int?,
      weightUnitOverrideId: weightUnitOverrideId as int?,
    ));
    return const EntityWriteResult<EntityUnit>(value: null, pending: false);
  }

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
  NutritionBasis basis = const NutritionBasis();

  _RecordingPersister() : super(isAdmin: true);

  @override
  Future<EntityDraftPersistResult> persist({
    required String entityType,
    required int entityId,
    List<EntityUnit> units = const [],
    List<NutrientEntry> nutrients = const [],
    NutritionBasis basis = const NutritionBasis(),
  }) async {
    this.entityType = entityType;
    this.entityId = entityId;
    this.units = units;
    this.nutrients = nutrients;
    this.basis = basis;
    return EntityDraftPersistResult(
      unitsCreated: units.length,
      nutrientsSaved: nutrients.length,
    );
  }
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required _RecordingPersister persister,
  _FakeEntityRepository? entityRepository,
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
                    entityRepository: entityRepository ?? _FakeEntityRepository(),
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

/// 编辑态：商品 42（关联原料 5），用于「换绑原料后清理失效单位」的用例。
Future<void> _pumpEditForm(
  WidgetTester tester, {
  required _RecordingPersister persister,
  required _FakeEntityRepository entityRepository,
  required _FakeProductRepository productRepository,
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
                    product: const Product(id: 42, name: 'Milk', ingredientId: 5),
                    repository: productRepository,
                    ingredientRepository: _FakeIngredientRepository(),
                    entityRepository: entityRepository,
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

/// 依次关闭：单位下拉菜单（若开着）→ 单位编辑页 → 草稿列表页。
Future<void> _closeDraftFlow(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    final editorOpen =
        find.widgetWithText(TextField, 'Unit name *').evaluate().isNotEmpty;
    final draftOpen =
        find.byType(EntityUnitsDraftScreen).evaluate().isNotEmpty;
    if (!editorOpen && !draftOpen) return;
    await tester.pageBack();
    await tester.pumpAndSettle();
  }
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

    // 新建营养预填五项（首行是能量）；基准行在营养素表之前
    // （TextField 0 = 基准量，1 = 能量值）
    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Sodium'), findsOneWidget);

    final valueField = find.byType(TextField).at(1);
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

  testWidgets('单位草稿页的下拉带出关联原料的自定义单位（继承）', (tester) async {
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await _selectIngredient(tester);

    await _tapDraftTile(tester, 'Custom units');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    // 「量 + 单位」的下拉要能列出关联原料已有的自定义单位（盒，标注继承来源）
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('盒 (from ingredient)'), findsOneWidget);

    // 选中后保存草稿，落库时应带上原料单位的 id（正数 override 引用）
    await tester.tap(find.text('盒 (from ingredient)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Unit name *'), '箱');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '12');
    await tester.tap(find.text('Save unit'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(persister.entityType, 'product');
    expect(persister.entityId, 42);
    expect(persister.units.map((unit) => unit.unitName).toList(), ['箱']);
    expect(persister.units.first.weightUnitOverrideId, 77);
  });

  testWidgets('继承单位加载失败不缓存，下次打开自动重试', (tester) async {
    final entityRepo = _FakeEntityRepository()..failIngredientUnitsOnce = true;
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister, entityRepository: entityRepo);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await _selectIngredient(tester);

    // 第一次打开：关联原料单位恰好加载失败 → 下拉没有继承项
    await _tapDraftTile(tester, 'Custom units');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('盒 (from ingredient)'), findsNothing);
    await _closeDraftFlow(tester);

    // 第二次打开：失败被重试，继承项出现
    await _tapDraftTile(tester, 'Custom units');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('盒 (from ingredient)'), findsOneWidget);
  });

  testWidgets('继承单位与全局单位 id 撞车时，继承项仍要出现', (tester) async {
    // 全局单位 id=1（gram），原料自定义单位 id 也是 1：两张表 id 空间重叠
    final entityRepo = _FakeEntityRepository()
      ..ingredient5Units = const [
        EntityUnit(id: 1, unitName: '盒', weightPerUnit: 220, weightUnitId: 1),
      ];
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister, entityRepository: entityRepo);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await _selectIngredient(tester);

    await _tapDraftTile(tester, 'Custom units');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('盒 (from ingredient)'), findsOneWidget);
  });

  testWidgets('全局单位与原料自定义单位同名时，下拉只保留实体那一条', (tester) async {
    // 用户实测：包菜原料自定义了「颗 = 500 克」，而全局单位表里也有「颗」，
    // 下拉同时出现「颗 (颗)」和「颗 (from ingredient)」——应该合并成一条
    final entityRepo = _FakeEntityRepository()
      ..ingredient5Units = const [
        EntityUnit(id: 31, unitName: '颗', weightPerUnit: 500, weightUnitId: 1),
      ];
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister, entityRepository: entityRepo);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await _selectIngredient(tester);

    await _tapDraftTile(tester, 'Custom units');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('颗 (from ingredient)'), findsOneWidget);
    expect(find.text('颗 (颗)'), findsNothing);
    // 其它全局单位不受影响
    expect(find.text('gram (g)'), findsOneWidget);
  });

  testWidgets('新增态换关联原料后，引用旧原料单位的草稿单位被去掉并提示', (tester) async {
    // 用户实测：新增商品时选「包菜」，加了一个引用包菜独有单位「哈」的草稿单位；
    // 再把关联原料换成别的原料后，这条单位既没被去掉也没有提示
    final entityRepo = _FakeEntityRepository()
      ..ingredient5Units = const [
        EntityUnit(id: 77, unitName: '哈', weightPerUnit: 200, weightUnitId: 1),
      ]
      ..ingredient6Units = const [];
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister, entityRepository: entityRepo);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await _selectIngredient(tester); // 关联原料 = Milk powder(5)

    // 加一条引用原料独有单位「哈」的草稿单位：箱 = 12 哈
    await _tapDraftTile(tester, 'Custom units');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('哈 (from ingredient)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Unit name *'), '箱');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '12');
    await tester.tap(find.text('Save unit'));
    await tester.pumpAndSettle();
    await _closeDraftFlow(tester);

    // 换成 Cheese(6)：新原料没有「哈」→ 草稿单位被去掉并提示
    await tester.enterText(
      find.widgetWithText(TextField, 'Search and select a linked ingredient *'),
      'Cheese',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(ListTile), matching: find.text('Cheese'))
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('箱'), findsOneWidget);

    // 草稿列表里已没有这条单位（草稿全空时不会触发落库，故直接看界面）
    await _tapDraftTile(tester, 'Custom units');
    expect(find.byType(EntityUnitsDraftScreen), findsOneWidget); // 确认确实进了草稿页
    expect(find.text('No custom units'), findsOneWidget);
    expect(find.text('箱'), findsNothing);
  });

  testWidgets('新增态换原料后，引用改指向同名全局单位（单位不丢）', (tester) async {
    // 用户实测：引用的是「颗」，全局单位表里本来也有「颗」→ 换原料后不该被清掉
    final entityRepo = _FakeEntityRepository()
      ..ingredient5Units = const [
        EntityUnit(id: 77, unitName: '颗', weightPerUnit: 500, weightUnitId: 1),
      ]
      ..ingredient6Units = const [];
    final persister = _RecordingPersister();
    await _pumpForm(tester, persister: persister, entityRepository: entityRepo);
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await _selectIngredient(tester);

    await _tapDraftTile(tester, 'Custom units');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-weight-unit-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('颗 (from ingredient)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Unit name *'), '箱');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '12');
    await tester.tap(find.text('Save unit'));
    await tester.pumpAndSettle();
    await _closeDraftFlow(tester);

    // 换成 Cheese(6)：新原料没有「颗」，全局单位里有 → 改指向，保留这条单位
    await tester.enterText(
      find.widgetWithText(TextField, 'Search and select a linked ingredient *'),
      'Cheese',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(ListTile), matching: find.text('Cheese'))
          .first,
    );
    await tester.pumpAndSettle();

    // 提示说的是「已改用同名单位」，不是「已移除」
    expect(find.textContaining('箱'), findsOneWidget);
    expect(find.textContaining('same-named unit'), findsOneWidget);

    // 落库时仍带这条单位，引用改成全局「颗」(49)、不再引用原料覆盖
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(persister.units.single.unitName, '箱');
    expect(persister.units.single.weightUnitId, 49);
    expect(persister.units.single.weightUnitOverrideId, isNull);
  });

  testWidgets('编辑态换原料后，失效引用改指向同名全局单位（不删除）', (tester) async {
    final entityRepo = _FakeEntityRepository()
      ..productUnits = const [
        EntityUnit(id: 9, unitName: '箱', weightPerUnit: 12, weightUnitOverrideId: 77),
      ]
      ..ingredient5Units = const [
        EntityUnit(id: 77, unitName: '颗', weightPerUnit: 500, weightUnitId: 1),
      ]
      ..ingredient6Units = const [];
    final persister = _RecordingPersister();
    final productRepo = _FakeProductRepository();
    await _pumpEditForm(
      tester,
      persister: persister,
      entityRepository: entityRepo,
      productRepository: productRepo,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Linked ingredient'),
      'Cheese',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(ListTile), matching: find.text('Cheese'))
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(productRepo.updatedIngredientId, 6);
    expect(entityRepo.deletedUnitIds, isEmpty);
    expect(entityRepo.updatedUnits.length, 1);
    expect(entityRepo.updatedUnits.single.id, 9);
    expect(entityRepo.updatedUnits.single.weightUnitId, 49);
    expect(entityRepo.updatedUnits.single.weightUnitOverrideId, isNull);
  });

  testWidgets('换绑原料后，引用失效的商品自定义单位被移除并提示', (tester) async {
    final entityRepo = _FakeEntityRepository()
      ..productUnits = const [
        EntityUnit(id: 9, unitName: '箱', weightPerUnit: 12, weightUnitOverrideId: 77),
        EntityUnit(id: 10, unitName: '个', weightPerUnit: 200, weightUnitId: 1),
      ]
      ..ingredient6Units = const [];
    final persister = _RecordingPersister();
    final productRepo = _FakeProductRepository();
    await _pumpEditForm(
      tester,
      persister: persister,
      entityRepository: entityRepo,
      productRepository: productRepo,
    );

    // 把关联原料从 Milk powder(5) 换成 Cheese(6)：「箱」引用的 77 在新原料里不存在
    await tester.enterText(
      find.widgetWithText(TextField, 'Linked ingredient'),
      'Cheese',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(ListTile),
            matching: find.text('Cheese'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(productRepo.updatedIngredientId, 6);
    // 只有引用失效的「箱」(id=9) 被删除；「个」指向全局单位，保留
    expect(entityRepo.deletedUnitIds, [9]);
    expect(find.textContaining('箱'), findsOneWidget);
  });
}

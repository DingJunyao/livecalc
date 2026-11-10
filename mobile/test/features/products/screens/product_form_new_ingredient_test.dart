import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient_category.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/widgets/alias_tags_field.dart';

class _FakeProductRepository extends ProductRepository {
  String? createdName;
  int? createdIngredientId;
  int createCalls = 0;

  @override
  Future<Product> createProduct({
    required String name,
    required int ingredientId,
    String? brand,
    String? barcode,
    List<String> aliases = const [],
    List<String> tags = const [],
  }) async {
    createCalls += 1;
    createdName = name;
    createdIngredientId = ingredientId;
    return Product(id: 42, name: name);
  }
}

class _FakeIngredientRepository extends IngredientRepository {
  int createCalls = 0;
  String? lastName;
  int? lastCategoryId;
  List<String>? lastAliases;
  bool? lastReuseExisting;
  bool? lastCreateSameNameProduct;

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
  }) async =>
      const IngredientPage(items: [], total: 0);

  @override
  Future<Ingredient> createIngredient({
    required String name,
    int? categoryId,
    List<String> aliases = const [],
    bool reuseExisting = false,
    bool createSameNameProduct = true,
  }) async {
    createCalls += 1;
    lastName = name;
    lastCategoryId = categoryId;
    lastAliases = aliases;
    lastReuseExisting = reuseExisting;
    lastCreateSameNameProduct = createSameNameProduct;
    return Ingredient(id: 7, name: name, categoryId: categoryId);
  }
}

/// 下拉搜索有结果的原料仓库：用于「输入文字但未匹配」与「已匹配」两种场景。
class _SearchableIngredientRepository extends IngredientRepository {
  _SearchableIngredientRepository(this.items);

  final List<Ingredient> items;

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
    final query = (search ?? '').trim();
    final filtered = items
        .where((item) => query.isEmpty || item.name.contains(query))
        .toList();
    return IngredientPage(items: filtered, total: filtered.length);
  }
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required _FakeProductRepository productRepository,
  required IngredientRepository ingredientRepository,
  Ingredient? fixedIngredient,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ingredientCategoriesProvider.overrideWith(
          (ref) async => const [
            IngredientCategory(id: 3, name: 'vegetables', displayName: '蔬菜'),
            IngredientCategory(id: 4, name: 'fruits', displayName: '水果'),
          ],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProductFormScreen(
          fixedIngredient: fixedIngredient,
          repository: productRepository,
          ingredientRepository: ingredientRepository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save'));
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('开关开启：按填写的名称/分类/别名创建对应原料并挂到该原料', (tester) async {
    final productRepository = _FakeProductRepository();
    final ingredientRepository = _FakeIngredientRepository();
    await _pumpForm(
      tester,
      productRepository: productRepository,
      ingredientRepository: ingredientRepository,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product name *'),
      'Milk',
    );
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    // 开启后显示原料名称/分类/别名三个输入项，关联原料下拉隐藏
    expect(
      find.widgetWithText(TextFormField, 'Ingredient name'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Search and select a linked ingredient *'),
      findsNothing,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ingredient name'),
      'Milk powder',
    );

    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vegetables').last);
    await tester.pumpAndSettle();

    // 第一个 AliasTagsField 是新建原料的别名（商品别名在其后）
    final ingredientAliases = find.byType(AliasTagsField).first;
    final aliasInput = find.descendant(
      of: ingredientAliases,
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(aliasInput);
    await tester.pumpAndSettle();
    await tester.enterText(aliasInput, 'Milk dust');
    final addButton = find.descendant(
      of: ingredientAliases,
      matching: find.byIcon(Icons.add),
    );
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pump();

    await _save(tester);

    expect(ingredientRepository.createCalls, 1);
    expect(ingredientRepository.lastName, 'Milk powder');
    expect(ingredientRepository.lastCategoryId, 3);
    expect(ingredientRepository.lastAliases, ['Milk dust']);
    expect(ingredientRepository.lastReuseExisting, isTrue);
    expect(ingredientRepository.lastCreateSameNameProduct, isFalse);

    expect(productRepository.createCalls, 1);
    expect(productRepository.createdName, 'Milk');
    expect(productRepository.createdIngredientId, 7);
  });

  testWidgets('开关开启且原料名称留空：按商品名称创建原料', (tester) async {
    final productRepository = _FakeProductRepository();
    final ingredientRepository = _FakeIngredientRepository();
    await _pumpForm(
      tester,
      productRepository: productRepository,
      ingredientRepository: ingredientRepository,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product name *'),
      'Milk',
    );
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    // 原料名称留空：分类/别名也不填
    await _save(tester);

    expect(ingredientRepository.createCalls, 1);
    expect(ingredientRepository.lastName, 'Milk');
    expect(ingredientRepository.lastCategoryId, isNull);
    expect(ingredientRepository.lastAliases, isEmpty);
    expect(ingredientRepository.lastReuseExisting, isTrue);
    expect(ingredientRepository.lastCreateSameNameProduct, isFalse);

    expect(productRepository.createCalls, 1);
    expect(productRepository.createdIngredientId, 7);
  });

  testWidgets('开关关闭且未选原料：提示选择关联原料且不创建原料', (tester) async {
    final productRepository = _FakeProductRepository();
    final ingredientRepository = _FakeIngredientRepository();
    await _pumpForm(
      tester,
      productRepository: productRepository,
      ingredientRepository: ingredientRepository,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product name *'),
      'Milk',
    );
    await _save(tester);

    expect(ingredientRepository.createCalls, 0);
    expect(productRepository.createCalls, 0);

    // 错误提示在表单底部：滚到底再断言（ListView 懒构建，视口外找不到）
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(
      find.text(
        'Select a linked ingredient or enable "Add corresponding ingredient".',
      ),
      findsOneWidget,
    );
  });

  testWidgets('开关开启后再关掉：恢复原有固定原料并正常保存', (tester) async {
    final productRepository = _FakeProductRepository();
    final ingredientRepository = _FakeIngredientRepository();
    await _pumpForm(
      tester,
      productRepository: productRepository,
      ingredientRepository: ingredientRepository,
      fixedIngredient: const Ingredient(id: 8, name: 'Flour'),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Product name *'),
      'Milk',
    );
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    await _save(tester);

    expect(ingredientRepository.createCalls, 0);
    expect(productRepository.createCalls, 1);
    expect(productRepository.createdIngredientId, 8);
  });

  testWidgets('关联原料只输入未匹配文字时，开启开关自动带入新原料名称', (tester) async {
    await _pumpForm(
      tester,
      productRepository: _FakeProductRepository(),
      ingredientRepository: _SearchableIngredientRepository(const []),
    );

    final ingredientField = find.widgetWithText(
      TextField,
      'Search and select a linked ingredient *',
    );
    await tester.enterText(ingredientField, 'Milk powder');
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final newNameField = find.descendant(
      of: find.widgetWithText(TextFormField, 'Ingredient name'),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(newNameField).controller?.text,
      'Milk powder',
      reason: '未匹配到已有原料时，输入的关联原料文字应带到新原料名称',
    );
  });

  testWidgets('关联原料已匹配到已有原料时，开启开关不复制名称', (tester) async {
    await _pumpForm(
      tester,
      productRepository: _FakeProductRepository(),
      ingredientRepository: _SearchableIngredientRepository(
          const [Ingredient(id: 81, name: '牛奶')]),
    );

    final ingredientField = find.widgetWithText(
      TextField,
      'Search and select a linked ingredient *',
    );
    await tester.enterText(ingredientField, '牛奶');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, '牛奶').first);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final newNameField = find.descendant(
      of: find.widgetWithText(TextFormField, 'Ingredient name'),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(newNameField).controller?.text,
      isEmpty,
      reason: '已匹配到已有原料时不应把它的名字复制成新原料名称',
    );
  });
}

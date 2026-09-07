import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient_category.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_detail_screen.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_form_screen.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_hierarchy_screen.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_list_screen.dart';
import 'package:com_a4ding_livecalc/features/merchants/providers/merchant_provider.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/hierarchy_relation.dart';

const _builtinCategory = IngredientCategory(
  id: 2,
  name: 'vegetables',
  displayName: '蔬菜',
);

const _customCategory = IngredientCategory(
  id: 99,
  name: 'custom-key',
  displayName: 'My Pantry Category',
);

class _FakeIngredientRepository extends IngredientRepository {
  int? lastCategoryId;

  @override
  Future<Ingredient> createIngredient({
    required String name,
    int? categoryId,
    List<String> aliases = const [],
  }) async {
    lastCategoryId = categoryId;
    return Ingredient(id: 10, name: name, categoryId: categoryId);
  }

  @override
  Future<Ingredient> getIngredient(int id) async {
    return const Ingredient(
      id: 8,
      name: 'Stored Ingredient Name',
      categoryId: 2,
      aliases: ['Stored alias'],
    );
  }

  @override
  Future<List<IngredientCategory>> getCategories() async {
    return const [_builtinCategory, _customCategory];
  }
}

class _StaticIngredientListNotifier extends IngredientListNotifier {
  _StaticIngredientListNotifier() {
    state = state.copyWith(
      items: const [
        Ingredient(
          id: 8,
          name: 'Stored Ingredient Name',
          categoryId: 2,
          category: '蔬菜',
        ),
      ],
      total: 1,
      hasMore: false,
    );
  }

  @override
  Future<void> load({bool loadMore = false}) async {}
}

class _StaticIngredientDetailNotifier extends IngredientDetailPageNotifier {
  _StaticIngredientDetailNotifier(super.id) {
    state = const IngredientDetailPageState(
      ingredient: Ingredient(
        id: 8,
        name: 'Stored Ingredient Name',
        categoryId: 2,
        category: '蔬菜',
        aliases: ['Stored alias'],
      ),
      hierarchy: IngredientHierarchyData(
        childRelations: [
          HierarchyRelation(
            id: 1,
            parentId: 8,
            parentName: 'Stored Ingredient Name',
            childId: 9,
            childName: 'Stored Child',
            relationType: 'contains',
            strength: 50,
          ),
        ],
      ),
      products: [
        Product(id: 20, name: 'Linked Product'),
      ],
    );
  }

  @override
  Future<void> load({int initialDays = 30, int? regionId}) async {}
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

Future<void> _pumpLocalized(
  WidgetTester tester,
  Locale locale,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ingredientCategoriesProvider.overrideWith((ref) async {
          return const [_builtinCategory, _customCategory];
        }),
        merchantListProvider.overrideWith(
          (ref) => MerchantListNotifier(_FakeMerchantRepository()),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('English ingredient list and category filters localize', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const IngredientListScreen(),
      overrides: [
        ingredientListProvider.overrideWith(
          (ref) => _StaticIngredientListNotifier(),
        ),
      ],
    );

    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Search ingredients...'), findsOneWidget);
    expect(find.text('Stored Ingredient Name'), findsOneWidget);
    expect(find.text('Vegetables'), findsWidgets);
    expect(find.text('蔬菜'), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Special conditions'), findsOneWidget);
    expect(find.text('No maintained price'), findsOneWidget);
    expect(find.text('Vegetables'), findsWidgets);
    expect(find.text('My Pantry Category'), findsOneWidget);
  });

  testWidgets('Arabic ingredient list and category filters localize', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const IngredientListScreen(),
      overrides: [
        ingredientListProvider.overrideWith(
          (ref) => _StaticIngredientListNotifier(),
        ),
      ],
    );

    expect(find.text('المكوّنات'), findsOneWidget);
    expect(find.text('ابحث عن المكوّنات...'), findsOneWidget);
    expect(find.text('Stored Ingredient Name'), findsOneWidget);
    expect(find.text('الخضروات'), findsWidgets);
    expect(find.text('蔬菜'), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('الفلاتر'), findsOneWidget);
    expect(find.text('الفئة'), findsOneWidget);
    expect(find.text('شروط خاصة'), findsOneWidget);
    expect(find.text('لا يوجد سعر مُصان'), findsOneWidget);
    expect(find.text('الخضروات'), findsWidgets);
    expect(find.text('My Pantry Category'), findsOneWidget);
  });

  testWidgets('English ingredient detail localizes data and deletion copy', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const IngredientDetailScreen(id: 8),
      overrides: [
        ingredientDetailPageProvider.overrideWith(
          (ref, id) => _StaticIngredientDetailNotifier(id),
        ),
      ],
    );

    expect(find.text('Ingredient'), findsOneWidget);
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Vegetables'), findsOneWidget);
    expect(find.text('Stored alias'), findsOneWidget);
    expect(find.text('Hierarchy'), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.delete_outline).first);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Delete product'), findsOneWidget);
    expect(find.text('Delete product "Linked Product"?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -10000));
    await tester.pump();
    expect(find.text('Contains'), findsOneWidget);
    expect(find.text('Stored Ingredient Name'), findsWidgets);
    expect(find.text('Stored Child'), findsOneWidget);
  });

  testWidgets('Arabic ingredient detail localizes data and deletion copy', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const IngredientDetailScreen(id: 8),
      overrides: [
        ingredientDetailPageProvider.overrideWith(
          (ref, id) => _StaticIngredientDetailNotifier(id),
        ),
      ],
    );

    expect(find.text('مكوّن'), findsOneWidget);
    expect(find.text('المعلومات الأساسية'), findsOneWidget);
    expect(find.text('الفئة'), findsOneWidget);
    expect(find.text('الخضروات'), findsOneWidget);
    expect(find.text('Stored alias'), findsOneWidget);
    expect(find.text('التسلسل الهرمي'), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.delete_outline).first);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('حذف المنتج'), findsOneWidget);
    expect(find.text('حذف المنتج "Linked Product"؟'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -10000));
    await tester.pump();
    expect(find.text('يحتوي'), findsOneWidget);
  });

  testWidgets(
      'English ingredient create form validates and submits category id',
      (tester) async {
    final repository = _FakeIngredientRepository();
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      IngredientFormScreen(repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add ingredient'), findsOneWidget);
    expect(find.text('Ingredient name'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Ingredient name is required'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ingredient name'),
      'Stored Ingredient Name',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vegetables').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.lastCategoryId, 2);
  });

  testWidgets('Arabic ingredient edit form keeps business data canonical', (
    tester,
  ) async {
    final repository = _FakeIngredientRepository();
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      IngredientFormScreen(
        ingredient: const Ingredient(
          id: 8,
          name: 'Stored Ingredient Name',
          categoryId: 2,
          aliases: ['Stored alias'],
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعديل المكوّن'), findsOneWidget);
    expect(find.text('اسم المكوّن'), findsOneWidget);
    expect(find.text('الفئة'), findsOneWidget);
    expect(find.text('الخضروات'), findsOneWidget);
    expect(find.text('Stored Ingredient Name'), findsOneWidget);
    expect(find.text('Stored alias'), findsOneWidget);
  });

  testWidgets('English hierarchy form and deletion confirmation localize', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      IngredientHierarchyScreen(
        ingredientId: 8,
        ingredientName: 'Stored Ingredient Name',
        hierarchyData: const IngredientHierarchyData(
          childRelations: [
            HierarchyRelation(
              id: 1,
              parentId: 8,
              parentName: 'Stored Ingredient Name',
              childId: 9,
              childName: 'Stored Child',
              relationType: 'contains',
              strength: 50,
            ),
          ],
        ),
        isAdmin: true,
        onAdd: (_) async => null,
        onUpdateStrength: (_, __) async => null,
        onDelete: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage ingredient relations'), findsOneWidget);
    expect(find.text('Relation graph'), findsOneWidget);
    expect(find.text('Relation list'), findsOneWidget);
    expect(find.text('Add hierarchy relation'), findsOneWidget);
    expect(find.text('Search ingredient *'), findsOneWidget);
    expect(find.text('Relation type'), findsOneWidget);
    expect(find.text('Contains'), findsOneWidget);

    await tester.tap(find.text('Relation list'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete relation'), findsOneWidget);
    expect(find.text('Delete this hierarchy relation?'), findsOneWidget);
  });

  testWidgets('Arabic hierarchy form and deletion confirmation localize', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      IngredientHierarchyScreen(
        ingredientId: 8,
        ingredientName: 'Stored Ingredient Name',
        hierarchyData: const IngredientHierarchyData(
          childRelations: [
            HierarchyRelation(
              id: 1,
              parentId: 8,
              parentName: 'Stored Ingredient Name',
              childId: 9,
              childName: 'Stored Child',
              relationType: 'contains',
              strength: 50,
            ),
          ],
        ),
        isAdmin: true,
        onAdd: (_) async => null,
        onUpdateStrength: (_, __) async => null,
        onDelete: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة علاقات المكوّنات'), findsOneWidget);
    expect(find.text('مخطط العلاقات'), findsOneWidget);
    expect(find.text('قائمة العلاقات'), findsOneWidget);
    expect(find.text('إضافة علاقة تسلسل هرمي'), findsOneWidget);
    expect(find.text('ابحث عن مكوّن *'), findsOneWidget);
    expect(find.text('نوع العلاقة'), findsOneWidget);
    expect(find.text('يحتوي'), findsOneWidget);

    await tester.tap(find.text('قائمة العلاقات'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('حذف العلاقة'), findsOneWidget);
    expect(find.text('حذف علاقة التسلسل الهرمي هذه؟'), findsOneWidget);
  });
}

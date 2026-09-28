import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/products/models/product.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/products/screens/product_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

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
      Product(id: 1, name: name);
}

class _FormalDataIngredientRepository extends IngredientRepository {
  @override
  Future<IngredientPage> search({
    String? search,
    List<int>? categoryIds,
    List<String>? conditions,
    int skip = 0,
    int limit = 20,
    String sortBy = 'price_records',
  }) async {
    const items = [
      Ingredient(id: 240, name: '???'),
      Ingredient(id: 242, name: '??'),
      Ingredient(id: 573, name: '???'),
    ];
    final q = (search ?? '').trim();
    return IngredientPage(
      items:
          q.isEmpty ? items : items.where((i) => i.name.contains(q)).toList(),
      total: 3,
    );
  }
}

Future<void> pumpForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProductFormScreen(
      repository: _FakeProductRepository(),
      ingredientRepository: _FormalDataIngredientRepository(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final field = find.widgetWithText(
    TextField,
    'Search and select a linked ingredient *',
  );
  final option = find.descendant(
    of: find.byType(ListTile),
    matching: find.text('???'),
  );

  testWidgets('full formal keyword shows an option, not only field text',
      (tester) async {
    await pumpForm(tester);
    await tester.enterText(field, '???');
    await tester.pump(const Duration(milliseconds: 50));
    expect(option, findsWidgets);
  });

  testWidgets('rapid input ends on full formal keyword option', (tester) async {
    await pumpForm(tester);
    for (final text in ['?', '??', '???']) {
      await tester.enterText(field, text);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(option, findsWidgets);
  });
}

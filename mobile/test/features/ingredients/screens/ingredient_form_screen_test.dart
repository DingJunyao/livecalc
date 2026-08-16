import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient_category.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_form_screen.dart';

class _FakeIngredientRepository extends IngredientRepository {
  String? lastName;
  int? lastCategoryId;
  List<String>? lastAliases;

  @override
  Future<Ingredient> createIngredient({
    required String name,
    int? categoryId,
    List<String> aliases = const [],
  }) async {
    lastName = name;
    lastCategoryId = categoryId;
    lastAliases = aliases;
    return Ingredient(id: 1, name: name);
  }
}

void main() {
  testWidgets('新增原料页加载分类并用标签维护别名', (tester) async {
    final repo = _FakeIngredientRepository();
    bool? popped;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ingredientCategoriesProvider.overrideWith(
          (ref) async => const [
            IngredientCategory(id: 3, name: 'vegetable', displayName: '蔬菜'),
            IngredientCategory(id: 4, name: 'fruit', displayName: '水果'),
          ],
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => IngredientFormScreen(repository: repo),
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, '添加原料'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '原料名称'),
      '西红柿',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('蔬菜').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '别名'),
      '番茄, 洋柿子',
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(repo.lastName, '西红柿');
    expect(repo.lastCategoryId, 3);
    expect(repo.lastAliases, ['番茄, 洋柿子']);
  });
}

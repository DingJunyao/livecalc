import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient.dart';
import 'package:com_a4ding_livecalc/features/ingredients/models/ingredient_category.dart';
import 'package:com_a4ding_livecalc/features/ingredients/providers/ingredient_provider.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';
import 'package:com_a4ding_livecalc/features/ingredients/screens/ingredient_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

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
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeIngredientRepository();
    IngredientFormResult? pushedResult;
    await tester.pumpWidget(ProviderScope(
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
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              pushedResult =
                  await Navigator.of(context).push<IngredientFormResult>(
                MaterialPageRoute(
                  builder: (_) => IngredientFormScreen(repository: repo),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppBar, 'Add ingredient'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ingredient name'),
      '西红柿',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vegetables').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Aliases'),
      '番茄, 洋柿子',
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(pushedResult?.saved, isTrue);
    expect(pushedResult?.pending, isFalse);
    expect(repo.lastName, '西红柿');
    expect(repo.lastCategoryId, 3);
    expect(repo.lastAliases, ['番茄, 洋柿子']);
  });
}

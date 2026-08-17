import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/nutrition/models/usda_models.dart';
import 'package:com_a4ding_livecalc/features/recipes/models/recipe_detail.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_form_screen.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  late MockRecipeRepository repository;
  late List<Map<String, dynamic>> payloads;

  setUp(() {
    registerFallbackValue(<String, dynamic>{});
    repository = MockRecipeRepository();
    payloads = [];
    when(() => repository.getUnitOptions())
        .thenAnswer((_) async => const [RecipeUnitOption(id: 2, label: 'g')]);
    when(() => repository.getIngredientOptions(any())).thenAnswer(
      (_) async => const [IngredientOption(id: 8, name: '鸡蛋')],
    );
  });

  Future<Future<RecipeFormResult?>?> pumpForm(
    WidgetTester tester, {
    RecipeDetail? recipe,
  }) async {
    Future<RecipeFormResult?>? result;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = Navigator.of(context).push<RecipeFormResult>(
                      MaterialPageRoute(
                        builder: (_) => RecipeFormScreen(
                          repository: repository,
                          recipe: recipe,
                          recipeId: recipe?.id,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('creates a recipe through a full-page form', (tester) async {
    when(() => repository.createRecipe(any())).thenAnswer((invocation) async {
      payloads.add(Map<String, dynamic>.from(
        invocation.positionalArguments.first as Map<String, dynamic>,
      ));
      return RecipeMutationResult.applied(
        const RecipeDetail(id: 12, name: '番茄炒蛋'),
        '',
      );
    });

    final resultFuture = await pumpForm(tester);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '番茄炒蛋');
    await tester.dragUntilVisible(
      find.widgetWithText(TextFormField, '原料'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.enterText(find.widgetWithText(TextFormField, '原料'), '鸡蛋');
    await tester.enterText(find.widgetWithText(TextFormField, '推荐量'), '2');
    await tester.dragUntilVisible(
      find.widgetWithText(DropdownButtonFormField<String>, '单位'),
      find.byType(ListView).first,
      const Offset(0, -120),
    );
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<String>, '单位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('g').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.widgetWithText(TextFormField, '内容'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '内容'),
      '鸡蛋打散',
    );
    await tester.dragUntilVisible(
      find.widgetWithText(TextFormField, '小贴士'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '小贴士'),
      '热锅快炒',
    );
    final createButton = find.widgetWithText(FilledButton, '创建菜谱');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.saved, isTrue);
    expect(result?.pending, isFalse);
    expect(result?.recipeId, 12);
    expect(payloads.single['name'], '番茄炒蛋');
    expect(payloads.single['ingredients'], hasLength(1));
    expect(
      (payloads.single['ingredients'] as List).single.toJson(),
      {
        'ingredient_name': '鸡蛋',
        'quantity': '2',
        'unit_id': 2,
        'is_optional': false,
      },
    );
    expect(
      payloads.single['cooking_steps'],
      [
        {'content': '鸡蛋打散'}
      ],
    );
    expect(payloads.single['tips'], ['热锅快炒']);
  });

  testWidgets('returns pending and does not treat proposal as applied',
      (tester) async {
    when(() => repository.updateRecipe(any(), any())).thenAnswer(
      (_) async => RecipeMutationResult.pending(
        MutationReviewResult.fromJson(
          const {
            'proposal_id': 99,
            'status': 'pending',
            'message': '编辑已提交，待管理员审核',
          },
        ),
      ),
    );

    const recipe = RecipeDetail(
      id: 3,
      name: '番茄炒蛋',
      ingredients: [
        RecipeIngredient(id: 1, ingredientId: 8, name: '鸡蛋', quantity: '2'),
      ],
      steps: [RecipeStep(stepNumber: 1, content: '炒')],
    );
    final resultFuture = await pumpForm(tester, recipe: recipe);

    await tester.enterText(find.byType(TextFormField).first, '番茄炒蛋改');
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-save-basic')));
    await tester.tap(find.byKey(const ValueKey('recipe-save-basic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pageBack();
    await tester.pump();
    final result = await resultFuture;
    expect(result?.saved, isTrue);
    expect(result?.pending, isTrue);
    expect(result?.recipeId, 3);
    expect(find.textContaining('待管理员审核'), findsAtLeastNWidgets(1));
  });

  testWidgets('edits recipe sections through independent payloads', (
    tester,
  ) async {
    final payloads = <Map<String, dynamic>>[];
    when(() => repository.updateRecipe(any(), any())).thenAnswer(
      (invocation) async {
        payloads.add(Map<String, dynamic>.from(
          invocation.positionalArguments.last as Map<String, dynamic>,
        ));
        return RecipeMutationResult.applied(
          const RecipeDetail(id: 3, name: '番茄炒蛋'),
          '',
        );
      },
    );

    const recipe = RecipeDetail(
      id: 3,
      name: '番茄炒蛋',
      ingredients: [
        RecipeIngredient(id: 1, ingredientId: 8, name: '鸡蛋', quantity: '2'),
      ],
      steps: [RecipeStep(stepNumber: 1, content: '炒')],
      tips: ['热锅快炒'],
    );
    final resultFuture = await pumpForm(tester, recipe: recipe);

    await tester.enterText(find.byType(TextFormField).first, '番茄炒蛋改');
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-save-basic')));
    await tester.tap(find.byKey(const ValueKey('recipe-save-basic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('recipe-save-ingredients')),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '2').first,
      '3',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('recipe-save-ingredients')),
    );
    await tester.tap(find.byKey(const ValueKey('recipe-save-ingredients')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('recipe-save-steps')),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.enterText(find.widgetWithText(TextFormField, '炒'), '翻炒');
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-save-steps')));
    await tester.tap(find.byKey(const ValueKey('recipe-save-steps')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('recipe-save-tips')),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '热锅快炒'),
      '小火慢煎',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('recipe-save-tips')));
    await tester.tap(find.byKey(const ValueKey('recipe-save-tips')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(payloads, hasLength(4));
    expect(payloads[0].keys, ['name']);
    expect(payloads[1].keys, ['ingredients']);
    expect(payloads[2].keys, ['cooking_steps']);
    expect(payloads[3].keys, ['tips']);

    await tester.pageBack();
    await tester.pump();
    final result = await resultFuture;
    expect(result?.saved, isTrue);
    expect(result?.pending, isFalse);
  });
}

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
    RecipeFormSection? section,
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
                          section: section,
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
    expect(
      ((payloads[1]['ingredients'] as List).single as RecipeIngredientInput)
          .toJson(),
      isA<Map<String, dynamic>>().having(
        (item) => item['ingredient_id'],
        'ingredient_id',
        8,
      ),
    );
    expect(payloads[2].keys, ['cooking_steps']);
    expect(payloads[3].keys, ['tips']);

    await tester.pageBack();
    await tester.pump();
    final result = await resultFuture;
    expect(result?.saved, isTrue);
    expect(result?.pending, isFalse);
  });

  testWidgets('edit form starts from all pending proposals', (tester) async {
    final recipe = RecipeDetail.fromJson(const {
      'id': 3,
      'name': 'base recipe',
      'ingredients': [],
      'cooking_steps': [],
      'tips': [],
      'pending_proposals': [
        {
          'id': 11,
          'action': 'update',
          'payload': {
            'update_data': {'name': 'first pending name'},
          },
        },
        {
          'id': 12,
          'action': 'update',
          'payload': {
            'update_data': {
              'tips': ['second pending tip']
            },
          },
        },
      ],
    });
    final resultFuture = await pumpForm(tester, recipe: recipe);

    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      'first pending name',
    );
    await tester.dragUntilVisible(
      find.widgetWithText(TextFormField, 'second pending tip'),
      find.byType(ListView).first,
      const Offset(0, -400),
    );
    expect(
      find.widgetWithText(TextFormField, 'second pending tip'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    final result = await resultFuture;
    expect(result?.saved, isFalse);
  });

  testWidgets(
      'section edit page only shows its own section and pops after save',
      (tester) async {
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
    final resultFuture = await pumpForm(
      tester,
      recipe: recipe,
      section: RecipeFormSection.ingredients,
    );

    expect(
      find.byKey(const ValueKey('recipe-form-section-ingredients')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('recipe-form-section-basic')), findsNothing);
    expect(
        find.byKey(const ValueKey('recipe-form-section-steps')), findsNothing);
    expect(
        find.byKey(const ValueKey('recipe-form-section-tips')), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, '2'), '3');
    await tester.tap(find.widgetWithText(FilledButton, '保存修改'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final result = await resultFuture;
    expect(result?.saved, isTrue);
    expect(result?.pending, isFalse);
    expect(payloads.single.keys, ['ingredients']);
  });

  testWidgets('basic edit reorders and removes recipe images', (tester) async {
    final payloads = <Map<String, dynamic>>[];
    when(() => repository.updateRecipe(any(), any())).thenAnswer(
      (invocation) async {
        payloads.add(Map<String, dynamic>.from(
          invocation.positionalArguments.last as Map<String, dynamic>,
        ));
        return RecipeMutationResult.applied(
          const RecipeDetail(id: 3, name: 'recipe'),
          '',
        );
      },
    );

    const recipe = RecipeDetail(
      id: 3,
      name: 'recipe',
      images: ['recipes/first.jpg', 'recipes/second.jpg'],
      imageUrls: ['', ''],
      ingredients: [],
      steps: [],
    );
    final resultFuture = await pumpForm(tester, recipe: recipe);

    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('recipe-image-handle-recipes/first.jpg')),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final deleteButton = tester.widget<IconButton>(
      find.byKey(
        const ValueKey('recipe-image-delete-recipes/first.jpg'),
      ),
    );
    expect(deleteButton.onPressed, isNotNull);
    deleteButton.onPressed!();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('recipe-image-thumb-recipes/first.jpg')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('recipe-image-thumb-recipes/second.jpg')),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 250));
    await tester.pump();
    final saveButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('recipe-save-basic')),
    );
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pageBack();
    await tester.pump();

    expect(payloads.single, {
      'images': ['recipes/second.jpg'],
    });
    final result = await resultFuture;
    expect(result?.saved, isTrue);
  });

  testWidgets('basic edit supports drag handle image reordering', (
    tester,
  ) async {
    final payloads = <Map<String, dynamic>>[];
    when(() => repository.updateRecipe(any(), any())).thenAnswer(
      (invocation) async {
        payloads.add(Map<String, dynamic>.from(
          invocation.positionalArguments.last as Map<String, dynamic>,
        ));
        return RecipeMutationResult.applied(
          const RecipeDetail(id: 3, name: 'recipe'),
          '',
        );
      },
    );

    const recipe = RecipeDetail(
      id: 3,
      name: 'recipe',
      images: ['recipes/first.webp', 'recipes/second.webp'],
      imageUrls: [
        'https://cdn.example.test/recipes/first.webp',
        'https://cdn.example.test/recipes/second.webp',
      ],
      ingredients: [],
      steps: [],
    );
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final resultFuture = await pumpForm(tester, recipe: recipe);

    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pump();
    final first =
        find.byKey(const ValueKey('recipe-image-item-recipes/first.webp'));
    final second =
        find.byKey(const ValueKey('recipe-image-item-recipes/second.webp'));
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('recipe-image-handle-recipes/first.webp')),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(16, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
        tester.getTopLeft(first).dx, greaterThan(tester.getTopLeft(second).dx));

    final saveButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('recipe-save-basic')),
    );
    saveButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pageBack();
    await tester.pump();

    expect(payloads.single, {
      'images': ['recipes/second.webp', 'recipes/first.webp'],
    });
    final result = await resultFuture;
    expect(result?.saved, isTrue);
  });
}

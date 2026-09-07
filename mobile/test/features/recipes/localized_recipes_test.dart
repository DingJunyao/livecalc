import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/features/recipes/models/recipe_detail.dart';
import 'package:com_a4ding_livecalc/features/recipes/models/recipe_summary.dart';
import 'package:com_a4ding_livecalc/features/recipes/providers/recipe_provider.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_analysis_screen.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_detail_screen.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_form_screen.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_list_screen.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/cost_proportion_chart.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/cost_trend_chart.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/cost_trend_stacked_chart.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/merchant_cost_cards.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/merchant_price_matrix.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/nutrition_source_grid.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/providers/calc_context_provider.dart';

const _summary = RecipeSummary(
  id: 1,
  name: 'Stored recipe',
  estimatedCost: 6.5,
  calories: 420,
  servings: 2,
);

class _ListRepository extends RecipeRepository {
  @override
  Future<RecipePage> getRecipes({
    String? search,
    List<String>? categories,
    List<String>? difficulties,
    List<int>? ingredientIds,
    List<String>? conditions,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const RecipePage(items: [_summary], total: 1);
  }

  @override
  Future<Map<int, RecipeCostInfo>> getRecipesBatchCost(
    List<int> ids, {
    int? regionId,
  }) async {
    return {
      for (final id in ids)
        id: const RecipeCostInfo(estimatedCost: 6.5, calories: 420)
    };
  }
}

class _NoopRepository extends RecipeRepository {}

const _detail = RecipeDetail(
  id: 1,
  name: 'Stored recipe',
  category: '荤菜',
  difficulty: 'simple',
  servings: 2,
  ingredients: [
    RecipeIngredient(
      id: 1,
      ingredientId: 8,
      name: 'Stored egg',
      quantity: '100',
      unit: 'g',
      isOptional: true,
    ),
  ],
  steps: [
    RecipeStep(stepNumber: 1, content: 'Stored step', durationMinutes: 5)
  ],
  tips: ['Stored tip'],
);

const _cost = RecipeCost(
  totalCost: 10,
  costPerServing: 5,
  breakdown: [
    CostBreakdownItem(
      ingredientName: 'Stored egg',
      ingredientId: 8,
      cost: 10,
      unitPrice: 0.1,
    ),
  ],
);

const _history = [
  CostHistoryPoint(date: '09-01', minCost: 8, maxCost: 12, avgCost: 10),
  CostHistoryPoint(date: '09-02', minCost: 7, maxCost: 11, avgCost: 9),
  CostHistoryPoint(date: '09-03', minCost: 6, maxCost: 10, avgCost: 8),
];

const _nutrition = RecipeNutrition(
  totalCalories: 420,
  totalProtein: 20,
  totalFat: 10,
  totalCarbs: 30,
  perServingNutrients: {
    '能量': NutritionItem(value: 420, unit: 'kcal', nrpPct: 21),
    '蛋白质': NutritionItem(value: 20, unit: 'g', nrpPct: 33),
    '脂肪': NutritionItem(value: 10, unit: 'g', nrpPct: 18),
    '碳水化合物': NutritionItem(value: 30, unit: 'g', nrpPct: 10),
  },
);

const _unnamedMerchant = MerchantCostItem(
  merchantId: 9,
  merchantName: '',
  coveredCost: 3,
  externalCost: 0,
  totalCost: 3,
  coveredCount: 1,
  totalIngredients: 1,
  isRecommended: true,
);

const _merchant = MerchantCostItem(
  merchantId: 1,
  merchantName: 'Stored merchant',
  coveredCost: 8,
  externalCost: 2,
  totalCost: 10,
  coveredCount: 1,
  totalIngredients: 1,
  missingIngredients: ['Missing item'],
  fallbackChains: ['Chain'],
  isRecommended: true,
);

class _StaticDetailNotifier extends RecipeDetailPageNotifier {
  _StaticDetailNotifier() : super(_NoopRepository(), 1) {
    state = const RecipeDetailPageState(
      detail: _detail,
      cost: _cost,
      nutrition: _nutrition,
      costHistory: _history,
      displayServings: 2,
      merchantCosts: RecipeMerchantCost(merchants: [_merchant]),
      merchantPrices: [
        MerchantPriceItem(
          recipeIngredientId: 1,
          ingredientId: 8,
          ingredientName: 'Stored egg',
          prices: [
            MerchantPriceRecord(
              merchantId: 1,
              merchantName: 'Stored merchant',
              price: 10,
              totalCost: 10,
              isLowest: true,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<void> load({int initialDays = 30, int? regionId}) async {}

  @override
  Future<void> reloadHistory(int days) async {}
}

class _FormRepository extends RecipeRepository {
  @override
  Future<List<RecipeUnitOption>> getUnitOptions() async =>
      const [RecipeUnitOption(id: 2, label: 'g')];

  @override
  Future<List<IngredientOption>> getIngredientOptions(String query) async =>
      const [IngredientOption(id: 8, name: 'Stored ingredient')];
}

Future<void> _pumpLocalized(
  WidgetTester tester,
  Locale locale,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final previous = localeSettingsStore.current;
  addTearDown(() => localeSettingsStore.update(previous));
  localeSettingsStore.update(
    LocaleSettings(
      uiLocale: locale.languageCode == 'ar' ? 'ar' : 'en-US',
      formatLocale: locale.languageCode == 'ar' ? 'ar-EG' : 'en-US',
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        displayCurrencyProvider.overrideWith((ref) => 'USD'),
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
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('English recipe list and filters localize', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const RecipeListScreen(),
      overrides: [
        recipeListProvider.overrideWith(
          (ref) => RecipeListNotifier(_ListRepository()),
        ),
      ],
    );
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Search recipes...'), findsOneWidget);
    expect(find.text('Stored recipe'), findsOneWidget);
    expect(find.textContaining('servings'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Difficulty'), findsOneWidget);
    expect(find.text('Ingredients used'), findsOneWidget);
    expect(find.text('Special conditions'), findsOneWidget);
    expect(find.text('Meat dish'), findsWidgets);
    expect(find.text('Vegetable dish'), findsWidgets);
    expect(find.text('Very easy'), findsWidgets);
    expect(find.text('Easy'), findsWidgets);
    expect(
        find.text('Has ingredients without maintained prices'), findsOneWidget);
    expect(find.text('菜谱'), findsNothing);
  });

  testWidgets('Arabic recipe list and filters localize', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const RecipeListScreen(),
      overrides: [
        recipeListProvider.overrideWith(
          (ref) => RecipeListNotifier(_ListRepository()),
        ),
      ],
    );
    expect(find.text('الوصفات'), findsOneWidget);
    expect(find.text('ابحث عن الوصفات...'), findsOneWidget);
    expect(find.text('Stored recipe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('التصنيف'), findsOneWidget);
    expect(find.text('الصعوبة'), findsOneWidget);
    expect(find.text('المكوّنات المستخدمة'), findsOneWidget);
    expect(find.text('شروط خاصة'), findsOneWidget);
    expect(find.text('طبق باللحم'), findsWidgets);
    expect(find.text('菜谱'), findsNothing);
  });

  testWidgets('English recipe detail localizes sections and nutrient names', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const RecipeDetailScreen(id: 1),
      overrides: [
        recipeDetailPageProvider(1).overrideWith(
          (ref) => _StaticDetailNotifier(),
        ),
      ],
    );
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Unpublished'), findsOneWidget);
    expect(find.text('Cost estimate'), findsOneWidget);
    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Stored egg'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Stored step'), findsOneWidget);
    expect(find.text('Nutrition (per serving)'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Tips'), findsOneWidget);
    expect(find.text('Stored tip'), findsOneWidget);
  });

  testWidgets('Arabic recipe detail localizes sections and nutrient names', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      const RecipeDetailScreen(id: 1),
      overrides: [
        recipeDetailPageProvider(1).overrideWith(
          (ref) => _StaticDetailNotifier(),
        ),
      ],
    );
    expect(find.text('المعلومات الأساسية'), findsOneWidget);
    expect(find.text('غير منشورة'), findsOneWidget);
    expect(find.text('تقدير التكلفة'), findsOneWidget);
    expect(find.text('المكوّنات'), findsOneWidget);
    expect(find.text('Stored egg'), findsOneWidget);
    expect(find.text('الخطوات'), findsOneWidget);
    expect(find.text('Stored step'), findsOneWidget);
    expect(find.text('التغذية لكل حصة'), findsOneWidget);
    expect(find.text('الطاقة'), findsOneWidget);
    expect(find.text('البروتين'), findsOneWidget);
    expect(find.text('نصائح'), findsOneWidget);
    expect(find.text('Stored tip'), findsOneWidget);
  });

  testWidgets('English recipe create form labels localize', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      RecipeFormScreen(repository: _FormRepository()),
    );
    expect(find.text('Create recipe'), findsWidgets);
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Recipe name'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Difficulty'), findsOneWidget);
    expect(find.text('Servings'), findsOneWidget);
    expect(find.text('Total time (minutes)'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Result ingredient'), findsOneWidget);
    expect(find.text('Meat dish'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
  });

  testWidgets('Arabic recipe create form labels localize', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('ar'),
      RecipeFormScreen(repository: _FormRepository()),
    );
    expect(find.text('إنشاء وصفة'), findsWidgets);
    expect(find.text('المعلومات الأساسية'), findsOneWidget);
    expect(find.text('اسم الوصفة'), findsOneWidget);
    expect(find.text('التصنيف'), findsOneWidget);
    expect(find.text('الصعوبة'), findsOneWidget);
    expect(find.text('الحصص'), findsOneWidget);
    expect(find.text('الوقت الإجمالي (دقائق)'), findsOneWidget);
    expect(find.text('مقدمة'), findsOneWidget);
    expect(find.text('المكوّن الناتج'), findsOneWidget);
  });

  testWidgets('English and Arabic analysis surfaces localize', (tester) async {
    for (final (locale, label, chip, share) in [
      (
        const Locale('en', 'US'),
        'Stored recipe',
        'Analysis',
        'Ingredient cost share'
      ),
      (const Locale('ar'), 'Stored recipe', 'تحليل', 'توزيع تكلفة المكوّنات'),
    ]) {
      await _pumpLocalized(
        tester,
        locale,
        const RecipeAnalysisScreen(id: 1),
        overrides: [
          recipeDetailPageProvider(1).overrideWith(
            (ref) => _StaticDetailNotifier(),
          ),
        ],
      );
      expect(find.text(label), findsOneWidget);
      expect(find.text(chip), findsOneWidget);
      expect(find.text(share), findsOneWidget);
      expect(
        find.text(
          locale.languageCode == 'ar' ? 'اتجاه التكلفة' : 'Cost trend',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          locale.languageCode == 'ar' ? 'مصادر التغذية' : 'Nutrition sources',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          locale.languageCode == 'ar'
              ? 'تقديرات تكلفة التاجر'
              : 'Merchant cost estimates',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          locale.languageCode == 'ar'
              ? 'توصيات أسعار التاجر'
              : 'Merchant price recommendations',
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('proportion, nutrition, matrix, and merchant widgets localize', (
    tester,
  ) async {
    const breakdown = [
      CostBreakdownItem(
          ingredientName: 'Stored egg', ingredientId: 8, cost: 6, unitPrice: 0),
      CostBreakdownItem(
          ingredientName: 'Stored tomato',
          ingredientId: 9,
          cost: 4,
          unitPrice: 0),
    ];
    const ingredients = [
      RecipeIngredient(
          id: 1,
          ingredientId: 8,
          name: 'Stored egg',
          quantity: '100',
          unit: 'g'),
    ];
    const prices = [
      MerchantPriceItem(
        recipeIngredientId: 1,
        ingredientId: 8,
        ingredientName: 'Stored egg',
        prices: [
          MerchantPriceRecord(
              merchantId: 9,
              merchantName: '',
              price: 3,
              totalCost: 3,
              isLowest: true),
        ],
      ),
    ];
    final pages = <Widget>[
      const CostProportionChart(breakdown: breakdown, totalCost: 10),
      const NutritionSourceGrid(nutrition: _nutrition),
      const MerchantPriceMatrix(ingredients: ingredients, prices: prices),
      const MerchantCostCards(merchants: [_merchant]),
      const CostTrendChart(points: _history),
      const CostTrendStackedChart(points: _history),
    ];
    for (final (locale, labels) in [
      (
        const Locale('en', 'US'),
        <String, bool>{
          'Ingredient cost share': true,
          'Cost trend': true,
          'Nutrition sources': true,
          'Merchant price recommendations': true,
          'Merchant cost estimates': true,
          'Best value': true,
        },
      ),
      (
        const Locale('ar'),
        <String, bool>{
          'توزيع تكلفة المكوّنات': true,
          'اتجاه التكلفة': true,
          'مصادر التغذية': true,
          'توصيات أسعار التاجر': true,
          'تقديرات تكلفة التاجر': true,
          'أفضل قيمة': true,
        },
      ),
    ]) {
      await _pumpLocalized(
        tester,
        locale,
        Scaffold(
          body: SingleChildScrollView(
            child: Column(children: pages),
          ),
        ),
      );
      for (final label in labels.keys) {
        expect(find.text(label), findsWidgets, reason: 'missing $label');
      }
      if (locale.languageCode == 'ar') {
        expect(
          find.descendant(
            of: find.byType(CostTrendStackedChart),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Directionality && w.textDirection == TextDirection.ltr,
            ),
          ),
          findsWidgets,
        );
      }
      expect(find.text('菜谱'), findsNothing);
    }
  });

  testWidgets('unknown and other chart data labels localize', (tester) async {
    const emptyBreakdown = [
      CostBreakdownItem(
          ingredientName: '', ingredientId: 1, cost: 2, unitPrice: 0),
    ];
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      const CostProportionChart(breakdown: emptyBreakdown, totalCost: 2),
    );
    expect(find.text('Unknown ingredient'), findsOneWidget);
  });

  testWidgets(
      'empty merchant names localize fallbacks in cost cards and matrix', (
    tester,
  ) async {
    const ingredients = [
      RecipeIngredient(
          id: 1,
          ingredientId: 8,
          name: 'Stored egg',
          quantity: '100',
          unit: 'g'),
    ];
    const prices = [
      MerchantPriceItem(
        recipeIngredientId: 1,
        ingredientId: 8,
        ingredientName: 'Stored egg',
        prices: [
          MerchantPriceRecord(
              merchantId: 9,
              merchantName: '',
              price: 3,
              totalCost: 3,
              isLowest: true),
        ],
      ),
    ];
    for (final (locale, label) in [
      (const Locale('en', 'US'), 'Merchant #9'),
      (const Locale('ar'), 'تاجر #9'),
    ]) {
      await _pumpLocalized(
        tester,
        locale,
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                MerchantCostCards(merchants: [_unnamedMerchant]),
                MerchantPriceMatrix(
                  ingredients: ingredients,
                  prices: prices,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text(label), findsNWidgets(2), reason: label);
      expect(find.text('商家'), findsNothing);
    }
  });
}

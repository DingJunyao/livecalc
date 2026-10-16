import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/home/models/meal_recommendation.dart';
import 'package:com_a4ding_livecalc/features/home/widgets/meal_card.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('AI 推荐餐：AI 标识只有一处，块尾是成本 + 四项营养素（含 NRV）',
      (tester) async {
    const meal = MealRecommendation(
      mealType: 'dinner',
      source: 'system_ai',
      dishes: [
        RecommendedDish(
          recipeId: 1,
          name: 'Braised pork',
          estimatedCost: 3.14,
          currency: 'CNY',
          calories: 766.4,
          proteinG: 21.2,
          carbsG: 127.3,
          fatG: 18.2,
          role: 'staple',
        ),
        RecommendedDish(
          recipeId: 2,
          name: 'Egg soup',
          estimatedCost: 4.8,
          currency: 'CNY',
          calories: 331.6,
          proteinG: 18.7,
          carbsG: 8.7,
          fatG: 24.1,
          role: 'soup',
        ),
      ],
    );
    await _pumpCard(tester, const MealCard(meal: meal, userCurrency: 'CNY'));

    // 菜名只在清单里出现一次（标题不再重复写）
    expect(find.text('Braised pork'), findsOneWidget);
    expect(find.text('Egg soup'), findsOneWidget);
    // AI 标识去重后只剩块尾一处
    expect(find.text('AI generated'), findsOneWidget);
    // 块尾：成本合计 + 热量/蛋白质/碳水/脂肪 各带 NRV
    expect(find.text('7.94 CNY'), findsOneWidget);
    expect(find.textContaining('NRV'), findsNWidgets(4));
    expect(find.textContaining('1,098 kcal'), findsOneWidget);
  });

  testWidgets('方案来源餐：方案名与条目可点，块尾补碳水与 NRV', (tester) async {
    var planTaps = 0;
    MealPlanItemBrief? tappedItem;
    const meal = MealRecommendation(
      mealType: 'breakfast',
      source: 'plan',
      planId: 2,
      planName: 'Four dishes',
      planKind: 'meal',
      planItems: [
        MealPlanItemBrief(
          itemType: 'recipe',
          name: 'Rice',
          cost: 2.02,
          recipeId: 11,
        ),
        MealPlanItemBrief(
          itemType: 'product',
          name: 'Cucumber',
          cost: 0.4,
          productId: 7,
        ),
      ],
      planCost: 2.42,
      planCalories: 590.2,
      planProteinG: 25.2,
      planCarbsG: 99.7,
      planFatG: 13.8,
    );

    await _pumpCard(
      tester,
      MealCard(
        meal: meal,
        userCurrency: 'CNY',
        onPlanTap: () => planTaps++,
        onPlanItemTap: (item) => tappedItem = item,
      ),
    );

    expect(find.text('Four dishes'), findsOneWidget);
    expect(find.textContaining('NRV'), findsNWidgets(4));
    expect(find.text('2.42 CNY'), findsOneWidget);

    await tester.tap(find.text('Four dishes'));
    expect(planTaps, 1);

    await tester.tap(find.text('Cucumber'));
    expect(tappedItem?.productId, 7);
  });
}

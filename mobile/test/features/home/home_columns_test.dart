import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/features/home/models/meal_recommendation.dart';
import 'package:com_a4ding_livecalc/features/home/providers/home_provider.dart';
import 'package:com_a4ding_livecalc/features/home/repositories/home_repository.dart';
import 'package:com_a4ding_livecalc/features/home/screens/home_screen.dart';
import 'package:com_a4ding_livecalc/features/home/widgets/meal_card.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/providers/calc_context_provider.dart';

/// 三餐各一道菜：展开态应三栏并排（设计稿「今日推荐三栏式」）。
const _recommendation = DailyRecommendation(
  date: '2026-11-23',
  status: 'ready',
  meals: [
    MealRecommendation(
      mealType: 'breakfast',
      dishes: [
        RecommendedDish(
            recipeId: 1,
            name: '番茄炒蛋',
            estimatedCost: 3.42,
            currency: 'CNY',
            calories: 186,
            proteinG: 12,
            carbsG: 8,
            fatG: 11,
            role: 'main'),
      ],
    ),
    MealRecommendation(
      mealType: 'lunch',
      dishes: [
        RecommendedDish(
            recipeId: 2,
            name: '青椒肉丝',
            estimatedCost: 6.15,
            currency: 'CNY',
            calories: 320,
            proteinG: 22,
            carbsG: 10,
            fatG: 20,
            role: 'main'),
      ],
    ),
    MealRecommendation(
      mealType: 'dinner',
      dishes: [
        RecommendedDish(
            recipeId: 3,
            name: '黄焖鸡米饭',
            estimatedCost: 7.41,
            currency: 'CNY',
            calories: 310,
            proteinG: 28,
            carbsG: 30,
            fatG: 12,
            role: 'main'),
      ],
    ),
  ],
  totals: {
    'cost': 16.98,
    'currency': 'CNY',
    'calories': 816,
    'protein_g': 62,
    'carbs_g': 48,
    'fat_g': 43,
  },
);

class _StaticHomeRepository extends HomeRepository {
  @override
  Future<DailyRecommendation> getTodayRecommendation() async => _recommendation;
}

Future<void> _pump(WidgetTester tester, Size size,
    {FakeViewPadding padding = FakeViewPadding.zero}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
  final previous = localeSettingsStore.current;
  addTearDown(() => localeSettingsStore.update(previous));
  localeSettingsStore
      .update(const LocaleSettings(uiLocale: 'zh-CN', formatLocale: 'zh-CN'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeProvider.overrideWith(
          (ref) => HomeNotifier(_StaticHomeRepository()),
        ),
        displayCurrencyProvider.overrideWith((ref) => 'CNY'),
      ],
      child: const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('展开横屏（951×669）：今日推荐三栏并排', (tester) async {
    await _pump(tester, const Size(951, 669));

    final cards = find.byType(MealCard);
    expect(cards, findsNWidgets(3));
    final r0 = tester.getRect(cards.at(0));
    final r1 = tester.getRect(cards.at(1));
    final r2 = tester.getRect(cards.at(2));
    // 同一行（top 相同）、x 递增（三栏并排而非纵向堆叠）
    expect(r1.top, moreOrLessEquals(r0.top, epsilon: 0.5));
    expect(r2.top, moreOrLessEquals(r0.top, epsilon: 0.5));
    expect(r1.left, greaterThan(r0.right));
    expect(r2.left, greaterThan(r1.right));
    // 卡宽约为可用宽三分之一（951 - 32 padding - 24 gaps）/3 ≈ 298
    expect(r0.width, greaterThan(260));
  });

  testWidgets('展开竖屏（669×951）：两栏', (tester) async {
    await _pump(tester, const Size(669, 951));
    final cards = find.byType(MealCard);
    expect(cards, findsNWidgets(3));
    final r0 = tester.getRect(cards.at(0));
    final r1 = tester.getRect(cards.at(1));
    expect(r1.top, moreOrLessEquals(r0.top, epsilon: 0.5));
  });

  testWidgets('手机竖屏（390×844）：单列', (tester) async {
    await _pump(tester, const Size(390, 844));
    final cards = find.byType(MealCard);
    final r0 = tester.getRect(cards.at(0));
    final r1 = tester.getRect(cards.at(1));
    expect(r1.top, greaterThan(r0.bottom - 1));
  });
}

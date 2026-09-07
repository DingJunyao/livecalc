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

const _recommendation = DailyRecommendation(
  date: '2026-09-07',
  status: 'ready',
  meals: [
    MealRecommendation(
      mealType: 'breakfast',
      recipeId: 1,
      recipeName: 'Stored breakfast',
      estimatedCost: 12.5,
      calories: 420,
      proteinG: 18.0,
      carbsG: 30.0,
      fatG: 9.0,
    ),
    MealRecommendation(
      mealType: 'lunch',
      recipeId: 2,
      recipeName: null,
      estimatedCost: 20,
      calories: 650,
      proteinG: 28.0,
      carbsG: 55.0,
      fatG: 12.0,
    ),
  ],
);

class _StaticHomeRepository extends HomeRepository {
  @override
  Future<DailyRecommendation> getTodayRecommendation() async => _recommendation;
}

class _FailingHomeRepository extends HomeRepository {
  @override
  Future<DailyRecommendation> getTodayRecommendation() async =>
      throw Exception('forced');
}

Future<void> _pumpLocalized(
  WidgetTester tester,
  Locale locale, {
  Widget? child,
  bool failLoad = false,
}) async {
  tester.view.physicalSize = const Size(430, 1200);
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
        homeProvider.overrideWith(
          (ref) => HomeNotifier(
            failLoad ? _FailingHomeRepository() : _StaticHomeRepository(),
          ),
        ),
        displayCurrencyProvider.overrideWith((ref) => 'USD'),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? const HomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('English home summary and meal nutrition localize', (
    tester,
  ) async {
    await _pumpLocalized(tester, const Locale('en', 'US'));
    expect(find.text('LiveCalc'), findsOneWidget);
    expect(find.text("Today's recommendations"), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Stored breakfast'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('12.5 USD'), findsWidgets);
    expect(find.textContaining('Protein'), findsWidgets);
    expect(find.textContaining('Carbs'), findsWidgets);
    expect(find.textContaining('Fat'), findsWidgets);
    expect(find.text('推荐'), findsNothing);
  });

  testWidgets('Arabic home summary and meal nutrition localize', (
    tester,
  ) async {
    await _pumpLocalized(tester, const Locale('ar'));
    expect(find.text('لايف كالك'), findsOneWidget);
    expect(find.text('توصيات اليوم'), findsOneWidget);
    expect(find.text('الفطور'), findsOneWidget);
    expect(find.text('الغداء'), findsOneWidget);
    expect(find.text('Stored breakfast'), findsOneWidget);
    expect(find.text('غير محدد'), findsWidgets);
    expect(find.textContaining('البروتين'), findsWidgets);
    expect(find.textContaining('الكربوهيدرات'), findsWidgets);
    expect(find.textContaining('الدهون'), findsWidgets);
    expect(find.text('推荐'), findsNothing);
  });

  testWidgets('home load errors localize instead of leaking Han copy', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      failLoad: true,
    );
    expect(find.text('Could not load recommendations. Try again later.'),
        findsOneWidget);
    expect(find.textContaining('网络'), findsNothing);
  });

  testWidgets('meal card fallback copy and nutrition units localize', (
    tester,
  ) async {
    await _pumpLocalized(
      tester,
      const Locale('en', 'US'),
      child: const Scaffold(
        body: SingleChildScrollView(
          child: MealCard(
            meal: MealRecommendation(
              mealType: 'dinner',
              estimatedCost: 8,
              calories: 300,
              proteinG: 12,
              carbsG: 20,
              fatG: 5,
            ),
            userCurrency: 'USD',
          ),
        ),
      ),
    );
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.textContaining('Protein'), findsOneWidget);
    expect(find.text('8 USD'), findsOneWidget);
  });
}

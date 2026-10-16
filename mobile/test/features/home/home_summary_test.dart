import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/features/home/models/meal_recommendation.dart';
import 'package:com_a4ding_livecalc/features/home/providers/home_provider.dart';
import 'package:com_a4ding_livecalc/features/home/repositories/home_repository.dart';
import 'package:com_a4ding_livecalc/features/home/screens/home_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/providers/calc_context_provider.dart';

/// 与云端 GET /meals/recommendations 同形（含 totals —— 「今日预估」靠它）
const _recommendation = DailyRecommendation(
  date: '2026-10-17',
  status: 'ready',
  meals: [
    MealRecommendation(
      mealType: 'dinner',
      dishes: [
        RecommendedDish(
          recipeId: 1,
          name: 'Braised pork',
          estimatedCost: 3.14,
          currency: 'CNY',
          calories: 590.2,
          proteinG: 49.65,
          carbsG: 10.24,
          fatG: 38.06,
          role: 'staple',
        ),
      ],
    ),
  ],
  totals: {
    'cost': 22.84,
    'currency': 'CNY',
    'calories': 1310.5,
    'protein_g': 91.06,
    'carbs_g': 58.61,
    'fat_g': 79.28,
  },
);

class _StaticHomeRepository extends HomeRepository {
  @override
  Future<DailyRecommendation> getTodayRecommendation() async => _recommendation;
}

void main() {
  testWidgets('今日预估：成本 + 四项营养素（含 NRV%）', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final previous = localeSettingsStore.current;
    addTearDown(() => localeSettingsStore.update(previous));
    localeSettingsStore.update(
      const LocaleSettings(uiLocale: 'en-US', formatLocale: 'en-US'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProvider.overrideWith(
            (ref) => HomeNotifier(_StaticHomeRepository()),
          ),
          displayCurrencyProvider.overrideWith((ref) => 'CNY'),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Estimated today'), findsOneWidget);
    expect(find.textContaining('22.84 CNY'), findsOneWidget);
    expect(find.textContaining('NRV'), findsWidgets);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/cost_trend_chart.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/models/computed_price_point.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('无直接记录但有折算序列：仍绘制图表（不显示暂无数据）', (tester) async {
    final computed = [
      ComputedPricePoint.fromJson({
        'date': '2026-10-20',
        'source': 'contains_aggregation',
        'chain': '猪肉 ← 子食材(五花肉)',
        'min_ppg': '0.012',
        'max_ppg': '0.030',
        'avg_ppg': '0.020',
      }),
      ComputedPricePoint.fromJson({
        'date': '2026-10-21',
        'source': 'contains_aggregation',
        'min_ppg': '0.012',
        'max_ppg': '0.030',
        'avg_ppg': '0.021',
      }),
    ];

    await tester.pumpWidget(_wrap(CostTrendChart(
      points: const [],
      computedPoints: computed,
      includeComputed: true,
      showComputedSwitch: true,
      userCurrency: 'CNY',
    )));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CostTrendChart)),
    );
    expect(find.text(l10n.recipeNoCostTrend), findsNothing);
    // 开关与文字标签都在
    expect(find.byKey(const Key('include_computed_switch')), findsOneWidget);
    expect(find.text(l10n.includeComputed), findsOneWidget);
  });

  testWidgets('既无直接价也无折算：仍显示暂无数据', (tester) async {
    await tester.pumpWidget(_wrap(const CostTrendChart(
      points: [],
      includeComputed: true,
      showComputedSwitch: true,
    )));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CostTrendChart)),
    );
    expect(find.text(l10n.recipeNoCostTrend), findsOneWidget);
  });
}

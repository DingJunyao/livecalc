import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/planner/widgets/cost_trend_chart.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

void main() {
  test('trendRange 把区间带纳入 y 轴范围并留出上下余量', () {
    final range = trendRange([3.0, 4.0], [2.0, 3.0], [5.0, 6.0]);
    expect(range.lower, lessThan(2.0));
    expect(range.upper, greaterThan(6.0));

    // 只有平均值（无区间）时也不能贴边
    final flat = trendRange([4.0, 4.0], const [], const []);
    expect(flat.lower, lessThan(4.0));
    expect(flat.upper, greaterThan(4.0));
  });

  testWidgets('成本走势：展示平均与区间，区间切换回调', (tester) async {
    var pickedDays = 0;
    final points = [
      for (var i = 0; i < 30; i++)
        {
          'date': '2026-10-${(i + 1).toString().padLeft(2, '0')}',
          'total_cost': 22.0 + i * 0.1,
          'min_cost': 21.0 + i * 0.1,
          'max_cost': 23.5 + i * 0.1,
        },
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CostTrendChart(
              points: points,
              userCurrency: 'CNY',
              days: 90,
              onDaysChanged: (days) => pickedDays = days,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cost trend'), findsOneWidget);
    expect(find.textContaining('Average'), findsOneWidget);
    expect(find.textContaining('Low'), findsOneWidget);
    expect(find.textContaining('High'), findsOneWidget);
    expect(find.textContaining('24.9'), findsOneWidget);
    expect(find.textContaining('23.9'), findsOneWidget);
    expect(find.textContaining('26.4'), findsOneWidget);
    expect(find.textContaining('CNY'), findsWidgets);

    await tester.tap(find.text('30d'));
    expect(pickedDays, 30);
  });
}

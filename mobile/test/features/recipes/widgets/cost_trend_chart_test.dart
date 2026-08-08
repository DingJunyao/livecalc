import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/cost_trend_chart.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';

CostHistoryPoint _point(String date, double avg) => CostHistoryPoint(
    date: date, minCost: avg - 1, maxCost: avg + 1, avgCost: avg);

void main() {
  group('CostTrendChart 范围下拉与点击提示', () {
    testWidgets('范围切换改下拉：选「周」回调 7 天且按钮显示「周」', (tester) async {
      int? got;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CostTrendChart(
            points: [_point('07-01', 5), _point('07-02', 6), _point('07-03', 7)],
            onRangeChange: (days) => got = days,
          ),
        ),
      ));
      // 默认选中「月」
      expect(find.text('月'), findsOneWidget);
      await tester.tap(find.byKey(const Key('range_dropdown')));
      await tester.pumpAndSettle();
      // 菜单项出现（含按钮上当前值共 4 个文本，用 .last 点菜单里的「周」）
      await tester.tap(find.text('周').last);
      await tester.pumpAndSettle();
      expect(got, 7);
      expect(find.text('周'), findsOneWidget);
      expect(find.text('月'), findsNothing);
    });

    testWidgets('范围下拉含「年」：选「年」回调 365 天', (tester) async {
      int? got;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CostTrendChart(
            points: [_point('07-01', 5)],
            onRangeChange: (days) => got = days,
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('range_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('年').last);
      await tester.pumpAndSettle();
      expect(got, 365);
      expect(find.text('年'), findsOneWidget);
    });

    testWidgets('切换范围加载中：有旧数据时顶部显示进度条', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CostTrendChart(
            points: [_point('07-01', 5), _point('07-02', 6)],
            loading: true,
          ),
        ),
      ));
      // loading 且已有数据：图表保留旧数据 + 顶部细进度条（用户能感知在刷新）
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final chartPaint = find.descendant(
        of: find.byType(CostTrendChart),
        matching: find.byType(CustomPaint),
      );
      expect(chartPaint, findsWidgets);
    });

    testWidgets('点击图表显示 tooltip（均价+区间），无需拖动', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CostTrendChart(
            points: [_point('07-01', 5), _point('07-02', 6), _point('07-03', 7)],
          ),
        ),
      ));
      // 点图表中心（_Chart 的 GestureDetector 区域）。
      // 注意不能用 find.byType(CustomPaint).first：Material 内部 ink 层也有
      // CustomPaint 且占满全屏，first 会命中它、中心点落在图表区之外点不到。
      // 必须限定在 CostTrendChart 内部找图表的 CustomPaint。
      final chartPaint = find.descendant(
        of: find.byType(CostTrendChart),
        matching: find.byType(CustomPaint),
      );
      await tester.tapAt(tester.getCenter(chartPaint));
      await tester.pump();
      expect(find.textContaining('均价 ¥'), findsOneWidget);
      expect(find.textContaining('区间 ¥'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/layout/vertical_bar_edge.dart';
import 'package:com_a4ding_livecalc/shared/widgets/detail_two_column.dart';

void main() {
  group('DuoLayoutInfo.foldX（折叠区定位）', () {
    test('优先使用 division 保留区中心', () {
      const info = DuoLayoutInfo(
        width: 951,
        height: 669,
        divisions: [Rect.fromLTWH(560, 0, 20, 669)],
      );
      expect(info.foldX, 570);
    });

    test('无 division 时用细高遮挡带兜底', () {
      const info = DuoLayoutInfo(
        width: 951,
        height: 669,
        occlusions: [
          Rect.fromLTWH(0, 0, 84, 200), // 状态列（宽）
          Rect.fromLTWH(470, 0, 12, 669), // 折痕带（细高）
        ],
      );
      expect(info.foldX, 476);
    });

    test('完全展开（无折叠信息）返回 null', () {
      const info = DuoLayoutInfo(
        width: 951,
        height: 669,
        occlusions: [Rect.fromLTWH(0, 0, 84, 174)],
      );
      expect(info.foldX, isNull);
    });
  });

  group('DetailTwoColumn 半折不跨铰链', () {
    Future<void> pump(WidgetTester tester,
        {double? foldX, required double width}) async {
      tester.view.physicalSize = Size(width, 669);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        DuoLayoutScope(
          layout: DuoLayoutInfo(
            width: width,
            height: 669,
            divisions: foldX == null
                ? const []
                : [Rect.fromLTWH(foldX - 10, 0, 20, 669)],
          ),
          railWidth: 0,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DetailTwoColumn(
                  left: [const SizedBox(height: 80, child: Text('左块'))],
                  right: [const SizedBox(height: 80, child: Text('右块'))],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('有折叠信息时也按完全展开处理：等宽双栏', (tester) async {
      await pump(tester, foldX: 560, width: 951);
      await tester.pump();
      final left = tester.getRect(find.text('左块'));
      final right = tester.getRect(find.text('右块'));
      expect((left.width - right.width).abs(), lessThan(2), reason: '两栏应等宽');
    });

    testWidgets('完全展开：对半分栏（左半 / 右半）', (tester) async {
      await pump(tester, width: 951);
      await tester.pump();
      final left = tester.getRect(find.text('左块'));
      final right = tester.getRect(find.text('右块'));
      expect(left.right, lessThan(951 / 2));
      expect(right.left, greaterThan(951 / 2));
    });
  });

  group('DetailTwoColumn 默认断点 820：折叠横屏 / 展开竖屏不分栏', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 951);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DetailTwoColumn(
                left: [const SizedBox(height: 80, child: Text('左块'))],
                right: [const SizedBox(height: 80, child: Text('右块'))],
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('展开竖屏内容宽 637：单列（上下堆叠）', (tester) async {
      await pumpAt(tester, 669);
      final left = tester.getRect(find.text('左块'));
      final right = tester.getRect(find.text('右块'));
      expect(right.top, greaterThan(left.bottom));
      expect(right.left, moreOrLessEquals(left.left, epsilon: 0.5));
    });

    testWidgets('折叠横屏内容宽 646：单列', (tester) async {
      await pumpAt(tester, 678);
      final left = tester.getRect(find.text('左块'));
      final right = tester.getRect(find.text('右块'));
      expect(right.top, greaterThan(left.bottom));
    });

    testWidgets('展开横屏内容宽 867：双列并排', (tester) async {
      await pumpAt(tester, 899);
      final left = tester.getRect(find.text('左块'));
      final right = tester.getRect(find.text('右块'));
      expect(right.left, greaterThan(left.right));
      expect(left.center.dy, moreOrLessEquals(right.center.dy, epsilon: 1));
    });
  });

  group('DetailTwoColumn 低断点（菜谱分析页 600）', () {
    testWidgets('展开竖屏内容宽 637：两栏并排', (tester) async {
      tester.view.physicalSize = const Size(669, 951);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DetailTwoColumn(
                breakpoint: 600,
                left: [const SizedBox(height: 80, child: Text('左块'))],
                right: [const SizedBox(height: 80, child: Text('右块'))],
              ),
            ),
          ),
        ),
      ));
      final left = tester.getRect(find.text('左块'));
      final right = tester.getRect(find.text('右块'));
      expect(left.center.dy, moreOrLessEquals(right.center.dy, epsilon: 1));
      expect(right.left, greaterThan(left.right));
    });
  });
}

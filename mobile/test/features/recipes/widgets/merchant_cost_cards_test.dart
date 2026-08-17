import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';
import 'package:com_a4ding_livecalc/features/recipes/widgets/merchant_cost_cards.dart';

void main() {
  group('MerchantCostCards', () {
    testWidgets('渲染商家卡片：名称/总价/覆盖数/需外购', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MerchantCostCards(
            merchants: [
              MerchantCostItem(
                merchantId: 1,
                merchantName: '盒马',
                coveredCost: 8.5,
                externalCost: 3.2,
                totalCost: 11.7,
                coveredCount: 4,
                totalIngredients: 6,
                missingIngredients: ['盐'],
                isRecommended: true,
              ),
            ],
            loading: false,
          ),
        ),
      ));
      expect(find.text('盒马'), findsOneWidget);
      expect(find.text('¥11.70'), findsOneWidget);
      expect(find.textContaining('覆盖 4/6 种食材'), findsOneWidget);
      expect(find.textContaining('需外购'), findsOneWidget);
      expect(find.text('最实惠 ✓'), findsOneWidget);
    });

    testWidgets('fallback 链点击信息图标弹出弹窗', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MerchantCostCards(
            merchants: [
              MerchantCostItem(
                merchantId: 1,
                merchantName: '盒马',
                coveredCost: 8.5,
                externalCost: 3.2,
                totalCost: 11.7,
                coveredCount: 4,
                totalIngredients: 6,
                missingIngredients: ['盐'],
                fallbackChains: ['盐 → 海盐'],
              ),
            ],
            loading: false,
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();
      expect(find.text('根据以下食材计算价格：'), findsOneWidget);
      expect(find.text('盐 → 海盐'), findsOneWidget);
      // 关闭弹窗
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(find.text('根据以下食材计算价格：'), findsNothing);
    });

    testWidgets('loading 显示进度条', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MerchantCostCards(merchants: [], loading: true),
        ),
      ));
      // 不定动画：只用 pump，不用 pumpAndSettle
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('多商家横向滚动全部渲染', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MerchantCostCards(
            merchants: [
              MerchantCostItem(
                merchantId: 1,
                merchantName: '盒马',
                coveredCost: 1,
                externalCost: 0,
                totalCost: 1,
                coveredCount: 1,
                totalIngredients: 2,
              ),
              MerchantCostItem(
                merchantId: 2,
                merchantName: '永辉',
                coveredCost: 2,
                externalCost: 0,
                totalCost: 2,
                coveredCount: 2,
                totalIngredients: 2,
              ),
              MerchantCostItem(
                merchantId: 3,
                merchantName: '山姆',
                coveredCost: 3,
                externalCost: 0,
                totalCost: 3,
                coveredCount: 2,
                totalIngredients: 2,
              ),
            ],
            loading: false,
          ),
        ),
      ));
      expect(find.text('盒马'), findsOneWidget);
      expect(find.text('永辉'), findsOneWidget);
      expect(find.text('山姆'), findsOneWidget);
    });

    testWidgets('鼠标滚轮可水平滚动商家卡片', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MerchantCostCards(
            merchants: [
              MerchantCostItem(
                  merchantId: 1,
                  merchantName: '商家1',
                  coveredCost: 1,
                  externalCost: 0,
                  totalCost: 1,
                  coveredCount: 1,
                  totalIngredients: 2),
              MerchantCostItem(
                  merchantId: 2,
                  merchantName: '商家2',
                  coveredCost: 2,
                  externalCost: 0,
                  totalCost: 2,
                  coveredCount: 1,
                  totalIngredients: 2),
              MerchantCostItem(
                  merchantId: 3,
                  merchantName: '商家3',
                  coveredCost: 3,
                  externalCost: 0,
                  totalCost: 3,
                  coveredCount: 1,
                  totalIngredients: 2),
              MerchantCostItem(
                  merchantId: 4,
                  merchantName: '商家4',
                  coveredCost: 4,
                  externalCost: 0,
                  totalCost: 4,
                  coveredCount: 1,
                  totalIngredients: 2),
              MerchantCostItem(
                  merchantId: 5,
                  merchantName: '商家5',
                  coveredCost: 5,
                  externalCost: 0,
                  totalCost: 5,
                  coveredCount: 1,
                  totalIngredients: 2),
            ],
            loading: false,
          ),
        ),
      ));
      // 5 卡 × 220px + 分隔 > 800 测试视口，横向必然溢出
      final scrollableFinder = find.descendant(
        of: find.byType(MerchantCostCards),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollableFinder).position;
      expect(position.pixels, 0);
      // 桌面鼠标滚轮（dy）应映射为水平滚动（桌面端用户无触摸拖动直觉）。
      // 注意 hover 必须在横向列表区域内：Scaffold 会把组件拉满全屏，
      // 组件（Column）中心落在列表下方空白处，事件 hit 不到 Listener。
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
          pointer.hover(tester.getCenter(find.byType(ListView))));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pump();
      expect(position.pixels, greaterThan(0));
    });

    testWidgets('暗色模式推荐卡用暗色表面色', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: MerchantCostCards(
            merchants: [
              MerchantCostItem(
                merchantId: 1,
                merchantName: '盒马',
                coveredCost: 8.5,
                externalCost: 3.2,
                totalCost: 11.7,
                coveredCount: 4,
                totalIngredients: 6,
                missingIngredients: ['盐'],
                isRecommended: true,
              ),
            ],
            loading: false,
          ),
        ),
      ));
      final card = tester.widget<Container>(
        find
            .ancestor(of: find.text('盒马'), matching: find.byType(Container))
            .first,
      );
      final color = (card.decoration! as BoxDecoration).color;
      expect(color, ThemeData(brightness: Brightness.dark).colorScheme.surface);
      expect(color, isNot(const Color(0xFFFFF8E1)));
    });

    testWidgets('空数据显示空态', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MerchantCostCards(merchants: [], loading: false)),
      ));
      expect(find.text('暂无商家价格数据'), findsOneWidget);
    });
  });
}

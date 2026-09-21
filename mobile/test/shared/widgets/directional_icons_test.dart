import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/widgets/directional_icons.dart';

void main() {
  testWidgets('方向性图标保持正向，由 Flutter 依 Directionality 镜像',
      (tester) async {
    late IconData backArrow;
    late IconData forwardArrow;
    late IconData backChevron;
    late IconData forwardChevron;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            backArrow = DirectionalIcons.backArrow(context);
            forwardArrow = DirectionalIcons.forwardArrow(context);
            backChevron = DirectionalIcons.backChevron(context);
            forwardChevron = DirectionalIcons.forwardChevron(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // RTL 下必须返回“正向”图标：Flutter 会因 matchTextDirection 镜像一次，
    // 若这里再按 RTL 翻转一次，阿拉伯语下返回/前进箭头会指向语言反方向
    // （菜单项的 › 会显示成 ‹）。
    expect(backArrow, Icons.arrow_back);
    expect(forwardArrow, Icons.arrow_forward);
    expect(backChevron, Icons.chevron_left);
    expect(forwardChevron, Icons.chevron_right);

    // 依赖 Flutter 自动镜像的前提：这些图标本身声明了 matchTextDirection。
    expect(backArrow.matchTextDirection, isTrue);
    expect(forwardArrow.matchTextDirection, isTrue);
    expect(backChevron.matchTextDirection, isTrue);
    expect(forwardChevron.matchTextDirection, isTrue);
  });

  testWidgets('RTL 下 Flutter 镜像绘制前进箭头（菜单 › 变 ‹）', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Icon(Icons.chevron_right),
      ),
    );

    final mirrored = tester
        .widgetList<Transform>(find.byType(Transform))
        .any((transform) => transform.transform.storage[0] < 0);
    expect(mirrored, isTrue,
        reason: 'matchTextDirection 图标在 RTL 下应由 Flutter 镜像绘制');
  });

  testWidgets('流程文本箭头不是图标，需按语言方向手动反向', (tester) async {
    late String rtlArrow;
    late String ltrArrow;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            rtlArrow = DirectionalIcons.flowArrow(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            ltrArrow = DirectionalIcons.flowArrow(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(ltrArrow, '→');
    expect(rtlArrow, '←');
  });
}

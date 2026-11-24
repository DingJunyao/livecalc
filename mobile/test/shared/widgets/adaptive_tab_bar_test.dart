import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/widgets/adaptive_tab_bar.dart';

const _tabs = [
  Tab(text: '概览'),
  Tab(text: '原料·商品'),
  Tab(text: '菜谱·试算'),
  Tab(text: '热力图'),
];

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DefaultTabController(
        length: _tabs.length,
        child: Scaffold(
          appBar: AppBar(bottom: const AdaptiveTabBar(tabs: _tabs)),
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('宽屏：标签等分整行，右侧不留空白', (tester) async {
    await _pump(tester, const Size(900, 800));

    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
    // 四个标签等分 900：中心点依次落在每格正中（112.5 / 337.5 / 562.5 / 787.5）
    const cell = 900 / 4;
    for (var i = 0; i < _tabs.length; i++) {
      expect(
        tester.getCenter(find.text(_tabs[i].text!)).dx,
        moreOrLessEquals(cell * (i + 0.5), epsilon: 0.5),
        reason: '「${_tabs[i].text}」应在第 $i 格正中',
      );
    }
    // 标题栏高度按 TabBar 的真实高度算（46 + 2）
    expect(tester.getSize(find.byType(AppBar)).height, 56 + 48);
  });

  testWidgets('手机宽度：标签按内容排、可横向滚动（长文案不挤）', (tester) async {
    await _pump(tester, const Size(400, 800));

    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
  });
}

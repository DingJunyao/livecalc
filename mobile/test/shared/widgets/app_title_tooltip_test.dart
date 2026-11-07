import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/shared/widgets/app_title_tooltip.dart';

void main() {
  // 超出 360dp 标题预算的名字：省略号截断，长按弹完整气泡。
  const longName = '一个特别特别特别特别长的商品名字会被标题栏截断';

  testWidgets('长按标题弹出完整名称气泡', (tester) async {
    // 注意：Flutter 3.47 起 AppBar 构造函数不再是 const，
    // 因此 Scaffold/子树都不能整体 const。
    final appBar = AppBar(title: const AppTitleTooltip(message: longName));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: appBar, body: const SizedBox.expand()),
    ));

    // 标题本体只有一份（视觉上被截断，但 Text.data 是全名）。
    expect(find.text(longName), findsOneWidget);

    await tester.longPress(find.text(longName));
    await tester.pumpAndSettle();

    // 标题 + Tooltip 气泡各一份 → 气泡里是完整名称。
    expect(find.text(longName), findsNWidgets(2));
  });

  testWidgets('默认渲染单行省略的标题文本；带 child 时渲染 child', (tester) async {
    final appBar = AppBar(
      title: const AppTitleTooltip(
        message: 'name',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('name', maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(width: 8),
          Text('标签'),
        ]),
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: appBar, body: const SizedBox.expand()),
    ));

    expect(find.text('标签'), findsOneWidget);
    expect(find.text('name'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 防回归：app.dart 配置了中文 localizations，Material 内置组件
/// （返回按钮 tooltip、文本框长按菜单等）必须显示中文而非英文默认值。
void main() {
  testWidgets('中文配置下 BackButton tooltip 为「返回」', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          appBar: AppBar(title: const Text('测试')),
          body: const BackButton(),
        ),
      ),
    );
    expect(find.byTooltip('返回'), findsOneWidget);
    // 英文默认文案不应存在
    expect(find.byTooltip('Back'), findsNothing);
  });
}

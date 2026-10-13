import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/save_button_position_provider.dart';
import 'package:com_a4ding_livecalc/shared/widgets/save_action_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认位置是右上角', () {
    SharedPreferences.setMockInitialValues({});
    expect(SaveButtonPositionNotifier().state, SaveButtonPosition.topRight);
  });

  test('load 读取已保存的位置', () async {
    SharedPreferences.setMockInitialValues(
        {'mobile.save_button_position': 'bottom'});
    final n = SaveButtonPositionNotifier();
    await n.load();
    expect(n.state, SaveButtonPosition.bottom);
  });

  test('load 忽略非法值，保持右上角', () async {
    SharedPreferences.setMockInitialValues(
        {'mobile.save_button_position': 'left'});
    final n = SaveButtonPositionNotifier();
    await n.load();
    expect(n.state, SaveButtonPosition.topRight);
  });

  test('setPosition 写入本地并更新 state', () async {
    SharedPreferences.setMockInitialValues({});
    final n = SaveButtonPositionNotifier();
    await n.setPosition(SaveButtonPosition.bottom);
    expect(n.state, SaveButtonPosition.bottom);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mobile.save_button_position'), 'bottom');
  });

  testWidgets('位置=右上角时只有 AppBar 按钮，位置=下方时只有底部按钮条',
      (tester) async {
    var taps = 0;
    Future<void> pump(SaveButtonPosition position) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('表单'),
              actions: saveAppBarActions(
                position: position,
                onSave: () => taps++,
                label: '保存',
              ),
            ),
            bottomNavigationBar: saveBottomBar(
              context: context,
              position: position,
              onSave: () => taps++,
              label: '保存',
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ));
    }

    await pump(SaveButtonPosition.topRight);
    expect(find.text('保存'), findsOneWidget); // 仅 AppBar
    await tester.tap(find.text('保存'));
    expect(taps, 1);

    await pump(SaveButtonPosition.bottom);
    final bottomButton = find.widgetWithText(FilledButton, '保存');
    expect(find.text('保存'), findsOneWidget); // 仅底部
    expect(bottomButton, findsOneWidget);
    await tester.tap(bottomButton);
    expect(taps, 2);
  });
}

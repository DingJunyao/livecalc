import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/widgets/form_exit_guard.dart';

/// FormExitGuard 行为：有未保存修改 → 返回先弹对话框；无修改/禁用 → 直接返回。
void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required bool Function() isDirty,
    bool enabled = true,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FormExitGuard(
                enabled: enabled,
                isDirty: isDirty,
                child: Scaffold(
                  appBar: AppBar(title: const Text('FORM')),
                  body: const Center(child: Text('FORM_BODY')),
                ),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('干净表单：返回不弹对话框，直接退出', (tester) async {
    await pumpHost(tester, isDirty: () => false);

    await tester.tap(find.byTooltip('返回')); // AppBar 返回键 → maybePop
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('脏表单：返回先弹确认；取消留在页面，放弃后退出', (tester) async {
    var dirty = true;
    await pumpHost(tester, isDirty: () => dirty);

    // 返回 → 弹对话框
    await tester.tap(find.byTooltip('返回')); // AppBar 返回键 → maybePop
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('放弃未保存的修改？'), findsOneWidget);

    // 取消 → 留在表单
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('FORM_BODY'), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    // 再返回 → 放弃并退出
    await tester.tap(find.byTooltip('返回')); // AppBar 返回键 → maybePop
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃并退出'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('enabled=false：脏表单返回也直接退出（如保存成功后）', (tester) async {
    await pumpHost(tester, isDirty: () => true, enabled: false);

    await tester.tap(find.byTooltip('返回')); // AppBar 返回键 → maybePop
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('对话框打开期间按系统返回只关对话框、不会叠两层', (tester) async {
    await pumpHost(tester, isDirty: () => true);

    await tester.tap(find.byTooltip('返回')); // AppBar 返回键 → maybePop
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // 对话框未关闭时按系统返回：最顶层是对话框路由，返回只关掉它
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // 表单仍在
    expect(find.text('FORM_BODY'), findsOneWidget);
  });
}

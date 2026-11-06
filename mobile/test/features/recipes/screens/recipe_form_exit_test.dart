import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';
import 'package:com_a4ding_livecalc/features/recipes/screens/recipe_form_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class MockRepo extends Mock implements RecipeRepository {}

/// 菜谱表单（新增态）退出二次确认：写过内容返回时弹对话框，未写直接退出。
/// 编辑态走分区保存（有自己的 PopScope 语义），不在本文件覆盖。
void main() {
  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
    when(() => repo.getUnitOptions()).thenAnswer((_) async => const []);
  });

  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeFormScreen(repository: repo),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('没写过内容：返回不弹对话框，直接退出', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.byTooltip('返回')); // AppBar 返回键 → maybePop
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('写过名称：返回弹确认；取消留在页面，放弃后退出', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, '菜谱名称'),
      '番茄炒蛋',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('返回')); // AppBar 返回键 → maybePop
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('放弃未保存的修改？'), findsOneWidget);

    // 取消 → 留在表单
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('番茄炒蛋'), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    // 再返回 → 放弃并退出
    await tester.tap(find.byTooltip('返回')); // AppBar 返回键 → maybePop
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃并退出'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });
}

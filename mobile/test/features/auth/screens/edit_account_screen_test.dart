import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/auth/models/account_response.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/auth/screens/edit_account_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late AuthNotifier notifier;

  setUp(() {
    mockRepo = MockAuthRepository();
    notifier = AuthNotifier(mockRepo);
    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
  });

  /// 通过按钮 push 编辑页，保证保存后 pop 有去处。
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        EditAccountScreen(repository: mockRepo),
                  ),
                ),
                child: const Text('进入编辑'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('进入编辑'));
    await tester.pumpAndSettle();
  }

  testWidgets('表单预填当前用户信息，显示昵称与头像区', (tester) async {
    await pumpScreen(tester);

    expect(find.text('编辑个人信息'), findsOneWidget);
    expect(find.text('点击更换头像'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'alice'),
      findsOneWidget,
    );
    expect(find.text('a@test.com'), findsOneWidget);
  });

  testWidgets('改昵称保存，只传变化字段', (tester) async {
    when(() => mockRepo.updateAccount(any())).thenAnswer((_) async =>
        const UserAccountResponse(
          user: User(
              id: 1, username: 'alice', email: 'a@test.com', nickname: '小艾'),
        ));

    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, '昵称'), '小艾');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final captured =
        verify(() => mockRepo.updateAccount(captureAny())).captured;
    final body = captured.first as Map<String, dynamic>;
    expect(body, {'nickname': '小艾'});
    // 未变化的用户名/邮箱/手机不传
    expect(body.containsKey('username'), false);
    expect(body.containsKey('email'), false);
    expect(notifier.state.user?.nickname, '小艾');
  });

  testWidgets('校验失败不发请求（用户名过短）', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, '用户名 *'), 'ab');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('用户名长度需为 3-50 个字符'), findsOneWidget);
    verifyNever(() => mockRepo.updateAccount(any()));
  });

  testWidgets('无任何修改时提示且不发请求', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('没有需要保存的修改'), findsOneWidget);
    verifyNever(() => mockRepo.updateAccount(any()));
  });

  testWidgets('400 时显示后端 detail', (tester) async {
    when(() => mockRepo.updateAccount(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/auth/me/account'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me/account'),
          statusCode: 400,
          data: {'detail': '用户名已被占用'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, '用户名 *'), 'bob2');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('用户名已被占用'), findsOneWidget);
  });
}

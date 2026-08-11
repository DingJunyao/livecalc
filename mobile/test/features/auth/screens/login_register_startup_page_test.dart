import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/features/auth/models/login_request.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/auth/screens/login_screen.dart';
import 'package:com_a4ding_livecalc/features/auth/screens/register_screen.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/startup_page_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

GoRouter _router(String initial) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/prices',
          builder: (_, __) => const Scaffold(body: Text('价格记录页'))),
      GoRoute(
          path: '/home', builder: (_, __) => const Scaffold(body: Text('推荐页'))),
    ],
  );
}

void main() {
  late MockAuthRepository repo;

  setUpAll(() {
    registerFallbackValue(const LoginRequest(username: 'alice', passwordHash: 'hash'));
  });

  setUp(() {
    // flutter_secure_storage 的 method channel 在测试环境无宿主实现，
    // write/read 的 Future 永不完成（不是抛错），会让 _persistSession 挂死。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    repo = MockAuthRepository();
    when(() => repo.getCurrentUser()).thenAnswer(
      (_) async => const User(id: 1, username: 'alice', email: 'a@test.com'),
    );
  });

  Future<void> pumpAuthScreen(
    WidgetTester tester, {
    required String initial,
    required AuthNotifier notifier,
  }) async {
    final startup = StartupPageNotifier();
    await startup.load(); // 读 mock prefs（startup_page: prices）
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => notifier),
        startupPageProvider.overrideWith((ref) => startup),
      ],
      child: MaterialApp.router(routerConfig: _router(initial)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('配置计价为起始页时，登录成功跳转计价页', (tester) async {
    SharedPreferences.setMockInitialValues({'startup_page': 'prices'});
    when(() => repo.login(any())).thenAnswer(
      (_) async => const LoginResponse(accessToken: 'a', refreshToken: 'r'),
    );
    final notifier =
        AuthNotifier(repo, checkConnection: () async => true);
    await pumpAuthScreen(tester, initial: '/login', notifier: notifier);

    await tester.enterText(
        find.widgetWithText(TextFormField, '用户名'), 'alice');
    await tester.enterText(find.widgetWithText(TextFormField, '密码'), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('价格记录页'), findsOneWidget);
  });

  testWidgets('配置计价为起始页时，注册成功跳转计价页', (tester) async {
    SharedPreferences.setMockInitialValues({'startup_page': 'prices'});
    when(() => repo.register(
        username: any(named: 'username'),
        email: any(named: 'email'),
        passwordHash: any(named: 'passwordHash'),
        phone: any(named: 'phone'),
        inviteCode: any(named: 'inviteCode'))).thenAnswer(
      (_) async => const LoginResponse(accessToken: 'a', refreshToken: 'r'),
    );
    final notifier = AuthNotifier(repo);
    await pumpAuthScreen(tester, initial: '/register', notifier: notifier);

    await tester.enterText(
        find.widgetWithText(TextFormField, '用户名'), 'alice');
    await tester.enterText(find.widgetWithText(TextFormField, '邮箱'), 'a@test.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, '密码'), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '注册'));
    await tester.pumpAndSettle();

    expect(find.text('价格记录页'), findsOneWidget);
  });
}

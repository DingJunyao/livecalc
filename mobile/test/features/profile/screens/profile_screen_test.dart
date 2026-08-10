import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/profile_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late AuthNotifier notifier;

  setUp(() {
    ApiClient.instance.updateBaseUrl('https://example.test');
    notifier = AuthNotifier(MockAuthRepository());
  });

  Future<void> pumpScreen(WidgetTester tester, User user) async {
    notifier.state = AuthState(status: AuthStatus.authenticated, user: user);
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(home: ProfileScreen()),
    ));
  }

  testWidgets('显示昵称（nickname 优先）与邮箱', (tester) async {
    await pumpScreen(
      tester,
      const User(
        id: 1,
        username: 'alice',
        email: 'a@test.com',
        nickname: '小艾',
      ),
    );

    expect(find.text('小艾'), findsOneWidget);
    expect(find.text('a@test.com'), findsOneWidget);
    expect(find.text('alice'), findsNothing);
  });

  testWidgets('无昵称时显示用户名', (tester) async {
    await pumpScreen(
      tester,
      const User(id: 2, username: 'bob', email: 'b@test.com'),
    );

    expect(find.text('bob'), findsOneWidget);
  });

  testWidgets('有头像时 CircleAvatar 使用网络图，卡片可点（chevron）', (tester) async {
    await pumpScreen(
      tester,
      const User(
        id: 1,
        username: 'alice',
        email: 'a@test.com',
        avatar: 'avatars/x.png',
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.foregroundImage, isA<NetworkImage>());
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('无头像时 CircleAvatar 显示首字母', (tester) async {
    await pumpScreen(
      tester,
      const User(id: 3, username: 'carol', email: 'c@test.com'),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.foregroundImage, isNull);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('设置区无预算设置，单位偏好/营养目标可点', (tester) async {
    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/profile/settings/unit-preferences',
          builder: (_, __) => const Scaffold(body: Text('单位偏好页')),
        ),
        GoRoute(
          path: '/profile/settings/nutrition-goals',
          builder: (_, __) => const Scaffold(body: Text('营养目标页')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('预算设置'), findsNothing);
    expect(find.text('单位偏好'), findsOneWidget);
    expect(find.text('营养目标'), findsOneWidget);

    await tester.tap(find.text('单位偏好'));
    await tester.pumpAndSettle();
    expect(find.text('单位偏好页'), findsOneWidget);
  });
}

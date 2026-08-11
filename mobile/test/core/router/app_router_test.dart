import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/core/router/app_router.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/startup_page_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// 模拟 app.dart：在 initState 创建 router 并加载起始页配置，
/// 认证/配置变化时通知 router 重新 evaluate redirect。
class _RouterHost extends ConsumerStatefulWidget {
  const _RouterHost();
  @override
  ConsumerState<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends ConsumerState<_RouterHost> {
  final _notifier = ChangeNotifier();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(ref, _notifier);
    ref.read(startupPageProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, __) => _notifier.notifyListeners());
    ref.listen(startupPageProvider, (_, __) => _notifier.notifyListeners());
    return MaterialApp.router(routerConfig: _router);
  }
}

void main() {
  setUp(() {
    ApiClient.instance.updateBaseUrl('https://example.test');
  });

  /// splash 的 LoadingIndicator 是无限转圈动画，pumpAndSettle 必超时；
  /// 且落地页的网络请求在测试环境永不完成（body 一直转圈），
  /// 但 AppBar 标题不受影响——所以全程用有界 pump 代替 pumpAndSettle。
  Future<void> pumpPastAuth(WidgetTester tester, AuthNotifier notifier) async {
    // 1) 完成 startupPage 配置 load() 的微任务（此时仍停在 splash）
    await tester.pump();
    await tester.pump();

    // 2) 触发认证状态变化 → listener → router 重新 evaluate redirect
    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );

    // 3) 有界 pump 走完路由跳转与页面过渡（splash 移除后目标页 AppBar 可见）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('认证后 redirect 到配置的起始页（计价）', (tester) async {
    SharedPreferences.setMockInitialValues({'startup_page': 'prices'});
    final notifier = AuthNotifier(MockAuthRepository());
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: const _RouterHost(),
    ));
    await pumpPastAuth(tester, notifier);

    // 计价页 AppBar 标题（body 可能因无网络一直转圈，标题不受影响）
    expect(find.text('价格记录'), findsOneWidget);
  });

  testWidgets('未配置时默认落在推荐页', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = AuthNotifier(MockAuthRepository());
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: const _RouterHost(),
    ));
    await pumpPastAuth(tester, notifier);

    // 推荐页（HomeScreen）AppBar 标题「生计」；splash 也有「生计」文案，
    // 再用 shell 导航栏「我的」确认已进入 shell（splash 已移除）。
    expect(find.text('生计'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}

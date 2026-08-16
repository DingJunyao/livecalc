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

  /// 「更多」二级菜单测试组：切窄屏触发 mobile 底栏（默认 800x600 走桌面）。
  Future<void> pumpRouter(
    WidgetTester tester, {
    String startupPage = 'home',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'startup_page': startupPage});
    final notifier = AuthNotifier(MockAuthRepository());
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: const _RouterHost(),
    ));
    await pumpPastAuth(tester, notifier);
  }

  /// 打开底栏「更多」二级菜单，并 pump 至 modal 滑入动画稳定。
  /// 注意：modal 动画进度由 frame 驱动，单次 pump(Duration) 只推进一帧，
  /// 多 pump 几次让 progress 到达 1.0（否则胶囊 hit test 在屏幕外）。
  Future<void> openMoreMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tab-更多')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 选中态判断：_NavItem 选中时唯一 Container 带 BoxDecoration（secondaryContainer 胶囊）。
  /// 注意：耦合 _NavItem 选中态实现（selected 时 Container.decoration = BoxDecoration），
  /// 若改 _NavItem 选中渲染方式（如换成 Border/不同 widget），需同步更新此 helper。
  Finder selectedBoxDecoration(Key key) => find.descendant(
        of: find.byKey(key),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      );

  testWidgets('「更多」菜单为横排胶囊网格（非纵向 ListTile）', (tester) async {
    await pumpRouter(tester);
    await openMoreMenu(tester);

    // 4 个胶囊均存在（复用 _NavItem，key = more-<label>）
    expect(find.byKey(const ValueKey('more-原料')), findsOneWidget);
    expect(find.byKey(const ValueKey('more-商品')), findsOneWidget);
    expect(find.byKey(const ValueKey('more-商家')), findsOneWidget);
    expect(find.byKey(const ValueKey('more-我的')), findsOneWidget);

    // 旧纵向 ListTile 不再存在：菜单内不再用 ListTile 承载这些项
    expect(
      find.ancestor(
        of: find.text('原料'),
        matching: find.byType(ListTile),
      ),
      findsNothing,
    );
  });

  testWidgets('「更多」菜单中当前路由对应胶囊为选中态', (tester) async {
    // 起始页只允许 home/prices/recipes（kStartupPages），到达 /ingredients 需先导航。
    // 1) 在 home 打开菜单，点原料胶囊 → 跳到原料页
    await pumpRouter(tester);
    await openMoreMenu(tester);
    await tester.tap(find.byKey(const ValueKey('more-原料')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 2) 在原料页重新打开菜单，验证选中态
    await openMoreMenu(tester);

    expect(selectedBoxDecoration(const ValueKey('more-原料')),
        findsOneWidget);
    // 其他胶囊非选中态：Container.decoration 为 null（无 BoxDecoration）
    expect(selectedBoxDecoration(const ValueKey('more-商品')), findsNothing);
    expect(selectedBoxDecoration(const ValueKey('more-商家')), findsNothing);
    expect(selectedBoxDecoration(const ValueKey('more-我的')), findsNothing);
  });

  testWidgets('点击「更多」菜单胶囊跳转到对应路由', (tester) async {
    await pumpRouter(tester);
    await openMoreMenu(tester);

    // 点击「商品」胶囊 → 跳到商品页
    await tester.tap(find.byKey(const ValueKey('more-商品')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // ProductListScreen AppBar 标题「商品」
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('商品'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('「更多」菜单关闭按钮关闭 modal', (tester) async {
    await pumpRouter(tester);
    await openMoreMenu(tester);

    // 右上角关闭按钮存在
    final closeBtn = find.byWidgetPredicate(
      (w) => w is IconButton && (w.icon as Icon).icon == Icons.close,
    );
    expect(closeBtn, findsOneWidget);

    await tester.tap(closeBtn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 100));

    // modal 关闭后胶囊消失
    expect(find.byKey(const ValueKey('more-原料')), findsNothing);
  });

  testWidgets('新增商品入口是独立路由页面', (tester) async {
    await pumpRouter(tester);
    final context = tester.element(find.text('生计'));
    context.push('/products/new');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.widgetWithText(AppBar, '添加商品'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

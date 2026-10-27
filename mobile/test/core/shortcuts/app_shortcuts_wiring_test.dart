import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/app.dart';
import 'package:com_a4ding_livecalc/core/services/app_shortcuts_service.dart';
import 'package:com_a4ding_livecalc/core/shortcuts/app_shortcuts.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/server_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/screens/price_record_form_screen.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/startup_page_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// app.dart ↔ 原生通道接线：启动后把当前语言的快捷方式标题同步给原生，
/// 且 ready 握手只做一次（避免重复消费冷启动动作）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AppShortcutsService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('启动时同步三条快捷方式（标题取界面语言 zh）', (tester) async {
    SharedPreferences.setMockInitialValues({'mobile.ui_locale': 'zh-CN'});
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConfigProvider.overrideWith((_) => _NoopServerConfig()),
          startupPageProvider.overrideWith((_) => _NoopStartupPage()),
          authProvider.overrideWith((_) => _NoopAuthNotifier()),
        ],
        child: const LiveCalcApp(),
      ),
    );
    for (var i = 0;
        i < 10 && !calls.any((call) => call.method == 'setShortcutItems');
        i++) {
      await tester.pump();
    }

    expect(calls.where((call) => call.method == 'ready'), hasLength(1));

    final setItems =
        calls.where((call) => call.method == 'setShortcutItems').toList();
    expect(setItems, isNotEmpty);

    final items = (setItems.last.arguments as List<dynamic>)
        .cast<Map<dynamic, dynamic>>();
    expect(items, hasLength(AppShortcut.values.length));
    expect(
      items.map((item) => item['id']),
      ['record_price', 'daily_recommendation', 'recipes'],
    );
    expect(
      items.map((item) => item['title']),
      ['计价', '每日推荐', '菜谱'],
    );
    expect(
      items.map((item) => item['icon']),
      ['add', 'home', 'bookmark'],
    );
  });

  testWidgets('点击「计价」快捷方式直达新增价格记录页，且可返回列表', (tester) async {
    SharedPreferences.setMockInitialValues({'mobile.ui_locale': 'zh-CN'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'ready') return 'record_price';
      return null;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConfigProvider.overrideWith((_) => _NoopServerConfig()),
          startupPageProvider.overrideWith((_) => _NoopStartupPage()),
          authProvider.overrideWith((_) => _AuthedAuthNotifier()),
        ],
        child: const LiveCalcApp(),
      ),
    );
    // bootstrap（locale / 快捷方式 / 认证）→ go('/prices') → 下一帧 push 表单。
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final router = app.routerConfig! as GoRouter;

    expect(find.byType(PriceRecordFormScreen), findsOneWidget);
    // push 打开表单：当前页面是新增价格记录，且栈里有上一页（价格列表）。
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/prices/record',
    );
    expect(router.canPop(), isTrue);
  });
}

class _NoopServerConfig extends ServerConfigNotifier {
  @override
  Future<void> load() async {}
}

class _NoopStartupPage extends StartupPageNotifier {
  @override
  Future<void> load() async {}
}

class _NoopAuthNotifier extends AuthNotifier {
  _NoopAuthNotifier() : super(AuthRepository());

  @override
  Future<void> checkAuth() async {}
}

class _AuthedAuthNotifier extends AuthNotifier {
  _AuthedAuthNotifier() : super(AuthRepository()) {
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
  }

  @override
  Future<void> checkAuth() async {}
}

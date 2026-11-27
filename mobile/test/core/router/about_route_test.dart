import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/core/router/app_router.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

/// 「关于」是公开路由：未登录、甚至还没配置服务器时也要能打开
/// （服务器配置页底部与登录页底部都有入口）。这里直接以 /about 起步验证不被 redirect 弹走。
class _AboutHost extends ConsumerStatefulWidget {
  const _AboutHost();

  @override
  ConsumerState<_AboutHost> createState() => _AboutHostState();
}

class _AboutHostState extends ConsumerState<_AboutHost> {
  final _notifier = ChangeNotifier();
  late final GoRouter _router = createAppRouter(ref, _notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _router.go('/about'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

void main() {
  testWidgets('未配置服务器时 /about 可直接打开（不被重定向到服务器配置页）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.updateBaseUrl('');

    await tester.pumpWidget(const ProviderScope(child: _AboutHost()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // 关于页标题（AppBar）
    expect(find.widgetWithText(AppBar, '关于'), findsOneWidget);
    // 没有落到服务器配置页
    expect(find.text('服务器地址'), findsNothing);
    // 关于页内始终有法律文档入口
    expect(find.text('隐私政策'), findsWidgets);
  });
}

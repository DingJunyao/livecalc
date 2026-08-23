import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/server_provider.dart';
import 'features/profile/providers/startup_page_provider.dart';

/// Thin [ChangeNotifier] wrapper so [GoRouter.refreshListenable] can be nudged
/// from outside (notifyListeners is otherwise protected).
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class LiveCalcApp extends ConsumerStatefulWidget {
  const LiveCalcApp({super.key});

  @override
  ConsumerState<LiveCalcApp> createState() => _LiveCalcAppState();
}

class _LiveCalcAppState extends ConsumerState<LiveCalcApp> {
  final _refreshNotifier = _RouterRefreshNotifier();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Create the router exactly once; auth/server changes are wired through
    // refreshListenable so the redirect re-evaluates without rebuilding the
    // whole router each frame.
    _router = createAppRouter(ref, _refreshNotifier);
    _bootstrap();
  }

  @override
  void dispose() {
    _refreshNotifier.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Restore the server address first (the auth check needs the base URL),
    // then restore the session / auto-login from saved credentials.
    await ref.read(serverConfigProvider.notifier).load();
    // 起始页配置与服务器地址一样只存在本地，认证恢复前先加载，
    // 保证认证后的首次 redirect 就能落到用户配置的起始页。
    await ref.read(startupPageProvider.notifier).load();
    await ref.read(authProvider.notifier).checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    // Whenever auth or server state changes, nudge the router so its redirect
    // runs again with the fresh values.
    ref.listen(authProvider, (_, __) => _refreshNotifier.refresh());
    ref.listen(serverConfigProvider, (_, __) => _refreshNotifier.refresh());
    return MaterialApp.router(
      title: '生计 - 生活成本计算器',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      // 中文 localization：系统组件（返回按钮 tooltip、长按复制粘贴菜单等）
      // 全部显示中文，否则 Material 内置文案走默认英文。
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        // 系统状态栏/导航栏透明并跟随明暗主题，使 Android 全面屏下
        // 底部手势提示线区域显示应用背景色而非黑色。
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            // Android 29+ 会在透明系统栏后叠加一层对比度 scrim：
            // 浅色模式下（深色图标）会把提示条区域垫成白色，导致发白。
            // 关闭对比度强制，让透明栏直接透出应用背景色。
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: child!,
        );
      },
    );
  }
}

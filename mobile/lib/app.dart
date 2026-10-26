import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/i18n/app_locale.dart' as locale_utils;
import 'core/i18n/locale_settings.dart';
import 'core/router/app_router.dart';
import 'core/services/app_shortcuts_service.dart';
import 'core/shortcuts/app_shortcuts.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/server_provider.dart';
import 'features/profile/providers/startup_page_provider.dart';
import 'features/profile/providers/save_button_position_provider.dart';

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
  final _shortcuts = AppShortcutsService();
  late final GoRouter _router;

  /// 已点击但还没跳转的快捷方式：等认证完成后再执行，避免被 redirect 吞掉。
  AppShortcut? _pendingShortcut;

  @override
  void initState() {
    super.initState();
    // Create the router exactly once; auth/server changes are wired through
    // refreshListenable so the redirect re-evaluates without rebuilding the
    // whole router each frame.
    _router = createAppRouter(ref, _refreshNotifier);
    // 主屏快捷方式（长按图标）热启动点击；冷启动的点在 _bootstrap 中取回。
    _shortcuts.actions.listen(_onShortcutAction);
    _bootstrap();
  }

  @override
  void dispose() {
    _shortcuts.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Locale is restored before auth so cached authenticated preferences can
    // cover the startup frame while the user is being fetched.
    await ref.read(localeSettingsProvider.notifier).load(
          systemLocales: WidgetsBinding.instance.platformDispatcher.locales,
        );
    // Restore the server address (the auth check needs the base URL), then
    // restore the session / auto-login from saved credentials.
    await ref.read(serverConfigProvider.notifier).load();
    // 起始页配置与服务器地址一样只存在本地，认证恢复前先加载，
    // 保证认证后的首次 redirect 就能落到用户配置的起始页。
    await ref.read(startupPageProvider.notifier).load();
    // 保存按钮位置（右上角/页面下方）同样只存本地，表单首次构建前加载好
    await ref.read(saveButtonPositionProvider.notifier).load();
    // 主屏快捷方式：装好原生回调并取回冷启动时点的那一个；
    // 标题要跟随界面语言，所以放在 locale 加载之后同步。
    _pendingShortcut = await _shortcuts.initialize() ?? _pendingShortcut;
    await _syncShortcutItems();
    await ref.read(authProvider.notifier).checkAuth();
    // checkAuth 完成后才能跳转（未登录时 router 会先落到登录页，
    // 这里保留 pending 等登录成功后再跳）。
    _applyPendingShortcut();
  }

  /// 点击快捷方式：先存起来，等认证完成（或当前已登录）再跳转。
  void _onShortcutAction(AppShortcut shortcut) {
    _pendingShortcut = shortcut;
    _applyPendingShortcut();
  }

  void _applyPendingShortcut() {
    final shortcut = _pendingShortcut;
    if (shortcut == null) return;
    if (ref.read(authProvider).status != AuthStatus.authenticated) return;
    _pendingShortcut = null;
    // 等当前帧结束再导航：可能正在 splash → 落地页的 redirect 过程中。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router.go(shortcut.route);
    });
  }

  /// 把快捷方式标题同步给原生。Android 用 XML 静态声明（原生直接忽略），
  /// iOS 需要运行时注册，标题取当前界面语言。
  Future<void> _syncShortcutItems() async {
    final l10n = lookupAppLocalizations(
      locale_utils.flutterLocaleFor(ref.read(localeSettingsProvider).uiLocale),
    );
    await _shortcuts.setItems(
      AppShortcut.values
          .map((shortcut) => shortcut.toChannelItem(l10n))
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeSettings = ref.watch(localeSettingsProvider);
    // Whenever auth or server state changes, nudge the router so its redirect
    // runs again with the fresh values.
    ref.listen(authProvider, (_, authState) {
      if (authState.status == AuthStatus.authenticated ||
          authState.status == AuthStatus.unauthenticated ||
          authState.status == AuthStatus.error) {
        ref.read(localeSettingsProvider.notifier).applyUser(authState.user);
      }
      _refreshNotifier.refresh();
      // 登录完成后补跳之前点的快捷方式（登录页点击会先存在 _pendingShortcut）。
      _applyPendingShortcut();
    });
    ref.listen(serverConfigProvider, (_, __) => _refreshNotifier.refresh());
    // 切换界面语言后快捷方式标题要跟着变。
    ref.listen(localeSettingsProvider, (previous, next) {
      if (previous?.uiLocale != next.uiLocale) {
        _syncShortcutItems();
      }
    });
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: locale_utils.supportedUiLocales
          .map(locale_utils.flutterLocaleFor)
          .toList(growable: false),
      locale: locale_utils.flutterLocaleFor(localeSettings.uiLocale),
      localeResolutionCallback: (_, __) =>
          locale_utils.flutterLocaleFor(localeSettings.uiLocale),
      builder: (context, child) {
        // 系统状态栏/导航栏透明并跟随明暗主题，使 Android 全面屏下
        // 底部手势提示线区域显示应用背景色而非黑色。
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return KeyedSubtree(
          key:
              ValueKey('locale-format-${localeSettings.effectiveFormatLocale}'),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
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
          ),
        );
      },
    );
  }
}

import '../../l10n/app_localizations.dart';

/// 主屏快捷方式（长按应用图标弹出）的动作定义。
///
/// [id] 与原生侧一一对应：
/// - Android：`res/xml/shortcuts.xml` 中 intent 的 extra
///   `com.a4ding.livecalc.SHORTCUT_ACTION`；
/// - iOS：动态注册的 `UIApplicationShortcutItem.type`（标题随界面语言，
///   由 [toChannelItem] 下发）。
///
/// [route] 是最终目标路由（与 `app_router.dart` 中的路径一致）；
/// [baseRoute] 非空表示目标是「表单类」二级页面：先 [go] 到根页再 [push]
/// 表单，这样保存/返回能回到根页（否则作为首屏打开的表单无处可回）。
/// 登录态判定交给 router 的 redirect，未登录时会先落到登录页。
enum AppShortcut {
  recordPrice(
    id: 'record_price',
    route: '/prices/record',
    baseRoute: '/prices',
    iosIcon: 'add',
  ),
  dailyRecommendation(
    id: 'daily_recommendation',
    route: '/home',
    iosIcon: 'home',
  ),
  recipes(
    id: 'recipes',
    route: '/recipes',
    iosIcon: 'bookmark',
  );

  const AppShortcut({
    required this.id,
    required this.route,
    required this.iosIcon,
    this.baseRoute,
  });

  /// 原生侧识别用的稳定 id，不要随意改（改了两端要同步）。
  final String id;

  /// 点击快捷方式后最终停留的路由。
  final String route;

  /// 表单类入口的根页：先 go 到这里再 push [route]。
  final String? baseRoute;

  /// iOS 内置快捷方式图标类型名（对应 `UIApplicationShortcutIconType`，
  /// 见 `ios/Runner/AppDelegate.swift` 中的映射）；Android 用矢量图资源。
  final String iosIcon;

  /// 按 id 解析；未知 id（例如旧版本快捷方式残留）返回 null。
  static AppShortcut? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final shortcut in values) {
      if (shortcut.id == id) return shortcut;
    }
    return null;
  }

  /// 快捷方式的显示标题（系统语言跟随 App 界面语言）。
  String label(AppLocalizations l10n) {
    return switch (this) {
      AppShortcut.recordPrice => l10n.shortcutRecordPrice,
      AppShortcut.dailyRecommendation => l10n.shortcutDailyRecommendation,
      AppShortcut.recipes => l10n.shortcutRecipes,
    };
  }

  /// 下发给原生 `setShortcutItems` 的载荷。
  Map<String, String> toChannelItem(AppLocalizations l10n) => {
        'id': id,
        'title': label(l10n),
        'icon': iosIcon,
      };
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/app_back_button.dart';
import 'shell_chrome.dart';
import 'vertical_bar_edge.dart';

/// 页面标题栏：竖条导航（Duo 内屏横屏 / 分屏 / 折叠态）下，标题栏**不出现任何按钮**。
///
/// - 非竖条形态：与 [AppBar] 完全一致（后退 / 动作照常）。
/// - 竖条形态：不渲染 leading（返回由竖条置顶）与 actions（页面在 build 里用
///   `context.publishShellActions(...)` 交给竖条工具区）。
///
/// 应用内页面一律用它而不是直接构造 [AppBar]：
/// `test/core/layout/shell_app_bar_guard_test.dart` 会拦住裸 `AppBar(`，避免某个页面
/// 在竖条模式下又冒出标题栏按钮。带 `actions` 的页面还必须把动作发布到竖条。
class ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShellAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.bottom,
    this.toolbarHeight,
    this.leadingWidth,
    this.actionsPadding,
    this.titleSpacing,
    this.centerTitle,
    this.primary = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.scrolledUnderElevation,
    this.systemOverlayStyle,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;
  final double? leadingWidth;
  final EdgeInsetsGeometry? actionsPadding;
  final double? titleSpacing;
  final bool? centerTitle;
  final bool primary;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final double? scrolledUnderElevation;
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// 直接委托给 [AppBar]：Scaffold 只对它自己的 `preferredSize` 类型套用主题里的
  /// `toolbarHeight`（`AppBar.preferredHeightFor`），自己拼一个普通 [Size] 会让标题栏
  /// 高度被夹回 56。
  @override
  Size get preferredSize =>
      AppBar(toolbarHeight: toolbarHeight, bottom: bottom).preferredSize;

  @override
  Widget build(BuildContext context) {
    final rail = context.shellRailMode;
    final routeName = ModalRoute.of(context)?.settings.name;
    if (rail) {
      assert(() {
        _debugWarnIfUnpublished(context, routeName, actions, 'ShellAppBar');
        return true;
      }());
    }
    // 返回键统一成带尾巴的 `arrow_back`（`AppBackButton`）：框架 `BackButton` 在 iOS
    // 上是 chevron（无尾巴），与列表页的后退按钮样式不一致。这里接管自动返回键，
    // 顺带统一「先问 PopScope 守卫，再 pop，最后回首页」的语义。
    Widget? effectiveLeading = leading;
    var implyLeading = automaticallyImplyLeading;
    final bar = Theme.of(context).extension<DuoBarInsets>();
    if (!rail && leading == null && automaticallyImplyLeading) {
      final route = ModalRoute.of(context);
      if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
        effectiveLeading = const DrawerButton();
        implyLeading = false;
      } else if (route?.impliesAppBarDismissal ?? false) {
        effectiveLeading = route!.fullscreenDialog
            ? const CloseButton()
            : const AppBackButton();
        implyLeading = false;
      }
    }
    // Duo 横条形态、系统簇在 leading 侧：AppBar 把 leading 在 leadingWidth 里居中，
    // 会正好压在系统簇上 → 排到 leading 区的尾端（簇的右边）。
    if (!rail && effectiveLeading != null && (bar?.leadingInset ?? 0) > 0) {
      effectiveLeading = Align(
        alignment: AlignmentDirectional.centerEnd,
        child: effectiveLeading,
      );
    }
    // Duo 横条形态：标题栏内容（文本 / 返回键 / 动作图标）对齐系统状态图标的光轴
    // 中心（`DuoBarInsets.contentCenterY`，单行簇实测 48pt）。AppBar 把每个槽位垂直
    // 居中，所以给槽位加 2Δ 的顶部内边距即可把内容中心下移 Δ。
    final delta = (bar == null || bar.toolbarHeight <= 0)
        ? 0.0
        : (bar.contentCenterY - bar.toolbarHeight / 2).clamp(-24.0, 24.0);
    final shift = delta == 0 ? null : EdgeInsets.only(top: 2 * delta);
    Widget? shiftedLeading = effectiveLeading;
    Widget? shiftedTitle = title;
    EdgeInsetsGeometry? effectiveActionsPadding = actionsPadding;
    if (!rail && shift != null) {
      if (effectiveLeading != null) {
        shiftedLeading = Padding(padding: shift, child: effectiveLeading);
      }
      if (title != null) {
        shiftedTitle = Padding(padding: shift, child: title);
      }
      // AppBar 解析顺序是「widget → 主题 → 默认」，这里显式合并时也要带回主题值，
      // 否则会把 Duo 主题里给系统簇让位的 end 内边距覆盖成 0。
      final baseActionsPadding =
          actionsPadding ?? Theme.of(context).appBarTheme.actionsPadding;
      effectiveActionsPadding = (baseActionsPadding ?? EdgeInsets.zero)
              .resolve(Directionality.of(context)) +
          (shift as EdgeInsets);
    }
    // 竖条形态：标题栏只留标题（与 bottom，如 TabBar）。
    return AppBar(
      leading: rail ? null : shiftedLeading,
      automaticallyImplyLeading: rail ? false : implyLeading,
      title: shiftedTitle,
      actions: rail ? null : actions,
      bottom: bottom,
      toolbarHeight: toolbarHeight,
      leadingWidth: rail ? null : leadingWidth,
      actionsPadding: rail ? null : effectiveActionsPadding,
      titleSpacing: titleSpacing,
      centerTitle: centerTitle,
      primary: primary,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      systemOverlayStyle: systemOverlayStyle,
    );
  }
}

/// [SliverAppBar] 的竖条版本，语义同 [ShellAppBar]。
class ShellSliverAppBar extends StatelessWidget {
  const ShellSliverAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.pinned = false,
    this.floating = false,
    this.snap = false,
    this.expandedHeight,
    this.collapsedHeight,
    this.flexibleSpace,
    this.bottom,
    this.toolbarHeight,
    this.leadingWidth,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.scrolledUnderElevation,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final bool pinned;
  final bool floating;
  final bool snap;
  final double? expandedHeight;
  final double? collapsedHeight;
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;
  final double? leadingWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final double? scrolledUnderElevation;

  @override
  Widget build(BuildContext context) {
    final rail = context.shellRailMode;
    final routeName = ModalRoute.of(context)?.settings.name;
    if (rail) {
      assert(() {
        _debugWarnIfUnpublished(
            context, routeName, actions, 'ShellSliverAppBar');
        return true;
      }());
    }
    // 返回键统一成带尾巴的 `arrow_back`（见 ShellAppBar 同处注释）。
    Widget? effectiveLeading = leading;
    var implyLeading = automaticallyImplyLeading;
    if (!rail && leading == null && automaticallyImplyLeading) {
      final route = ModalRoute.of(context);
      if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
        effectiveLeading = const DrawerButton();
        implyLeading = false;
      } else if (route?.impliesAppBarDismissal ?? false) {
        effectiveLeading = route!.fullscreenDialog
            ? const CloseButton()
            : const AppBackButton();
        implyLeading = false;
      }
    }
    // SliverAppBar.toolbarHeight 默认是 56（不是 null），直接透传会盖掉主题里按系统
    // 状态簇设定的标题栏高度，所以这里按「参数 → 主题 → 默认」解析。
    final effectiveToolbarHeight = toolbarHeight ??
        Theme.of(context).appBarTheme.toolbarHeight ??
        kToolbarHeight;
    return SliverAppBar(
      leading: rail ? null : effectiveLeading,
      automaticallyImplyLeading: rail ? false : implyLeading,
      title: title,
      actions: rail ? null : actions,
      pinned: pinned,
      floating: floating,
      snap: snap,
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      toolbarHeight: effectiveToolbarHeight,
      leadingWidth: rail ? null : leadingWidth,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
    );
  }
}

/// 已提示过「动作没进竖条」的路由（每个路由只提示一次，避免刷屏）。
final Set<String> _warnedRoutes = <String>{};

/// 页面带了动作却没发布到竖条：竖条里就没这些按钮了。只在 debug 下提示，
/// 硬约束由源码守卫测试负责。
void _debugWarnIfUnpublished(
  BuildContext context,
  String? routeName,
  List<Widget>? actions,
  String kind,
) {
  if (actions == null || actions.isEmpty) return;
  final chrome = ShellChromeScope.maybeOf(context);
  if (chrome == null) return;
  if (chrome.actions.isNotEmpty || chrome.primary != null) return;
  if (_warnedRoutes.add('$kind:$routeName')) {
    debugPrint(
      '[$kind] 竖条模式下 "$routeName" 的标题栏动作没有发布到竖条：'
      '请在页面 build 里调用 context.publishShellActions(...)',
    );
  }
}

import 'package:flutter/material.dart';

/// 宽屏铺满、窄屏按内容排的 TabBar。
///
/// 手机上标签按内容宽度排、可横向滚动（长文案不被挤扁）；宽屏（可用宽度 ≥
/// [wideBreakpoint]，如 Duo 展开）标签等分整行，右侧不再空出一大截。
class AdaptiveTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.onTap,
  });

  final List<Widget> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;

  /// 判定「宽屏」的宽度阈值（Duo 展开竖屏 669 / 横屏内容宽 867 都在内）。
  static const double wideBreakpoint = 600;

  @override
  Size get preferredSize {
    // 与 Flutter TabBar 的 preferredSize 同口径（AppBar 布局时本控件还没挂载，读不到
    // 主题，按默认 indicatorWeight 2 计）：纯文字标签 46 + 2，图标 + 文字 72 + 2。
    final hasIconAndText = tabs.any(
      (t) => t is Tab && t.icon != null && (t.text != null || t.child != null),
    );
    return Size.fromHeight((hasIconAndText ? 72 : 46) + 2);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    return TabBar(
      controller: controller,
      isScrollable: !wide,
      tabAlignment: wide ? TabAlignment.fill : TabAlignment.start,
      onTap: onTap,
      tabs: tabs,
    );
  }
}

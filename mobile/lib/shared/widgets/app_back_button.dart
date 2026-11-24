import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'directional_icons.dart';

/// 子页面返回按钮：路由可返回时执行 pop，否则回首页
/// （原料/商品/商家/地图通常由首页快捷入口进入）。
///
/// 用 maybePop 而非 context.pop()：go_router 的 pop 走 Navigator.pop 强制
/// 退出，会绕过路由上的 PopScope（表单未保存退出确认就靠它拦截）。
/// maybePop 会先问路由的 popDisposition —— 没有拦截器时行为与 pop 一致，
/// 有 FormExitGuard 的表单页则先弹确认。
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(DirectionalIcons.backArrow(context)),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () async {
        // 有未保存确认（PopScope / FormExitGuard）时交给 maybePop：由守卫决定弹确认
        // 还是取消，不能绕过（GoRouter.pop 不经过 PopScope）。
        final route = ModalRoute.of(context);
        if (route != null &&
            route.popDisposition == RoutePopDisposition.doNotPop) {
          await Navigator.of(context).maybePop();
          return;
        }
        // ShellRoute 下 Navigator.maybePop 不可靠（会「按了没反应」），有可返回
        // 路由时用 GoRouter.pop 强制弹栈。独立页面（无 GoRouter，如组件测试）退回
        // Navigator，否则会直接抛「No GoRouter found in context」。
        final router = GoRouter.maybeOf(context);
        if (router != null && router.canPop()) {
          router.pop();
          return;
        }
        if (await Navigator.of(context).maybePop()) return;
        // tab 根页 / 无处可退：回首页
        if (router != null && context.mounted) context.go('/home');
      },
    );
  }
}

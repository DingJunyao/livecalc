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
        final popped = await Navigator.of(context).maybePop();
        // maybePop 失败且无路由可退（表单确认放弃 / 已是根路由）→ 回首页
        if (!popped && context.mounted && !context.canPop()) {
          context.go('/home');
        }
      },
    );
  }
}

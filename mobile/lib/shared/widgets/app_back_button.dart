import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 子页面返回按钮：路由可返回时执行 pop，否则回首页
/// （原料/商品/商家/地图通常由首页快捷入口进入）。
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: '返回',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
    );
  }
}

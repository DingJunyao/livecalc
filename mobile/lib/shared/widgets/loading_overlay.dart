import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 半透明全屏加载覆盖层：在后台查询等耗时操作期间覆盖页面并阻止用户交互。
/// 必须作为 [Stack] 的直接子节点使用（通常放在最后一个）。
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final Color barrierColor;

  const LoadingOverlay({
    super.key,
    this.message,
    this.barrierColor = const Color(0x59000000),
  });

  @override
  Widget build(BuildContext context) {
    final message = this.message ?? AppLocalizations.of(context).commonLoading;
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: barrierColor,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

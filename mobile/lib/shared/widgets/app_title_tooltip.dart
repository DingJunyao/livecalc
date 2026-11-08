import 'package:flutter/material.dart';

/// AppBar 标题：超长省略，长按弹出完整内容。
///
/// 标题预算不足时 AppBar 会把标题截成「…」（SDK 强制单行省略），
/// 本组件用长按 Tooltip 兜底展示全名；静态短标题用它也无副作用。
/// [child] 缺省渲染单行省略的 [Text]；标题带附加元素（如类型标签）时
/// 传入自定义 Row，[message] 仍传完整名称。
class AppTitleTooltip extends StatelessWidget {
  const AppTitleTooltip({
    super.key,
    required this.message,
    this.child,
    this.style,
  });

  final String message;
  final Widget? child;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 4),
      child: child ??
          Text(message,
              style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

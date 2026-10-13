import 'package:flutter/material.dart';

import '../../features/profile/providers/save_button_position_provider.dart';

/// 全屏表单统一的「保存」入口，位置由用户本地设置决定：
/// - [SaveButtonPosition.topRight]：AppBar 右上角（沿用历史行为）
/// - [SaveButtonPosition.bottom]：页面下方整宽按钮条
///
/// 用法（两者一起放，位置决定谁生效）：
/// ```dart
/// appBar: AppBar(
///   title: ...,
///   actions: [
///     ...otherActions,
///     ...saveAppBarActions(position: pos, onSave: _save, label: l10n.commonSave),
///   ],
/// ),
/// bottomNavigationBar:
///     saveBottomBar(context: context, position: pos, onSave: _save, label: l10n.commonSave),
/// ```
List<Widget> saveAppBarActions({
  required SaveButtonPosition position,
  required VoidCallback? onSave,
  required String label,
  bool busy = false,
}) {
  if (position != SaveButtonPosition.topRight) return const <Widget>[];
  return <Widget>[
    TextButton(
      onPressed: onSave,
      child: busy ? const _SaveSpinner(size: 18) : Text(label),
    ),
  ];
}

/// 位置为「页面下方」时返回底部保存条，否则 null（Scaffold 不显示）。
PreferredSizeWidget? saveBottomBar({
  required BuildContext context,
  required SaveButtonPosition position,
  required VoidCallback? onSave,
  required String label,
  bool busy = false,
  String? subtitle,
}) {
  if (position != SaveButtonPosition.bottom) return null;
  final theme = Theme.of(context);
  return PreferredSize(
    preferredSize: Size.fromHeight(subtitle == null ? 64 : 84),
    child: Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle != null) ...[
                Text(subtitle, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: onSave,
                  child: busy
                      ? const _SaveSpinner(size: 18, light: true)
                      : Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SaveSpinner extends StatelessWidget {
  final double size;
  final bool light;

  const _SaveSpinner({required this.size, this.light = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: light ? Theme.of(context).colorScheme.onPrimary : null,
      ),
    );
  }
}

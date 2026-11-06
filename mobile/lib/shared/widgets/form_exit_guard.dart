import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// 表单未保存退出确认对话框。返回 true = 放弃修改并退出。
Future<bool> confirmDiscardUnsavedChanges(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      title: Text(l10n.formExitUnsavedTitle),
      content: Text(l10n.formExitUnsavedBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogCtx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: Text(l10n.formExitDiscard),
        ),
      ],
    ),
  );
  return result == true;
}

/// 表单页退出二次确认：有未保存修改时，返回（系统返回手势 / AppBar 返回键 /
/// maybePop）先弹对话框，确认「放弃并退出」才真正退出。
///
/// 拦截机制：包装 [PopScope]（canPop=false），由 [Navigator.maybePop] 触发。
/// 注意 `context.pop()`（go_router）与保存成功后的 `Navigator.pop()` 是**强制
/// pop、不经过本组件**——前者由调用方自行决定（AppBackButton 已改为
/// maybePop 优先），后者正是保存后免确认直接退出的通路。
///
/// 用法：把 Scaffold 包在 [FormExitGuard] 里：
/// ```dart
/// FormExitGuard(
///   enabled: !_isEdit,            // 本次只对新增态启用
///   isDirty: () => _name.text.trim().isNotEmpty,
///   child: Scaffold(...),
/// )
/// ```
class FormExitGuard extends StatefulWidget {
  const FormExitGuard({
    super.key,
    required this.child,
    required this.isDirty,
    this.enabled = true,
  });

  final Widget child;

  /// 弹出时实时求值：true = 有未保存修改，需要确认。
  final bool Function() isDirty;

  /// false 时返回直接放行（如编辑态、保存成功后）。
  final bool enabled;

  @override
  State<FormExitGuard> createState() => _FormExitGuardState();
}

class _FormExitGuardState extends State<FormExitGuard> {
  /// 对话框已弹出时忽略新的返回事件（避免 Android 返回键连按弹两层）。
  bool _confirming = false;

  Future<void> _handlePop() async {
    if (!widget.enabled || !widget.isDirty()) {
      Navigator.of(context).pop();
      return;
    }
    if (_confirming) return;
    _confirming = true;
    final discard = await confirmDiscardUnsavedChanges(context);
    _confirming = false;
    if (discard && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: widget.child,
    );
  }
}

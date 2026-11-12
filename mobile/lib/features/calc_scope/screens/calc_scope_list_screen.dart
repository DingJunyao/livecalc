import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/calc_scope.dart';
import '../providers/calc_scope_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/empty_state.dart';
import 'calc_scope_form_screen.dart';

/// 服务端错误文案：透出后端 detail（如「已存在同名范围」「未知地区」），
/// 取不到落回通用失败文案。
String calcScopeWriteError(Object e, AppLocalizations l10n) {
  if (e is DioException &&
      e.response?.data is Map &&
      (e.response!.data as Map)['detail'] is String) {
    return (e.response!.data as Map)['detail'] as String;
  }
  return l10n.calcScopeOperationFailed;
}

/// 自定义计算范围列表：FAB 新建 + 行内菜单（设为默认/编辑/删除）。
/// 「设为默认」走 PATCH /auth/me 的 default_calc_scope_id（用户级设置）。
class CalcScopeListScreen extends ConsumerStatefulWidget {
  const CalcScopeListScreen({super.key});

  @override
  ConsumerState<CalcScopeListScreen> createState() =>
      _CalcScopeListScreenState();
}

class _CalcScopeListScreenState extends ConsumerState<CalcScopeListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(calcScopeListProvider.notifier).load());
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      if (!mounted) return;
      _toast(calcScopeWriteError(e, AppLocalizations.of(context)));
    }
  }

  Future<void> _confirmDelete(CalcScope scope) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.calcScopeDeleteTitle),
        content: Text(l10n.calcScopeDeleteMessage(scope.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await ref.read(calcScopeListProvider.notifier).remove(scope.id);
      // 删除可能清掉当前默认（后端会清 users.default_calc_scope_id），刷新用户态
      final user = await AuthRepository().getCurrentUser();
      if (!mounted) return;
      ref.read(authProvider.notifier).applyUser(user);
    });
  }

  Future<void> _setDefault(CalcScope scope) async {
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      final user = await AuthRepository().updateMe({
        'default_calc_scope_id': scope.id,
      });
      if (!mounted) return;
      ref.read(authProvider.notifier).applyUser(user);
      await ref.read(calcScopeListProvider.notifier).load();
      _toast(l10n.calcScopeDefaultSet);
    });
  }

  Future<void> _openEditor({CalcScope? scope}) async {
    final result = await context.push<CalcScopeFormResult>(
      scope == null
          ? '/profile/calc-scopes/new'
          : '/profile/calc-scopes/${scope.id}/edit',
      extra: CalcScopeFormArguments(scope: scope),
    );
    if (result?.saved == true && mounted) {
      final l10n = AppLocalizations.of(context);
      _toast(l10n.calcScopeSaved);
      // 编辑可能改变了默认范围的构成，刷新列表的默认标记
      await ref.read(calcScopeListProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(calcScopeListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calcScopeListTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: l10n.calcScopeAdd,
        child: const Icon(Icons.add),
      ),
      body: state.loading && state.items.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.items.isEmpty
              ? ErrorDisplay(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(calcScopeListProvider.notifier).load(),
                )
              : state.items.isEmpty
                  ? EmptyState(
                      icon: Icons.layers_clear_outlined,
                      title: l10n.calcScopeEmptyTitle,
                      subtitle: l10n.calcScopeEmptySubtitle)
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(calcScopeListProvider.notifier).load(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final scope = state.items[i];
                          return ListTile(
                            leading: Icon(
                              scope.isDefault
                                  ? Icons.star
                                  : Icons.layers_outlined,
                              color: scope.isDefault
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(scope.name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (scope.isDefault) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.calcScopeDefaultBadge,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              scope.regionsSummary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: l10n.calcScopeMoreActions,
                              onSelected: (v) async {
                                switch (v) {
                                  case 'default':
                                    _setDefault(scope);
                                  case 'edit':
                                    _openEditor(scope: scope);
                                  case 'delete':
                                    _confirmDelete(scope);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  enabled: !scope.isDefault,
                                  value: 'default',
                                  child: Text(l10n.calcScopeSetDefault),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(l10n.commonEdit),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n.commonDelete),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

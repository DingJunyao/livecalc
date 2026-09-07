import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proposal.dart';
import '../providers/profile_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/empty_state.dart';

/// 我的提议：列表（标题/类型/动作/状态）+ 点击查看详情（变更 diff）。
class MyProposalsScreen extends ConsumerStatefulWidget {
  const MyProposalsScreen({super.key});

  @override
  ConsumerState<MyProposalsScreen> createState() => _MyProposalsScreenState();
}

class _MyProposalsScreenState extends ConsumerState<MyProposalsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(proposalListProvider.notifier).load());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'approved':
        return l10n.proposalStatusApproved;
      case 'rejected':
        return l10n.proposalStatusRejected;
      default:
        return l10n.proposalStatusPending;
    }
  }

  String _typeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'ingredient':
        return l10n.proposalTypeIngredient;
      case 'nutrition':
      case 'product_nutrition':
        return l10n.proposalTypeNutrition;
      case 'unit':
        return l10n.proposalTypeUnit;
      case 'merchant':
        return l10n.proposalTypeMerchant;
      case 'merchant_merge':
        return l10n.proposalTypeMerchantMerge;
      case 'product':
        return l10n.proposalTypeProduct;
      case 'recipe':
        return l10n.proposalTypeRecipe;
      case 'usda_ingredient_match':
      case 'usda_product_match':
        return l10n.proposalTypeUsdaMatch;
      default:
        return type.isEmpty ? l10n.proposalTypeUnknown : type;
    }
  }

  String _actionLabel(String action, AppLocalizations l10n) {
    switch (action) {
      case 'create':
        return l10n.proposalActionCreate;
      case 'update':
        return l10n.proposalActionUpdate;
      case 'delete':
        return l10n.commonDelete;
      case 'merge':
        return l10n.proposalActionMerge;
      case 'publish':
        return l10n.proposalActionPublish;
      default:
        return action.isEmpty ? l10n.proposalActionUnknown : action;
    }
  }

  void _showDetail(Proposal p) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Expanded(child: Text(l10n.proposalDetailTitle(p.id))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(p.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusLabel(p.status, l10n),
              style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                  color: _statusColor(p.status), fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.title.isNotEmpty)
                Text(p.title, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${_typeLabel(p.entityType, l10n)} · '
                '${_actionLabel(p.action, l10n)} · ${p.createdAt}',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(ctx).colorScheme.outline),
              ),
              if (p.entityId != null) ...[
                const SizedBox(height: 4),
                Text(l10n.proposalEntityId(p.entityId!),
                    style: Theme.of(ctx).textTheme.bodySmall),
              ],
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.proposalReviewComment,
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(p.description, style: Theme.of(ctx).textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              Text(l10n.proposalChanges,
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 4),
              ..._diffRows(p, l10n),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  /// 变更 diff：snapshot（before）vs payload（after）键并集，逐行展示。
  /// 简化实现：不解析嵌套结构，直接展示序列化值。
  List<Widget> _diffRows(Proposal p, AppLocalizations l10n) {
    final keys = <String>{...p.snapshot.keys, ...p.payload.keys};
    if (keys.isEmpty) {
      return [
        Text(l10n.proposalNoDetails,
            style: Theme.of(context).textTheme.bodySmall),
      ];
    }
    final rows = <Widget>[];
    for (final k in keys.toList()..sort()) {
      final before = p.snapshot[k];
      final after = p.payload[k];
      if (before == after) continue; // 未变化的字段不展示
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(TextSpan(
          children: [
            TextSpan(
                text: '$k: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(
              text: '${_val(before, l10n)} → ${_val(after, l10n)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        )),
      ));
    }
    if (rows.isEmpty) {
      return [
        Text(l10n.proposalNoDetails,
            style: Theme.of(context).textTheme.bodySmall),
      ];
    }
    return rows;
  }

  String _val(dynamic v, AppLocalizations l10n) {
    if (v == null) return l10n.proposalValueNone;
    if (v is Map || v is List) return v.toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(proposalListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileMyProposals)),
      body: state.loading && state.items.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.items.isEmpty
              ? ErrorDisplay(
                  message: state.error!,
                  onRetry: () => ref.read(proposalListProvider.notifier).load())
              : state.items.isEmpty
                  ? EmptyState(
                      icon: Icons.rate_review_outlined,
                      title: l10n.proposalEmptyTitle,
                      subtitle: l10n.proposalEmptySubtitle)
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(proposalListProvider.notifier).load(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = state.items[i];
                          return ListTile(
                            title: Text(p.title),
                            subtitle: Text(
                                '${_typeLabel(p.entityType, l10n)} · '
                                '${_actionLabel(p.action, l10n)} · '
                                '${p.createdAt}',
                                style: theme.textTheme.bodySmall),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(p.status)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statusLabel(p.status, l10n),
                                style: theme.textTheme.labelMedium?.copyWith(
                                    color: _statusColor(p.status),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            onTap: () => _showDetail(p),
                          );
                        },
                      ),
                    ),
    );
  }
}

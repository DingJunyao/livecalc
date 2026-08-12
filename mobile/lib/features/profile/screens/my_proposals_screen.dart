import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proposal.dart';
import '../providers/profile_provider.dart';
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

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return '已生效';
      case 'rejected':
        return '已驳回';
      default:
        return '待审';
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'ingredient':
        return '食材';
      case 'nutrition':
      case 'product_nutrition':
        return '营养';
      case 'unit':
        return '单位';
      case 'merchant':
        return '商家';
      case 'merchant_merge':
        return '商家合并';
      case 'product':
        return '商品';
      case 'recipe':
        return '菜谱';
      case 'usda_ingredient_match':
      case 'usda_product_match':
        return 'USDA 匹配';
      default:
        return type.isEmpty ? '未知' : type;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'create':
        return '新增';
      case 'update':
        return '修改';
      case 'delete':
        return '删除';
      case 'merge':
        return '合并';
      case 'publish':
        return '发布';
      default:
        return action.isEmpty ? '未知' : action;
    }
  }

  void _showDetail(Proposal p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Expanded(child: Text('提议 #${p.id}')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(p.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusLabel(p.status),
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
                '${_typeLabel(p.entityType)} · ${_actionLabel(p.action)} · ${p.createdAt}',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(ctx).colorScheme.outline),
              ),
              if (p.entityId != null) ...[
                const SizedBox(height: 4),
                Text('实体 ID: ${p.entityId}',
                    style: Theme.of(ctx).textTheme.bodySmall),
              ],
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('审核意见', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(p.description, style: Theme.of(ctx).textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              Text('变更内容', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 4),
              ..._diffRows(p),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 变更 diff：snapshot（before）vs payload（after）键并集，逐行展示。
  /// 简化实现：不解析嵌套结构，直接展示序列化值。
  List<Widget> _diffRows(Proposal p) {
    final keys = <String>{...p.snapshot.keys, ...p.payload.keys};
    if (keys.isEmpty) {
      return [Text('无明细', style: Theme.of(context).textTheme.bodySmall)];
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
                text: '$k：',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(
              text: '${_val(before)} → ${_val(after)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        )),
      ));
    }
    if (rows.isEmpty) {
      return [Text('无明细', style: Theme.of(context).textTheme.bodySmall)];
    }
    return rows;
  }

  String _val(dynamic v) {
    if (v == null) return '无';
    if (v is Map || v is List) return v.toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(proposalListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的提议')),
      body: state.loading && state.items.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.items.isEmpty
              ? ErrorDisplay(
                  message: state.error!,
                  onRetry: () => ref.read(proposalListProvider.notifier).load())
              : state.items.isEmpty
                  ? const EmptyState(
                      icon: Icons.rate_review_outlined,
                      title: '暂无提议',
                      subtitle: '对共享数据的修改会显示在这里')
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
                                '${_typeLabel(p.entityType)} · ${_actionLabel(p.action)} · ${p.createdAt}',
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
                                _statusLabel(p.status),
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

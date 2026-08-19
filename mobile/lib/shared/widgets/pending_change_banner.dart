import 'package:flutter/material.dart';

/// A single, consolidated pending-review notice for a detail page.
class PendingChangeBanner extends StatelessWidget {
  final Set<String> modifications;
  final Set<String> deletions;

  static const _internalFieldLabels = {'updated_by', 'update_by'};

  const PendingChangeBanner({
    super.key,
    this.modifications = const {},
    this.deletions = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modificationLabels = modifications
        .where((label) =>
            label.isNotEmpty && !_internalFieldLabels.contains(label))
        .toList();
    final deletionLabels =
        deletions.where((label) => label.isNotEmpty).toList();
    if (modificationLabels.isEmpty && deletionLabels.isEmpty) {
      return const SizedBox.shrink();
    }

    final String message;
    if (deletionLabels.isEmpty) {
      message = '修改待管理员审核：${modificationLabels.join('、')}';
    } else if (modificationLabels.isEmpty) {
      message = '删除待管理员审核：${deletionLabels.join('、')}';
    } else {
      message =
          '待管理员审核：修改${modificationLabels.join('、')}、删除${deletionLabels.join('、')}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hourglass_top_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

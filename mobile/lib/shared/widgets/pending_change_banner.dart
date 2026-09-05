import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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

    final l10n = AppLocalizations.of(context);
    final String message;
    if (deletionLabels.isEmpty) {
      message = l10n.pendingModificationReview(
        modificationLabels.join(l10n.commonListSeparator),
      );
    } else if (modificationLabels.isEmpty) {
      message = l10n.pendingDeletionReview(
        deletionLabels.join(l10n.commonListSeparator),
      );
    } else {
      message = l10n.pendingCombinedReview(
        modificationLabels.join(l10n.commonListSeparator),
        deletionLabels.join(l10n.commonListSeparator),
      );
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

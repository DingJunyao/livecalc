import 'package:flutter/material.dart';

import '../../features/entities/repositories/entity_repository.dart';
import '../../l10n/app_localizations.dart';
import '../models/entity_quantity_link.dart';
import '../utils/currency_fmt.dart';
import 'entity_quantity_link_edit_page.dart';

/// 单位与密度卡片内的「关联与换算」区：一条关联 = 一句等式。
class EntityQuantityLinksSection extends StatefulWidget {
  final String entityType;
  final int entityId;
  final String? entityName;
  final int? ingredientId;
  final String? ingredientName;
  final String currency;
  final EntityRepository? repository;

  const EntityQuantityLinksSection({
    super.key,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.ingredientId,
    this.ingredientName,
    this.currency = 'CNY',
    this.repository,
  });

  @override
  State<EntityQuantityLinksSection> createState() =>
      _EntityQuantityLinksSectionState();
}

class _EntityQuantityLinksSectionState
    extends State<EntityQuantityLinksSection> {
  late final EntityRepository _repo;
  List<EntityQuantityLink> _links = const [];
  List<EntityQuantityLink> _ingredientLinks = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? EntityRepository();
    _load();
  }

  @override
  void didUpdateWidget(covariant EntityQuantityLinksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityId != widget.entityId ||
        oldWidget.entityType != widget.entityType) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final links = await _repo.listQuantityLinks(
        widget.entityType,
        widget.entityId,
      );
      List<EntityQuantityLink> ingredientLinks = const [];
      if (widget.entityType == 'product' && widget.ingredientId != null) {
        ingredientLinks = await _repo.listQuantityLinks(
          'ingredient',
          widget.ingredientId!,
        );
      }
      if (!mounted) return;
      setState(() {
        _links = links;
        _ingredientLinks = ingredientLinks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _links = const [];
        _ingredientLinks = const [];
        _loading = false;
      });
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openEditor({EntityQuantityLink? editing}) async {
    final l10n = AppLocalizations.of(context);
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EntityQuantityLinkEditPage(
          repository: _repo,
          entityType: widget.entityType,
          entityId: widget.entityId,
          entityName: widget.entityName,
          ingredientId: widget.ingredientId,
          link: editing,
        ),
      ),
    );
    if (result == null) return;
    await _load();
    if (!mounted) return;
    _toast(result == 'pending'
        ? l10n.commonSubmittedPendingReview
        : l10n.entityLinksSaved);
  }

  Future<void> _delete(EntityQuantityLink link) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.entityLinksDelete),
        content: Text(l10n.entityLinksDeleteConfirm),
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
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final res = await _repo.deleteQuantityLink(
        widget.entityType,
        widget.entityId,
        link.id,
      );
      if (!mounted) return;
      _toast(res.pending ? l10n.entityLinksPending : l10n.entityLinksDeleted);
      await _load();
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.entityLinksTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : () => _openEditor(),
              icon: const Icon(Icons.link, size: 18),
              label: Text(l10n.entityLinksAdd),
            ),
          ],
        ),
        Text(
          l10n.entityLinksHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.commonLoading,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          if (_links.isEmpty)
            Text(
              l10n.entityLinksEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final link in _links)
            _LinkRow(
              link: link,
              currency: widget.currency,
              busy: _busy,
              onEdit: () => _openEditor(editing: link),
              onDelete: () => _delete(link),
            ),
          if (_ingredientLinks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.entityLinksReadOnlyScope(widget.ingredientName ?? '—'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final link in _ingredientLinks)
              _LinkRow(
                link: link,
                currency: widget.currency,
                busy: true,
                onEdit: null,
                onDelete: null,
              ),
          ],
        ],
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final EntityQuantityLink link;
  final String currency;
  final bool busy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _LinkRow({
    required this.link,
    required this.currency,
    required this.busy,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final grams = link.gramsSelfCheck;
    final price = link.equivalentCurrentPrice;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: link.pending
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.35)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  link.sentence,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (link.pending)
                Chip(
                  label: Text(l10n.entityLinksPending),
                  visualDensity: VisualDensity.compact,
                )
              else if (onEdit != null && onDelete != null)
                Wrap(
                  children: [
                    IconButton(
                      tooltip: l10n.entityLinksEdit,
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: l10n.entityLinksDelete,
                      onPressed: busy ? null : onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
            ],
          ),
          if (grams != null)
            Text(
              grams,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (price != null)
            Text(
              '≈ ${formatMoney(price, currency)} / ${link.current.unit}',
              style: theme.textTheme.bodySmall,
            )
          else
            Text(
              l10n.entityLinksNoPrice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (!link.resolvable)
            Text(
              l10n.entityLinksUnresolvable(link.current.unit, link.other.unit),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (link.note != null && link.note!.isNotEmpty)
            Text(
              link.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

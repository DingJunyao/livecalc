import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../models/entity_quantity_link.dart';
import '../utils/currency_fmt.dart';
import '../../features/entities/repositories/entity_repository.dart';

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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _QuantityLinkDialog(
        repository: _repo,
        entityType: widget.entityType,
        entityId: widget.entityId,
        entityName: widget.entityName,
        editing: editing,
        l10n: l10n,
      ),
    );
    if (result != true) return;
    await _load();
    if (mounted) _toast(l10n.entityLinksSaved);
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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

class _QuantityLinkDialog extends StatefulWidget {
  final EntityRepository repository;
  final String entityType;
  final int entityId;
  final String? entityName;
  final EntityQuantityLink? editing;
  final AppLocalizations l10n;

  const _QuantityLinkDialog({
    required this.repository,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.editing,
    required this.l10n,
  });

  @override
  State<_QuantityLinkDialog> createState() => _QuantityLinkDialogState();
}

class _QuantityLinkDialogState extends State<_QuantityLinkDialog> {
  final _search = TextEditingController();
  final _fromQty = TextEditingController(text: '1');
  final _fromUnit = TextEditingController();
  final _toQty = TextEditingController(text: '1');
  final _toUnit = TextEditingController();
  final _note = TextEditingController();
  Timer? _debounce;
  int _searchSeq = 0;
  String _targetType = 'product';
  Map<String, dynamic>? _target;
  List<Map<String, dynamic>> _options = const [];
  bool _searching = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _targetType = editing.other.type;
      _target = {
        'id': editing.other.id,
        'name': editing.other.name,
        'ingredient_id': editing.other.ingredientId,
      };
      _fromQty.text = _fmt(editing.current.quantity);
      _fromUnit.text = editing.current.unit;
      _toQty.text = _fmt(editing.other.quantity);
      _toUnit.text = editing.other.unit;
      _note.text = editing.note ?? '';
    } else {
      _targetType = widget.entityType == 'product' ? 'product' : 'ingredient';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _fromQty.dispose();
    _fromUnit.dispose();
    _toQty.dispose();
    _toUnit.dispose();
    _note.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _options = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final seq = ++_searchSeq;
      setState(() => _searching = true);
      try {
        final rows = await widget.repository
            .searchQuantityLinkTargets(_targetType, query);
        if (!mounted || seq != _searchSeq) return;
        setState(() => _options = rows);
      } finally {
        if (mounted && seq == _searchSeq) {
          setState(() => _searching = false);
        }
      }
    });
  }

  String get _preview {
    final fromName = widget.entityName ?? '—';
    final toName = _target?['name']?.toString() ?? '—';
    return '${_fromQty.text.trim()} ${_fromUnit.text.trim()} $fromName'
        ' = ${_toQty.text.trim()} ${_toUnit.text.trim()} $toName';
  }

  Future<void> _save() async {
    final l10n = widget.l10n;
    final targetId = (_target?['id'] as num?)?.toInt();
    final fromQty = double.tryParse(_fromQty.text.trim());
    final toQty = double.tryParse(_toQty.text.trim());
    if (targetId == null) {
      _show(l10n.entityLinksTargetRequired);
      return;
    }
    if (fromQty == null || fromQty <= 0 || toQty == null || toQty <= 0) {
      _show(l10n.entityLinksQuantityInvalid);
      return;
    }
    if (_fromUnit.text.trim().isEmpty || _toUnit.text.trim().isEmpty) {
      _show(l10n.entityLinksUnitRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final editing = widget.editing;
      if (editing != null) {
        await widget.repository.updateQuantityLink(
          widget.entityType, widget.entityId, editing.id,
          fromQuantity: fromQty,
          fromUnit: _fromUnit.text.trim(),
          toQuantity: toQty,
          toUnit: _toUnit.text.trim(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
      } else {
        await widget.repository.createQuantityLink(
          widget.entityType, widget.entityId,
          toType: _targetType,
          toId: targetId,
          fromQuantity: fromQty,
          fromUnit: _fromUnit.text.trim(),
          toQuantity: toQty,
          toUnit: _toUnit.text.trim(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final editing = widget.editing != null;
    return AlertDialog(
      title: Text(editing ? l10n.entityLinksEdit : l10n.entityLinksAdd),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.entityLinksCurrent}: ${widget.entityName ?? '—'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'product',
                    label: Text(l10n.entityLinksProduct),
                  ),
                  ButtonSegment(
                    value: 'ingredient',
                    label: Text(l10n.entityLinksIngredient),
                  ),
                ],
                selected: {_targetType},
                onSelectionChanged: editing
                    ? null
                    : (values) => setState(() {
                          _targetType = values.first;
                          _target = null;
                          _options = const [];
                          _search.clear();
                        }),
              ),
              const SizedBox(height: 8),
              if (!editing)
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: l10n.entityLinksSearch,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onSearch,
                ),
              if (!editing && _options.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final row in _options)
                        ListTile(
                          dense: true,
                          title: Text(row['name']?.toString() ?? '—'),
                          subtitle: row['ingredient_name'] != null
                              ? Text(row['ingredient_name'].toString())
                              : null,
                          selected: _target?['id'] == row['id'],
                          onTap: () => setState(() => _target = row),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fromQty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.entityLinksQuantity,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fromUnit,
                      decoration: InputDecoration(
                        labelText: l10n.entityLinksUnit,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _toQty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.entityLinksQuantity,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _toUnit,
                      decoration: InputDecoration(
                        labelText: l10n.entityLinksUnit,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${l10n.entityLinksPreview}: $_preview',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l10n.entityLinksNote,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.commonSave),
        ),
      ],
    );
  }
}

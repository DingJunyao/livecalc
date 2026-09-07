import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/hierarchy_relation.dart';
import '../../../l10n/app_localizations.dart';
import '../../entities/repositories/entity_repository.dart';
import '../models/ingredient.dart';
import '../repositories/ingredient_repository.dart';
import '../widgets/hierarchy_graph.dart';

class HierarchyWriteInput {
  final int targetId;
  final String relationType;
  final int strength;

  const HierarchyWriteInput({
    required this.targetId,
    required this.relationType,
    required this.strength,
  });
}

class IngredientHierarchyArguments {
  final int ingredientId;
  final String ingredientName;
  final IngredientHierarchyData? hierarchyData;
  final bool loading;
  final bool isAdmin;
  final Future<Object?> Function(HierarchyWriteInput input) onAdd;
  final Future<Object?> Function(int relationId, int strength) onUpdateStrength;
  final Future<Object?> Function(int relationId) onDelete;

  const IngredientHierarchyArguments({
    required this.ingredientId,
    required this.ingredientName,
    required this.hierarchyData,
    required this.loading,
    required this.isAdmin,
    required this.onAdd,
    required this.onUpdateStrength,
    required this.onDelete,
  });
}

class IngredientHierarchyScreen extends StatefulWidget {
  final int ingredientId;
  final String ingredientName;
  final IngredientHierarchyData? hierarchyData;
  final bool loading;
  final bool isAdmin;
  final Future<Object?> Function(HierarchyWriteInput input) onAdd;
  final Future<Object?> Function(int relationId, int strength) onUpdateStrength;
  final Future<Object?> Function(int relationId) onDelete;

  const IngredientHierarchyScreen({
    super.key,
    required this.ingredientId,
    required this.ingredientName,
    required this.hierarchyData,
    this.loading = false,
    required this.isAdmin,
    required this.onAdd,
    required this.onUpdateStrength,
    required this.onDelete,
  });

  @override
  State<IngredientHierarchyScreen> createState() =>
      _IngredientHierarchyScreenState();
}

class _IngredientHierarchyScreenState extends State<IngredientHierarchyScreen> {
  final _searchController = TextEditingController();
  final _repository = IngredientRepository();
  Timer? _debounce;
  List<Ingredient> _options = const [];
  Ingredient? _selected;
  HierarchyRelation? _editing;
  String _relationType = 'contains';
  int _strength = 50;
  bool _searching = false;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        setState(() {
          _options = const [];
          _searching = false;
        });
        return;
      }
      setState(() => _searching = true);
      try {
        final page = await _repository.search(search: query, limit: 20);
        if (mounted) {
          setState(() {
            _options = page.items
                .where((item) => item.id != widget.ingredientId)
                .toList();
            _searching = false;
          });
        }
      } on Exception {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final editing = _editing;
    if (editing != null) {
      await _run(() => widget.onUpdateStrength(editing.id, _strength));
      return;
    }
    final selected = _selected;
    if (selected == null) {
      _toast(l10n.ingredientSelectRelation);
      return;
    }
    await _run(
      () => widget.onAdd(
        HierarchyWriteInput(
          targetId: selected.id,
          relationType: _relationType,
          strength: _strength,
        ),
      ),
      onApplied: () {
        setState(() {
          _selected = null;
          _searchController.clear();
          _options = const [];
        });
      },
    );
  }

  Future<void> _delete(HierarchyRelation relation) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.ingredientDeleteRelation),
        content: Text(
          l10n.ingredientDeleteRelationMessage,
        ),
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
    await _run(() => widget.onDelete(relation.id));
  }

  Future<void> _run(
    Future<Object?> Function() action, {
    VoidCallback? onApplied,
  }) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final result = await action();
      if (!mounted) return;
      if (result is EntityWriteResult && result.pending) {
        _toast(
          result.message.isEmpty
              ? l10n.commonSubmittedPendingReview
              : result.message,
        );
        return;
      }
      setState(() {
        _changed = true;
        _editing = null;
      });
      onApplied?.call();
    } on Exception {
      if (mounted) _toast(l10n.commonSaveFailedRetry);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.ingredientManageRelations),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_changed),
              child: Text(l10n.commonDone),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.ingredientRelationGraph),
              Tab(text: l10n.ingredientRelationList),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildForm(),
                const SizedBox(height: 16),
                HierarchyGraph(
                  ingredientId: widget.ingredientId,
                  ingredientName: widget.ingredientName,
                  hierarchyData: widget.hierarchyData,
                  relationFallbackName: l10n.ingredientRelationFallbackName,
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildForm(),
                const SizedBox(height: 16),
                ..._relations().map(
                  (relation) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _relationPairLabel(relation, l10n),
                    ),
                    subtitle: Text(
                      '${_relationLabel(relation.relationType, l10n)}'
                      ' · ${l10n.journeyRelationStrength(relation.strength)}',
                    ),
                    trailing: relation.isPending
                        ? Chip(label: Text(l10n.unitsPendingReview))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.journeyAdjustStrength,
                                onPressed: () => setState(() {
                                  _editing = relation;
                                  _strength = relation.strength;
                                }),
                                icon: const Icon(Icons.tune),
                              ),
                              IconButton(
                                tooltip: l10n.commonDelete,
                                onPressed:
                                    _saving ? null : () => _delete(relation),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editing == null
                  ? l10n.ingredientAddRelation
                  : l10n.ingredientAdjustRelationStrength,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_editing != null) ...[
              Text(_relationPairLabel(_editing!, l10n)),
              TextButton(
                onPressed: () => setState(() => _editing = null),
                child: Text(l10n.ingredientChangeToAddRelation),
              ),
            ] else ...[
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: l10n.ingredientSearchRelation,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(
                    label: Text(_selected!.name),
                    onDeleted: () => setState(() => _selected = null),
                  ),
                ),
              if (_options.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _options.length,
                    itemBuilder: (context, index) {
                      final ingredient = _options[index];
                      return ListTile(
                        dense: true,
                        title: Text(ingredient.name),
                        onTap: () => setState(() {
                          _selected = ingredient;
                          _searchController.text = ingredient.name;
                          _options = const [];
                        }),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _relationType,
                decoration: InputDecoration(
                  labelText: l10n.ingredientRelationType,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'contains',
                    child: Text(l10n.ingredientRelationContains),
                  ),
                  DropdownMenuItem(
                    value: 'substitutable',
                    child: Text(l10n.ingredientRelationSubstitutable),
                  ),
                  DropdownMenuItem(
                    value: 'fallback',
                    child: Text(l10n.ingredientRelationFallback),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _relationType = value ?? 'contains'),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.journeyRelationStrength(_strength)),
                Expanded(
                  child: Slider(
                    value: _strength.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '$_strength',
                    onChanged: (value) =>
                        setState(() => _strength = value.round()),
                  ),
                ),
              ],
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.ingredientSaveRelation),
            ),
          ],
        ),
      ),
    );
  }

  List<HierarchyRelation> _relations() {
    final data = widget.hierarchyData;
    if (data == null) return const [];
    return [
      ...data.childRelations,
      ...data.parentRelations,
      for (final expanded in data.expandedRelations) ...expanded.childRelations,
      for (final expanded in data.expandedRelations)
        ...expanded.parentRelations,
    ];
  }

  String _relationLabel(String type, AppLocalizations l10n) => switch (type) {
        'contains' => l10n.ingredientRelationContains,
        'substitutable' => l10n.ingredientRelationSubstitutable,
        'fallback' => l10n.ingredientRelationFallback,
        _ => type,
      };

  String _relationPairLabel(
    HierarchyRelation relation,
    AppLocalizations l10n,
  ) {
    return '${ingredientRelationEndpointDisplay(
      storedName: relation.parentName,
      ingredientId: relation.parentId,
      fallbackName: l10n.ingredientRelationFallbackName,
    )} → ${ingredientRelationEndpointDisplay(
      storedName: relation.childName,
      ingredientId: relation.childId,
      fallbackName: l10n.ingredientRelationFallbackName,
    )}';
  }
}

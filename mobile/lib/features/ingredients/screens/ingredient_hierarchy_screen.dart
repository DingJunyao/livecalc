import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/i18n/app_formatters.dart';
import '../../../shared/models/hierarchy_relation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/directional_icons.dart';
import '../../entities/repositories/entity_repository.dart';
import '../models/ingredient.dart';
import '../repositories/ingredient_repository.dart';
import '../widgets/hierarchy_graph.dart';

class HierarchyWriteInput {
  final int targetId;
  final String relationType;
  final int strength;
  final HierarchyFactorInput? factor;

  const HierarchyWriteInput({
    required this.targetId,
    required this.relationType,
    required this.strength,
    this.factor,
  });
}

class HierarchyUpdateInput {
  final int relationId;
  final int strength;
  final HierarchyFactorInput? factor;

  const HierarchyUpdateInput({
    required this.relationId,
    required this.strength,
    this.factor,
  });
}

class IngredientHierarchyArguments {
  final int ingredientId;
  final String ingredientName;
  final IngredientHierarchyData? hierarchyData;
  final bool loading;
  final bool isAdmin;
  final Future<Object?> Function(HierarchyWriteInput input) onAdd;
  final Future<Object?> Function(HierarchyUpdateInput input) onUpdateStrength;
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
  final Future<Object?> Function(HierarchyUpdateInput input) onUpdateStrength;
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
  int _searchSequence = 0;
  List<Ingredient> _options = const [];
  Ingredient? _selected;
  HierarchyRelation? _editing;
  String _relationType = 'contains';
  int _strength = 50;
  bool _searching = false;
  bool _saving = false;
  bool _changed = false;
  bool _factorExpanded = false;
  final _factorParentQty = TextEditingController();
  final _factorParentUnit = TextEditingController();
  final _factorChildQty = TextEditingController();
  final _factorChildUnit = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _factorParentQty.dispose();
    _factorParentUnit.dispose();
    _factorChildQty.dispose();
    _factorChildUnit.dispose();
    super.dispose();
  }

  /// 解析四个系数输入：全空返回 null（= 1:1 / 清除），不完整返回 false 标记。
  ({HierarchyFactorInput? factor, bool incomplete}) _parseFactor() {
    final parentQty = double.tryParse(_factorParentQty.text.trim());
    final parentUnit = _factorParentUnit.text.trim();
    final childQty = double.tryParse(_factorChildQty.text.trim());
    final childUnit = _factorChildUnit.text.trim();
    final anyFilled = parentQty != null ||
        parentUnit.isNotEmpty ||
        childQty != null ||
        childUnit.isNotEmpty;
    final allFilled = parentQty != null &&
        parentQty > 0 &&
        parentUnit.isNotEmpty &&
        childQty != null &&
        childQty > 0 &&
        childUnit.isNotEmpty;
    if (!anyFilled) return (factor: null, incomplete: false);
    if (!allFilled) return (factor: null, incomplete: true);
    return (
      factor: HierarchyFactorInput(
        parentQuantity: parentQty,
        parentUnit: parentUnit,
        childQuantity: childQty,
        childUnit: childUnit,
      ),
      incomplete: false,
    );
  }

  void _loadFactorFrom(HierarchyRelation relation) {
    _factorParentQty.text = relation.factorParentQuantity == null
        ? ''
        : formatQuantity(relation.factorParentQuantity!);
    _factorParentUnit.text = relation.factorParentUnit ?? '';
    _factorChildQty.text = relation.factorChildQuantity == null
        ? ''
        : formatQuantity(relation.factorChildQuantity!);
    _factorChildUnit.text = relation.factorChildUnit ?? '';
    _factorExpanded = relation.hasFactor;
  }

  void _clearFactor() {
    _factorParentQty.clear();
    _factorParentUnit.clear();
    _factorChildQty.clear();
    _factorChildUnit.clear();
  }

  /// 等式实时预览：`1 kg 干 = 3 kg 鲜`（按当前填写的父/子，名称随表单选择）。
  String? _factorPreview(AppLocalizations l10n) {
    final parsed = _parseFactor();
    if (parsed.factor != null) {
      // 表单语义：当前原料为父、选中的目标为子（与 onAdd 的 parent/child 一致）。
      final parentName = widget.ingredientName;
      final childName = _editing != null
          ? ingredientRelationEndpointDisplay(
              storedName: _editing!.childName,
              ingredientId: _editing!.childId,
              fallbackName: l10n.ingredientRelationFallbackName,
            )
          : (_selected?.name ?? l10n.ingredientRelationFallbackName);
      return '${formatQuantity(parsed.factor!.parentQuantity)} '
          '${parsed.factor!.parentUnit} $parentName = '
          '${formatQuantity(parsed.factor!.childQuantity)} '
          '${parsed.factor!.childUnit} $childName';
    }
    return null;
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = _searchController.text.trim();
      final searchSequence = ++_searchSequence;
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
        if (mounted && searchSequence == _searchSequence) {
          setState(() {
            _options = page.items
                .where((item) => item.id != widget.ingredientId)
                .toList();
            _searching = false;
          });
        }
      } on Exception {
        if (mounted && searchSequence == _searchSequence) {
          setState(() => _searching = false);
        }
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final editing = _editing;
    final parsedFactor = _parseFactor();
    if (parsedFactor.incomplete) {
      _toast(l10n.hierarchyFactorIncomplete);
      return;
    }
    if (editing != null) {
      await _run(
        () => widget.onUpdateStrength(
          HierarchyUpdateInput(
            relationId: editing.id,
            strength: _strength,
            factor: parsedFactor.factor,
          ),
        ),
      );
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
          factor: parsedFactor.factor,
        ),
      ),
      onApplied: () {
        setState(() {
          _selected = null;
          _searchController.clear();
          _options = const [];
          _clearFactor();
          _factorExpanded = false;
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
                  (relation) {
                    final equation = relation.factorEquation();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _relationPairLabel(context, relation, l10n),
                      ),
                      subtitle: Text(
                        '${_relationLabel(relation.relationType, l10n)}'
                        ' · ${l10n.journeyRelationStrength(formatNumber(relation.strength))}'
                        '${equation == null ? '' : '\n$equation'}',
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
                                    _loadFactorFrom(relation);
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
                    );
                  },
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
            // 保存按钮放在卡片标题行右上角，避免软键盘遮挡底部的确认按钮。
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing == null
                        ? l10n.ingredientAddRelation
                        : l10n.ingredientAdjustRelationStrength,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.ingredientSaveRelation),
                ),
              ],
            ),
            if (_editing != null) ...[
              Text(_relationPairLabel(context, _editing!, l10n)),
              TextButton(
                onPressed: () => setState(() {
                  _editing = null;
                  _clearFactor();
                  _factorExpanded = false;
                }),
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
            _buildFactorSection(l10n, theme),
            Row(
              children: [
                Text(l10n.journeyRelationStrength(formatNumber(_strength))),
                Expanded(
                  child: Slider(
                    value: _strength.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: formatNumber(_strength),
                    onChanged: (value) =>
                        setState(() => _strength = value.round()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 换算系数区（默认收起）：父数量/父单位 = 子数量/子单位，实时等式预览。
  Widget _buildFactorSection(AppLocalizations l10n, ThemeData theme) {
    final preview = _factorPreview(l10n);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      initiallyExpanded: _factorExpanded,
      onExpansionChanged: (value) => _factorExpanded = value,
      title: Text(
        l10n.hierarchyFactorSection,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        preview ?? l10n.hierarchyFactorDefaultHint,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _factorParentQty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.hierarchyFactorParentQuantity,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: TextField(
                controller: _factorParentUnit,
                decoration: InputDecoration(
                  labelText: l10n.hierarchyFactorParentUnit,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Icon(Icons.drag_handle, size: 20),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _factorChildQty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.hierarchyFactorChildQuantity,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: TextField(
                controller: _factorChildUnit,
                decoration: InputDecoration(
                  labelText: l10n.hierarchyFactorChildUnit,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (preview != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${l10n.hierarchyFactorPreview}: $preview',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
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
    BuildContext context,
    HierarchyRelation relation,
    AppLocalizations l10n,
  ) {
    return '${ingredientRelationEndpointDisplay(
      storedName: relation.parentName,
      ingredientId: relation.parentId,
      fallbackName: l10n.ingredientRelationFallbackName,
    )} ${DirectionalIcons.flowArrow(context)} ${ingredientRelationEndpointDisplay(
      storedName: relation.childName,
      ingredientId: relation.childId,
      fallbackName: l10n.ingredientRelationFallbackName,
    )}';
  }
}

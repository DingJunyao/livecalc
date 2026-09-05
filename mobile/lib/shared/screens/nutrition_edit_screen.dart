import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/i18n/app_formatters.dart';
import '../../features/nutrition/models/usda_models.dart';
import '../../features/nutrition/repositories/usda_repository.dart';
import '../../l10n/app_localizations.dart';
import '../models/nutrition.dart';

class NutritionEditResult {
  final bool saved;
  final bool pending;
  final bool clear;

  const NutritionEditResult({
    this.saved = false,
    this.pending = false,
    this.clear = false,
  });
}

class NutritionEditArguments {
  final String entityType;
  final int entityId;
  final String? entityName;
  final NutritionInfo? nutrition;
  final bool allowClear;
  final Future<void> Function()? onRefresh;
  final Future<Object?> Function(List<NutrientEntry>) onSave;
  final Future<Object?> Function()? onClear;

  const NutritionEditArguments({
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.nutrition,
    this.allowClear = false,
    this.onRefresh,
    required this.onSave,
    this.onClear,
  });
}

class NutritionEditScreen extends StatefulWidget {
  final String entityType;
  final int entityId;
  final String? entityName;
  final NutritionInfo? nutrition;
  final List<NutrientEntry> initialNutrients;
  final bool allowClear;
  final Future<void> Function()? onRefresh;
  final Future<Object?> Function(List<NutrientEntry>)? onSave;
  final Future<Object?> Function()? onClear;
  final UsdaRepository? usdaRepository;

  const NutritionEditScreen({
    super.key,
    this.entityType = 'ingredient',
    this.entityId = 0,
    this.entityName,
    this.nutrition,
    this.initialNutrients = const [],
    this.allowClear = false,
    this.onRefresh,
    this.onSave,
    this.onClear,
    this.usdaRepository,
  });

  @override
  State<NutritionEditScreen> createState() => _NutritionEditScreenState();
}

class _NutritionEditScreenState extends State<NutritionEditScreen> {
  final _rows = <_NutritionEditRow>[];
  final _searchController = TextEditingController();
  final _usdaRepo = UsdaRepository();
  Timer? _debounce;
  List<UsdaFood> _results = const [];
  UsdaFood? _selected;
  bool _searching = false;
  bool _saving = false;
  bool _usdaMode = false;

  @override
  void initState() {
    super.initState();
    final initialNutrients = widget.initialNutrients.isNotEmpty
        ? widget.initialNutrients
        : widget.nutrition?.nutrients ?? const <NutrientEntry>[];
    _rows.addAll([
      for (final nutrient in initialNutrients) _NutritionEditRow.from(nutrient),
    ]);
    if (_rows.isEmpty) _addRow();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    _rows.add(_NutritionEditRow());
  }

  void _removeRow(int index) {
    _rows[index].controller.dispose();
    _rows.removeAt(index);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _searchUsda);
  }

  Future<void> _searchUsda() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await (widget.usdaRepository ?? _usdaRepo).search(query);
      if (mounted) {
        setState(() {
          _results = results;
          _selected = null;
          _searching = false;
        });
      }
    } on Exception {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickFood(UsdaFood food) async {
    setState(() => _searching = true);
    try {
      final detail =
          await (widget.usdaRepository ?? _usdaRepo).getFood(food.fdcId);
      if (mounted) setState(() => _selected = detail);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).nutritionUsdaLoadFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _confirmUsdaMatch() async {
    final food = _selected;
    if (food == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).nutritionConfirmMatch),
        content: Text(
          AppLocalizations.of(context).nutritionConfirmMatchDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).nutritionConfirmWrite),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runMutation(() async {
      return (widget.usdaRepository ?? _usdaRepo).match(
        entityType: widget.entityType,
        entityId: widget.entityId,
        fdcId: food.fdcId,
      );
    }, onRefresh: widget.onRefresh);
  }

  Future<void> _saveManual() async {
    final entries = <NutrientEntry>[];
    for (final row in _rows) {
      final value = row.value;
      if (row.label.isEmpty || value == null || value <= 0) continue;
      entries.add(NutrientEntry(
        key: row.label,
        label: row.label,
        value: value,
        unit: row.unit,
        originalKey: row.originalKey,
      ));
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).nutritionAtLeastOne),
        ),
      );
      return;
    }
    await _runMutation(() async => await widget.onSave?.call(entries));
  }

  Future<void> _clearCustom() async {
    await _runMutation(
      () async => await widget.onClear?.call(),
      clear: true,
    );
  }

  Future<void> _runMutation(
    Future<Object?> Function() action, {
    bool clear = false,
    Future<void> Function()? onRefresh,
  }) async {
    setState(() => _saving = true);
    try {
      final response = await action();
      if (!mounted) return;
      var pending = false;
      var message = '';
      if (response is MutationReviewResult) {
        pending = response.pending;
        message = response.message;
      }
      await onRefresh?.call();
      if (!mounted) return;
      if (pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.isEmpty
                  ? AppLocalizations.of(context).commonSubmittedPendingReview
                  : message,
            ),
          ),
        );
        Navigator.of(context)
            .pop(const NutritionEditResult(saved: true, pending: true));
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(NutritionEditResult(saved: true, clear: clear));
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).commonSaveFailedRetry,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entityName == null
            ? l10n.nutritionEditTitle
            : l10n.nutritionEditTitleWithName(widget.entityName!)),
        actions: [
          if (widget.allowClear && !_usdaMode)
            TextButton(
              onPressed: _saving ? null : _clearCustom,
              child: Text(l10n.nutritionClearCustom),
            ),
        ],
      ),
      body: Column(
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: false, label: Text(l10n.nutritionManualEdit)),
              const ButtonSegment(value: true, label: Text('USDA')),
            ],
            selected: {_usdaMode},
            onSelectionChanged: (values) =>
                setState(() => _usdaMode = values.first),
          ),
          Expanded(
            child: _usdaMode ? _buildUsdaPane(theme) : _buildManualPane(theme),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed:
                _saving ? null : (_usdaMode ? _confirmUsdaMatch : _saveManual),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _usdaMode ? l10n.nutritionConfirmMatch : l10n.commonSave,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualPane(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.nutritionNutrient)),
            SizedBox(width: 96, child: Text(l10n.nutritionQuantity)),
            SizedBox(width: 88, child: Text(l10n.nutritionUnit)),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _NutritionEditorRow(
              row: _rows[i],
              onDelete:
                  _rows.length > 1 ? () => setState(() => _removeRow(i)) : null,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _addRow()),
            icon: const Icon(Icons.add),
            label: Text(l10n.nutritionAddNutrient),
          ),
        ),
      ],
    );
  }

  Widget _buildUsdaPane(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;
    if (selected != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _selected = null),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.nutritionBackToList),
            ),
          ),
          Text(
            selected.displayName,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (selected.description != selected.displayName)
            Text(
              selected.description,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          const SizedBox(height: 12),
          for (final nutrient in selected.nutrients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(nutrient.displayName)),
                  Text(
                      '${_formatDisplayAmount(nutrient.amount)} ${nutrient.unit}'),
                ],
              ),
            ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchUsda(),
            decoration: InputDecoration(
              labelText: l10n.nutritionSearchLabel,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    l10n.nutritionUsdaSearchPrompt,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final food = _results[index];
                    return ListTile(
                      title: Text(food.displayName),
                      subtitle: Text(
                        l10n.nutritionUsdaResultDetail(
                          food.description,
                          food.dataType,
                          food.nutrientCount,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _pickFood(food),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NutritionEditRow {
  final TextEditingController controller;
  String label;
  String unit;
  String? originalKey;
  List<String> units;

  _NutritionEditRow({
    TextEditingController? controller,
    this.label = '',
    this.unit = 'g',
    this.originalKey,
    this.units = const ['g', 'mg', 'µg'],
  }) : controller = controller ?? TextEditingController();

  factory _NutritionEditRow.from(NutrientEntry entry) {
    return _NutritionEditRow(
      controller: TextEditingController(text: _formatAmount(entry.value)),
      label: entry.label,
      unit: entry.unit.isEmpty ? 'g' : entry.unit,
      originalKey: entry.originalKey,
      units: _unitsFor(entry.label, entry.unit),
    );
  }

  double? get value => double.tryParse(controller.text.trim());
}

const _nutrientOptions = <({String label, List<String> units})>[
  (label: '能量', units: ['kcal', 'kJ']),
  (label: '蛋白质', units: ['g']),
  (label: '脂肪', units: ['g']),
  (label: '碳水化合物', units: ['g']),
  (label: '膳食纤维', units: ['g']),
  (label: '钠', units: ['mg', 'g']),
  (label: '钾', units: ['mg', 'g']),
  (label: '钙', units: ['mg', 'g']),
  (label: '铁', units: ['mg', 'g']),
  (label: '锌', units: ['mg', 'g']),
  (label: '磷', units: ['mg', 'g']),
  (label: '镁', units: ['mg', 'g']),
  (label: '维生素A', units: ['µg', 'mg']),
  (label: '维生素C', units: ['mg', 'g']),
  (label: '维生素B1', units: ['mg']),
  (label: '维生素B2', units: ['mg']),
  (label: '维生素B6', units: ['mg']),
  (label: '维生素B12', units: ['µg']),
  (label: '维生素D', units: ['µg']),
  (label: '维生素E', units: ['mg']),
  (label: '维生素K', units: ['µg']),
  (label: '叶酸', units: ['µg']),
  (label: '烟酸', units: ['mg']),
  (label: '胆固醇', units: ['mg']),
  (label: '饱和脂肪', units: ['g']),
];

String _nutrientDisplayLabel(String label, AppLocalizations l10n) {
  return switch (label) {
    '能量' => l10n.nutritionNutrientEnergy,
    '蛋白质' => l10n.nutritionNutrientProtein,
    '脂肪' => l10n.nutritionNutrientFat,
    '碳水化合物' => l10n.nutritionNutrientCarbohydrate,
    '膳食纤维' => l10n.nutritionNutrientDietaryFiber,
    '钠' => l10n.nutritionNutrientSodium,
    '钾' => l10n.nutritionNutrientPotassium,
    '钙' => l10n.nutritionNutrientCalcium,
    '铁' => l10n.nutritionNutrientIron,
    '锌' => l10n.nutritionNutrientZinc,
    '磷' => l10n.nutritionNutrientPhosphorus,
    '镁' => l10n.nutritionNutrientMagnesium,
    '维生素A' => l10n.nutritionNutrientVitaminA,
    '维生素C' => l10n.nutritionNutrientVitaminC,
    '维生素B1' => l10n.nutritionNutrientVitaminB1,
    '维生素B2' => l10n.nutritionNutrientVitaminB2,
    '维生素B6' => l10n.nutritionNutrientVitaminB6,
    '维生素B12' => l10n.nutritionNutrientVitaminB12,
    '维生素D' => l10n.nutritionNutrientVitaminD,
    '维生素E' => l10n.nutritionNutrientVitaminE,
    '维生素K' => l10n.nutritionNutrientVitaminK,
    '叶酸' => l10n.nutritionNutrientFolate,
    '烟酸' => l10n.nutritionNutrientNiacin,
    '胆固醇' => l10n.nutritionNutrientCholesterol,
    '饱和脂肪' => l10n.nutritionNutrientSaturatedFat,
    _ => label,
  };
}

List<String> _unitsFor(String label, String currentUnit) {
  for (final option in _nutrientOptions) {
    if (option.label == label) return option.units;
  }
  return [if (currentUnit.isNotEmpty) currentUnit, 'g', 'mg', 'µg'];
}

String _formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _formatDisplayAmount(double value) => formatQuantity(value);

class _NutritionEditorRow extends StatefulWidget {
  final _NutritionEditRow row;
  final VoidCallback? onDelete;

  const _NutritionEditorRow({required this.row, this.onDelete});

  @override
  State<_NutritionEditorRow> createState() => _NutritionEditorRowState();
}

class _NutritionEditorRowState extends State<_NutritionEditorRow> {
  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final l10n = AppLocalizations.of(context);
    final options = [
      ..._nutrientOptions,
      if (row.label.isNotEmpty &&
          !_nutrientOptions.any((option) => option.label == row.label))
        (label: row.label, units: row.units),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: row.label.isEmpty ? null : row.label,
          decoration: InputDecoration(
            labelText: l10n.nutritionNutrient,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          selectedItemBuilder: (context) => [
            for (final option in options)
              Text(_nutrientDisplayLabel(option.label, l10n)),
          ],
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option.label,
                child: Text(_nutrientDisplayLabel(option.label, l10n)),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              row.label = value;
              row.units = _unitsFor(value, row.unit);
              if (!row.units.contains(row.unit)) row.unit = row.units.first;
            });
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: row.controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: row.unit,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final unit in row.units.toSet())
                    DropdownMenuItem(value: unit, child: Text(unit)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => row.unit = value);
                },
              ),
            ),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import '../../features/nutrition/models/usda_models.dart';
import '../../features/nutrition/repositories/usda_repository.dart';
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
  final Future<Object?> Function(List<NutrientEntry>) onSave;
  final Future<Object?> Function()? onClear;

  const NutritionEditArguments({
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.nutrition,
    this.allowClear = false,
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
          const SnackBar(content: Text('USDA 数据加载失败')),
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
        title: const Text('确认匹配'),
        content: const Text('将清空当前营养数据并写入所选 USDA 食材的营养数据，此操作不可撤销。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认写入'),
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
    });
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
        const SnackBar(content: Text('请至少填写一项营养素')),
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
      if (pending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.isEmpty ? '已提交，待管理员审核' : message)),
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
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.entityName == null ? '编辑营养成分' : '${widget.entityName} · 营养'),
        actions: [
          if (widget.allowClear && !_usdaMode)
            TextButton(
              onPressed: _saving ? null : _clearCustom,
              child: const Text('清空自定义'),
            ),
        ],
      ),
      body: Column(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('手动编辑')),
              ButtonSegment(value: true, label: Text('USDA')),
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
                : Text(_usdaMode ? '确认匹配' : '保存'),
          ),
        ),
      ),
    );
  }

  Widget _buildManualPane(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          children: [
            Expanded(child: Text('营养素')),
            SizedBox(width: 96, child: Text('数量')),
            SizedBox(width: 88, child: Text('单位')),
            SizedBox(width: 40),
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
            label: const Text('添加营养素'),
          ),
        ),
      ],
    );
  }

  Widget _buildUsdaPane(ThemeData theme) {
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
              label: const Text('返回列表'),
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
                  Text('${_formatAmount(nutrient.amount)} ${nutrient.unit}'),
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
            decoration: const InputDecoration(
              labelText: '搜索（原文/译文任意命中）',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    '输入关键词搜索 USDA 食材',
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
                        '${food.description} · ${food.dataType} · ${food.nutrientCount} 项营养素',
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
          decoration: const InputDecoration(
            labelText: '营养素',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option.label, child: Text(option.label)),
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

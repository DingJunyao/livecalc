import 'package:flutter/material.dart';
import '../models/nutrition.dart';

/// 营养编辑行。
class _NutritionEditRow {
  String label;
  final TextEditingController valueController;
  String unit;
  final String? originalKey;
  List<String> units;

  _NutritionEditRow({
    required this.label,
    required this.valueController,
    required this.unit,
    this.originalKey,
    required this.units,
  });

  double? get value => double.tryParse(valueController.text.trim());
}

const _nutrientOptions = <({String label, List<String> units})>[
  (label: '能量', units: ['kcal', 'kJ']),
  (label: '蛋白质', units: ['g']),
  (label: '脂肪', units: ['g']),
  (label: '碳水化合物', units: ['g']),
  (label: '膳食纤维', units: ['g']),
  (label: '钠', units: ['mg', 'g']),
  (label: '钙', units: ['mg', 'g']),
  (label: '铁', units: ['mg', 'g']),
  (label: '钾', units: ['mg', 'g']),
  (label: '磷', units: ['mg', 'g']),
  (label: '镁', units: ['mg', 'g']),
  (label: '锌', units: ['mg', 'g']),
  (label: '维生素A', units: ['μg', 'mg']),
  (label: '维生素C', units: ['mg', 'g']),
  (label: '维生素B1', units: ['mg']),
  (label: '维生素B2', units: ['mg']),
  (label: '维生素B6', units: ['mg']),
  (label: '维生素B12', units: ['μg']),
  (label: '维生素D', units: ['μg']),
  (label: '维生素E', units: ['mg']),
  (label: '维生素K', units: ['μg']),
  (label: '叶酸', units: ['μg']),
  (label: '烟酸', units: ['mg']),
  (label: '胆固醇', units: ['mg']),
  (label: '饱和脂肪', units: ['g']),
];

List<String> _unitsForLabel(String label) {
  for (final o in _nutrientOptions) {
    if (o.label == label) return o.units;
  }
  return const ['g', 'mg', 'μg'];
}

/// 营养成分卡片（原料/商品共用），支持编辑与（商品）清空自定义数据。
class NutritionCard extends StatelessWidget {
  final NutritionInfo? nutrition;
  final bool loading;
  final bool saving;
  final bool allowClear;
  final Future<void> Function(List<NutrientEntry>) onSave;
  final Future<void> Function()? onClear;

  const NutritionCard({
    super.key,
    required this.nutrition,
    required this.loading,
    required this.saving,
    this.allowClear = false,
    required this.onSave,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = nutrition;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.food_bank_outlined,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('营养成分',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Text('（每${_baseLabel(info)}）',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const Spacer(),
                if (!loading)
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => _openEditor(context),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('编辑'),
                  ),
              ],
            ),
            const Divider(height: 8),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (info == null || !info.hasData)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.no_food_outlined,
                          size: 40, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 8),
                      Text('暂无营养数据',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(height: 4),
                      Text('点击右上角「编辑」添加',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              )
            else
              _NutritionTable(info: info),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final info = nutrition;
    final initial = info == null
        ? <_NutritionEditRow>[]
        : [
            for (final n in info.nutrients)
              _NutritionEditRow(
                label: n.label,
                valueController: TextEditingController(
                  text: n.value.toStringAsFixed(
                    n.value == n.value.roundToDouble() ? 0 : 2,
                  ),
                ),
                unit: n.unit.isEmpty ? _unitsForLabel(n.label).first : n.unit,
                originalKey: n.originalKey,
                units: _unitsForLabel(n.label),
              ),
          ];
    final result = await showDialog<_NutritionEditResult>(
      context: context,
      builder: (_) => _NutritionEditorDialog(
        rows: initial,
        allowClear: allowClear,
      ),
    );
    if (result == null) return;
    if (result.clear && onClear != null) {
      await onClear!();
    } else if (result.nutrients.isNotEmpty) {
      await onSave(result.nutrients);
    }
  }
}

class _NutritionEditResult {
  final List<NutrientEntry> nutrients;
  final bool clear;
  const _NutritionEditResult(this.nutrients, {this.clear = false});
}

String _baseLabel(NutritionInfo? info) {
  final qty = info?.baseQuantity ?? 100;
  final unit = (info?.baseUnit ?? 'g').trim();
  final qtyStr =
      qty == qty.roundToDouble() ? qty.toInt().toString() : _fmtValue(qty);
  return unit.isEmpty ? '${qtyStr}g' : '$qtyStr$unit';
}

class _NutritionTable extends StatefulWidget {
  final NutritionInfo info;
  const _NutritionTable({required this.info});

  @override
  State<_NutritionTable> createState() => _NutritionTableState();
}

class _NutritionTableState extends State<_NutritionTable> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrients = widget.info.nutrients;
    final core = nutrients.length <= 5 ? nutrients : nutrients.take(5).toList();
    final others = nutrients.length <= 5
        ? <NutrientEntry>[]
        : nutrients.skip(5).toList();
    const valueW = 76.0;
    const nrvW = 56.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 表头（对齐菜谱详情营养成分表样式）
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: const Row(
            children: [
              Expanded(child: Text('营养素')),
              SizedBox(
                  width: valueW, child: Text('数量', textAlign: TextAlign.right)),
              SizedBox(
                  width: nrvW, child: Text('NRV%', textAlign: TextAlign.right)),
            ],
          ),
        ),
        ..._rows(theme, core, valueW, nrvW),
        if (others.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more,
                  size: 18),
              label: Text(_showAll ? '收起' : '展开 +${others.length} 项'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        if (_showAll) ..._rows(theme, others, valueW, nrvW),
        const SizedBox(height: 8),
        Text('NRV = 营养素参考值百分比',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }

  List<Widget> _rows(ThemeData theme, List<NutrientEntry> items,
      double valueW, double nrvW) {
    return [
      for (var i = 0; i < items.length; i++)
        Container(
          decoration: BoxDecoration(
            border: i == items.length - 1
                ? null
                : Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(items[i].label)),
              SizedBox(
                width: valueW,
                child: Text(
                  '${_fmtValue(items[i].value)} ${items[i].unit}',
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: nrvW,
                child: Text(
                  items[i].nrvPct == null
                      ? ''
                      : '${items[i].nrvPct!.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

String _fmtValue(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

class _NutritionEditorDialog extends StatefulWidget {
  final List<_NutritionEditRow> rows;
  final bool allowClear;
  const _NutritionEditorDialog({required this.rows, required this.allowClear});

  @override
  State<_NutritionEditorDialog> createState() =>
      _NutritionEditorDialogState();
}

class _NutritionEditorDialogState extends State<_NutritionEditorDialog> {
  late final List<_NutritionEditRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.rows;
    if (_rows.isEmpty) _addRow();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.valueController.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_NutritionEditRow(
        label: '',
        valueController: TextEditingController(),
        unit: 'g',
        units: const ['g', 'mg', 'μg'],
      ));
    });
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index));
  }

  void _save() {
    final entries = <NutrientEntry>[];
    for (final r in _rows) {
      final value = r.value;
      if (r.label.isEmpty) continue;
      if (value == null || value <= 0) continue;
      entries.add(NutrientEntry(
        key: r.label,
        label: r.label,
        value: value,
        unit: r.unit,
        originalKey: r.originalKey,
      ));
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少填写一项营养素')),
      );
      return;
    }
    Navigator.of(context).pop(_NutritionEditResult(entries));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('编辑营养成分'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('营养素',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('数量',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('单位',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const Divider(height: 12),
              for (var i = 0; i < _rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EditorRow(
                    row: _rows[i],
                    onDelete: _rows.length > 1 ? () => _removeRow(i) : null,
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加营养素'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.allowClear)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _NutritionEditResult([], clear: true)),
            child: const Text('清空自定义'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

class _EditorRow extends StatefulWidget {
  final _NutritionEditRow row;
  final VoidCallback? onDelete;
  const _EditorRow({required this.row, this.onDelete});

  @override
  State<_EditorRow> createState() => _EditorRowState();
}

class _EditorRowState extends State<_EditorRow> {
  String? _label;
  String? _unit;

  _NutritionEditRow get row => widget.row;

  /// 标准选项 + 数据中已存在的其他营养素（避免 initialValue 不在候选项中断言失败）。
  List<({String label, List<String> units})> get _allOptions {
    final result = List<({String label, List<String> units})>.of(
      _nutrientOptions,
    );
    final existing = result.map((o) => o.label).toSet();
    if (row.label.isNotEmpty && !existing.contains(row.label)) {
      result.add((label: row.label, units: row.units));
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _label = row.label.isEmpty ? null : row.label;
    _unit = row.unit.isEmpty ? null : row.unit;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue: _label,
            isExpanded: true,
            hint: const Text('选择营养素'),
            decoration: _decoration(),
            items: [
              for (final o in _allOptions)
                DropdownMenuItem(value: o.label, child: Text(o.label)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _label = v;
                row.label = v;
                row.units = _unitsForLabel(v);
                if (!row.units.contains(row.unit)) {
                  row.unit = row.units.first;
                  _unit = row.unit;
                }
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: row.valueController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            decoration: _decoration(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: InputDecorator(
            decoration: _decoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _unit,
                isExpanded: true,
                isDense: true,
                hint: const Text('单位'),
                items: [
                  for (final u in row.units)
                    DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _unit = v;
                      row.unit = v;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: theme.colorScheme.error,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onDelete,
        ),
      ],
    );
  }

  InputDecoration _decoration() => InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}

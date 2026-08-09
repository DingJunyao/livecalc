import 'package:flutter/material.dart';
import '../models/entity_unit.dart';

/// 单位与密度卡片（原料/商品共用）。
class EntityUnitsCard extends StatelessWidget {
  final List<EntityUnit> units;
  final List<UnmappedUnit> unmappedUnits;
  final List<EntityDensity> densities;
  final bool loading;
  final Future<void> Function({
    required String unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool isDefault,
  }) onAddUnit;
  final Future<void> Function(
    int unitId, {
    String? unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool? isDefault,
  }) onEditUnit;
  final Future<void> Function(int unitId) onDeleteUnit;
  final Future<void> Function(UnmappedUnit unit) onQuickAddUnmapped;
  final Future<void> Function({
    required double density,
    String? condition,
  }) onAddDensity;
  final Future<void> Function(int densityId) onDeleteDensity;

  const EntityUnitsCard({
    super.key,
    required this.units,
    required this.unmappedUnits,
    required this.densities,
    required this.loading,
    required this.onAddUnit,
    required this.onEditUnit,
    required this.onDeleteUnit,
    required this.onQuickAddUnmapped,
    required this.onAddDensity,
    required this.onDeleteDensity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten,
                    color: theme.colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Text('单位与密度',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('自定义单位',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () => _showUnitDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加单位'),
                ),
              ],
            ),
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
            else ...[
              if (unmappedUnits.isNotEmpty) ...[
                Text('待配置单位（来自菜谱，点击快速添加，默认 100 g）',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final u in unmappedUnits)
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14),
                        label: Text('${u.unitName}（${u.usageCount}次）'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onQuickAddUnmapped(u),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (units.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('暂无自定义单位',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                )
              else
                for (final u in units)
                  _UnitRow(
                    unit: u,
                    onEdit: () => _showUnitDialog(context, unit: u),
                    onDelete: () => onDeleteUnit(u.id),
                  ),
            ],
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('密度（kg/m³）',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () => _showDensityDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加密度'),
                ),
              ],
            ),
            if (densities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('暂无密度数据',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
              )
            else
              for (final d in densities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${d.density.toStringAsFixed(2)} kg/m³'
                          '${d.condition == null || d.condition!.isEmpty ? '' : '（${d.condition}）'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: theme.colorScheme.error,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onDeleteDensity(d.id),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUnitDialog(BuildContext context, {EntityUnit? unit}) async {
    final nameController = TextEditingController(text: unit?.unitName ?? '');
    final conversionController = TextEditingController(
      text: unit?.conversionFactor == null
          ? ''
          : _fmtNum(unit!.conversionFactor!),
    );
    final weightController = TextEditingController(
      text: unit?.weightPerUnit == null
          ? ''
          : _fmtNum(unit!.weightPerUnit!),
    );
    var isDefault = unit?.isDefault ?? false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(unit == null ? '添加单位' : '编辑单位'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: unit == null,
                  decoration: const InputDecoration(
                    labelText: '单位名称 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: conversionController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '换算系数（1单位 = ? 个）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '单重（g/个）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('设为默认单位'),
                  value: isDefault,
                  onChanged: (v) => setDialogState(() => isDefault = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入单位名称')),
        );
      }
      return;
    }
    final conversion = double.tryParse(conversionController.text.trim());
    final weight = double.tryParse(weightController.text.trim());
    if (unit == null) {
      await onAddUnit(
        unitName: name,
        conversionFactor: conversion,
        weightPerUnit: weight,
        isDefault: isDefault,
      );
    } else {
      await onEditUnit(
        unit.id,
        unitName: name,
        conversionFactor: conversion,
        weightPerUnit: weight,
        isDefault: isDefault,
      );
    }
  }

  Future<void> _showDensityDialog(BuildContext context) async {
    final densityController = TextEditingController();
    final conditionController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加密度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: densityController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '密度（kg/m³）*',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: conditionController,
              decoration: const InputDecoration(
                labelText: '状态描述（如：切块 / 压碎，可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final density = double.tryParse(densityController.text.trim());
    if (density == null || density <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的密度')),
        );
      }
      return;
    }
    await onAddDensity(
      density: density,
      condition: conditionController.text.trim(),
    );
  }
}

class _UnitRow extends StatelessWidget {
  final EntityUnit unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _UnitRow({
    required this.unit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = <String>[
      if (unit.conversionFactor != null)
        '1${unit.unitName} = ${_fmtNum(unit.conversionFactor!)}个',
      if (unit.weightPerUnit != null)
        '${_fmtNum(unit.weightPerUnit!)}g/个',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Chip(
            label: Text(unit.unitName),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: theme.colorScheme.secondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.isNotEmpty)
                  Text(detail, style: theme.textTheme.bodySmall),
                Row(
                  children: [
                    if (unit.isDefault)
                      Text('默认单位',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.primary)),
                    if (unit.isDefault && unit.source != null)
                      Text(' · ', style: theme.textTheme.labelSmall),
                    if (unit.source != null)
                      Text(unit.source == 'import' ? '自动' : '手动',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: '编辑',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: '删除',
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

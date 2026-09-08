import 'package:flutter/material.dart';

import '../../core/i18n/app_formatters.dart';
import '../../features/entities/repositories/entity_repository.dart';
import '../../l10n/app_localizations.dart';
import '../models/entity_unit.dart';

class UnitWriteInput {
  final String unitName;
  final double? conversionFactor;
  final double? weightPerUnit;
  final bool isDefault;

  const UnitWriteInput({
    required this.unitName,
    this.conversionFactor,
    this.weightPerUnit,
    this.isDefault = false,
  });
}

class DensityWriteInput {
  final double density;
  final String? condition;

  const DensityWriteInput({required this.density, this.condition});
}

class EntityUnitsResult {
  final bool changed;
  const EntityUnitsResult({required this.changed});
}

class EntityUnitsArguments {
  final String entityType;
  final int entityId;
  final String? entityName;
  final List<EntityUnit> units;
  final List<UnmappedUnit> unmappedUnits;
  final List<EntityDensity> densities;
  final bool loading;
  final bool isAdmin;
  final Future<Object?> Function(UnitWriteInput input) onAddUnit;
  final Future<Object?> Function(
    int unitId,
    UnitWriteInput input,
  ) onEditUnit;
  final Future<Object?> Function(int unitId) onDeleteUnit;
  final Future<Object?> Function(UnmappedUnit unit) onQuickAddUnmapped;
  final Future<Object?> Function(DensityWriteInput input) onAddDensity;
  final Future<Object?> Function(int densityId) onDeleteDensity;

  const EntityUnitsArguments({
    required this.entityType,
    required this.entityId,
    this.entityName,
    required this.units,
    required this.unmappedUnits,
    required this.densities,
    this.loading = false,
    this.isAdmin = true,
    required this.onAddUnit,
    required this.onEditUnit,
    required this.onDeleteUnit,
    required this.onQuickAddUnmapped,
    required this.onAddDensity,
    required this.onDeleteDensity,
  });
}

class EntityUnitsScreen extends StatefulWidget {
  final String entityType;
  final int entityId;
  final String? entityName;
  final List<EntityUnit> units;
  final List<UnmappedUnit> unmappedUnits;
  final List<EntityDensity> densities;
  final bool loading;
  final bool isAdmin;
  final Future<Object?> Function(UnitWriteInput input) onAddUnit;
  final Future<Object?> Function(int unitId, UnitWriteInput input) onEditUnit;
  final Future<Object?> Function(int unitId) onDeleteUnit;
  final Future<Object?> Function(UnmappedUnit unit) onQuickAddUnmapped;
  final Future<Object?> Function(DensityWriteInput input) onAddDensity;
  final Future<Object?> Function(int densityId) onDeleteDensity;

  const EntityUnitsScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    this.entityName,
    required this.units,
    required this.unmappedUnits,
    required this.densities,
    this.loading = false,
    this.isAdmin = true,
    required this.onAddUnit,
    required this.onEditUnit,
    required this.onDeleteUnit,
    required this.onQuickAddUnmapped,
    required this.onAddDensity,
    required this.onDeleteDensity,
  });

  @override
  State<EntityUnitsScreen> createState() => _EntityUnitsScreenState();
}

class _EntityUnitsScreenState extends State<EntityUnitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _unitName = TextEditingController();
  final _conversion = TextEditingController();
  final _weight = TextEditingController();
  final _density = TextEditingController();
  final _condition = TextEditingController();
  EntityUnit? _editingUnit;
  bool _unitDefault = false;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _unitName.dispose();
    _conversion.dispose();
    _weight.dispose();
    _density.dispose();
    _condition.dispose();
    super.dispose();
  }

  void _startAddUnit() {
    setState(() {
      _editingUnit = null;
      _unitName.clear();
      _conversion.clear();
      _weight.clear();
      _unitDefault = false;
      _tabController.index = 0;
    });
  }

  void _startEditUnit(EntityUnit unit) {
    setState(() {
      _editingUnit = unit;
      _unitName.text = unit.unitName;
      _conversion.text =
          unit.conversionFactor == null ? '' : _format(unit.conversionFactor!);
      _weight.text =
          unit.weightPerUnit == null ? '' : _format(unit.weightPerUnit!);
      _unitDefault = unit.isDefault;
      _tabController.index = 0;
    });
  }

  Future<void> _saveUnit() async {
    final name = _unitName.text.trim();
    if (name.isEmpty) {
      _toast(AppLocalizations.of(context).unitsNameRequired);
      return;
    }
    final input = UnitWriteInput(
      unitName: name,
      conversionFactor: double.tryParse(_conversion.text.trim()),
      weightPerUnit: double.tryParse(_weight.text.trim()),
      isDefault: _unitDefault,
    );
    await _run(
      () => _editingUnit == null
          ? widget.onAddUnit(input)
          : widget.onEditUnit(_editingUnit!.id, input),
      onApplied: _startAddUnit,
    );
  }

  Future<void> _saveDensity() async {
    final value = double.tryParse(_density.text.trim());
    if (value == null || value <= 0) {
      _toast(AppLocalizations.of(context).unitsDensityRequired);
      return;
    }
    final input = DensityWriteInput(
      density: value,
      condition: _condition.text.trim(),
    );
    await _run(
      () => widget.onAddDensity(input),
      onApplied: () {
        _density.clear();
        _condition.clear();
      },
    );
  }

  Future<void> _delete(
      String title, String message, Future<Object?> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(action);
  }

  Future<void> _run(
    Future<Object?> Function() action, {
    VoidCallback? onApplied,
  }) async {
    setState(() => _saving = true);
    try {
      final result = await action();
      if (!mounted) return;
      if (result is EntityWriteResult && result.pending) {
        _toast(
          result.message.isEmpty
              ? AppLocalizations.of(context).commonSubmittedPendingReview
              : result.message,
        );
        return;
      }
      setState(() => _changed = true);
      onApplied?.call();
    } on Exception {
      if (mounted) {
        _toast(AppLocalizations.of(context).commonSaveFailedRetry);
      }
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entityName == null
            ? l10n.unitsScreenTitle
            : l10n.unitsScreenTitleWithName(widget.entityName!)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(EntityUnitsResult(changed: _changed)),
            child: Text(l10n.commonDone),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.unitsCustomTab),
            Tab(text: l10n.unitsDensityTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUnitsPane(theme),
          _buildDensityPane(theme),
        ],
      ),
    );
  }

  Widget _buildUnitsPane(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editingUnit == null
                      ? l10n.unitsAddTitle
                      : l10n.unitsEditTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _unitName,
                  decoration: InputDecoration(
                    labelText: l10n.unitsNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _conversion,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: l10n.unitsConversionLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: l10n.unitsWeightLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.unitsSetDefault),
                  value: _unitDefault,
                  onChanged: (value) => setState(() => _unitDefault = value),
                ),
                FilledButton(
                  onPressed: _saving ? null : _saveUnit,
                  child: Text(l10n.unitsSave),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.unmappedUnits.isNotEmpty) ...[
          Text(
            l10n.unitsUnmappedTitle,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final unit in widget.unmappedUnits)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 14),
                  label: Text(
                    l10n.unitsUnmappedUsage(unit.unitName, unit.usageCount),
                  ),
                  onPressed: _saving
                      ? null
                      : () => _run(() => widget.onQuickAddUnmapped(unit)),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        for (final unit in widget.units)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(unit.unitName),
            subtitle: Text([
              if (unit.conversionFactor != null)
                l10n.unitsConversionDetail(
                  unit.unitName,
                  _formatDisplay(unit.conversionFactor!),
                ),
              if (unit.weightPerUnit != null)
                l10n.unitsWeightDetail(_formatDisplay(unit.weightPerUnit!)),
              if (unit.isDefault) l10n.unitsDefault,
            ].join(' · ')),
            trailing: unit.isPending
                ? Chip(label: Text(l10n.unitsPendingReview))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.commonEdit,
                        onPressed: () => _startEditUnit(unit),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: l10n.commonDelete,
                        onPressed: _saving
                            ? null
                            : () => _delete(
                                  l10n.unitsDeleteTitle,
                                  l10n.unitsDeleteMessage(unit.unitName),
                                  () => widget.onDeleteUnit(unit.id),
                                ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _buildDensityPane(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.densityAddTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _density,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.densityLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _condition,
                  decoration: InputDecoration(
                    labelText: l10n.densityConditionLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _saveDensity,
                  child: Text(l10n.densitySave),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final density in widget.densities)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${_formatDisplay(density.density)} kg/m³'),
            subtitle: density.condition == null || density.condition!.isEmpty
                ? null
                : Text(density.condition!),
            trailing: density.isPending
                ? Chip(label: Text(l10n.unitsPendingReview))
                : IconButton(
                    tooltip: l10n.commonDelete,
                    onPressed: _saving
                        ? null
                        : () => _delete(
                              l10n.densityDeleteTitle,
                              l10n.densityDeleteMessage,
                              () => widget.onDeleteDensity(density.id),
                            ),
                    icon: const Icon(Icons.delete_outline),
                  ),
          ),
      ],
    );
  }
}

String _format(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _formatDisplay(double value) =>
    formatNumber(value, maximumFractionDigits: 6);

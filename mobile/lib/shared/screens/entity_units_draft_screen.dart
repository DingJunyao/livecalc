import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../models/entity_unit.dart';
import '../utils/draft_units.dart';
import '../widgets/entity_units_card.dart';

/// 「新增商品」时自定义单位的草稿列表页。
///
/// 商品还不存在（没有 id），因此这里只在内存里维护草稿（负数 id），
/// 每次改动通过 [onChanged] 回写给商品表单，等商品保存成功后再一并落库。
/// 因此本页没有「保存」语义：返回即完成，不会丢数据。
class EntityUnitsDraftScreen extends StatefulWidget {
  final List<EntityUnit> initialUnits;

  /// 关联原料已有的自定义单位：可作为「量 + 单位」的引用来源（继承）。
  final List<EntityUnit> inheritedUnits;
  final List<GlobalUnitOption> globalUnitOptions;
  final double effectiveDensityKgM3;
  /// 实体名（商品/原料），只用于「保存 XX 时一并保存」这句提示。
  final String target;
  final ValueChanged<List<EntityUnit>> onChanged;

  const EntityUnitsDraftScreen({
    super.key,
    this.initialUnits = const [],
    this.inheritedUnits = const [],
    this.globalUnitOptions = const [],
    this.effectiveDensityKgM3 = 1000,
    this.target = '',
    required this.onChanged,
  });

  @override
  State<EntityUnitsDraftScreen> createState() => _EntityUnitsDraftScreenState();
}

class _EntityUnitsDraftScreenState extends State<EntityUnitsDraftScreen> {
  late List<EntityUnit> _units = List<EntityUnit>.of(widget.initialUnits);

  /// 参与换算链解析与下拉选项的完整单位表：草稿优先，
  /// 其次是关联原料的继承单位（同名时草稿胜出）。
  List<EntityUnit> get _allUnits {
    final ownNames = {for (final unit in _units) unit.unitName};
    return [
      ..._units,
      for (final unit in widget.inheritedUnits)
        if (!ownNames.contains(unit.unitName)) unit,
    ];
  }

  double get _density =>
      widget.effectiveDensityKgM3 <= 0 ? 1000 : widget.effectiveDensityKgM3;

  void _update(List<EntityUnit> units) {
    setState(() => _units = units);
    widget.onChanged(List<EntityUnit>.of(units));
  }

  Future<void> _openEditor({EntityUnit? unit}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => EntityUnitEditPage(
          unit: unit,
          units: _allUnits,
          inheritedUnitIds: {for (final row in widget.inheritedUnits) row.id},
          globalUnitOptions: widget.globalUnitOptions,
          effectiveDensityKgM3: _density,
          onSave: (input) async {
            final next = List<EntityUnit>.of(_units);
            final id = unit?.id ?? nextDraftUnitId(_units);
            final row = EntityUnit(
              id: id,
              unitName: input.unitName,
              conversionFactor: input.conversionFactor,
              weightPerUnit: input.weightPerUnit,
              isDefault: input.isDefault,
              weightUnitId: input.weightUnitId,
              weightUnitOverrideId: input.weightUnitOverrideId,
            );
            final index = next.indexWhere((item) => item.id == id);
            if (index >= 0) {
              next[index] = row;
            } else {
              next.add(row);
            }
            _update(next);
            // 不落库：草稿由商品表单在商品创建成功后统一保存
            return null;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final secondaryStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.unitsCustomTab),
        actions: [
          IconButton(
            tooltip: l10n.commonAdd,
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.productDraftSavedTogether(widget.target),
              style: secondaryStyle),
          const SizedBox(height: 12),
          if (_units.isEmpty)
            Text(l10n.entityUnitsNoCustomUnits, style: secondaryStyle)
          else
            for (final unit in _units)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  unit.unitName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: _detailLine(unit) == null
                    ? null
                    : Text(_detailLine(unit)!, style: secondaryStyle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.commonEdit,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openEditor(unit: unit),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: l10n.commonDelete,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _update(removeDraftUnit(_units, unit.id)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String? _detailLine(EntityUnit unit) {
    return entityUnitDetailLine(
      context,
      unit,
      _allUnits,
      widget.globalUnitOptions,
      _density,
    );
  }
}

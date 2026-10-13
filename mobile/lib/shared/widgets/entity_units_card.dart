import 'package:flutter/material.dart';

import '../../core/i18n/app_formatters.dart';
import '../../features/entities/repositories/entity_repository.dart';
import '../../l10n/app_localizations.dart';
import '../models/entity_unit.dart';

/// 单位数值上限（换算链解析深度），与后端环检测口径一致的客户端保护。
const int unitChainDepthCap = 8;

/// 单位写入参数（由卡片内的对话框产出，直接透传给 provider）。
class UnitWriteInput {
  final String unitName;
  final double? conversionFactor;
  final double? weightPerUnit;

  /// 全局质量/体积单位 id；与 [weightUnitOverrideId] 互斥。
  final int? weightUnitId;

  /// 本实体另一个自定义单位 id（嵌套）；与 [weightUnitId] 互斥。
  final int? weightUnitOverrideId;
  final bool isDefault;

  const UnitWriteInput({
    required this.unitName,
    this.conversionFactor,
    this.weightPerUnit,
    this.weightUnitId,
    this.weightUnitOverrideId,
    this.isDefault = false,
  });
}

/// 密度写入参数；编辑即按同一 condition 重新 upsert。
class DensityWriteInput {
  final double density;
  final String? condition;

  const DensityWriteInput({required this.density, this.condition});
}

/// 单位与密度卡片：直接在原料/商品详情页展示并维护自定义单位与密度，
/// 不再跳转到整页维护界面。
class EntityUnitsCard extends StatelessWidget {
  final String entityType;
  final int entityId;
  final String? entityName;
  final List<EntityUnit> units;
  final List<UnmappedUnit> unmappedUnits;
  final List<EntityDensity> densities;
  final List<GlobalUnitOption> globalUnitOptions;
  final bool loading;
  final bool isAdmin;
  // 生效密度（kg/m³）：自身 > 关联原料 > 水密度 1000（由 provider 计算）
  final double? effectiveDensityKgM3;
  final Future<Object?> Function(UnitWriteInput input) onAddUnit;
  final Future<Object?> Function(int unitId, UnitWriteInput input) onEditUnit;
  final Future<Object?> Function(int unitId) onDeleteUnit;
  final Future<Object?> Function(DensityWriteInput input) onAddDensity;
  final Future<Object?> Function(int densityId) onDeleteDensity;

  const EntityUnitsCard({
    super.key,
    required this.entityType,
    required this.entityId,
    this.entityName,
    required this.units,
    required this.unmappedUnits,
    required this.densities,
    this.globalUnitOptions = const [],
    this.loading = false,
    this.isAdmin = true,
    this.effectiveDensityKgM3,
    required this.onAddUnit,
    required this.onEditUnit,
    required this.onDeleteUnit,
    required this.onAddDensity,
    required this.onDeleteDensity,
  });

  double get _effectiveDensity {
    final d = effectiveDensityKgM3;
    return (d == null || d <= 0) ? 1000 : d;
  }

  /// 单行密度：取第一条（后端按 (entity_type, entity_id, condition) upsert）。
  EntityDensity? get _activeDensity {
    for (final density in densities) {
      return density;
    }
    return null;
  }

  Future<void> _openUnitDialog(
    BuildContext context, {
    EntityUnit? unit,
    String? prefillName,
  }) async {
    // 保存成功后对话框自行关闭并由 provider 重新拉取列表，这里只负责打开。
    await showDialog<bool>(
      context: context,
      builder: (ctx) => _UnitDialog(
        unit: unit,
        initialName: prefillName,
        units: units,
        globalUnitOptions: globalUnitOptions,
        effectiveDensityKgM3: _effectiveDensity,
        onSave: (input) => unit == null
            ? onAddUnit(input)
            : onEditUnit(unit.id, input),
      ),
    );
  }

  Future<void> _openDensityDialog(
    BuildContext context, {
    EntityDensity? density,
  }) async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => _DensityDialog(
        density: density,
        onSave: onAddDensity,
      ),
    );
  }

  Future<void> _confirmDeleteUnit(
    BuildContext context,
    EntityUnit unit,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirm(
      context,
      title: l10n.unitsDeleteTitle,
      message: l10n.unitsDeleteMessage(unit.unitName),
    );
    if (ok != true || !context.mounted) return;
    await _runMutation(
      context,
      () => onDeleteUnit(unit.id),
    );
  }

  Future<void> _confirmDeleteDensity(
    BuildContext context,
    EntityDensity density,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirm(
      context,
      title: l10n.densityDeleteTitle,
      message: l10n.densityDeleteMessage,
    );
    if (ok != true || !context.mounted) return;
    await _runMutation(
      context,
      () => onDeleteDensity(density.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final secondaryStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    final density = _activeDensity;
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
                Expanded(
                  child: Text(
                    l10n.unitsScreenTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              // ---- 自定义单位明细 ----
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.unitsCustomTab,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonAdd,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openUnitDialog(context),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (units.isEmpty && unmappedUnits.isEmpty)
                Text(l10n.entityUnitsNoCustomUnits, style: secondaryStyle)
              else ...[
                if (unmappedUnits.isNotEmpty) ...[
                  Text(l10n.entityUnitsUnmappedTitle, style: secondaryStyle),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final unit in unmappedUnits)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: Text(l10n.unitsUnmappedUsage(
                              unit.unitName, formatNumber(unit.usageCount))),
                          onPressed: () => _openUnitDialog(
                            context,
                            prefillName: unit.unitName,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                for (final unit in units)
                  _UnitRow(
                    unit: unit,
                    detail: _unitDetailLine(
                      context,
                      unit,
                      units,
                      globalUnitOptions,
                      _effectiveDensity,
                    ),
                    onEdit: unit.isPending
                        ? null
                        : () => _openUnitDialog(context, unit: unit),
                    onDelete: unit.isPending
                        ? null
                        : () => _confirmDeleteUnit(context, unit),
                  ),
              ],
              const Divider(height: 20),
              // ---- 密度明细（每实体最多一条生效密度）----
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.entityUnitsDensityInfo,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (density == null)
                    IconButton(
                      tooltip: l10n.commonAdd,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openDensityDialog(context),
                      icon: const Icon(Icons.add),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (density == null)
                Text(l10n.entityUnitsNoDensityData, style: secondaryStyle)
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatQuantity(density.density)} kg/m³',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (density.condition != null &&
                                density.condition!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(density.condition!, style: secondaryStyle),
                            ],
                          ],
                        ),
                      ),
                      if (density.isPending)
                        _PendingChip(label: l10n.unitsPendingReview)
                      else ...[
                        IconButton(
                          tooltip: l10n.commonEdit,
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _openDensityDialog(context, density: density),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: l10n.commonDelete,
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _confirmDeleteDensity(context, density),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单条自定义单位行：名称 + 解析后的换算链 + 编辑/删除（待审行无操作）。
class _UnitRow extends StatelessWidget {
  final EntityUnit unit;
  final String? detail;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _UnitRow({
    required this.unit,
    required this.detail,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final secondaryStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        unit.unitName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.unitsDefault,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                    if (unit.isPending) ...[
                      const SizedBox(width: 6),
                      _PendingChip(label: l10n.unitsPendingReview),
                    ],
                  ],
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: secondaryStyle),
                ],
              ],
            ),
          ),
          if (unit.source != null &&
              unit.source != 'pending' &&
              !unit.isPending) ...[
            const SizedBox(width: 8),
            Text(
              unit.source == 'import'
                  ? l10n.entityUnitsSourceAuto
                  : l10n.entityUnitsSourceManual,
              style: secondaryStyle,
            ),
          ],
          if (onEdit != null)
            IconButton(
              tooltip: l10n.commonEdit,
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: l10n.commonDelete,
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  final String label;

  const _PendingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
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
}

/// 执行删除/保存类写入，按 provider 返回值提示待审或失败。
Future<void> _runMutation(
  BuildContext context,
  Future<Object?> Function() action,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await action();
    if (result is EntityWriteResult && result.pending) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message.isEmpty
              ? l10n.commonSubmittedPendingReview
              : result.message),
        ),
      );
    }
  } on Exception {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.commonSaveFailedRetry)),
    );
  }
}

// ---------- 换算链解析 ----------

class _ResolvedUnit {
  /// 每 1 个「重量单位」的克数；null 表示链上引用了不可解析的自定义单位
  /// （例如被引用的自定义单位没有重量数据，无法再折算出克）。
  final double? gramsPerWeightUnit;

  /// 该「重量单位」是否为体积语义（体积经密度折算为克）。
  final bool isVolume;

  /// 显示用的重量单位标签：嵌套时为被引用单位名（盒），全局单位时为缩写（g/mL…）。
  final String weightUnitLabel;

  const _ResolvedUnit({
    required this.gramsPerWeightUnit,
    required this.isVolume,
    required this.weightUnitLabel,
  });
}

/// 解析 [unit] 的「1 单位 = 量 × 重量单位」：
/// 沿 weight_unit_override_id 链递归（visited + 深度上限 [unitChainDepthCap]），
/// 终点是全局质量/体积单位（体积经密度折算），或未设置（按克）。
_ResolvedUnit? _resolveUnit(
  EntityUnit unit,
  List<EntityUnit> units,
  List<GlobalUnitOption> globalUnitOptions,
  double densityKgM3,
) {
  final byId = {for (final u in units) u.id: u};
  final byGlobalId = {for (final u in globalUnitOptions) u.id: u};

  /// 1 个 [current] 折算成克；null 表示链上引用了无法解析的自定义单位。
  late double? Function(EntityUnit, Set<int>, int) gramsOf;

  /// 解析 [current] 的「重量单位」语义：标签（盒 / g / mL）、是否体积、
  /// 以及每 1 个重量单位的克数。
  late _ResolvedUnit? Function(EntityUnit, Set<int>, int) walk;

  gramsOf = (EntityUnit current, Set<int> visited, int depth) {
    if (depth > unitChainDepthCap) return null;
    final weightUnitId = current.weightUnitId;
    final refId = current.weightUnitOverrideId;
    final value = _positiveOrOne(current.weightPerUnit);
    final factor = _positiveOrOne(current.conversionFactor);
    if (weightUnitId != null) {
      final option = byGlobalId[weightUnitId];
      if (option == null) return null;
      final perWeightUnit = option.isVolume
          ? option.siFactor * densityKgM3 / 1000.0
          : option.siFactor;
      return perWeightUnit * value * factor;
    }
    if (refId == null) return value * factor;
    if (refId == unit.id || !visited.add(refId)) return null;
    final ref = byId[refId];
    if (ref == null) return null;
    final refGrams = gramsOf(ref, visited, depth + 1);
    if (refGrams == null) return null;
    return value * factor * refGrams;
  };

  walk = (EntityUnit current, Set<int> visited, int depth) {
    if (depth > unitChainDepthCap) return null;
    final weightUnitId = current.weightUnitId;
    if (weightUnitId != null) {
      final option = byGlobalId[weightUnitId];
      if (option == null) return null;
      return _ResolvedUnit(
        gramsPerWeightUnit: option.isVolume
            ? option.siFactor * densityKgM3 / 1000.0
            : option.siFactor,
        isVolume: option.isVolume,
        weightUnitLabel:
            option.abbreviation.isEmpty ? option.name : option.abbreviation,
      );
    }
    final refId = current.weightUnitOverrideId;
    if (refId == null) {
      // 未设置重量单位：后端按克处理
      return const _ResolvedUnit(
        gramsPerWeightUnit: 1,
        isVolume: false,
        weightUnitLabel: 'g',
      );
    }
    if (refId == unit.id || !visited.add(refId)) return null;
    final ref = byId[refId];
    if (ref == null) return null;
    final resolved = walk(ref, visited, depth + 1);
    if (resolved == null) return null;
    return _ResolvedUnit(
      gramsPerWeightUnit: gramsOf(ref, {...visited}, depth + 1),
      isVolume: resolved.isVolume,
      weightUnitLabel: ref.unitName.isEmpty
          ? resolved.weightUnitLabel
          : ref.unitName,
    );
  };

  return walk(unit, <int>{unit.id}, 0);
}

/// 单位行副标题；无可展示的换算信息时返回 null。
String? _unitDetailLine(
  BuildContext context,
  EntityUnit unit,
  List<EntityUnit> units,
  List<GlobalUnitOption> globalUnitOptions,
  double densityKgM3,
) {
  final l10n = AppLocalizations.of(context);
  final resolved = _resolveUnit(unit, units, globalUnitOptions, densityKgM3);
  if (resolved == null) {
    return unit.weightUnitOverrideId != null ? l10n.unitsReferenceMissing : null;
  }
  final factor = _positiveOrOne(unit.conversionFactor);
  final amount = factor * _positiveOrOne(unit.weightPerUnit);
  final amountText = formatQuantity(amount);
  final unitLabel = resolved.weightUnitLabel;
  final gramsPer = resolved.gramsPerWeightUnit;
  if (resolved.isVolume && gramsPer != null) {
    return l10n.unitsQuantityVolumeChain(
      unit.unitName,
      amountText,
      unitLabel,
      formatQuantity(amount * gramsPer),
    );
  }
  return l10n.unitsQuantityChain(unit.unitName, amountText, unitLabel);
}

double _positiveOrOne(double? value) {
  if (value == null || value <= 0) return 1;
  return value;
}

// ---------- 单位对话框 ----------

class _UnitDialog extends StatefulWidget {
  final EntityUnit? unit;
  final String? initialName;
  final List<EntityUnit> units;
  final List<GlobalUnitOption> globalUnitOptions;
  final double effectiveDensityKgM3;
  final Future<Object?> Function(UnitWriteInput input) onSave;

  const _UnitDialog({
    this.unit,
    this.initialName,
    required this.units,
    required this.globalUnitOptions,
    required this.effectiveDensityKgM3,
    required this.onSave,
  });

  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog> {
  late final TextEditingController _name;
  late final TextEditingController _conversion;
  late final TextEditingController _weight;
  int? _weightUnitId;
  int? _weightUnitOverrideId;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final unit = widget.unit;
    _name = TextEditingController(text: unit?.unitName ?? widget.initialName ?? '');
    _conversion = TextEditingController(
      text: unit?.conversionFactor == null
          ? ''
          : formatQuantity(unit!.conversionFactor!),
    );
    _weight = TextEditingController(
      text: unit?.weightPerUnit == null
          ? ''
          : formatQuantity(unit!.weightPerUnit!),
    );
    _isDefault = unit?.isDefault ?? false;
    // 优先回填嵌套引用（weight_unit_override_id），其次全局单位
    if (unit?.weightUnitOverrideId != null) {
      _weightUnitOverrideId = unit!.weightUnitOverrideId;
    } else if (unit?.weightUnitId != null) {
      _weightUnitId = unit!.weightUnitId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _conversion.dispose();
    _weight.dispose();
    super.dispose();
  }

  double get _density => widget.effectiveDensityKgM3 <= 0
      ? 1000
      : widget.effectiveDensityKgM3;

  /// 下拉可选项：默认（按克）+ 全局质量/体积单位 + 本实体其它自定义单位。
  List<DropdownMenuItem<int?>> _weightUnitItems() {
    final l10n = AppLocalizations.of(context);
    final excluded = _excludedOverrideIds();
    final values = <int?>{};
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(
        value: null,
        child: Text('${l10n.unitsWeightLabel} · ${l10n.unitsDefault} (g)'),
      ),
    ];
    for (final option in widget.globalUnitOptions) {
      if (!values.add(option.id)) continue;
      items.add(_item(option.id, '${option.name} (${option.abbreviation})'));
    }
    for (final unit in widget.units) {
      if (excluded.contains(unit.id) || !values.add(unit.id)) continue;
      items.add(_item(unit.id, l10n.unitsCustomUnitOption(unit.unitName)));
    }
    // 当前值即使被环保护排除也要能回显（否则下拉会退回到「默认」）
    final current = _weightUnitId ?? _weightUnitOverrideId;
    if (current != null && !values.contains(current)) {
      final unit = _unitById(current);
      items.add(_item(
        current,
        unit == null
            ? '$current'
            : l10n.unitsCustomUnitOption(unit.unitName),
      ));
    }
    return items;
  }

  DropdownMenuItem<int?> _item(int value, String label) {
    return DropdownMenuItem<int?>(
      value: value,
      child: Text(label, overflow: TextOverflow.ellipsis),
    );
  }

  EntityUnit? _unitById(int id) {
    for (final unit in widget.units) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  /// 不能作为重量单位引用的自定义单位：自身 + 引用链会回到自身的单位。
  Set<int> _excludedOverrideIds() {
    final selfId = widget.unit?.id;
    if (selfId == null) return const {};
    final byId = {for (final unit in widget.units) unit.id: unit};
    final excluded = <int>{selfId};
    for (final candidate in widget.units) {
      if (candidate.id == selfId) continue;
      if (_chainReaches(candidate, byId, selfId)) excluded.add(candidate.id);
    }
    return excluded;
  }

  /// 从 [start] 沿 weight_unit_override_id 链能否到达 [targetId]；
  /// 链上出现环时同样排除（否则保存必被后端拒绝）。
  bool _chainReaches(
    EntityUnit start,
    Map<int, EntityUnit> byId,
    int? targetId,
  ) {
    final seen = <int>{start.id};
    var refId = start.weightUnitOverrideId;
    for (var depth = 0; depth < unitChainDepthCap; depth++) {
      if (refId == null) return false;
      if (targetId != null && refId == targetId) return true;
      if (!seen.add(refId)) return true;
      final next = byId[refId];
      if (next == null) return false;
      refId = next.weightUnitOverrideId;
    }
    return true;
  }
  bool get _selectedIsVolume {
    final globalId = _weightUnitId;
    if (globalId == null) return false;
    for (final option in widget.globalUnitOptions) {
      if (option.id == globalId) return option.isVolume;
    }
    return false;
  }

  double get _selectedSiFactor {
    final globalId = _weightUnitId;
    if (globalId == null) return 1;
    for (final option in widget.globalUnitOptions) {
      if (option.id == globalId) return option.siFactor;
    }
    return 1;
  }

  String _volumeHint(AppLocalizations l10n) {
    final value = _parseLocalizedNumber(_weight.text);
    if (value == null || value <= 0) return l10n.unitsVolumeDensityHintEmpty;
    final grams = value * _selectedSiFactor * _density / 1000.0;
    return l10n.unitsVolumeDensityHint(
      formatQuantity(_density / 1000),
      formatQuantity(grams),
    );
  }

  void _selectWeightUnit(int? value) {
    setState(() {
      if (value == null) {
        _weightUnitId = null;
        _weightUnitOverrideId = null;
        return;
      }
      if (widget.globalUnitOptions.any((option) => option.id == value)) {
        _weightUnitId = value;
        _weightUnitOverrideId = null;
      } else {
        _weightUnitOverrideId = value;
        _weightUnitId = null;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unitsNameRequired)),
      );
      return;
    }
    if (widget.unit != null && _weightUnitOverrideId == widget.unit!.id) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unitsSelfReference)),
      );
      return;
    }
    final input = UnitWriteInput(
      unitName: name,
      conversionFactor: _blankOrZeroToNull(_conversion.text),
      weightPerUnit: _blankOrZeroToNull(_weight.text),
      weightUnitId: _weightUnitId,
      weightUnitOverrideId: _weightUnitOverrideId,
      isDefault: _isDefault,
    );
    setState(() => _saving = true);
    try {
      final result = await widget.onSave(input);
      if (!mounted) return;
      if (result is EntityWriteResult && result.pending) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message.isEmpty
                ? l10n.commonSubmittedPendingReview
                : result.message),
          ),
        );
        setState(() => _saving = false);
        return;
      }
      Navigator.of(context).pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commonSaveFailedRetry)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.unit != null;
    return AlertDialog(
      title: Text(isEditing ? l10n.unitsEditTitle : l10n.unitsAddTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.unitsNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _conversion,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.unitsConversionLabel,
                  hintText: '1',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.unitsWeightValueLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.unitsWeightUnitLabel,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          key: const Key('unit-weight-unit-dropdown'),
                          value: _weightUnitId ?? _weightUnitOverrideId,
                          isExpanded: true,
                          isDense: true,
                          items: _weightUnitItems(),
                          onChanged: _saving ? null : _selectWeightUnit,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedIsVolume) ...[
                const SizedBox(height: 8),
                Text(
                  _volumeHint(l10n),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.unitsSetDefault),
                value: _isDefault,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isDefault = value),
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
          child: Text(l10n.unitsSave),
        ),
      ],
    );
  }
}

double? _blankOrZeroToNull(String raw) {
  final value = _parseLocalizedNumber(raw);
  if (value == null || value <= 0) return null;
  return value;
}

/// 解析用户输入的数字：兼容本地化分组（1,030）与阿拉伯数字（١٢٣）。
double? _parseLocalizedNumber(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const extendedArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final arabicIndex = arabicIndic.indexOf(char);
    if (arabicIndex >= 0) {
      buffer.write(arabicIndex);
      continue;
    }
    final extendedIndex = extendedArabicIndic.indexOf(char);
    if (extendedIndex >= 0) {
      buffer.write(extendedIndex);
      continue;
    }
    if (char == ',' || char == '\u066C' || char == '\u00A0') continue;
    if (char == '\u066B' || char == '٫') {
      buffer.write('.');
      continue;
    }
    buffer.write(char);
  }
  text = buffer.toString();
  return double.tryParse(text);
}

// ---------- 密度对话框 ----------

class _DensityDialog extends StatefulWidget {
  final EntityDensity? density;
  final Future<Object?> Function(DensityWriteInput input) onSave;

  const _DensityDialog({this.density, required this.onSave});

  @override
  State<_DensityDialog> createState() => _DensityDialogState();
}

class _DensityDialogState extends State<_DensityDialog> {
  late final TextEditingController _density;
  late final TextEditingController _condition;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final density = widget.density;
    _density = TextEditingController(
      text: density == null ? '' : formatQuantity(density.density),
    );
    _condition = TextEditingController(text: density?.condition ?? '');
  }

  @override
  void dispose() {
    _density.dispose();
    _condition.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final value = _parseLocalizedNumber(_density.text);
    if (value == null || value <= 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unitsDensityRequired)),
      );
      return;
    }
    final input = DensityWriteInput(
      density: value,
      condition: _condition.text.trim(),
    );
    setState(() => _saving = true);
    try {
      final result = await widget.onSave(input);
      if (!mounted) return;
      if (result is EntityWriteResult && result.pending) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message.isEmpty
                ? l10n.commonSubmittedPendingReview
                : result.message),
          ),
        );
        setState(() => _saving = false);
        return;
      }
      Navigator.of(context).pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.commonSaveFailedRetry)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.density != null;
    final presets = <({String label, double value})>[
      (label: l10n.unitsPresetWater, value: 1000),
      (label: l10n.unitsPresetMilk, value: 1030),
      (label: l10n.unitsPresetCookingOil, value: 920),
      (label: l10n.unitsPresetSoySauce, value: 1150),
      (label: l10n.unitsPresetHoney, value: 1420),
    ];
    return AlertDialog(
      title: Text(isEditing ? l10n.unitsEditTitle : l10n.densityAddTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                l10n.unitsDensityPresets,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in presets)
                    ActionChip(
                      label: Text(
                          '${preset.label} ${formatQuantity(preset.value)}'),
                      onPressed: _saving
                          ? null
                          : () => setState(() =>
                              _density.text = formatQuantity(preset.value)),
                    ),
                ],
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
          child: Text(l10n.densitySave),
        ),
      ],
    );
  }
}

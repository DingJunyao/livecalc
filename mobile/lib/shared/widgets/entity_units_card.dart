import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_formatters.dart';
import '../../features/entities/repositories/entity_repository.dart';
import '../../features/profile/providers/save_button_position_provider.dart';
import '../../l10n/app_localizations.dart';
import '../models/entity_unit.dart';
import 'save_action_button.dart';

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
  /// 关联原料的自定义单位（仅商品有）：本商品没覆盖时继承使用，
  /// 用于「箱 = 12 盒」这类引用（盒 定义在原料上）与下拉选项。
  final List<EntityUnit> inheritedUnits;
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
    this.inheritedUnits = const [],
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

  /// 参与换算链解析与下拉选项的完整单位表：本实体的覆盖优先，
  /// 其次是继承自关联原料的覆盖（同名时本实体的覆盖胜出）。
  List<EntityUnit> get _allUnits {
    final ownNames = {for (final unit in units) unit.unitName};
    return [
      ...units,
      for (final unit in inheritedUnits)
        if (!ownNames.contains(unit.unitName)) unit,
    ];
  }

  Future<void> _openUnitPage(
    BuildContext context, {
    EntityUnit? unit,
    String? prefillName,
  }) async {
    // 单位编辑是整页（与价格记录编辑一致的体验，不再用对话框）：
    // 覆盖底部导航，编辑时不误触；保存成功后页面 pop(true)，provider 已回调里重拉列表。
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => EntityUnitEditPage(
          unit: unit,
          initialName: prefillName,
          units: _allUnits,
          inheritedUnitIds: {for (final unit in inheritedUnits) unit.id},
          globalUnitOptions: globalUnitOptions,
          effectiveDensityKgM3: _effectiveDensity,
          onSave: (input) => unit == null
              ? onAddUnit(input)
              : onEditUnit(unit.id, input),
        ),
      ),
    );
  }

  Future<void> _openDensityPage(
    BuildContext context, {
    EntityDensity? density,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => _DensityEditPage(
          density: density,
          onSave: onAddDensity,
        ),
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
                    onPressed: () => _openUnitPage(context),
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
                          onPressed: () => _openUnitPage(
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
                    detail: entityUnitDetailLine(
                      context,
                      unit,
                      _allUnits,
                      globalUnitOptions,
                      _effectiveDensity,
                    ),
                    onEdit: unit.isPending
                        ? null
                        : () => _openUnitPage(context, unit: unit),
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
                      onPressed: () => _openDensityPage(context),
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
                              _openDensityPage(context, density: density),
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

/// 每 1 个全局质量/体积单位的克数。
///
/// 注意：后端 `/units/` 的 `si_factor` 基准是 **SI 基本单位**，不是克/mL——
/// - 质量：换算到 **kg**（克 = 0.001、斤 = 0.5、100g = 0.1、kg = 1），
///   见 `backend/app/main.py:57`「si_factor 以 kg 为基准，100g = 0.1kg」，
///   故 1 个质量单位 = `si_factor × 1000` 克（200 g 就是 200 g，不是 0.2 g）。
/// - 体积：换算到 **L**（mL = 0.001、L = 1），见
///   `unit_conversion_service.py:180`「体积 si_factor 换算到 SI 基本单位 L（不是 m³）」，
///   故 1 个体积单位 = `si_factor`(L) × 0.001(m³/L) × 密度(kg/m³) × 1000(g/kg)
///   = `si_factor × 密度` 克（220 mL / 1030 kg/m³ → 226.6 g）。
///
/// 不要"化简"回 `si_factor / 1000`，那会让显示值小 1000 倍。
double _gramsPerGlobalWeightUnit(GlobalUnitOption option, double densityKgM3) {
  return option.isVolume
      ? option.siFactor * densityKgM3
      : option.siFactor * 1000.0;
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
      // si_factor 基准见 [_gramsPerGlobalWeightUnit]（质量→kg、体积→L）。
      final perWeightUnit = _gramsPerGlobalWeightUnit(option, densityKgM3);
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
        // si_factor 基准见 [_gramsPerGlobalWeightUnit]（质量→kg、体积→L）。
        gramsPerWeightUnit: _gramsPerGlobalWeightUnit(option, densityKgM3),
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

/// 单位行副标题（公开，供「新增商品」的单位草稿列表复用同一套换算口径）；
/// 无可展示的换算信息时返回 null。
String? entityUnitDetailLine(
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

// ---------- 单位编辑页（整页，非对话框；公开以便「新增商品」草稿复用） ----------

class EntityUnitEditPage extends ConsumerStatefulWidget {
  final EntityUnit? unit;
  final String? initialName;
  final List<EntityUnit> units;
  /// 其中哪些是「继承自关联原料」的单位（下拉里标注出来）。
  final Set<int> inheritedUnitIds;
  final List<GlobalUnitOption> globalUnitOptions;
  final double effectiveDensityKgM3;
  final Future<Object?> Function(UnitWriteInput input) onSave;

  const EntityUnitEditPage({
    super.key,
    this.unit,
    this.initialName,
    required this.units,
    this.inheritedUnitIds = const {},
    required this.globalUnitOptions,
    required this.effectiveDensityKgM3,
    required this.onSave,
  });

  @override
  ConsumerState<EntityUnitEditPage> createState() => _EntityUnitEditPageState();
}

class _EntityUnitEditPageState extends ConsumerState<EntityUnitEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _weight;

  /// 下拉选中的「单位」值，带来源前缀：
  /// `''` = 默认（克）、`u:<全局单位 id>`、`e:<本实体/继承的自定义单位 id>`。
  ///
  /// 必须带前缀：全局单位表与实体单位覆盖表是两张表，id 空间重叠，
  /// 若直接用 int 去重，撞车的自定义单位会被静默丢弃（表现为「下拉里没有
  /// 关联原料的自定义单位」，而全局单位照常显示）。
  String _weightUnit = '';
  bool _isDefault = false;
  bool _saving = false;

  int? get _selectedGlobalUnitId =>
      _weightUnit.startsWith('u:') ? int.tryParse(_weightUnit.substring(2)) : null;

  int? get _selectedOverrideUnitId =>
      _weightUnit.startsWith('e:') ? int.tryParse(_weightUnit.substring(2)) : null;

  @override
  void initState() {
    super.initState();
    final unit = widget.unit;
    _name = TextEditingController(text: unit?.unitName ?? widget.initialName ?? '');
    // 换算系数已从表单移除：打开时把「系数 × 量」合并进「量」，
    // 保存时系数恒为 1，语义不变（老数据里 系数12 + 空量 会显示成 量=12）。
    final storedFactor = _positiveOrOne(unit?.conversionFactor);
    final storedWeight = unit?.weightPerUnit;
    final hasAmount = storedWeight != null || (unit != null && storedFactor != 1);
    _weight = TextEditingController(
      text: !hasAmount
          ? ''
          : formatQuantity(_positiveOrOne(storedWeight) * storedFactor),
    );
    _isDefault = unit?.isDefault ?? false;
    // 优先回填嵌套引用（weight_unit_override_id），其次全局单位
    if (unit?.weightUnitOverrideId != null) {
      _weightUnit = 'e:${unit!.weightUnitOverrideId}';
    } else if (unit?.weightUnitId != null) {
      _weightUnit = 'u:${unit!.weightUnitId}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  double get _density => widget.effectiveDensityKgM3 <= 0
      ? 1000
      : widget.effectiveDensityKgM3;

  /// 下拉可选项：默认（克）+ 全局质量/体积单位 + 本实体其它自定义单位
  /// + 继承自关联原料的自定义单位（同名时本实体的覆盖优先）。
  ///
  /// 选项值带来源前缀（`u:` 全局 / `e:` 自定义），避免两张表的 id 撞车时
  /// 把自定义单位去重掉。
  List<DropdownMenuItem<String>> _weightUnitItems() {
    final l10n = AppLocalizations.of(context);
    final excluded = _excludedOverrideIds();
    final values = <String>{};
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: '',
        child: Text(l10n.unitsWeightUnitDefault),
      ),
    ];
    for (final option in widget.globalUnitOptions) {
      if (!values.add('u:${option.id}')) continue;
      items.add(_item('u:${option.id}', '${option.name} (${option.abbreviation})'));
    }
    for (final unit in widget.units) {
      if (excluded.contains(unit.id) || !values.add('e:${unit.id}')) continue;
      items.add(_item(
        'e:${unit.id}',
        widget.inheritedUnitIds.contains(unit.id)
            ? l10n.unitsCustomUnitInherited(unit.unitName)
            : l10n.unitsCustomUnitOption(unit.unitName),
      ));
    }
    // 当前值即使被环保护排除也要能回显（否则下拉会退回到「默认」）
    if (_weightUnit.isNotEmpty && !values.contains(_weightUnit)) {
      final unitId = _selectedOverrideUnitId;
      final unit = unitId == null ? null : _unitById(unitId);
      items.add(_item(
        _weightUnit,
        unit == null
            ? _weightUnit
            : l10n.unitsCustomUnitOption(unit.unitName),
      ));
    }
    return items;
  }

  DropdownMenuItem<String> _item(String value, String label) {
    return DropdownMenuItem<String>(
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
    final globalId = _selectedGlobalUnitId;
    if (globalId == null) return false;
    for (final option in widget.globalUnitOptions) {
      if (option.id == globalId) return option.isVolume;
    }
    return false;
  }

  /// 选中的全局单位的原始 `si_factor`。体积语义下它是「换算到 L」的系数
  /// （mL = 0.001、L = 1，见 unit_conversion_service.py:180），**不是** mL→g；
  /// 只有体积提示 [_volumeHint] 用它，质量路径不经过这里。
  double get _selectedSiFactor {
    final globalId = _selectedGlobalUnitId;
    if (globalId == null) return 1;
    for (final option in widget.globalUnitOptions) {
      if (option.id == globalId) return option.siFactor;
    }
    return 1;
  }

  String _volumeHint(AppLocalizations l10n) {
    final value = _parseLocalizedNumber(_weight.text);
    if (value == null || value <= 0) return l10n.unitsVolumeDensityHintEmpty;
    // 1 个体积单位 = si_factor(L) × 0.001(m³/L) × 密度(kg/m³) × 1000(g/kg)
    //               = value × si_factor × 密度
    // 这里不能再除 1000：0.001 与 1000 正好抵消（220 mL / 1030 → 226.6 g）。
    final grams = value * _selectedSiFactor * _density;
    return l10n.unitsVolumeDensityHint(
      formatQuantity(_density / 1000),
      formatQuantity(grams),
    );
  }

  void _selectWeightUnit(String? value) {
    setState(() => _weightUnit = value ?? '');
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
    final weightUnitId = _selectedGlobalUnitId;
    final weightUnitOverrideId = _selectedOverrideUnitId;
    if (widget.unit != null && weightUnitOverrideId == widget.unit!.id) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unitsSelfReference)),
      );
      return;
    }
    final input = UnitWriteInput(
      unitName: name,
      // 换算系数已从表单移除：语义上恒为 1（存 1，避免再出现"要不要填系数"的困惑）
      conversionFactor: 1,
      weightPerUnit: _blankOrZeroToNull(_weight.text),
      weightUnitId: weightUnitId,
      weightUnitOverrideId: weightUnitOverrideId,
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
    final savePosition = ref.watch(saveButtonPositionProvider);
    final saveLabel = l10n.unitsSave;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.unitsEditTitle : l10n.unitsAddTitle),
        actions: [
          ...saveAppBarActions(
            position: savePosition,
            onSave: _saving ? null : _save,
            label: saveLabel,
            busy: _saving,
          ),
        ],
      ),
      bottomNavigationBar: saveBottomBar(
        context: context,
        position: savePosition,
        onSave: _saving ? null : _save,
        label: saveLabel,
        busy: _saving,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.unitsNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // 「量」+「单位」必须等高：量 用 TextField 的默认高度（56），
          // 单位 用 InputDecorator 时补同样的内容边距，二者外框对齐。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _weight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.unitsWeightValueLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.unitsWeightUnitLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('unit-weight-unit-dropdown'),
                        value: _weightUnit,
                        isExpanded: true,
                        isDense: true,
                        items: _weightUnitItems(),
                        onChanged: _saving ? null : _selectWeightUnit,
                      ),
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
            onChanged:
                _saving ? null : (value) => setState(() => _isDefault = value),
          ),
        ],
      ),
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

// ---------- 密度编辑页（整页，非对话框） ----------

class _DensityEditPage extends ConsumerStatefulWidget {
  final EntityDensity? density;
  final Future<Object?> Function(DensityWriteInput input) onSave;

  const _DensityEditPage({this.density, required this.onSave});

  @override
  ConsumerState<_DensityEditPage> createState() => _DensityEditPageState();
}

class _DensityEditPageState extends ConsumerState<_DensityEditPage> {
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
    final savePosition = ref.watch(saveButtonPositionProvider);
    final saveLabel = l10n.densitySave;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.unitsEditTitle : l10n.densityAddTitle),
        actions: [
          ...saveAppBarActions(
            position: savePosition,
            onSave: _saving ? null : _save,
            label: saveLabel,
            busy: _saving,
          ),
        ],
      ),
      bottomNavigationBar: saveBottomBar(
        context: context,
        position: savePosition,
        onSave: _saving ? null : _save,
        label: saveLabel,
        busy: _saving,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                  label: Text('${preset.label} ${formatQuantity(preset.value)}'),
                  onPressed: _saving
                      ? null
                      : () => setState(
                          () => _density.text = formatQuantity(preset.value)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/entity_unit.dart';
import '../screens/entity_units_screen.dart';

/// 单位与密度卡片；在原料/商品详情页直接展示单位与密度明细，
/// 维护入口进入整页表单。
class EntityUnitsCard extends StatelessWidget {
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

  const EntityUnitsCard({
    super.key,
    required this.entityType,
    required this.entityId,
    this.entityName,
    required this.units,
    required this.unmappedUnits,
    required this.densities,
    required this.loading,
    this.isAdmin = true,
    required this.onAddUnit,
    required this.onEditUnit,
    required this.onDeleteUnit,
    required this.onQuickAddUnmapped,
    required this.onAddDensity,
    required this.onDeleteDensity,
  });

  Future<void> _openMaintenance(BuildContext context) async {
    await context.push<EntityUnitsResult>(
      '/entities/$entityType/$entityId/units',
      extra: EntityUnitsArguments(
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        units: units,
        unmappedUnits: unmappedUnits,
        densities: densities,
        loading: loading,
        isAdmin: isAdmin,
        onAddUnit: onAddUnit,
        onEditUnit: onEditUnit,
        onDeleteUnit: onDeleteUnit,
        onQuickAddUnmapped: onQuickAddUnmapped,
        onAddDensity: onAddDensity,
        onDeleteDensity: onDeleteDensity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryStyle = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.outline);
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
                    '单位与密度',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openMaintenance(context),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('维护'),
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
              Text(
                '自定义单位',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (units.isEmpty && unmappedUnits.isEmpty)
                Text('暂无自定义单位', style: secondaryStyle)
              else ...[
                if (unmappedUnits.isNotEmpty) ...[
                  Text('待配置单位（来自菜谱，默认 100 g）', style: secondaryStyle),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final unit in unmappedUnits)
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: Text('${unit.unitName}（${unit.usageCount}次）'),
                          onPressed: () => _openMaintenance(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                for (final unit in units)
                  Padding(
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
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600),
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
                                        '默认',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (unit.isPending) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '待审',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color:
                                              theme.colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (unit.conversionFactor != null ||
                                  unit.weightPerUnit != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (unit.conversionFactor != null)
                                      '1 ${unit.unitName} = '
                                          '${_format(unit.conversionFactor!)} 个',
                                    if (unit.weightPerUnit != null)
                                      '${_format(unit.weightPerUnit!)} g/个',
                                  ].join(' · '),
                                  style: secondaryStyle,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (unit.source != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            unit.source == 'import' ? '自动' : '手动',
                            style: secondaryStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
              const Divider(height: 12),
              // ---- 密度明细 ----
              Text(
                '密度信息',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (densities.isEmpty)
                Text('暂无密度数据', style: secondaryStyle)
              else
                for (final density in densities)
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
                                '${_format(density.density)} kg/m³',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                              if (density.condition != null &&
                                  density.condition!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(density.condition!, style: secondaryStyle),
                              ],
                            ],
                          ),
                        ),
                        if (density.isPending) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '待审',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
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

String _format(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

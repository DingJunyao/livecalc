import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/entity_unit.dart';
import '../screens/entity_units_screen.dart';

/// 单位与密度摘要卡；维护入口进入整页表单。
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
              Text(
                '自定义单位 ${units.length} 个'
                '${unmappedUnits.isEmpty ? '' : ' · 待配置 ${unmappedUnits.length} 个'}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                densities.isEmpty
                    ? '暂无密度数据'
                    : densities
                        .map((d) => '${_format(d.density)} kg/m³'
                            '${d.condition == null || d.condition!.isEmpty ? '' : '（${d.condition}）'}')
                        .join(' · '),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_formatters.dart';
import '../../l10n/app_localizations.dart';
import '../models/nutrition.dart';
import '../screens/nutrition_edit_screen.dart';

/// 营养成分卡片（原料/商品共用），支持编辑与（商品）清空自定义数据。
class NutritionCard extends StatelessWidget {
  final NutritionInfo? nutrition;
  final bool loading;
  final bool saving;
  final bool allowClear;
  final Future<void> Function()? onRefresh;
  final String entityType;
  final int entityId;
  final String? entityName;
  final Future<Object?> Function(List<NutrientEntry>) onSave;
  final Future<Object?> Function()? onClear;

  const NutritionCard({
    super.key,
    required this.nutrition,
    required this.loading,
    required this.saving,
    this.allowClear = false,
    this.onRefresh,
    required this.entityType,
    required this.entityId,
    this.entityName,
    required this.onSave,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                Text(l10n.nutritionTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Text(l10n.nutritionPerBase(_baseLabel(info)),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const Spacer(),
                if (!loading)
                  TextButton.icon(
                    onPressed: saving ? null : () => _openEditor(context),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(l10n.commonEdit),
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
                      Text(l10n.nutritionNoData,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(height: 4),
                      Text(l10n.nutritionNoDataHint,
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
    await context.push<NutritionEditResult>(
      '/entities/$entityType/$entityId/nutrition',
      extra: NutritionEditArguments(
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        nutrition: nutrition,
        allowClear: allowClear,
        onRefresh: onRefresh,
        onSave: onSave,
        onClear: onClear,
      ),
    );
  }
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
    final l10n = AppLocalizations.of(context);
    final nutrients = widget.info.nutrients;
    final core = nutrients.length <= 5 ? nutrients : nutrients.take(5).toList();
    final others =
        nutrients.length <= 5 ? <NutrientEntry>[] : nutrients.skip(5).toList();
    const valueW = 76.0;
    const nrvW = 56.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 表头（对齐菜谱详情营养成分表样式）
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(l10n.nutritionNutrient)),
              SizedBox(
                width: valueW,
                child: Text(l10n.nutritionQuantity, textAlign: TextAlign.end),
              ),
              const SizedBox(
                width: nrvW,
                child: Text('NRV%', textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
        ..._rows(theme, core, valueW, nrvW),
        if (others.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more,
                  size: 18),
              label: Text(
                _showAll
                    ? l10n.nutritionCollapse
                    : l10n.nutritionExpand(others.length),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        if (_showAll) ..._rows(theme, others, valueW, nrvW),
        const SizedBox(height: 8),
        Text(l10n.nutritionNrvExplanation,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }

  List<Widget> _rows(
      ThemeData theme, List<NutrientEntry> items, double valueW, double nrvW) {
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
                  textAlign: TextAlign.end,
                ),
              ),
              SizedBox(
                width: nrvW,
                child: Text(
                  items[i].nrvPct == null
                      ? ''
                      : formatPercentValue(items[i].nrvPct!),
                  textAlign: TextAlign.end,
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

String _fmtValue(double v) => formatQuantity(v);

import 'package:flutter/material.dart';

import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/currency_fmt.dart';

/// 合计 vs 目标（成本 / 热量 / 蛋白质 / 脂肪），试算编辑页与详情页共用。
class PlanTotalsGrid extends StatelessWidget {
  final Map<String, dynamic> totals;
  final Map<String, dynamic> targets;
  final String userCurrency;

  const PlanTotalsGrid({
    super.key,
    required this.totals,
    required this.targets,
    this.userCurrency = 'CNY',
  });

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rows = [
      (
        l10n.plansTotalCost,
        formatMoney(_num(totals['cost']),
            (totals['currency'] as String?) ?? userCurrency),
        formatMoney(_num(targets['cost']), userCurrency),
        _num(totals['cost']) > _num(targets['cost']),
      ),
      (
        l10n.plansCalories,
        '${formatNumber(_num(totals['calories']).round())} kcal',
        '${formatNumber(_num(targets['calories']).round())} kcal',
        _num(totals['calories']) > _num(targets['calories']),
      ),
      (
        l10n.plansProtein,
        '${formatNumber(_num(totals['protein_g']), maximumFractionDigits: 1)} g',
        '${formatNumber(_num(targets['protein_g']), maximumFractionDigits: 1)} g',
        _num(totals['protein_g']) > _num(targets['protein_g']),
      ),
      (
        l10n.plansFat,
        '${formatNumber(_num(totals['fat_g']), maximumFractionDigits: 1)} g',
        '${formatNumber(_num(targets['fat_g']), maximumFractionDigits: 1)} g',
        _num(totals['fat_g']) > _num(targets['fat_g']),
      ),
    ];
    return Column(
      children: [
        for (final (label, value, target, over) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: over
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${l10n.plansTarget} $target',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

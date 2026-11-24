// region_price_matrix.dart — 实体×地区比价矩阵（冻结首列 + 横向滚动）。
// 与菜谱分析的商家比价矩阵（merchant_price_matrix）同布局：
// 行=实体、列=地区，每行最低价（非陈旧）绿色加粗、缺失「—」、超期灰色。

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../repositories/comparison_repository.dart';

class RegionMatrixColumn {
  final int regionId;
  final String label;
  const RegionMatrixColumn({required this.regionId, required this.label});
}

class RegionPriceMatrix extends StatelessWidget {
  final List<RegionMatrixColumn> columns;
  final List<EntityPriceRow> rows;
  final bool loading;
  final String emptyText;
  final String unassignedNote;
  final String userCurrency;

  const RegionPriceMatrix({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyText,
    this.loading = false,
    this.unassignedNote = '',
    this.userCurrency = 'CNY',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (rows.isEmpty || columns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.table_chart_outlined,
                size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(emptyText,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }
    const entityWidth = 120.0;
    const rowHeight = 44.0;

    Widget cell(double? price, bool isLowest, bool isStale) {
      return SizedBox(
        width: 88,
        height: rowHeight,
        child: Center(
          child: Text(
            price == null ? '—' : formatMoney(price, userCurrency),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: price == null
                  ? theme.colorScheme.outline
                  : isStale
                      ? theme.colorScheme.outline
                      : isLowest
                          ? Colors.green.shade700
                          : null,
              fontWeight: isLowest && !isStale ? FontWeight.bold : null,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  l10n.compareMatrixTitle,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 冻结首列：实体名
                  SizedBox(
                    width: entityWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          height: rowHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              l10n.compareMatrixEntityCol,
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                        for (final row in rows)
                          SizedBox(
                            height: rowHeight,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                row.unit == null || row.unit!.isEmpty
                                    ? row.name
                                    : '${row.name} / ${row.unit}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 地区列：横向滚动
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (final col in columns)
                                SizedBox(
                                  width: 88,
                                  height: rowHeight,
                                  child: Center(
                                    child: Text(
                                      col.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          for (final row in rows)
                            Row(
                              children: [
                                for (final col in columns)
                                  Builder(builder: (ctx) {
                                    final c =
                                        row.regions[col.regionId.toString()];
                                    final price = c?.price;
                                    final isStale = c?.isStale ?? false;
                                    return cell(
                                      price,
                                      price != null &&
                                          !isStale &&
                                          _isLowest(row, col.regionId),
                                      isStale,
                                    );
                                  }),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (unassignedNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    unassignedNote,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 每行最低价（只看非陈旧、有价的列；单列不标）。
  bool _isLowest(EntityPriceRow row, int regionId) {
    final prices = <double>[];
    for (final col in columns) {
      final c = row.regions[col.regionId.toString()];
      if (c != null && c.price != null && !c.isStale) prices.add(c.price!);
    }
    if (prices.length < 2) return false;
    final c = row.regions[regionId.toString()];
    if (c == null || c.price == null) return false;
    return c.price! <= prices.reduce((a, b) => a < b ? a : b);
  }
}

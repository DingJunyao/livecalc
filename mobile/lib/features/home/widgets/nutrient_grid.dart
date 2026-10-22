import 'package:flutter/material.dart';

/// 四项营养素宫格条目（nrv 不为空时单独一行显示，避免与数值挤在一起）
class NutrientGridItem {
  final IconData icon;
  final String label;
  final String value;
  final String? nrv;

  const NutrientGridItem({
    required this.icon,
    required this.label,
    required this.value,
    this.nrv,
  });
}

/// 营养素宫格：每行 2 列（窄屏 2×2），与 web 的 NutrientSummaryGrid 同口径。
class NutrientGrid extends StatelessWidget {
  final List<NutrientGridItem> items;

  const NutrientGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    final valueStyle =
        theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    Widget cell(NutrientGridItem item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(item.icon, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: valueStyle),
              if (item.nrv != null && item.nrv!.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  item.nrv!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ],
            ],
          ),
        );

    final rows = <TableRow>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(TableRow(children: [
        cell(items[i]),
        if (i + 1 < items.length) cell(items[i + 1]) else const SizedBox(),
      ]));
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: rows,
    );
  }
}

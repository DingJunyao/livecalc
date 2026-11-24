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
///
/// 宽屏（可用宽度 ≥ [wideBreakpoint]，如 Duo 展开横屏）可指定 [wideColumns] 把全部
/// 条目排成一行；不指定则恒为 2 列（餐卡等窄容器）。
class NutrientGrid extends StatelessWidget {
  final List<NutrientGridItem> items;

  /// 宽屏时每行的列数（如 4）；null = 恒为 2 列。
  final int? wideColumns;

  /// 判定「宽屏」的可用宽度阈值：展开竖屏（669）里 Today 卡内实际可用宽约 605
  /// （页面 16 内边距 + 卡内 16 内边距），四列每列约 145，标签 / 数值 / NRV 仍放得下；
  /// 手机（约 358）保持 2×2。
  static const double wideBreakpoint = 560;

  const NutrientGrid({super.key, required this.items, this.wideColumns});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            wideColumns != null && constraints.maxWidth >= wideBreakpoint
                ? wideColumns!
                : 2;
        final theme = Theme.of(context);
        final labelStyle = theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline);
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
                      Icon(item.icon,
                          size: 14, color: theme.colorScheme.outline),
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
                  Text(item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle),
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
        for (var i = 0; i < items.length; i += columns) {
          rows.add(TableRow(children: [
            for (var j = 0; j < columns; j++)
              if (i + j < items.length)
                cell(items[i + j])
              else
                const SizedBox(),
          ]));
        }

        return Table(
          columnWidths: {
            for (var i = 0; i < columns; i++) i: const FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: rows,
        );
      },
    );
  }
}

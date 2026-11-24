import 'package:flutter/material.dart';

/// 详情页双栏容器。
///
/// - 窄屏：按页面原有顺序单列（[DetailTwoColumn.rows] 的 `single`，或左右两栏
///   顺次展开）。
///
/// 断点 820：只有展开横屏（Duo 内屏横屏 951−84=867）这类宽屏才分栏；折叠横屏
/// （646）与展开竖屏（637）保持单列（用户定调：详情页不在这两个姿态分栏）。
/// - 宽屏（≥[breakpoint]）：两栏等宽并排；[DetailTwoColumn.rows]
///   按行成对（每行左右各自独立高度、同排等高），对应 web 详情页的桌面栅格。
///
/// 半折叠（铰链分区）暂不处理：系统不保证上报折叠区，一律按完全展开布局。
class DetailTwoColumn extends StatelessWidget {
  const DetailTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 820,
    this.gap = 16,
  })  : rows = null,
        single = null;

  /// 按行成对：每行 [左, 右]。宽屏逐行两列，窄屏走 [single]（缺省则依次展开）。
  const DetailTwoColumn.rows({
    super.key,
    required List<List<Widget>> this.rows,
    List<Widget>? single,
    this.breakpoint = 820,
    this.gap = 16,
  })  : left = const [],
        right = const [],
        single = single;

  final List<Widget> left;
  final List<Widget> right;
  final List<List<Widget>>? rows;

  /// 单列（窄屏）时的渲染顺序：保持页面原有的移动端顺序；
  /// 双列分组（[rows]，对齐 web 桌面栅格）只在宽屏生效。
  final List<Widget>? single;
  final double breakpoint;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= breakpoint;
      final rowGroups = rows;

      if (rowGroups == null) {
        if (!wide) return _ColumnOf(items: [...left, ...right], gap: gap);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ColumnOf(items: left, gap: gap)),
            SizedBox(width: gap),
            Expanded(child: _ColumnOf(items: right, gap: gap)),
          ],
        );
      }

      if (!wide) {
        return _ColumnOf(
          items: single ?? [for (final group in rowGroups) ...group],
          gap: gap,
        );
      }

      final blocks = <Widget>[];
      for (var i = 0; i < rowGroups.length; i++) {
        final group = rowGroups[i];
        if (i > 0) blocks.add(SizedBox(height: gap));
        if (group.length == 1) {
          blocks.add(group.first);
          continue;
        }
        // 同一行两侧等宽、同排等高（IntrinsicHeight 提供有界高度后再 stretch，
        // 否则 ListView 内会得到无限高约束）。
        blocks.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < group.length; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(child: group[j]),
              ],
            ],
          ),
        ));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: blocks,
      );
    });
  }
}

class _ColumnOf extends StatelessWidget {
  const _ColumnOf({required this.items, required this.gap});

  final List<Widget> items;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) children.add(SizedBox(height: gap));
      children.add(items[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

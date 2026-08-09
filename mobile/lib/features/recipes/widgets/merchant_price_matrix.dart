import 'package:flutter/material.dart';
import '../../../shared/widgets/mouse_wheel_horizontal_scroll.dart';
import '../models/recipe_detail.dart';
import '../repositories/recipe_repository.dart';

/// 矩阵单元格
class MatrixCell {
  final String display;
  final bool isLowest;
  final bool hasPrice;
  const MatrixCell(
      {required this.display, this.isLowest = false, this.hasPrice = true});
}

/// 矩阵行
class MatrixRow {
  final String name;
  final String quantityDisplay;
  final String? fallbackChain;
  final Map<String, MatrixCell> cells;
  const MatrixRow({
    required this.name,
    required this.quantityDisplay,
    this.fallbackChain,
    required this.cells,
  });
}

/// 构建比价矩阵行（对齐 web MerchantPriceMatrix.tableRows：
/// 优先 total_cost 预估总价、回退 price 单价；is_lowest 高亮；无价格「—」）。
List<MatrixRow> buildMatrixRows({
  required List<RecipeIngredient> ingredients,
  required List<MerchantPriceItem> prices,
}) {
  if (ingredients.isEmpty) return const [];
  final names = <String>[];
  for (final p in prices) {
    for (final pr in p.prices) {
      final n = _merchantLabel(pr);
      if (!names.contains(n)) names.add(n);
    }
  }

  return ingredients
      .where((ing) => ing.ingredientId != null)
      .map((ing) {
        // 显式循环查找（避免 firstOrNull 额外依赖）
        MerchantPriceItem? item;
        for (final p in prices) {
          if (p.recipeIngredientId == ing.id) {
            item = p;
            break;
          }
        }
        final cells = <String, MatrixCell>{};
        for (final name in names) {
          MerchantPriceRecord? match;
          for (final pr in item?.prices ?? const <MerchantPriceRecord>[]) {
            final n = _merchantLabel(pr);
            if (n == name) {
              match = pr;
              break;
            }
          }
          if (match != null) {
            final displayVal = match.totalCost ?? match.price;
            cells[name] = MatrixCell(
              display: displayVal.toStringAsFixed(2),
              isLowest: match.isLowest,
            );
          } else {
            cells[name] = const MatrixCell(
                display: '—', isLowest: false, hasPrice: false);
          }
        }
        return MatrixRow(
          name: ing.name,
          quantityDisplay: _qtyText(ing),
          fallbackChain: item?.fallbackChain,
          cells: cells,
        );
      })
      .toList();
}

/// 商家列标签：merchantName 为空时回退「商家{id}」
String _merchantLabel(MerchantPriceRecord pr) =>
    pr.merchantName.isEmpty ? '商家${pr.merchantId}' : pr.merchantName;

String _qtyText(RecipeIngredient ing) {
  if (ing.quantityRange != null && ing.quantityRange!.min > 0) {
    return '${_fmt(ing.quantityRange!.min)}-${_fmt(ing.quantityRange!.max)}'
        '${ing.unit == null || ing.unit!.isEmpty ? '' : ' ${ing.unit}'}';
  }
  final q = ing.quantity;
  if (q != null && q.isNotEmpty) {
    return '$q'
        '${ing.unit == null || ing.unit!.isEmpty ? '' : ' ${ing.unit}'}';
  }
  if (ing.originalQuantity != null && ing.originalQuantity!.isNotEmpty) {
    return ing.originalQuantity!;
  }
  return '';
}

String _fmt(double v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

/// 商家比价推荐矩阵：横向滚动表（行=食材，列=商家），最低价橙色加粗、缺失「—」。
/// 桌面端支持鼠标滚轮水平滚动（见 MouseWheelHorizontalScroll）。
class MerchantPriceMatrix extends StatefulWidget {
  final List<RecipeIngredient> ingredients;
  final List<MerchantPriceItem> prices;
  final bool loading;
  const MerchantPriceMatrix({
    super.key,
    required this.ingredients,
    required this.prices,
    this.loading = false,
  });

  @override
  State<MerchantPriceMatrix> createState() => _MerchantPriceMatrixState();
}

class _MerchantPriceMatrixState extends State<MerchantPriceMatrix> {
  final ScrollController _controller = ScrollController();
  // 统一行高：冻结列与滚动列拆成两个 Table，只有行高固定才能逐行对齐
  static const double _rowHeight = 44;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows =
        buildMatrixRows(ingredients: widget.ingredients, prices: widget.prices);
    final names = <String>[];
    for (final r in rows) {
      for (final name in r.cells.keys) {
        if (!names.contains(name)) names.add(name);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.table_chart_outlined,
              color: theme.colorScheme.tertiary, size: 20),
          const SizedBox(width: 8),
          Text('商家比价推荐',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        if (widget.loading && rows.isEmpty)
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (names.isEmpty)
          SizedBox(
            height: 100,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_chart_outlined,
                      size: 40, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text('暂无比价数据',
                      style: TextStyle(color: theme.colorScheme.outline)),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 冻结列：食材/用量（web .vue:176 sticky-col 语义，横向滚动不参与）
                _buildFrozenColumn(context, theme, rows),
                Expanded(
                  child: MouseWheelHorizontalScroll(
                    controller: _controller,
                    child: SingleChildScrollView(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      child: _buildPriceTable(context, theme, rows, names),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 冻结列：surface 背景盖住下层滚动内容 + 右侧 1px 分隔线，滚动时首列不动
  Widget _buildFrozenColumn(
      BuildContext context, ThemeData theme, List<MatrixRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Table(
        columnWidths: const {0: FixedColumnWidth(150)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside:
              BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest),
            children: [
              SizedBox(height: _rowHeight, child: _headerCell(theme, '食材 / 用量')),
            ],
          ),
          for (final row in rows)
            TableRow(children: [
              SizedBox(
                height: _rowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(row.name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    // 用量 badge（web .vue:31 qty-badge 灰色小字）
                    if (row.quantityDisplay.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(row.quantityDisplay,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.outline)),
                      ),
                    if (row.fallbackChain != null &&
                        row.fallbackChain!.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: EdgeInsets.zero,
                        iconSize: 14,
                        icon: Icon(Icons.info_outline,
                            color: theme.colorScheme.primary),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('根据以下食材计算价格：'),
                            scrollable: true,
                            content: Text(row.fallbackChain!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('知道了'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
        ],
      ),
    );
  }

  // 滚动列：商家价格（行高与冻结列一致的 _rowHeight）
  Widget _buildPriceTable(BuildContext context, ThemeData theme,
      List<MatrixRow> rows, List<String> names) {
    return Table(
      columnWidths: {
        for (var i = 0; i < names.length; i++) i: const FixedColumnWidth(110),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside:
            BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        verticalInside:
            BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      children: [
        // 表头
        TableRow(
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest),
          children: [
            for (final n in names)
              SizedBox(height: _rowHeight, child: _headerCell(theme, n, right: true)),
          ],
        ),
        for (final row in rows)
          TableRow(children: [
            for (final n in names)
              SizedBox(
                height: _rowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          // ¥ 前缀（对齐 web .vue:46 与 Task 8：¥3.50 而非 3.50 ¥）
                          row.cells[n]!.hasPrice
                              ? '¥${row.cells[n]!.display}'
                              : row.cells[n]!.display,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: !row.cells[n]!.hasPrice
                                ? theme.colorScheme.outlineVariant
                                : row.cells[n]!.isLowest
                                    ? const Color(0xFFE65100)
                                    : null,
                            fontWeight: row.cells[n]!.isLowest
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ]),
      ],
    );
  }

  Widget _headerCell(ThemeData theme, String text, {bool right = false}) {
    // Align 撑满外层 SizedBox(height: _rowHeight) 保证垂直居中：直接 Padding
    // 会在 tight 高度约束下把 Text 顶对齐（表头贴行顶的根因）
    return Align(
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

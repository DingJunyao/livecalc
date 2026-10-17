import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/currency_fmt.dart';

/// 成本走势的 y 轴范围：把平均线与区间带一起纳入，上下各留 8% 余量。
/// 单独抽出来是为了能脱离绘制做单测。
({double lower, double upper}) trendRange(
  List<double> avg,
  List<double?> min,
  List<double?> max,
) {
  final values = <double>[
    ...avg,
    ...min.whereType<double>(),
    ...max.whereType<double>(),
  ];
  if (values.isEmpty) return (lower: 0, upper: 1);
  final lo = values.reduce((a, b) => a < b ? a : b);
  final hi = values.reduce((a, b) => a > b ? a : b);
  final span = hi - lo;
  if (span == 0) {
    final pad = hi == 0 ? 1.0 : hi.abs() * 0.1;
    return (lower: lo - pad, upper: hi + pad);
  }
  return (lower: lo - span * 0.08, upper: hi + span * 0.08);
}

/// 成本走势图：平均线 + 价格区间带（min–max），点按某天可看当日平均与区间。
/// 与 web 试算详情同口径（后端 as-of 逐日 cost-trend，含 min_cost/max_cost/avg_cost）。
class CostTrendChart extends StatefulWidget {
  final List<Map<String, dynamic>> points;
  final String userCurrency;
  final bool loading;

  /// 区间切换（天）：null 表示不显示切换按钮
  final int? days;
  final ValueChanged<int>? onDaysChanged;

  static const daysOptions = <int>[30, 90, 365];

  const CostTrendChart({
    super.key,
    required this.points,
    this.userCurrency = 'CNY',
    this.loading = false,
    this.days,
    this.onDaysChanged,
  });

  @override
  State<CostTrendChart> createState() => _CostTrendChartState();
}

class _CostTrendChartState extends State<CostTrendChart> {
  int? _selected;

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static double? _numOrNull(dynamic v) => (v as num?)?.toDouble();

  @override
  void didUpdateWidget(CostTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points.length != widget.points.length ||
        oldWidget.points != widget.points) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final points = widget.points;
    final avg =
        points.map((p) => _num(p['total_cost'])).toList(growable: false);
    final min =
        points.map((p) => _numOrNull(p['min_cost'])).toList(growable: false);
    final max =
        points.map((p) => _numOrNull(p['max_cost'])).toList(growable: false);
    final hasBand = min.any((v) => v != null) && max.any((v) => v != null);

    final index = _selected ?? (points.isEmpty ? null : points.length - 1);
    final point = index == null ? null : points[index];
    final range =
        trendRange(avg, hasBand ? min : const [], hasBand ? max : const []);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart,
                    color: theme.colorScheme.tertiary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.plansCostTrend,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.days != null && widget.onDaysChanged != null)
                  for (final option in CostTrendChart.daysOptions)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          foregroundColor: option == widget.days
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        onPressed: option == widget.days
                            ? null
                            : () => widget.onDaysChanged!(option),
                        child: Text('$option${l10n.plansDays}'),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.loading)
              const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (points.length < 2)
              SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    l10n.recipeNoCostTrend,
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ),
              )
            else ...[
              if (point != null)
                Text(
                  point['date']?.toString() ?? '',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              if (point != null)
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _summaryItem(
                      theme,
                      l10n.chartsAverage,
                      formatMoney(
                        _num(point['total_cost']),
                        widget.userCurrency,
                      ),
                    ),
                    if (hasBand &&
                        _numOrNull(point['min_cost']) != null &&
                        _numOrNull(point['max_cost']) != null) ...[
                      _summaryItem(
                        theme,
                        l10n.chartsLow,
                        formatMoney(
                          _num(point['min_cost']),
                          widget.userCurrency,
                        ),
                      ),
                      _summaryItem(
                        theme,
                        l10n.chartsHigh,
                        formatMoney(
                          _num(point['max_cost']),
                          widget.userCurrency,
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 6),
              SizedBox(
                height: 170,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    void selectAt(double dx) {
                      final step = constraints.maxWidth / (points.length - 1);
                      final i = (dx / step).round().clamp(0, points.length - 1);
                      setState(() => _selected = i);
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => selectAt(d.localPosition.dx),
                      onHorizontalDragUpdate: (d) =>
                          selectAt(d.localPosition.dx),
                      child: CustomPaint(
                        painter: CostTrendPainter(
                          avg: avg,
                          min: hasBand ? min : null,
                          max: hasBand ? max : null,
                          lower: range.lower,
                          upper: range.upper,
                          selected: index,
                          lineColor: theme.colorScheme.primary,
                          bandColor:
                              theme.colorScheme.primary.withValues(alpha: 0.18),
                          gridColor: theme.colorScheme.outlineVariant,
                          labelStyle: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline),
                          startLabel: points.first['date'] as String? ?? '',
                          endLabel: points.last['date'] as String? ?? '',
                          moneyLabel: (v) =>
                              formatMoney(v, widget.userCurrency),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(ThemeData theme, String label, String value) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.outline),
        children: [
          TextSpan(
            text: value,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 平均线 + 区间带（对齐 web 成本走势：带 = min..max，线 = 平均）。
class CostTrendPainter extends CustomPainter {
  final List<double> avg;
  final List<double?>? min;
  final List<double?>? max;
  final double lower;
  final double upper;
  final int? selected;
  final Color lineColor;
  final Color bandColor;
  final Color gridColor;
  final TextStyle? labelStyle;
  final String startLabel;
  final String endLabel;
  final String Function(double value) moneyLabel;

  CostTrendPainter({
    required this.avg,
    this.min,
    this.max,
    required this.lower,
    required this.upper,
    this.selected,
    required this.lineColor,
    required this.bandColor,
    required this.gridColor,
    required this.labelStyle,
    required this.startLabel,
    required this.endLabel,
    required this.moneyLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 62.0;
    const rightPad = 8.0;
    const topPad = 6.0;
    const bottomPad = 22.0;
    final width = size.width - leftPad - rightPad;
    final height = size.height - topPad - bottomPad;
    if (width <= 0 || height <= 0 || avg.length < 2) return;

    double y(double value) {
      final ratio = (value - lower) / (upper - lower);
      return topPad + (1 - ratio.clamp(0.0, 1.0)) * height;
    }

    double x(int index) => leftPad + width * (index / (avg.length - 1));

    // 网格 + 左侧刻度（3 条）
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final value = upper - (upper - lower) * (i / 2);
      final gy = y(value);
      canvas.drawLine(
          Offset(leftPad, gy), Offset(size.width - rightPad, gy), grid);
      final tp = TextPainter(
        text: TextSpan(text: moneyLabel(value), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPad - 6);
      tp.paint(canvas, Offset(leftPad - 6 - tp.width, gy - tp.height / 2));
    }

    // 区间带：先沿 max 走一遍，再沿 min 走回来
    final minValues = min;
    final maxValues = max;
    if (minValues != null && maxValues != null) {
      final band = Path();
      for (var i = 0; i < avg.length; i++) {
        final offset = Offset(x(i), y(maxValues[i] ?? avg[i]));
        if (i == 0) {
          band.moveTo(offset.dx, offset.dy);
        } else {
          band.lineTo(offset.dx, offset.dy);
        }
      }
      for (var i = avg.length - 1; i >= 0; i--) {
        band.lineTo(x(i), y(minValues[i] ?? avg[i]));
      }
      band.close();
      canvas.drawPath(band, Paint()..color = bandColor);
    }

    // 平均线
    final line = Path();
    for (var i = 0; i < avg.length; i++) {
      final offset = Offset(x(i), y(avg[i]));
      if (i == 0) {
        line.moveTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // 选中日：竖线 + 圆点
    final sel = selected;
    if (sel != null && sel >= 0 && sel < avg.length) {
      final sx = x(sel);
      canvas.drawLine(
        Offset(sx, topPad),
        Offset(sx, topPad + height),
        Paint()
          ..color = lineColor.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
          Offset(sx, y(avg[sel])), 3.5, Paint()..color = lineColor);
    }

    // 首尾日期
    for (final (label, alignRight) in [(startLabel, false), (endLabel, true)]) {
      if (label.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      tp.paint(
        canvas,
        Offset(alignRight ? size.width - rightPad - tp.width : leftPad,
            topPad + height + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CostTrendPainter old) =>
      old.avg != avg ||
      old.min != min ||
      old.max != max ||
      old.lower != lower ||
      old.upper != upper ||
      old.selected != selected;
}

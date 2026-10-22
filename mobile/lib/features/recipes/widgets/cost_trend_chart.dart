import 'package:flutter/material.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/computed_price_point.dart';
import '../../../shared/utils/smooth_path.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../repositories/recipe_repository.dart';

/// 成本趋势图表：min/max 区间带 + avg 折线 + 触摸 tooltip + 区间筛选。
/// 与 Web 端 PriceTrendChart 体验一致（无第三方图表库依赖）。
class CostTrendChart extends StatefulWidget {
  final List<CostHistoryPoint> points;
  final bool loading;
  final String unit;
  final Color color;
  final ValueChanged<int>? onRangeChange;
  final String userCurrency;

  /// 替代/回退/半成品/从属折算价（每斤），画紫色虚线 + 浅色区间带。
  final List<ComputedPricePoint> computedPoints;

  /// 「含替代/从属」开关状态（父组件持有；切换后父组件重新取数）
  final bool includeComputed;

  /// 是否显示「含替代/从属」开关（原料详情用）
  final bool showComputedSwitch;
  final ValueChanged<bool>? onIncludeComputedChange;

  const CostTrendChart({
    super.key,
    required this.points,
    this.loading = false,
    this.unit = '元',
    this.color = const Color(0xFFFF9800),
    this.onRangeChange,
    this.userCurrency = 'CNY',
    this.computedPoints = const [],
    this.includeComputed = true,
    this.showComputedSwitch = false,
    this.onIncludeComputedChange,
  });

  @override
  State<CostTrendChart> createState() => _CostTrendChartState();
}

enum _Range { week, month, quarter, year, all }

String _formatDate(String value, {bool short = false}) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return short ? formatShortDate(date) : formatDate(date);
}

class _CostTrendChartState extends State<CostTrendChart> {
  _Range _selected = _Range.month;
  int? _touchIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, color: widget.color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.recipeCostTrend,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.showComputedSwitch)
              Tooltip(
                message: l10n.includeComputed,
                child: Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    key: const Key('include_computed_switch'),
                    value: widget.includeComputed,
                    onChanged: (v) => widget.onIncludeComputedChange?.call(v),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            _buildRangeToggle(),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: Stack(children: [
            _buildBody(theme),
            // 切换范围加载中：保留旧数据 + 顶部细进度条，避免用户误以为
            // 「选什么都没反应」（慢查询时旧图要一直显示到新数据到达）
            if (widget.loading && widget.points.isNotEmpty)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ]),
        ),
      ],
    );
  }

  // 范围切换用 DropdownButton 而非 SegmentedButton：多段按钮在窄屏标题行
  // 会撑爆报 RIGHT OVERFLOWED，下拉宽度自适应当前选中项根治溢出
  Widget _buildRangeToggle() {
    final l10n = AppLocalizations.of(context);
    return DropdownButton<_Range>(
      key: const Key('range_dropdown'),
      value: _selected,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: _Range.values
          .map((r) =>
              DropdownMenuItem(value: r, child: Text(_rangeLabel(r, l10n))))
          .toList(),
      onChanged: (r) {
        if (r == null) return;
        setState(() => _selected = r);
        final days = switch (r) {
          _Range.week => 7,
          _Range.month => 30,
          _Range.quarter => 90,
          _Range.year => 365,
          _Range.all => 3650,
        };
        widget.onRangeChange?.call(days);
      },
    );
  }

  String _rangeLabel(_Range range, AppLocalizations l10n) {
    return switch (range) {
      _Range.week => l10n.recipeWeek,
      _Range.month => l10n.recipeMonth,
      _Range.quarter => l10n.recipeQuarter,
      _Range.year => l10n.recipeYear,
      _Range.all => l10n.recipeAll,
    };
  }

  Widget _buildBody(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    if (widget.loading && widget.points.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (widget.points.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(l10n.recipeNoCostTrend,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      );
    }
    return _Chart(
      points: widget.points,
      color: widget.color,
      touchIndex: _touchIndex,
      onTouch: (i) => setState(() => _touchIndex = i),
      userCurrency: widget.userCurrency,
      computedPoints: widget.includeComputed ? widget.computedPoints : const [],
    );
  }
}

class _Chart extends StatelessWidget {
  final List<CostHistoryPoint> points;
  final Color color;
  final int? touchIndex;
  final ValueChanged<int?> onTouch;
  final String userCurrency;
  final List<ComputedPricePoint> computedPoints;

  const _Chart({
    required this.points,
    required this.color,
    required this.touchIndex,
    required this.onTouch,
    required this.userCurrency,
    this.computedPoints = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 快速点击（tap）也要出 tooltip——onPanDown 只在拖动手势竞技场获胜后触发，
          // 单点 tap 永远不触发，用户「点击没提示」的根因
          // tap 不清空 tooltip（无 onTapUp 清空），tooltip 驻留到下次触摸——
          // 对齐 web 点击选中点语义，非遗漏
          onTapDown: (d) => _handleTouch(d.localPosition, constraints.biggest),
          onPanDown: (d) => _handleTouch(d.localPosition, constraints.biggest),
          onPanUpdate: (d) =>
              _handleTouch(d.localPosition, constraints.biggest),
          onPanEnd: (_) => onTouch(null),
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _TrendPainter(
                  points: points,
                  computedPoints: computedPoints,
                  color: color,
                  touchIndex: touchIndex,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                  userCurrency: userCurrency,
                ),
              ),
              if (touchIndex != null && touchIndex! < points.length)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _Tooltip(
                      points: points,
                      computedPoints: computedPoints,
                      index: touchIndex!,
                      color: color,
                      userCurrency: userCurrency),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleTouch(Offset local, Size size) {
    if (points.isEmpty) return;
    // 只有一个数据点时没有横向插值可言，直接选中它（tooltip 仍能看到日期与价格）
    if (points.length == 1) {
      onTouch(0);
      return;
    }
    const plotLeft = 44.0;
    final plotW = size.width - plotLeft - 8;
    final dx = plotW / (points.length - 1);
    final rel = (local.dx - plotLeft) / dx;
    final idx = rel.round().clamp(0, points.length - 1);
    onTouch(idx);
  }
}

class _Tooltip extends StatelessWidget {
  final List<CostHistoryPoint> points;
  final List<ComputedPricePoint> computedPoints;
  final int index;
  final Color color;
  final String userCurrency;
  const _Tooltip(
      {required this.points,
      this.computedPoints = const [],
      required this.index,
      required this.color,
      required this.userCurrency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final p = points[index];
    final computed = _computedForDate(p.date);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formatDate(p.date),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onInverseSurface)),
            const SizedBox(height: 2),
            Text(
                '${l10n.recipeAverageLabel} ${formatMoney(p.avgCost, userCurrency)}',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold)),
            Text(
                '${l10n.recipeRangeLabel} ${formatMoney(p.minCost, userCurrency)} ~ ${formatMoney(p.maxCost, userCurrency)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onInverseSurface)),
            if (computed != null) ...[
              const SizedBox(height: 2),
              Text(
                  '${l10n.computedPrice} ${formatMoney(computed.avg, userCurrency)}'
                  '${computed.max > computed.min + 1e-9 ? ' (${formatMoney(computed.min, userCurrency)} ~ ${formatMoney(computed.max, userCurrency)})' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFB39DDB),
                      fontWeight: FontWeight.bold)),
              if (computed.chain != null && computed.chain!.isNotEmpty)
                Text(_computedSourceLabel(computed.source, l10n),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onInverseSurface
                            .withValues(alpha: 0.7))),
            ],
          ],
        ),
      ),
    );
  }

  ComputedPricePoint? _computedForDate(String date) {
    for (final c in computedPoints) {
      if (c.date == date) return c;
    }
    return null;
  }
}

String _computedSourceLabel(String source, AppLocalizations l10n) {
  switch (source) {
    case 'fallback':
      return l10n.computedSourceFallback;
    case 'name_match':
      return l10n.computedSourceNameMatch;
    case 'recipe':
      return l10n.computedSourceRecipe;
    case 'contains_aggregation':
      return l10n.computedSourceContains;
    default:
      return l10n.computedPrice;
  }
}

class _TrendPainter extends CustomPainter {
  final List<CostHistoryPoint> points;
  final Color color;
  final int? touchIndex;
  final Color gridColor;
  final String userCurrency;
  final List<ComputedPricePoint> computedPoints;

  _TrendPainter({
    required this.points,
    required this.color,
    required this.touchIndex,
    required this.gridColor,
    required this.userCurrency,
    this.computedPoints = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const plotLeft = 44.0;
    const plotTop = 8.0;
    final plotRight = size.width - 8;
    final plotBottom = size.height - 24;
    final plotW = plotRight - plotLeft;
    final plotH = plotBottom - plotTop;

    double minV = double.infinity;
    double maxV = double.negativeInfinity;
    for (final p in points) {
      if (p.minCost < minV) minV = p.minCost;
      if (p.maxCost > maxV) maxV = p.maxCost;
    }
    // 折算序列的区间也要落进同一坐标系，否则虚线/区间带会被裁在画布外
    for (final c in computedPoints) {
      if (c.min < minV) minV = c.min;
      if (c.max > maxV) maxV = c.max;
    }
    if (maxV == minV) {
      maxV += 1;
      minV -= 1;
    }
    final pad = (maxV - minV) * 0.08;
    minV -= pad;
    maxV += pad;
    final yScale = plotH / (maxV - minV);

    double xAt(int i) => plotLeft + (plotW / (points.length - 1)) * i;
    double yAt(double v) => plotBottom - (v - minV) * yScale;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    // 镙囩鏍煎眰闂撮殧灏忎簬 1 鏃朵繚鐣欎竴浣嶅皬鏁帮紝閬垮厤鍥涜垗浜斿叆鍚庡嚭鐜?6,6,7,7 杩欐牱鐨勯噸澶嶆爣绛?
    final gridStep = (maxV - minV) / 4;
    for (var i = 0; i <= 4; i++) {
      final v = minV + (maxV - minV) * i / 4;
      final y = yAt(v);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      final label = gridStep < 1
          ? formatMoney(v, userCurrency)
          : formatMoney(v.round(), userCurrency);
      _text(canvas, label, Offset(2, y - 7), gridColor, 9);
    }

    // 只有一个数据点（实体只有一次价格记录、所选区间也拿不到更早的携带起点）：
    // 折线与区间带都无从画起，但至少要把这个点画出来，否则整张图是空白。
    if (points.length < 2) {
      final centerX = (plotLeft + plotRight) / 2;
      canvas.drawCircle(
        Offset(centerX, yAt(points.first.avgCost)),
        4,
        Paint()..color = color,
      );
      _text(
        canvas,
        _formatDate(points.first.date, short: true),
        Offset(centerX - 12, plotBottom + 6),
        gridColor,
        9,
      );
      return;
    }

    // min/max 区间带
    final bandPath = Path();
    appendSmoothSegments(
      bandPath,
      [
        for (var i = 0; i < points.length; i++)
          Offset(xAt(i), yAt(points[i].maxCost)),
      ],
    );
    appendSmoothSegments(
      bandPath,
      [
        for (var i = points.length - 1; i >= 0; i--)
          Offset(xAt(i), yAt(points[i].minCost)),
      ],
      moveToFirst: false,
    );
    bandPath.close();
    canvas.drawPath(
      bandPath,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    // 折算序列（替代/回退/半成品/从属）：紫色浅色区间带 + 紫色虚线均价
    _drawComputed(canvas, xAt, yAt);

    // min/max 虚线
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _drawDashed(canvas, _pathOf(points, xAt, (p) => p.minCost, yAt), dashPaint);
    _drawDashed(canvas, _pathOf(points, xAt, (p) => p.maxCost, yAt), dashPaint);

    // 均价折线
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;
    canvas.drawPath(_pathOf(points, xAt, (p) => p.avgCost, yAt), linePaint);

    // 触摸十字线 + 高亮点
    if (touchIndex != null && touchIndex! >= 0 && touchIndex! < points.length) {
      final x = xAt(touchIndex!);
      canvas.drawLine(
        Offset(x, plotTop),
        Offset(x, plotBottom),
        Paint()
          ..color = gridColor.withValues(alpha: 0.8)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(x, yAt(points[touchIndex!].avgCost)),
        4,
        Paint()..color = color,
      );
    }

    // X 轴日期（首/中/尾）
    final idxList = [0, (points.length / 2).floor(), points.length - 1];
    for (final i in idxList) {
      final label = _formatDate(points[i].date, short: true);
      _text(canvas, label, Offset(xAt(i) - 12, plotBottom + 6), gridColor, 9);
    }
  }

  Path _pathOf(List<CostHistoryPoint> pts, double Function(int) xAt,
      double Function(CostHistoryPoint) sel, double Function(double) yAt) {
    return buildSmoothPath([
      for (var i = 0; i < pts.length; i++) Offset(xAt(i), yAt(sel(pts[i]))),
    ]);
  }

  /// 折算序列：按日期对齐到主序列的下标位置（同日期无点则跳过）。
  void _drawComputed(
      Canvas canvas, double Function(int) xAt, double Function(double) yAt) {
    if (computedPoints.isEmpty) return;
    final indexByDate = <String, int>{};
    for (var i = 0; i < points.length; i++) {
      indexByDate[points[i].date] = i;
    }
    final matched = <int, ComputedPricePoint>{};
    for (final c in computedPoints) {
      final idx = indexByDate[c.date];
      if (idx != null) matched[idx] = c;
    }
    if (matched.isEmpty) return;
    const purple = Color(0xFF7E57C2);
    if (matched.length >= 2) {
      final idxs = matched.keys.toList()..sort();
      final band = Path();
      appendSmoothSegments(
        band,
        [for (final i in idxs) Offset(xAt(i), yAt(matched[i]!.max))],
        moveToFirst: true,
      );
      appendSmoothSegments(
        band,
        [for (final i in idxs.reversed) Offset(xAt(i), yAt(matched[i]!.min))],
        moveToFirst: false,
      );
      band.close();
      canvas.drawPath(
        band,
        Paint()
          ..color = purple.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
      final line = buildSmoothPath([
        for (final i in idxs) Offset(xAt(i), yAt(matched[i]!.avg)),
      ]);
      _drawDashed(
        canvas,
        line,
        Paint()
          ..color = purple
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      final entry = matched.entries.first;
      canvas.drawCircle(
        Offset(xAt(entry.key), yAt(entry.value.avg)),
        3,
        Paint()..color = purple,
      );
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + 4;
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += 7;
      }
    }
  }

  void _text(Canvas canvas, String s, Offset pos, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points != points ||
      old.computedPoints != computedPoints ||
      old.touchIndex != touchIndex ||
      old.color != color ||
      old.userCurrency != userCurrency;
}

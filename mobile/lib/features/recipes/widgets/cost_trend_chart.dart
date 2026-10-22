import 'package:flutter/material.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/computed_price_point.dart';
import '../../../shared/utils/smooth_path.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../prices/utils/price_trend.dart' show PriceMerchantSeries;
import '../repositories/recipe_repository.dart';

/// 按商家对比时各商家线条的固定色板（与 Web 端商家对比同一组色）。
const List<Color> kMerchantLineColors = [
  Color(0xFF1976D2),
  Color(0xFF388E3C),
  Color(0xFFF57C00),
  Color(0xFF7B1FA2),
  Color(0xFF00796B),
  Color(0xFFC2185B),
  Color(0xFF455A64),
  Color(0xFF5D4037),
];

/// 趋势图口径：综合（所有商家合并）/ 按商家对比。
enum TrendViewMode { overall, merchant }

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

  /// 按商家对比序列（≥2 家时出现「综合 / 按商家」切换）
  final List<PriceMerchantSeries> merchantSeries;

  /// 综合口径的真实记录日（只在有记录的日子画点）
  final Set<String> recordDays;

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
    this.merchantSeries = const [],
    this.recordDays = const {},
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
  TrendViewMode _viewMode = TrendViewMode.overall;
  final Set<int> _selectedMerchants = {};

  bool get _canCompareMerchants => widget.merchantSeries.length >= 2;

  @override
  void initState() {
    super.initState();
    _syncDefaultMerchants();
  }

  @override
  void didUpdateWidget(covariant CostTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换区间会重取商家序列：只在「商家集合变了」时重置默认选中，
    // 用户手动勾选的商家在切区间后保持（与 Web 端一致）。
    final oldIds = oldWidget.merchantSeries.map((e) => e.merchantId).toSet();
    final newIds = widget.merchantSeries.map((e) => e.merchantId).toSet();
    if (oldIds.length != newIds.length || !oldIds.containsAll(newIds)) {
      _selectedMerchants.removeWhere((id) => !newIds.contains(id));
      _syncDefaultMerchants();
    }
    if (!_canCompareMerchants && _viewMode == TrendViewMode.merchant) {
      _viewMode = TrendViewMode.overall;
    }
  }

  /// 默认选中记录数最多的前 3 家（防线条过多）；已选过则不覆盖。
  void _syncDefaultMerchants() {
    if (!_canCompareMerchants || _selectedMerchants.isNotEmpty) return;
    _selectedMerchants.addAll(
      widget.merchantSeries.take(3).map((e) => e.merchantId),
    );
  }

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
            const SizedBox(width: 8),
            // 「综合 / 按商家」与时间区间一样做成下拉（≥2 家商家时出现）
            if (_canCompareMerchants) ...[
              _buildModeToggle(),
              const SizedBox(width: 6),
            ],
            _buildRangeToggle(),
          ],
        ),
        // 「含替代/从属」：移动端没有 hover，必须带可见文字标签，否则只有一个光秃秃的开关
        if (widget.showComputedSwitch)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              key: const Key('include_computed_row'),
              onTap: () =>
                  widget.onIncludeComputedChange?.call(!widget.includeComputed),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 28,
                    child: FittedBox(
                      child: Switch(
                        key: const Key('include_computed_switch'),
                        value: widget.includeComputed,
                        onChanged: (v) =>
                            widget.onIncludeComputedChange?.call(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.includeComputed,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        // 「按商家」时用下拉选择要对比的商家（多选，默认记录数最多的前 3 家）。
        // 不再用单行 chips：横向滚动既看不出能拖，屏幕窄时也难操作。
        if (_canCompareMerchants && _viewMode == TrendViewMode.merchant) ...[
          const SizedBox(height: 6),
          _buildMerchantSelector(theme),
        ],
        const SizedBox(height: 8),
        SizedBox(
          // 按商家模式下方多一行 chips，图高略降保证整体卡片不跳动过大
          height: 210,
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

  /// 商家多选下拉：点开后在底部弹出勾选面板（移动端比横向 chips 更易操作，
  /// 也不会因为「一行标签」让人看不出可以拖动）。
  Widget _buildMerchantSelector(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final selected = widget.merchantSeries
        .where((s) => _selectedMerchants.contains(s.merchantId))
        .toList();
    final String label;
    if (selected.isEmpty) {
      label = l10n.chartByMerchant;
    } else if (selected.length <= 2) {
      label = selected.map((s) => s.name).join('、');
    } else {
      label = '${selected.take(2).map((s) => s.name).join('、')} 等 '
          '${selected.length} 家';
    }
    return InkWell(
      key: const Key('merchant_selector'),
      borderRadius: BorderRadius.circular(8),
      onTap: _openMerchantPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DefaultTextStyle.of(context).style,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openMerchantPicker() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final temp = Set<int>.from(_selectedMerchants);
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.chartByMerchant),
                    trailing: TextButton(
                      onPressed: () => Navigator.pop(ctx, temp),
                      child: Text(l10n.commonDone),
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (var i = 0; i < widget.merchantSeries.length; i++)
                          CheckboxListTile(
                            value: temp
                                .contains(widget.merchantSeries[i].merchantId),
                            title: Text(widget.merchantSeries[i].name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            secondary: CircleAvatar(
                              radius: 6,
                              backgroundColor: kMerchantLineColors[
                                  i % kMerchantLineColors.length],
                            ),
                            dense: true,
                            onChanged: (v) {
                              final id = widget.merchantSeries[i].merchantId;
                              setSheet(() {
                                if (v == true) {
                                  temp.add(id);
                                } else if (temp.length > 1) {
                                  // 至少留一家，避免整张图空白
                                  temp.remove(id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedMerchants
        ..clear()
        ..addAll(picked);
    });
  }

  /// 「综合 / 按商家」下拉：与时间区间下拉同一形态，避免窄屏两个 chips 撑爆标题行。
  Widget _buildModeToggle() {
    final l10n = AppLocalizations.of(context);
    return DropdownButton<TrendViewMode>(
      key: const Key('merchant_mode_dropdown'),
      value: _viewMode,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: TrendViewMode.values
          .map((m) => DropdownMenuItem(
                value: m,
                child: Text(
                  m == TrendViewMode.overall
                      ? l10n.chartOverall
                      : l10n.chartByMerchant,
                  // 不设自定义 style：与时间区间下拉保持同一字号（DropdownButton 默认样式）
                ),
              ))
          .toList(),
      onChanged: (m) {
        if (m == null) return;
        setState(() => _viewMode = m);
      },
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
    final computed = widget.includeComputed
        ? nonDirectComputedPoints(widget.computedPoints)
        : const <ComputedPricePoint>[];
    if (widget.loading && widget.points.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    // 「有数据」= 直接价序列 **或** 折算序列任一存在：
    // 猪肉这类没有直接商品记录、只靠从属聚合的原料，points 为空但
    // computedPoints 有值，不能再显示「暂无成本历史数据」。
    final hasAny = widget.points.isNotEmpty || computed.isNotEmpty;
    if (!hasAny) {
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
    // X 轴日期：优先用直接价序列；没有直接价时用折算点的日期当轴，
    // 否则折算曲线没有可落笔的横坐标。
    final dateAxis = widget.points.isNotEmpty
        ? [for (final p in widget.points) p.date]
        : [for (final c in computed) c.date];
    return _Chart(
      points: widget.points,
      dateAxis: dateAxis,
      color: widget.color,
      touchIndex: _touchIndex,
      onTouch: (i) => setState(() => _touchIndex = i),
      userCurrency: widget.userCurrency,
      computedPoints: computed,
      recordDays: widget.recordDays,
      merchantMode: _viewMode == TrendViewMode.merchant,
      merchantSeries: widget.merchantSeries
          .where((s) => _selectedMerchants.contains(s.merchantId))
          .toList(),
    );
  }
}

class _Chart extends StatelessWidget {
  final List<CostHistoryPoint> points;

  /// X 轴日期（升序）。points 为空时由折算点日期兜底。
  final List<String> dateAxis;
  final Color color;
  final int? touchIndex;
  final ValueChanged<int?> onTouch;
  final String userCurrency;
  final List<ComputedPricePoint> computedPoints;
  final Set<String> recordDays;
  final bool merchantMode;
  final List<PriceMerchantSeries> merchantSeries;

  const _Chart({
    required this.points,
    required this.dateAxis,
    required this.color,
    required this.touchIndex,
    required this.onTouch,
    required this.userCurrency,
    this.computedPoints = const [],
    this.recordDays = const {},
    this.merchantMode = false,
    this.merchantSeries = const [],
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
                  dateAxis: dateAxis,
                  computedPoints: computedPoints,
                  color: color,
                  touchIndex: touchIndex,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                  userCurrency: userCurrency,
                  recordDays: recordDays,
                  merchantMode: merchantMode,
                  merchantSeries: merchantSeries,
                ),
              ),
              if (touchIndex != null && touchIndex! < dateAxis.length)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _Tooltip(
                      points: points,
                      dateAxis: dateAxis,
                      computedPoints: computedPoints,
                      index: touchIndex!,
                      color: color,
                      userCurrency: userCurrency,
                      merchantMode: merchantMode,
                      merchantSeries: merchantSeries),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleTouch(Offset local, Size size) {
    if (dateAxis.isEmpty) return;
    // 只有一个数据点时没有横向插值可言，直接选中它（tooltip 仍能看到日期与价格）
    if (dateAxis.length == 1) {
      onTouch(0);
      return;
    }
    const plotLeft = 44.0;
    final plotW = size.width - plotLeft - 8;
    final dx = plotW / (dateAxis.length - 1);
    final rel = (local.dx - plotLeft) / dx;
    final idx = rel.round().clamp(0, dateAxis.length - 1);
    onTouch(idx);
  }
}

class _Tooltip extends StatelessWidget {
  final List<CostHistoryPoint> points;
  final List<ComputedPricePoint> computedPoints;
  final int index;
  final Color color;
  final String userCurrency;
  final bool merchantMode;
  final List<PriceMerchantSeries> merchantSeries;

  /// X 轴日期（points 为空时由折算点日期兜底）
  final List<String> dateAxis;
  const _Tooltip(
      {required this.points,
      this.computedPoints = const [],
      required this.index,
      required this.color,
      required this.userCurrency,
      this.merchantMode = false,
      this.merchantSeries = const [],
      this.dateAxis = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // 触摸下标对应轴上的日期；points 为空（仅折算）时轴就是折算点日期
    final axisDate = index < dateAxis.length
        ? dateAxis[index]
        : (points.isNotEmpty ? points.first.date : '');
    final hasDirect = index < points.length && points[index].date == axisDate;
    final p = hasDirect ? points[index] : null;
    final computed = _computedForDate(axisDate);
    // 按商家模式：逐行列出各选中商家在该日的均价
    final merchantRows = <Widget>[];
    if (merchantMode) {
      for (var i = 0; i < merchantSeries.length; i++) {
        final s = merchantSeries[i];
        final point = s.points.firstWhere(
          (e) => e.date == axisDate,
          orElse: () => CostHistoryPoint(
              date: axisDate,
              minCost: double.nan,
              maxCost: 0,
              avgCost: double.nan),
        );
        if (point.avgCost.isNaN) continue;
        final color = kMerchantLineColors[i % kMerchantLineColors.length];
        merchantRows.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  // 有区间时一并给出（该商家当天多个商品的 min~max）
                  '${s.name} ${formatMoney(point.avgCost, userCurrency)}'
                  '${point.maxCost > point.minCost + 1e-9 ? ' (${formatMoney(point.minCost, userCurrency)} ~ ${formatMoney(point.maxCost, userCurrency)})' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onInverseSurface),
                ),
              ),
            ],
          ),
        ));
      }
    }
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
            Text(_formatDate(axisDate),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onInverseSurface)),
            if (merchantMode) ...[
              if (merchantRows.isEmpty)
                Text(l10n.recipeNoCostTrend,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onInverseSurface
                            .withValues(alpha: 0.7))),
              ...merchantRows,
            ] else ...[
              // 没有直接价（仅折算）时没有 avg/range 主序列行
              if (p != null) ...[
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
              ],
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
  final List<String> dateAxis;
  final Color color;
  final int? touchIndex;
  final Color gridColor;
  final String userCurrency;
  final List<ComputedPricePoint> computedPoints;
  final Set<String> recordDays;
  final bool merchantMode;
  final List<PriceMerchantSeries> merchantSeries;

  _TrendPainter({
    required this.points,
    required this.dateAxis,
    required this.color,
    required this.touchIndex,
    required this.gridColor,
    required this.userCurrency,
    this.computedPoints = const [],
    this.recordDays = const {},
    this.merchantMode = false,
    this.merchantSeries = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // points 为空（仅折算序列）时也要画：轴由 dateAxis 兜底
    if (dateAxis.isEmpty) return;
    const plotLeft = 44.0;
    const plotTop = 8.0;
    final plotRight = size.width - 8;
    final plotBottom = size.height - 24;
    final plotW = plotRight - plotLeft;
    final plotH = plotBottom - plotTop;

    double minV = double.infinity;
    double maxV = double.negativeInfinity;
    if (merchantMode) {
      for (final s in merchantSeries) {
        for (final p in s.points) {
          if (p.minCost < minV) minV = p.minCost;
          if (p.maxCost > maxV) maxV = p.maxCost;
        }
      }
      if (minV == double.infinity) {
        minV = 0;
        maxV = 1;
      }
    } else {
      for (final p in points) {
        if (p.minCost < minV) minV = p.minCost;
        if (p.maxCost > maxV) maxV = p.maxCost;
      }
      // 折算序列的区间也要落进同一坐标系，否则虚线/区间带会被裁在画布外
      for (final c in computedPoints) {
        if (c.min < minV) minV = c.min;
        if (c.max > maxV) maxV = c.max;
      }
    }
    if (maxV == minV) {
      maxV += 1;
      minV -= 1;
    }
    final pad = (maxV - minV) * 0.08;
    minV -= pad;
    maxV += pad;
    final yScale = plotH / (maxV - minV);

    double xAt(int i) =>
        plotLeft +
        (plotW / (dateAxis.length > 1 ? dateAxis.length - 1 : 1)) * i;
    double yAt(double v) => plotBottom - (v - minV) * yScale;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
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

    // ---- 按商家对比：每家一条均价线，只在真实记录日画点 ----
    if (merchantMode) {
      final dateIndex = <String, int>{};
      for (var i = 0; i < dateAxis.length; i++) {
        dateIndex[dateAxis[i]] = i;
      }
      for (var m = 0; m < merchantSeries.length; m++) {
        final series = merchantSeries[m];
        final lineColor = kMerchantLineColors[m % kMerchantLineColors.length];
        final linePaint = Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..isAntiAlias = true;
        final idxs = <int>[];
        final pts = <Offset>[];
        final bandPts = <(int, CostHistoryPoint)>[];
        for (final p in series.points) {
          final idx = dateIndex[p.date];
          if (idx == null) continue;
          idxs.add(idx);
          pts.add(Offset(xAt(idx), yAt(p.avgCost)));
          // 该商家当天有多个商品（或价格区间）时记录区间点，稍后画淡色带
          if (p.maxCost > p.minCost + 1e-9) bandPts.add((idx, p));
        }
        if (pts.length >= 2) {
          canvas.drawPath(buildSmoothPath(pts), linePaint);
        } else if (pts.length == 1) {
          canvas.drawCircle(pts.first, 3, Paint()..color = lineColor);
        }
        // 区间带：与该商家均价同色、低透明度（该商家当天有 min/max 跨度时才有）
        if (bandPts.length >= 2) {
          final bandPath = Path();
          appendSmoothSegments(
            bandPath,
            [
              for (final (i, p) in bandPts) Offset(xAt(i), yAt(p.maxCost)),
            ],
            moveToFirst: true,
          );
          appendSmoothSegments(
            bandPath,
            [
              for (final (i, p) in bandPts.reversed)
                Offset(xAt(i), yAt(p.minCost)),
            ],
            moveToFirst: false,
          );
          bandPath.close();
          canvas.drawPath(
            bandPath,
            Paint()
              ..color = lineColor.withValues(alpha: 0.12)
              ..style = PaintingStyle.fill,
          );
        }
        // 只在「该商家真有记录」的日子画点，as-of 携带日不画
        for (var k = 0; k < idxs.length; k++) {
          if (!series.recordDays.contains(series.points[k].date)) continue;
          canvas.drawCircle(pts[k], 2.6, Paint()..color = lineColor);
        }
      }
      if (touchIndex != null &&
          touchIndex! >= 0 &&
          touchIndex! < dateAxis.length) {
        final x = xAt(touchIndex!);
        canvas.drawLine(
          Offset(x, plotTop),
          Offset(x, plotBottom),
          Paint()
            ..color = gridColor.withValues(alpha: 0.8)
            ..strokeWidth = 1,
        );
      }
      final idxList = [0, (dateAxis.length / 2).floor(), dateAxis.length - 1];
      for (final i in idxList) {
        final label = _formatDate(dateAxis[i], short: true);
        _text(canvas, label, Offset(xAt(i) - 12, plotBottom + 6), gridColor, 9);
      }
      return;
    }

    // 主序列（直接价）只有 1 个点：画出这个点即可，折算叠加照常进行
    if (points.length == 1) {
      canvas.drawCircle(
        Offset(xAt(0), yAt(points.first.avgCost)),
        4,
        Paint()..color = color,
      );
    }

    // min/max 区间带（points 为空 = 仅折算序列，主序列整体跳过）
    if (points.length >= 2) {
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

      // min/max 虚线
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      _drawDashed(
          canvas, _pathOf(points, xAt, (p) => p.minCost, yAt), dashPaint);
      _drawDashed(
          canvas, _pathOf(points, xAt, (p) => p.maxCost, yAt), dashPaint);

      // 均价折线
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..isAntiAlias = true;
      canvas.drawPath(_pathOf(points, xAt, (p) => p.avgCost, yAt), linePaint);

      // 只在真实记录日画点（as-of 携带日不画），与 Web 端口径一致
      if (recordDays.isNotEmpty) {
        final dotPaint = Paint()..color = color;
        for (var i = 0; i < points.length; i++) {
          if (!recordDays.contains(points[i].date)) continue;
          canvas.drawCircle(
              Offset(xAt(i), yAt(points[i].avgCost)), 2.6, dotPaint);
        }
      }
    }

    // 折算序列（替代/回退/半成品/从属）：紫色浅色区间带 + 紫色虚线均价。
    // 放在主序列之外：points 为空（仅折算）时也要画。
    _drawComputed(canvas, xAt, yAt);

    // 触摸十字线 + 高亮点（仅折算时没有主序列高亮点）
    if (touchIndex != null &&
        touchIndex! >= 0 &&
        touchIndex! < dateAxis.length) {
      final x = xAt(touchIndex!);
      canvas.drawLine(
        Offset(x, plotTop),
        Offset(x, plotBottom),
        Paint()
          ..color = gridColor.withValues(alpha: 0.8)
          ..strokeWidth = 1,
      );
      if (touchIndex! < points.length) {
        canvas.drawCircle(
          Offset(x, yAt(points[touchIndex!].avgCost)),
          4,
          Paint()..color = color,
        );
      }
    }

    // X 轴日期（首/中/尾）
    final idxList = [0, (dateAxis.length / 2).floor(), dateAxis.length - 1];
    for (final i in idxList) {
      final label = _formatDate(dateAxis[i], short: true);
      _text(canvas, label, Offset(xAt(i) - 12, plotBottom + 6), gridColor, 9);
    }
  }

  Path _pathOf(List<CostHistoryPoint> pts, double Function(int) xAt,
      double Function(CostHistoryPoint) sel, double Function(double) yAt) {
    return buildSmoothPath([
      for (var i = 0; i < pts.length; i++) Offset(xAt(i), yAt(sel(pts[i]))),
    ]);
  }

  /// 折算序列：按日期对齐到轴的下标位置（同日期无点则跳过）。
  void _drawComputed(
      Canvas canvas, double Function(int) xAt, double Function(double) yAt) {
    if (computedPoints.isEmpty) return;
    final indexByDate = <String, int>{};
    for (var i = 0; i < dateAxis.length; i++) {
      indexByDate[dateAxis[i]] = i;
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
      old.dateAxis != dateAxis ||
      old.computedPoints != computedPoints ||
      old.recordDays != recordDays ||
      old.merchantMode != merchantMode ||
      old.merchantSeries != merchantSeries ||
      old.touchIndex != touchIndex ||
      old.color != color ||
      old.userCurrency != userCurrency;
}

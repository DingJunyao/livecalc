import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_title_tooltip.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../comparison/repositories/comparison_repository.dart';
import '../../recipes/repositories/recipe_repository.dart';
import '../../recipes/widgets/cost_proportion_chart.dart';
import '../../recipes/widgets/nutrition_source_grid.dart';
import '../providers/planner_provider.dart';
import '../repositories/planner_repository.dart';
import '../widgets/cost_trend_chart.dart';
import '../widgets/plan_actions.dart';
import '../widgets/plan_totals_grid.dart';

/// 试算方案详情（独立路由 /plans/:id）：成本与营养分析 + 条目跳转 + 设为今日 / 编辑 / 删除。
class PlanDetailScreen extends ConsumerStatefulWidget {
  final int planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  final _repo = PlannerRepository();
  final _comparisonRepo = ComparisonRepository();

  bool _loading = true;
  bool _busy = false;
  bool _trendLoading = true;
  String? _error;
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _evaluation;
  List<Map<String, dynamic>> _trend = const [];
  int _trendDays = 90;

  // 合计卡口径切换（当前 | 各地区对比）：草稿/已存方案都走 plan-evaluate-regions
  List<RegionCandidate> _regionCandidates = const [];
  List<Map<String, dynamic>> _regionTotals = const [];
  bool _regionTotalsLoading = false;
  bool _totalsByRegion = false;

  /// 有价格数据的地区候选（失败返回空 → 切换隐藏）。
  Future<List<RegionCandidate>> _ensureRegionCandidates() async {
    if (_regionCandidates.isNotEmpty) return _regionCandidates;
    try {
      _regionCandidates = await _comparisonRepo.getRegions();
    } on Exception {
      _regionCandidates = const [];
    }
    return _regionCandidates;
  }

  Future<void> _loadRegionTotals() async {
    final plan = _plan;
    if (plan == null) return;
    final candidates = await _ensureRegionCandidates();
    if (candidates.length < 2) return;
    setState(() => _regionTotalsLoading = true);
    try {
      // 条目形状 = 后端 PlanItemIn（group/item_type/ids/servings/quantity/unit_id）
      final items = ((plan['items'] as List?) ?? const [])
          .map((e) => e as Map)
          .map((m) => {
                'group': m['group'] ?? 'other',
                'item_type': m['item_type'],
                'recipe_id': m['recipe_id'],
                'ingredient_id': m['ingredient_id'],
                'product_id': m['product_id'],
                'servings': (m['servings'] as num?)?.toDouble(),
                'quantity': (m['quantity'] as num?)?.toDouble(),
                'unit_id': m['unit_id'],
                'sort_order': (m['sort_order'] as num?)?.toInt() ?? 0,
                'note': m['note'],
              })
          .toList();
      final regions = await _comparisonRepo.planEvaluateRegions(
        items: items,
        regionIds: candidates.take(6).map((r) => r.regionId).toList(),
        kind: (plan['kind'] as String?) ?? 'meal',
      );
      if (mounted) setState(() => _regionTotals = regions);
    } on Exception {
      if (mounted) setState(() => _regionTotals = const []);
    } finally {
      if (mounted) setState(() => _regionTotalsLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _repo.get(widget.planId);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
      await _evaluate();
      await _loadTrend();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> _itemToPayload(Map<String, dynamic> item) => {
        'group': item['group'] ?? 'other',
        'item_type': item['item_type'],
        'recipe_id': item['recipe_id'],
        'ingredient_id': item['ingredient_id'],
        'product_id': item['product_id'],
        'servings': item['servings'],
        'quantity': item['quantity'],
        'unit_id': item['unit_id'],
        'sort_order': item['sort_order'] ?? 0,
      };

  /// 与 web 同口径：meal 方案按条目分组推餐次（other 退回午餐）
  String _mealTypeOf(List<Map<String, dynamic>> items) {
    final group = items.isEmpty ? null : items.first['group'];
    return (group == 'breakfast' || group == 'dinner')
        ? group as String
        : 'lunch';
  }

  List<Map<String, dynamic>> get _items =>
      ((_plan?['items'] as List?) ?? const []).cast<Map<String, dynamic>>();

  Future<void> _evaluate() async {
    final items = _items;
    if (items.isEmpty) return;
    try {
      final evaluation = await _repo.evaluate(
        kind: (_plan?['kind'] ?? 'meal') as String,
        mealType: _mealTypeOf(items),
        items: items.map(_itemToPayload).toList(),
      );
      if (!mounted) return;
      setState(() => _evaluation = evaluation);
    } on Exception {
      // 求值失败静默：详情仍展示方案本身
    }
  }

  Future<void> _loadTrend() async {
    try {
      setState(() => _trendLoading = true);
      final trend = await _repo.costTrend(widget.planId, days: _trendDays);
      if (!mounted) return;
      setState(() => _trend = trend);
    } on Exception {
      // 趋势失败静默
    } finally {
      if (mounted) setState(() => _trendLoading = false);
    }
  }

  Future<void> _editPlan() async {
    final plan = _plan;
    if (plan == null) return;
    await context.push('/plans/edit', extra: {'plan': plan});
    await _load();
  }

  Future<void> _setToday() async {
    final plan = _plan;
    if (plan == null || _busy) return;
    setState(() => _busy = true);
    try {
      await setPlanToday(context, plan);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final plan = _plan;
    if (plan == null || _busy) return;
    if (!await confirmDeletePlan(context, plan)) return;
    setState(() => _busy = true);
    try {
      await ref.read(plannerListProvider.notifier).delete(widget.planId);
      if (!mounted) return;
      context.pop();
    } on Exception {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  /// 条目 → 对应实体详情页
  void _openItem(Map<String, dynamic> item) {
    final type = item['item_type'];
    if (type == 'recipe' && item['recipe_id'] != null) {
      context.push('/recipes/${item['recipe_id']}');
    } else if (type == 'ingredient' && item['ingredient_id'] != null) {
      context.push('/ingredients/${item['ingredient_id']}');
    } else if (type == 'product' && item['product_id'] != null) {
      context.push('/products/${item['product_id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final userCurrency = ref.watch(displayCurrencyProvider);
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(
        // 方案名是动态标题，操作全部收进 ⋮ 菜单，避免挤压标题；长按看全名。
        title: AppTitleTooltip(
          message: plan?['name'] as String? ?? l10n.navPlans,
        ),
        leading: const AppBackButton(),
        actions: [
          const CalcContextMenuButton(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'edit') {
                _editPlan();
              } else if (v == 'setToday') {
                _setToday();
              } else if (v == 'delete') {
                _delete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                enabled: !_loading,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.plansEdit),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'setToday',
                enabled: !_busy,
                child: ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(l10n.plansSetToday),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: !_busy,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.commonDelete),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(theme, l10n, userCurrency),
    );
  }

  Widget _buildBody(
      ThemeData theme, AppLocalizations l10n, String userCurrency) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return ErrorDisplay(message: _error!, onRetry: _load);
    }
    final plan = _plan;
    if (plan == null) {
      return ErrorDisplay(message: l10n.plansEmpty, onRetry: _load);
    }
    final evaluation = _evaluation;
    final totals = (evaluation?['totals'] as Map<String, dynamic>?) ?? const {};
    final targets =
        (evaluation?['targets'] as Map<String, dynamic>?) ?? const {};
    final nutrition = evaluation?['nutrition'] as Map<String, dynamic>?;
    final evalItems = ((evaluation?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final items = _items;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.plansItems,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: plan['kind'] == 'day'
                            ? theme.colorScheme.tertiaryContainer
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        plan['kind'] == 'day'
                            ? l10n.plansKindDay
                            : l10n.plansKindMeal,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: plan['kind'] == 'day'
                              ? theme.colorScheme.onTertiaryContainer
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.plansItemCount(items.length),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                for (var i = 0; i < items.length; i++)
                  _itemRow(
                    theme,
                    l10n,
                    items[i],
                    evalItems.length > i ? evalItems[i] : null,
                    userCurrency,
                  ),
                if ((plan['note'] as String?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(plan['note'] as String? ?? '',
                      style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        if (evaluation != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(l10n.plansTotals,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // 口径切换（当前 | 各地区对比）：有 ≥2 个有数据地区时出现
                      if (_regionCandidates.length >= 2)
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: false,
                              label: Text(l10n.compareDimensionCurrent,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text(l10n.compareByRegion,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                          selected: {_totalsByRegion},
                          onSelectionChanged: (s) {
                            final v = s.first;
                            setState(() => _totalsByRegion = v);
                            if (v && _regionTotals.isEmpty) _loadRegionTotals();
                          },
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                              visualDensity: VisualDensity.compact),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_totalsByRegion)
                    _RegionTotalsTable(
                      rows: _regionTotals,
                      candidates: _regionCandidates,
                      loading: _regionTotalsLoading,
                      userCurrency: userCurrency,
                    )
                  else
                    PlanTotalsGrid(
                      totals: totals,
                      targets: targets,
                      userCurrency: userCurrency,
                    ),
                ],
              ),
            ),
          ),
        ],
        CostTrendChart(
          points: _trend,
          userCurrency: userCurrency,
          loading: _trendLoading,
          days: _trendDays,
          onDaysChanged: (days) {
            setState(() => _trendDays = days);
            _loadTrend();
          },
        ),
        if (evaluation != null) ...[
          CostProportionChart(
            breakdown: _costBreakdown(items, evalItems),
            totalCost: _num(totals['cost']),
            userCurrency: (totals['currency'] as String?) ?? userCurrency,
          ),
          NutritionSourceGrid(
            nutrition: RecipeNutrition.fromJson(nutrition ?? const {}),
          ),
        ],
      ],
    );
  }

  Widget _itemRow(
    ThemeData theme,
    AppLocalizations l10n,
    Map<String, dynamic> item,
    Map<String, dynamic>? detail,
    String userCurrency,
  ) {
    final cost = (detail?['cost'] as num?)?.toDouble();
    final unit = detail?['unit'] as String?;
    final recipe = item['item_type'] == 'recipe';
    final quantityText = recipe
        ? '${l10n.plansServings} ${item['servings'] ?? 1}'
        : [
            '${l10n.plansQuantity} ${item['quantity'] ?? 0}',
            if (unit != null && unit.isNotEmpty) unit,
          ].join(' ');
    return InkWell(
      onTap: () => _openItem(item),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (item['name'] ?? detail?['name'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    quantityText,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            Text(
              cost != null ? formatMoney(cost, userCurrency) : '--',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// 逐条目成本占比（与 web CostProportionChart 同口径：按条目成本降序）
  List<CostBreakdownItem> _costBreakdown(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> evalItems,
  ) {
    final out = <CostBreakdownItem>[];
    for (var i = 0; i < items.length; i++) {
      final detail =
          evalItems.length > i ? evalItems[i] : const <String, dynamic>{};
      final cost = (detail['cost'] as num?)?.toDouble() ?? 0;
      if (cost <= 0) continue;
      out.add(CostBreakdownItem(
        ingredientName: (items[i]['name'] ?? detail['name'] ?? '').toString(),
        // 营养溯源也以 item_id 配色，这里保持同一标识，避免同名色块不一致。
        ingredientId: detail['item_id'] as int?,
        cost: cost,
        unitPrice: 0,
      ));
    }
    return out;
  }
}

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// 各地区合计对照表（合计卡「按地区」口径）：行=地区，列=成本/热量/蛋白/脂肪。
/// 成本最低地区绿色加粗（≥2 个有成本地区才标）。
class _RegionTotalsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<RegionCandidate> candidates;
  final bool loading;
  final String userCurrency;

  const _RegionTotalsTable({
    required this.rows,
    required this.candidates,
    this.loading = false,
    this.userCurrency = 'CNY',
  });

  String _name(int rid) {
    for (final c in candidates) {
      if (c.regionId == rid) return c.displayName;
    }
    return '#$rid';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(l10n.compareNoRegionData, style: theme.textTheme.bodySmall),
      );
    }
    final valid = rows
        .map((r) => _num((r['totals'] as Map?)?['cost']))
        .where((v) => v > 0)
        .toList();
    final minCost =
        valid.length >= 2 ? valid.reduce((a, b) => a < b ? a : b) : null;
    String metric(dynamic totals, String key, {int digits = 1}) {
      final v = _num((totals as Map?)?[key]);
      if (v <= 0) return '—';
      return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : digits);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 36,
        columns: [
          DataColumn(label: Text(l10n.compareRegionCol, style: theme.textTheme.labelSmall)),
          DataColumn(
              label: Text(l10n.compareMetricCost, style: theme.textTheme.labelSmall),
              numeric: true),
          DataColumn(
              label: Text(l10n.compareMetricCalories, style: theme.textTheme.labelSmall),
              numeric: true),
          DataColumn(
              label: Text(l10n.compareMetricProtein, style: theme.textTheme.labelSmall),
              numeric: true),
          DataColumn(
              label: Text(l10n.compareMetricFat, style: theme.textTheme.labelSmall),
              numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text(_name((r['region_id'] as num?)?.toInt() ?? 0),
                  style: theme.textTheme.bodySmall)),
              DataCell(Text(
                _fmtCost(r, minCost, l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight:
                      _isLowest(r, minCost) ? FontWeight.bold : null,
                  color: _isLowest(r, minCost)
                      ? Colors.green.shade700
                      : null,
                ),
              )),
              DataCell(Text(metric(r['totals'], 'calories', digits: 0),
                  style: theme.textTheme.bodySmall)),
              DataCell(Text(metric(r['totals'], 'protein_g'),
                  style: theme.textTheme.bodySmall)),
              DataCell(Text(metric(r['totals'], 'fat_g'),
                  style: theme.textTheme.bodySmall)),
            ]),
        ],
      ),
    );
  }

  bool _isLowest(Map<String, dynamic> r, double? minCost) {
    if (minCost == null || minCost <= 0) return false;
    return _num((r['totals'] as Map?)?['cost']) == minCost;
  }

  String _fmtCost(Map<String, dynamic> r, double? minCost, AppLocalizations l10n) {
    final cost = _num((r['totals'] as Map?)?['cost']);
    if (cost <= 0) return '—';
    return formatMoney(cost, userCurrency);
  }
}

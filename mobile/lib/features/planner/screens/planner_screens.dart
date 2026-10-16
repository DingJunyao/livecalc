import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/planner_provider.dart';
import '../repositories/planner_repository.dart';
import '../widgets/cost_trend_chart.dart';
import '../widgets/plan_actions.dart';
import '../widgets/plan_totals_grid.dart';

/// 试算方案列表：查看 / 新建 / 删除 / 设为今日。
class PlannerListScreen extends ConsumerStatefulWidget {
  const PlannerListScreen({super.key});

  @override
  ConsumerState<PlannerListScreen> createState() => _PlannerListScreenState();
}

class _PlannerListScreenState extends ConsumerState<PlannerListScreen> {
  bool _settingPlan = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(plannerListProvider.notifier).load());
  }

  /// 「一顿」方案要先选要替换哪一餐（与 web 同口径）；「一日」一次设三餐
  Future<void> _setToday(Map<String, dynamic> plan) async {
    if (_settingPlan) return;
    setState(() => _settingPlan = true);
    try {
      await setPlanToday(context, plan);
    } finally {
      if (mounted) setState(() => _settingPlan = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> plan) async {
    if (!await confirmDeletePlan(context, plan)) return;
    await ref.read(plannerListProvider.notifier).delete(plan['id'] as int);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(plannerListProvider);
    final userCurrency = ref.watch(displayCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navPlans),
        leading: const AppBackButton(),
        actions: [
          const CalcContextMenuButton(),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.plansNewPlan,
            onPressed: () async {
              await context.push('/plans/edit');
              ref.read(plannerListProvider.notifier).load();
            },
          ),
        ],
      ),
      body: _buildBody(theme, l10n, state, userCurrency),
    );
  }

  Widget _buildBody(
      ThemeData theme,
      AppLocalizations l10n,
      PlannerListState state,
      String userCurrency) {
    if (state.loading) return const LoadingIndicator();
    if (state.error != null) {
      return ErrorDisplay(
          message: state.error!,
          onRetry: () => ref.read(plannerListProvider.notifier).load());
    }
    if (state.plans.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: l10n.plansEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(plannerListProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final plan in state.plans)
            _planCard(theme, l10n, state, plan, userCurrency),
        ],
      ),
    );
  }

  /// 列表卡片：名称/类型 + 成本 + 营养素（含 NRV%）+ 30 天成本迷你图
  Widget _planCard(
    ThemeData theme,
    AppLocalizations l10n,
    PlannerListState state,
    Map<String, dynamic> plan,
    String userCurrency,
  ) {
    final planId = plan['id'];
    final totals = planId is int ? state.totals[planId] : null;
    final nutrients = planId is int ? state.nutrients[planId] : null;
    final trend =
        planId is int ? (state.trends[planId] ?? const <double>[]) : const <double>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () async {
          await context.push('/plans/${plan['id']}');
          ref.read(plannerListProvider.notifier).load();
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                plan['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.plansItemCount(((plan['items'] as List?) ?? const []).length),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            if (totals != null) ...[
              const SizedBox(height: 4),
              Text(
                formatMoney(_num(totals['cost']),
                    (totals['currency'] as String?) ?? userCurrency),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              Text(
                _nutritionLine(l10n, totals, nutrients),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (trend.length >= 2 && trend.any((v) => v > 0)) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 24,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MiniSparklinePainter(
                    values: trend,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _settingPlan ? null : () => _setToday(plan),
              child: Text(l10n.plansSetToday),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: l10n.commonDelete,
              onPressed: () => _delete(plan),
            ),
          ],
        ),
      ),
    );
  }
}

/// 试算方案编辑器：名称/类型 + 加菜谱条目 + 实时求值 + 保存 + 设为今日 + 成本趋势。
class PlannerEditScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? plan; // null = 新建
  const PlannerEditScreen({super.key, this.plan});

  @override
  ConsumerState<PlannerEditScreen> createState() => _PlannerEditScreenState();
}

class _PlannerEditScreenState extends ConsumerState<PlannerEditScreen> {
  final _nameController = TextEditingController();
  final _repo = PlannerRepository();
  String _kind = 'meal';
  int? _planId;
  bool _loading = true;
  bool _saving = false;
  bool _evaluating = false;
  String? _error;

  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic>? _evaluation;
  List<Map<String, dynamic>> _trend = const [];
  int _trendDays = 90;
  /// 全局单位（原料 / 商品条目选单位用）
  List<Map<String, dynamic>> _units = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load());
  }

  Future<void> _load() async {
    final plan = widget.plan;
    if (plan == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final full = await _repo.get(plan['id'] as int);
      if (!mounted) return;
      setState(() {
        _planId = full['id'] as int;
        _nameController.text = full['name'] ?? '';
        _kind = full['kind'] ?? 'meal';
        _items = ((full['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
      await _loadUnits();
      await _evaluate();
      await _loadTrend();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _evaluate() async {
    if (_items.isEmpty) {
      setState(() => _evaluation = null);
      return;
    }
    setState(() => _evaluating = true);
    try {
      final evaluation = await _repo.evaluate(
        kind: _kind,
        // 与 web 同口径：meal 方案按条目分组推餐次（other 退回午餐）
        mealType: _mealTypeOf(_items),
        items: _items.map(_itemToPayload).toList(),
      );
      if (!mounted) return;
      setState(() => _evaluation = evaluation);
      _backfillUnitIds();
    } on Exception {
      // 求值失败静默，保留上次结果
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  Future<void> _loadUnits() async {
    try {
      final units = await _repo.units();
      if (!mounted) return;
      setState(() {
        _units = units.where((unit) => unit['is_active'] != false).toList();
      });
    } on Exception {
      // 单位拉不到就保持后端默认单位
    }
  }

  String _unitLabel(Map<String, dynamic> unit) {
    final abbreviation = (unit['abbreviation'] as String?)?.trim() ?? '';
    final name = (unit['name'] as String?)?.trim() ?? '';
    if (abbreviation.isEmpty) return name;
    if (name.isEmpty || name == abbreviation) return abbreviation;
    return '$abbreviation ($name)';
  }

  Map<String, dynamic>? _unitById(dynamic id) {
    if (id == null) return null;
    for (final unit in _units) {
      if (unit['id'] == id) return unit;
    }
    return null;
  }

  /// 求值回到的「生效单位」→ 显式写回 unit_id（与 web 同口径：读 evaluate 的实际生效单位落库）
  void _backfillUnitIds() {
    final evaluation = _evaluation;
    if (evaluation == null || _units.isEmpty || _items.isEmpty) return;
    final evalItems = (evaluation['items'] as List?) ?? const [];
    final items = List<Map<String, dynamic>>.from(_items);
    var changed = false;
    for (var i = 0; i < items.length && i < evalItems.length; i++) {
      final item = items[i];
      if (item['item_type'] == 'recipe' || item['unit_id'] != null) continue;
      final name = (evalItems[i] as Map)['unit']?.toString() ?? '';
      if (name.isEmpty) continue;
      for (final unit in _units) {
        final matches = unit['name'] == name ||
            unit['abbreviation'] == name ||
            _unitLabel(unit) == name;
        if (!matches) continue;
        items[i] = {...item, 'unit_id': unit['id']};
        changed = true;
        break;
      }
    }
    if (changed) setState(() => _items = items);
  }

  void _setItemUnit(Map<String, dynamic> item, int? unitId) {
    final index = _items.indexOf(item);
    if (index < 0) return;
    setState(() {
      final items = List<Map<String, dynamic>>.from(_items);
      items[index] = {...item, 'unit_id': unitId};
      _items = items;
    });
    _evaluate();
  }

  /// 某条目求值后的生效单位名（下拉未选时的提示）
  String? _effectiveUnitName(int index) {
    final evalItems = (_evaluation?['items'] as List?) ?? const [];
    if (index >= evalItems.length) return null;
    final name = (evalItems[index] as Map)['unit']?.toString();
    return (name == null || name.isEmpty) ? null : name;
  }

  /// 与 web 同口径：meal 方案的目标按条目分组对应的餐次比例算
  String _mealTypeOf(List<Map<String, dynamic>> items) {
    final group = items.isEmpty ? null : items.first['group'];
    return (group == 'breakfast' || group == 'dinner')
        ? group as String
        : 'lunch';
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final items = _items.asMap().entries.map((e) {
        final payload = _itemToPayload(e.value);
        payload['sort_order'] = e.key;
        return payload;
      }).toList();
      if (_planId == null) {
        final created = await _repo.create(
          name: _nameController.text,
          kind: _kind,
          items: items,
        );
        _planId = created['id'] as int;
      } else {
        await _repo.update(_planId!,
            name: _nameController.text, kind: _kind, items: items);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.plansSaved)),
      );
      await _loadTrend();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.plansSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setToday() async {
    final l10n = AppLocalizations.of(context);
    if (_planId == null) await _save();
    if (_planId == null) return;
    try {
      await _repo.setPlan(_planId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.plansSetTodayDone)),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.plansSetTodayFailed)),
      );
    }
  }

  Future<void> _loadTrend() async {
    if (_planId == null) return;
    try {
      final trend = await _repo.costTrend(_planId!, days: _trendDays);
      if (!mounted) return;
      setState(() => _trend = trend);
    } on Exception {
      // 趋势失败静默
    }
  }

  Future<void> _addRecipe() async {
    final l10n = AppLocalizations.of(context);
    final recipe = await context.push<Map<String, dynamic>>(
        '/recipes?picker=1');
    if (recipe == null) return;
    setState(() {
      _items = [
        ..._items,
        {
          'group': _kind == 'day' ? 'other' : 'dinner',
          'item_type': 'recipe',
          'recipe_id': recipe['id'],
          'servings': 1.0,
          'sort_order': _items.length,
          'name': recipe['name'],
        }
      ];
    });
    await _evaluate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.plansItemAdded)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final userCurrency = ref.read(displayCurrencyProvider);

    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.navPlans),
          leading: const AppBackButton(),
        ),
        body: ErrorDisplay(message: _error!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_planId == null ? l10n.plansNewPlan : l10n.plansEdit),
        leading: const AppBackButton(),
        actions: [
          const CalcContextMenuButton(),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: l10n.commonSave,
            onPressed: _saving || _nameController.text.trim().isEmpty
                ? null
                : _save,
          ),
          IconButton(
            icon: const Icon(Icons.verified_outlined),
            tooltip: l10n.plansSetToday,
            onPressed: _saving ? null : _setToday,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  InputDecoration(labelText: l10n.plansPlanName),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'meal', label: Text(l10n.plansKindMeal)),
                ButtonSegment(value: 'day', label: Text(l10n.plansKindDay)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) {
                setState(() => _kind = v.first);
                _evaluate();
              },
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _addRecipe,
              icon: const Icon(Icons.add),
              label: Text(l10n.plansAddRecipe),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _items.length; index++)
              _itemTile(theme, l10n, index),
            if (_evaluation != null) ...[
              const Divider(height: 24),
              Text(l10n.plansTotals,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              PlanTotalsGrid(
                totals: (_evaluation!['totals'] as Map<String, dynamic>?) ??
                    const {},
                targets: (_evaluation!['targets'] as Map<String, dynamic>?) ??
                    const {},
                userCurrency: userCurrency,
              ),
              if (_evaluating)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
            const SizedBox(height: 12),
            CostTrendChart(
              points: _trend,
              userCurrency: userCurrency,
              days: _trendDays,
              onDaysChanged: (days) {
                setState(() => _trendDays = days);
                _loadTrend();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 单条目行：类型徽标 + 名称 +（菜谱：份量 / 原料·商品：数量 + 单位下拉）+ 操作
  Widget _itemTile(ThemeData theme, AppLocalizations l10n, int index) {
    final item = _items[index];
    final isRecipe = item['item_type'] == 'recipe';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: () => _openItem(item),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _planTypeLabel(item['item_type'] ?? '', l10n),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item['name'] ??
                  '#${item['recipe_id'] ?? item['ingredient_id'] ?? item['product_id']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: isRecipe
          ? Text('${l10n.plansServings}: ${item['servings'] ?? 1}')
          : Row(
              children: [
                Text('${l10n.plansQuantity}: ${item['quantity'] ?? 0}'),
                if (_units.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _unitById(item['unit_id']) == null
                        ? null
                        : item['unit_id'] as int,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    hint: Text(_effectiveUnitName(index) ?? ''),
                    items: [
                      for (final unit in _units)
                        DropdownMenuItem<int>(
                          value: unit['id'] as int,
                          child: Text(_unitLabel(unit)),
                        ),
                    ],
                    onChanged: (value) => _setItemUnit(item, value),
                  ),
                ],
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecipe)
            IconButton(
              icon: const Icon(Icons.exposure_plus_1, size: 18),
              tooltip: l10n.plansServingsPlus,
              onPressed: () {
                setState(() {
                  final items = List<Map<String, dynamic>>.from(_items);
                  items[index] = {
                    ...item,
                    'servings': ((item['servings'] as num?) ?? 1) + 1,
                  };
                  _items = items;
                });
                _evaluate();
              },
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _items = List.of(_items)..removeAt(index);
              });
              _evaluate();
            },
          ),
        ],
      ),
    );
  }

}

String _planTypeLabel(String type, AppLocalizations l10n) {
  switch (type) {
    case 'recipe':
      return l10n.plansTypeRecipe;
    case 'ingredient':
      return l10n.plansTypeIngredient;
    case 'product':
      return l10n.plansTypeProduct;
    default:
      return type;
  }
}

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// 列表卡片上的一行营养素（带 NRV%，与 web 列表同口径）
String _nutritionLine(
  AppLocalizations l10n,
  Map<String, dynamic> totals,
  Map<String, dynamic>? nutrients,
) {
  final perServing = nutrients?['per_serving_nutrition'] as Map<String, dynamic>?;
  final all = (perServing?['all_nutrients'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
  String nrv(String key) {
    final pct = (all[key] as Map<String, dynamic>?)?['nrp_pct'];
    return pct is num ? ' (NRV ${pct.round()}%)' : '';
  }

  return '${l10n.plansCalories} ${formatNumber(_num(totals['calories']).round())} kcal'
      '${nrv('energy')} · '
      '${l10n.plansProtein} ${formatNumber(_num(totals['protein_g']), maximumFractionDigits: 1)} g'
      '${nrv('protein')} · '
      '${l10n.plansFat} ${formatNumber(_num(totals['fat_g']), maximumFractionDigits: 1)} g'
      '${nrv('fat')}';
}

/// 列表卡片里的迷你成本折线（只描线，不画网格与坐标）
class _MiniSparklinePainter extends CustomPainter {
  _MiniSparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var minV = values.first;
    var maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = size.height -
          ((values[i] - minV) / span) * (size.height - 4) -
          2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter old) =>
      old.values != values || old.color != color;
}

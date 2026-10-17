import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/ingredients/repositories/ingredient_repository.dart';
import '../../../features/products/repositories/product_repository.dart';
import '../../../features/recipes/repositories/recipe_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/entity_unit_names.dart';
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/sparkline.dart';
import '../providers/planner_provider.dart';
import '../repositories/planner_repository.dart';
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
    Future.microtask(() => ref.read(plannerListProvider.notifier).load());
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

  Future<void> _openCreate() async {
    await context.push('/plans/edit');
    if (mounted) ref.read(plannerListProvider.notifier).load();
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
        actions: const [
          CalcContextMenuButton(),
        ],
      ),
      body: _buildBody(theme, l10n, state, userCurrency),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: l10n.plansNewPlan,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, AppLocalizations l10n,
      PlannerListState state, String userCurrency) {
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
    final trend = planId is int
        ? (state.trends[planId] ?? const <double>[])
        : const <double>[];

    final costText = totals == null
        ? '--'
        : formatMoney(_num(totals['cost']),
            (totals['currency'] as String?) ?? userCurrency);
    final isDay = plan['kind'] == 'day';

    return SizedBox(
      height: 76,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await context.push('/plans/${plan['id']}');
            ref.read(plannerListProvider.notifier).load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDay
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primaryContainer,
                  foregroundColor: isDay
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    isDay ? l10n.plansBadgeDay : l10n.plansBadgeMeal,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            isDay ? l10n.plansKindDay : l10n.plansKindMeal,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              costText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                KeyedSubtree(
                  key: const ValueKey('plan-cost-sparkline'),
                  child: Sparkline(
                    data: trend,
                    color: theme.colorScheme.tertiary,
                    width: 52,
                    height: 28,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.verified_outlined, size: 20),
                  tooltip: l10n.plansSetToday,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 36, height: 36),
                  padding: EdgeInsets.zero,
                  onPressed: _settingPlan ? null : () => _setToday(plan),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: l10n.commonDelete,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 36, height: 36),
                  padding: EdgeInsets.zero,
                  onPressed: () => _delete(plan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  /// 全局单位（原料 / 商品条目选单位用）
  List<Map<String, dynamic>> _units = const [];
  bool _unitsLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load());
  }

  Future<void> _load() async {
    final plan = widget.plan;
    if (plan == null) {
      // New plans can add an item before any persisted plan exists; fetch the
      // shared unit catalog in the background so quantity dropdowns are ready.
      Future.microtask(_loadUnits);
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
        _items =
            ((full['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
        _loading = false;
      });
      await _loadUnits();
      await _applyDefaultUnits();
      await _evaluate();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
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
    if (_unitsLoading) return;
    _unitsLoading = true;
    try {
      final units = await _repo.units();
      if (!mounted) return;
      setState(() {
        _units = units.where((unit) => unit['is_active'] != false).toList();
      });
    } on Exception {
      // 单位拉不到就保持后端默认单位
    } finally {
      _unitsLoading = false;
    }
  }

  Future<void> _ensureUnitsLoaded() async {
    if (_units.isNotEmpty) return;
    await _loadUnits();
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

  int? _unitIdByName(String? name) {
    final value = name?.trim() ?? '';
    if (value.isEmpty) return null;
    for (final unit in _units) {
      if (unit['name'] == value ||
          unit['abbreviation'] == value ||
          _unitLabel(unit) == value) {
        return unit['id'] as int?;
      }
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

  Future<void> _applyDefaultUnits() async {
    if (_units.isEmpty || _items.isEmpty) return;
    final items = List<Map<String, dynamic>>.from(_items);
    var changed = false;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final type = item['item_type'];
      if (item['unit_id'] != null || type == 'recipe') continue;
      final entityId = switch (type) {
        'ingredient' => item['ingredient_id'] as int?,
        'product' => item['product_id'] as int?,
        _ => null,
      };
      if (entityId == null) continue;
      final defaultName = await loadEntityDefaultUnitName(
        entityType: type as String,
        entityId: entityId,
      );
      final unitId = _unitIdByName(defaultName);
      if (unitId == null) continue;
      items[i] = {...item, 'unit_id': unitId};
      changed = true;
    }
    if (changed && mounted) setState(() => _items = items);
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

  void _setItemGroup(Map<String, dynamic> item, String? group) {
    final index = _items.indexOf(item);
    if (index < 0 || group == null) return;
    setState(() {
      final items = List<Map<String, dynamic>>.from(_items);
      items[index] = {...item, 'group': group};
      _items = items;
    });
    _evaluate();
  }

  void _setItemQuantity({
    required Map<String, dynamic> item,
    required int index,
    required bool isRecipe,
    required String rawValue,
  }) {
    final parsed = double.tryParse(rawValue.replaceAll(',', '.'));
    if (parsed == null) return;
    final value = isRecipe
        ? parsed.clamp(0.5, double.infinity).toDouble()
        : parsed.clamp(0, double.infinity).toDouble();
    setState(() {
      final items = List<Map<String, dynamic>>.from(_items);
      items[index] = {
        ...item,
        if (isRecipe) 'servings': value else 'quantity': value,
      };
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
      context.go('/plans/$_planId');
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

  Future<void> _addEntity(_PlanEntityType type) async {
    final selected = await _showEntityPicker(type);
    if (selected == null) return;
    int? unitId;
    if (selected.type != _PlanEntityType.recipe) {
      await _ensureUnitsLoaded();
      final defaultName = await loadEntityDefaultUnitName(
        entityType: selected.type.apiName,
        entityId: selected.id,
      );
      unitId = _unitIdByName(defaultName);
    }
    setState(() {
      _items = [
        ..._items,
        {
          'group': _kind == 'day' ? 'other' : 'dinner',
          'item_type': selected.type.apiName,
          'recipe_id':
              selected.type == _PlanEntityType.recipe ? selected.id : null,
          'ingredient_id':
              selected.type == _PlanEntityType.ingredient ? selected.id : null,
          'product_id':
              selected.type == _PlanEntityType.product ? selected.id : null,
          'servings': selected.type == _PlanEntityType.recipe ? 1 : null,
          'quantity': selected.type == _PlanEntityType.recipe ? null : 100,
          'unit_id': unitId,
          'sort_order': _items.length,
          'name': selected.name,
        }
      ];
    });
    await _evaluate();
  }

  Future<_PlanEntitySelection?> _showEntityPicker(_PlanEntityType initialType) {
    return showModalBottomSheet<_PlanEntitySelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PlanEntityPicker(initialType: initialType),
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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _nameController,
            builder: (context, value, _) => IconButton(
              icon: const Icon(Icons.save),
              tooltip: l10n.commonSave,
              onPressed: _saving || value.text.trim().isEmpty ? null : _save,
            ),
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
              decoration: InputDecoration(labelText: l10n.plansPlanName),
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
              onPressed: () => _addEntity(_PlanEntityType.recipe),
              icon: const Icon(Icons.add),
              label: Text(l10n.plansAddItem),
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
      subtitle: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_kind == 'day')
            DropdownButton<String>(
              value: (item['group'] as String?) ?? 'other',
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: 'breakfast',
                  child: Text(l10n.homeBreakfast),
                ),
                DropdownMenuItem(value: 'lunch', child: Text(l10n.homeLunch)),
                DropdownMenuItem(value: 'dinner', child: Text(l10n.homeDinner)),
                DropdownMenuItem(
                  value: 'other',
                  child: Text(l10n.plansGroupOther),
                ),
              ],
              onChanged: (value) => _setItemGroup(item, value),
            ),
          Text(isRecipe ? l10n.plansServings : l10n.plansQuantity),
          _PlanQuantityField(
            value: isRecipe
                ? ((item['servings'] as num?) ?? 1).toDouble()
                : ((item['quantity'] as num?) ?? 0).toDouble(),
            onChanged: (value) => _setItemQuantity(
              item: item,
              index: index,
              isRecipe: isRecipe,
              rawValue: value,
            ),
          ),
          if (!isRecipe && _units.isNotEmpty)
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
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

enum _PlanEntityType {
  recipe('recipe'),
  ingredient('ingredient'),
  product('product');

  const _PlanEntityType(this.apiName);

  final String apiName;
}

class _PlanEntitySelection {
  const _PlanEntitySelection({
    required this.type,
    required this.id,
    required this.name,
  });

  final _PlanEntityType type;
  final int id;
  final String name;
}

class _PlanPickerItem {
  const _PlanPickerItem({
    required this.type,
    required this.id,
    required this.name,
    required this.detail,
  });

  final _PlanEntityType type;
  final int id;
  final String name;
  final String detail;
}

class _PlanEntityPicker extends StatefulWidget {
  const _PlanEntityPicker({required this.initialType});

  final _PlanEntityType initialType;

  @override
  State<_PlanEntityPicker> createState() => _PlanEntityPickerState();
}

class _PlanEntityPickerState extends State<_PlanEntityPicker> {
  late _PlanEntityType _type = widget.initialType;
  final _searchController = TextEditingController();
  final _recipeRepository = RecipeRepository();
  final _ingredientRepository = IngredientRepository();
  final _productRepository = ProductRepository();
  Timer? _debounce;
  int _requestId = 0;
  bool _loading = true;
  String? _error;
  List<_PlanPickerItem> _results = const [];

  @override
  void initState() {
    super.initState();
    _scheduleSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final requestId = ++_requestId;
    final query = _searchController.text.trim();
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _loadResults(query, l10n);
      if (!mounted || requestId != _requestId) return;
      setState(() => _results = results);
    } on Exception catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<_PlanPickerItem>> _loadResults(
    String query,
    AppLocalizations l10n,
  ) async {
    switch (_type) {
      case _PlanEntityType.recipe:
        final page = await _recipeRepository.getRecipes(search: query);
        return [
          for (final item in page.items)
            _PlanPickerItem(
              type: _PlanEntityType.recipe,
              id: item.id,
              name: item.name,
              detail: '${l10n.plansServings} ${item.servings}',
            ),
        ];
      case _PlanEntityType.ingredient:
        final page = await _ingredientRepository.search(search: query);
        return [
          for (final item in page.items)
            _PlanPickerItem(
              type: _PlanEntityType.ingredient,
              id: item.id,
              name: item.name,
              detail: '',
            ),
        ];
      case _PlanEntityType.product:
        final page = await _productRepository.search(search: query);
        return [
          for (final item in page.items)
            _PlanPickerItem(
              type: _PlanEntityType.product,
              id: item.id,
              name: item.name,
              detail: '',
            ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: _PlanEntityType.values.length,
      initialIndex: _PlanEntityType.values.indexOf(widget.initialType),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                tabs: [
                  Tab(text: l10n.plansTypeRecipe),
                  Tab(text: l10n.plansTypeIngredient),
                  Tab(text: l10n.plansTypeProduct),
                ],
                onTap: (index) {
                  final type = _PlanEntityType.values[index];
                  if (type == _type) return;
                  setState(() => _type = type);
                  _scheduleSearch();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: switch (_type) {
                    _PlanEntityType.recipe => l10n.recipeSearch,
                    _PlanEntityType.ingredient => l10n.ingredientSearch,
                    _PlanEntityType.product => l10n.productSearch,
                  },
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => _scheduleSearch(),
              ),
            ),
            Expanded(child: _buildResults(context, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorDisplay(message: _error!, onRetry: _search);
    }
    if (_results.isEmpty) {
      return Center(child: Text(l10n.commonEmptyTitle));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return ListTile(
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: item.detail.isEmpty
              ? null
              : Text(
                  item.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: const Icon(Icons.add),
          onTap: () => Navigator.of(context).pop(
            _PlanEntitySelection(
              type: item.type,
              id: item.id,
              name: item.name,
            ),
          ),
        );
      },
    );
  }
}

class _PlanQuantityField extends StatefulWidget {
  const _PlanQuantityField({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<String> onChanged;

  @override
  State<_PlanQuantityField> createState() => _PlanQuantityFieldState();
}

class _PlanQuantityFieldState extends State<_PlanQuantityField> {
  late final TextEditingController _controller =
      TextEditingController(text: _formatQuantity(widget.value));

  @override
  void didUpdateWidget(covariant _PlanQuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final text = _formatQuantity(widget.value);
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (parsed != widget.value && _controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _formatQuantity(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: TextFormField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^[0-9.,]*$')),
        ],
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// compare_screen.dart — 物价对比（/compare）。
// 概览：地区摘要卡 + 物价指数条形 + 篮子均价趋势（多地区叠加）。
// 原料·商品：实体多选 + 各地区比价矩阵。
// 交互参照「按商家」对比模式：地区选择用底部弹层多选（勾选 2-6 个）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/calc_context_provider.dart'
    show displayCurrencyProvider;
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import '../../recipes/repositories/recipe_repository.dart';
import '../../recipes/widgets/cost_trend_chart.dart';
import '../../prices/utils/price_trend.dart' show PriceMerchantSeries;
import '../providers/comparison_provider.dart';
import '../repositories/comparison_repository.dart';
import '../widgets/heatmap_canvas.dart';
import '../widgets/region_price_matrix.dart';

final ComparisonRepository _heatmapRepo = ComparisonRepository();

const int _maxRegions = 6;

/// 数字序列（前向填充、结束于今天）→ 图表日点。
List<CostHistoryPoint> _trendToPoints(List<double> trend) {
  if (trend.isEmpty) return const [];
  final today = DateTime.now();
  String dayKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  return [
    for (var i = 0; i < trend.length; i++)
      CostHistoryPoint(
        date: dayKey(today.subtract(Duration(days: trend.length - 1 - i))),
        minCost: trend[i],
        maxCost: trend[i],
        avgCost: trend[i],
      ),
  ];
}

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(comparisonProvider.notifier);
      notifier.loadCandidates();
      notifier.loadPlanOptions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openRegionPicker() async {
    final state = ref.read(comparisonProvider);
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RegionPickerSheet(
        candidates: state.candidates,
        selected: state.selectedRegionIds,
        maxRegions: _maxRegions,
      ),
    );
    if (picked == null || !mounted) return;
    await ref.read(comparisonProvider.notifier).selectRegions(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(comparisonProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.compareTitle),
        actions: [
          IconButton(
            tooltip: l10n.compareRegions,
            icon: Badge(
              isLabelVisible: state.selectedRegionIds.isNotEmpty,
              label: Text('${state.selectedRegionIds.length}'),
              child: const Icon(Icons.map_outlined),
            ),
            onPressed: _openRegionPicker,
          ),
          const CalcContextMenuButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.compareTabOverview),
            Tab(text: l10n.compareTabPrices),
            Tab(text: l10n.compareTabRecipes),
            Tab(text: l10n.compareTabHeatmap),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(state: state, onPickRegions: _openRegionPicker, maxRegions: _maxRegions),
          _PricesTab(state: state, maxRegions: _maxRegions),
          const _RecipesTab(),
          const _HeatmapTab(),
        ],
      ),
    );
  }
}

// ============ 概览 ============

class _OverviewTab extends ConsumerWidget {
  final ComparisonState state;
  final Future<void> Function() onPickRegions;
  final int maxRegions;

  const _OverviewTab({
    required this.state,
    required this.onPickRegions,
    required this.maxRegions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (state.selectedRegionIds.length < 2) {
      return RefreshIndicator(
        onRefresh: () => ref.read(comparisonProvider.notifier).loadCandidates(),
        child: ListView(
          children: [
            const SizedBox(height: 48),
            Icon(Icons.map_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l10n.compareNeedTwoRegions,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.icon(
                onPressed: onPickRegions,
                icon: const Icon(Icons.add),
                label: Text(l10n.compareRegions),
              ),
            ),
          ],
        ),
      );
    }

    final summary = state.summary;
    return RefreshIndicator(
      onRefresh: () => ref.read(comparisonProvider.notifier).loadSummary(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 已选地区 chips（点击重新打开弹层）
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final rid in state.selectedRegionIds)
                  Chip(
                    label: Text(_regionName(state, rid), style: theme.textTheme.labelMedium),
                    visualDensity: VisualDensity.compact,
                  ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(l10n.compareRegions, style: theme.textTheme.labelMedium),
                  onPressed: onPickRegions,
                ),
              ],
            ),
          ),
          if (state.loadingSummary)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.compareNoBasketData, style: theme.textTheme.bodyMedium)),
            )
          else ...[
            const SizedBox(height: 8),
            // 地区摘要卡（横向滚动；最低指数高亮）
            SizedBox(
              height: 132,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: summary.regions.length,
                itemBuilder: (ctx, i) {
                  final r = summary.regions[i];
                  final lowest = _isLowestIndex(summary, r);
                  return Container(
                    width: 168,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: lowest
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            if (lowest)
                              Text(
                                l10n.compareLowestIndex,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: theme.colorScheme.primary),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          r.priceIndex == null ? '—' : _fmtIndex(r.priceIndex!),
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          l10n.comparePriceIndexCaption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const Spacer(),
                        Text(
                          '${l10n.compareRecordCount(r.recordCount)} · ${l10n.compareEntityCount(r.entityCount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // 物价指数条形对比（基准地区=100）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.comparePriceIndexTitle(_regionName(state, summary.baseRegionId)),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._buildIndexBars(summary, theme, l10n),
                      const SizedBox(height: 6),
                      Text(
                        l10n.compareBasketNote(summary.basketSize),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 篮子均价趋势（多地区叠加；参照「按商家」对比模式）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CostTrendChart(
                    points: _trendToPoints(_baseTrend(summary)),
                    unit: l10n.compareTrendUnit,
                    userCurrency: summary.currency,
                    merchantSeries: [
                      for (final r in summary.regions)
                        PriceMerchantSeries(
                          merchantId: r.regionId,
                          name: r.displayName,
                          points: _trendToPoints(r.trend),
                          recordDays: const {},
                        ),
                    ],
                    compareLabel: l10n.compareByRegion,
                    compareSuffixBuilder: (n) => l10n.compareRegionsSuffix(n),
                    recordDays: const {},
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _regionName(ComparisonState state, int rid) {
    for (final r in state.summary?.regions ?? const <RegionSummary>[]) {
      if (r.regionId == rid) return r.displayName;
    }
    for (final c in state.candidates) {
      if (c.regionId == rid) return c.displayName;
    }
    return '#$rid';
  }

  List<double> _baseTrend(ComparisonSummary summary) {
    for (final r in summary.regions) {
      if (r.regionId == summary.baseRegionId) return r.trend;
    }
    return summary.regions.isEmpty ? const [] : summary.regions.first.trend;
  }

  bool _isLowestIndex(ComparisonSummary summary, RegionSummary r) {
    final values = summary.regions
        .map((x) => x.priceIndex)
        .whereType<double>()
        .toList();
    if (values.length < 2 || r.priceIndex == null) return false;
    return r.priceIndex! <= values.reduce((a, b) => a < b ? a : b);
  }

  String _fmtIndex(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toString();
  }

  List<Widget> _buildIndexBars(ComparisonSummary summary, ThemeData theme, AppLocalizations l10n) {
    final items = [...summary.regions]
      ..sort((a, b) => (b.priceIndex ?? 0).compareTo(a.priceIndex ?? 0));
    final maxVal = items
        .map((r) => r.priceIndex ?? 0)
        .reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return const [];
    return [
      for (final r in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  r.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor:
                          (r.priceIndex ?? 0) / maxVal < 0.02 ? 0.02 : (r.priceIndex ?? 0) / maxVal,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: r.regionId == summary.baseRegionId
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Text(
                  r.priceIndex == null ? '—' : _fmtIndex(r.priceIndex!),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

// ============ 地区选择弹层 ============

class _RegionPickerSheet extends StatefulWidget {
  final List<RegionCandidate> candidates;
  final List<int> selected;
  final int maxRegions;

  const _RegionPickerSheet({
    required this.candidates,
    required this.selected,
    required this.maxRegions,
  });

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  late final Set<int> _temp;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _temp = Set<int>.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filtered = widget.candidates
        .where((c) => _keyword.isEmpty || c.displayName.contains(_keyword) || c.name.contains(_keyword))
        .toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.compareRegions),
            subtitle: Text(
              '${_temp.length}/${widget.maxRegions}',
              style: theme.textTheme.labelSmall,
            ),
            trailing: TextButton(
              onPressed: _temp.length >= 2 ? () => Navigator.pop(context, _temp.toList()) : null,
              child: Text(l10n.commonDone),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.compareSearchEntityHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _keyword = v.trim()),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final c = filtered[i];
                final checked = _temp.contains(c.regionId);
                final disabled = !checked && _temp.length >= widget.maxRegions;
                return CheckboxListTile(
                  value: checked,
                  secondary: Text(
                    '${c.recordCount}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  title: Text(c.displayName),
                  subtitle: Text(
                    '${c.merchantCount} · ${c.recordCount}',
                    style: theme.textTheme.labelSmall,
                  ),
                  onChanged: disabled
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _temp.add(c.regionId);
                            } else {
                              _temp.remove(c.regionId);
                            }
                          });
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 原料·商品 ============

class _PricesTab extends ConsumerStatefulWidget {
  final ComparisonState state;
  final int maxRegions;

  const _PricesTab({required this.state, required this.maxRegions});

  @override
  ConsumerState<_PricesTab> createState() => _PricesTabState();
}

class _PricesTabState extends ConsumerState<_PricesTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notifier = ref.read(comparisonProvider.notifier);
    final state = widget.state;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              // 实体类型切换：下拉（与趋势图模式切换同形态，窄屏不溢出）
              DropdownButton<String>(
                value: state.entityType,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: 'ingredient', child: Text(l10n.compareEntityTypeIngredient)),
                  DropdownMenuItem(value: 'product', child: Text(l10n.compareEntityTypeProduct)),
                ],
                onChanged: (v) {
                  if (v != null) notifier.setEntityType(v);
                },
              ),
              const Spacer(),
              Text(
                '${state.selectedEntityIds.length} ${l10n.compareSelectedCount}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.selectedRegionIds.length < 2 ? null : _openEntityPicker,
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.compareSelectEntities, style: theme.textTheme.labelMedium),
              ),
            ],
          ),
        ),
        if (state.selectedEntityIds.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final eid in state.selectedEntityIds)
                  InputChip(
                    label: Text(_entityName(state, eid), style: theme.textTheme.labelMedium),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => notifier.toggleEntity(eid),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        RegionPriceMatrix(
          columns: [
            for (final r in state.summary?.regions ?? const <RegionSummary>[])
              RegionMatrixColumn(regionId: r.regionId, label: r.displayName),
          ],
          rows: state.entityPrices?.entities ?? const [],
          loading: state.loadingEntityPrices,
          emptyText: state.selectedEntityIds.isEmpty
              ? l10n.compareNoMatrixData
              : (state.selectedRegionIds.length < 2 ? l10n.compareNeedTwoRegions : l10n.compareNoRegionData),
          unassignedNote: l10n.compareUnassignedNote,
        ),
      ],
    );
  }

  String _entityName(ComparisonState state, int eid) {
    for (final row in state.entityPrices?.entities ?? const <EntityPriceRow>[]) {
      if (row.entityId == eid) return row.name;
    }
    for (final o in state.entityOptions) {
      if (o.id == eid) return o.name;
    }
    return '#$eid';
  }

  Future<void> _openEntityPicker() async {
    final state = ref.read(comparisonProvider);
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EntityPickerSheet(
        entityType: state.entityType,
        selected: state.selectedEntityIds,
        options: state.entityOptions,
      ),
    );
    if (picked == null || !mounted) return;
    final notifier = ref.read(comparisonProvider.notifier);
    // 同步全量选择（弹层里可勾可取消）
    for (final id in state.selectedEntityIds) {
      if (!picked.contains(id)) notifier.toggleEntity(id);
    }
    for (final id in picked) {
      if (!state.selectedEntityIds.contains(id)) notifier.toggleEntity(id);
    }
  }
}

class _EntityPickerSheet extends ConsumerStatefulWidget {
  final String entityType;
  final List<int> selected;
  final List<EntityOption> options;

  const _EntityPickerSheet({
    required this.entityType,
    required this.selected,
    required this.options,
  });

  @override
  ConsumerState<_EntityPickerSheet> createState() => _EntityPickerSheetState();
}

class _EntityPickerSheetState extends ConsumerState<_EntityPickerSheet> {
  late final Set<int> _temp;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _temp = Set<int>.from(widget.selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(comparisonProvider.notifier).searchEntities();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(comparisonProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.compareSelectEntities),
            subtitle: Text('${_temp.length}', style: theme.textTheme.labelSmall),
            trailing: TextButton(
              onPressed: () => Navigator.pop(context, _temp.toList()),
              child: Text(l10n.commonDone),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.compareSearchEntityHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  ref.read(comparisonProvider.notifier).searchEntities(keyword: v.trim()),
            ),
          ),
          if (state.searching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.entityOptions.length,
                itemBuilder: (ctx, i) {
                  final o = state.entityOptions[i];
                  return CheckboxListTile(
                    value: _temp.contains(o.id),
                    title: Text(o.name),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _temp.add(o.id);
                        } else {
                          _temp.remove(o.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============ 菜谱·试算（二期） ============

/// 原始行 → RegionPriceMatrix 的 EntityPriceRow（cells 取 cost；无数据格为 null）。
EntityPriceRow _rowToEntity(Map<String, dynamic> row, String costKey) {
  final regionsRaw = (row['regions'] as Map?) ?? const {};
  final regions = <String, EntityRegionPrice?>{};
  regionsRaw.forEach((key, value) {
    if (value == null) {
      regions[key.toString()] = null;
      return;
    }
    final m = value as Map;
    final dynamic cost = m[costKey];
    regions[key.toString()] = EntityRegionPrice(
      price: cost == null ? null : _toDouble(cost),
      isStale: false,
      daysSinceRecord: null,
      participantCount: 0,
      unit: null,
      trend: const [],
    );
  });
  return EntityPriceRow(
    entityId: ((row['recipe_id'] ?? row['plan_id']) as num?)?.toInt() ?? 0,
    name: (row['name'] as String?) ?? '',
    unit: null,
    regions: regions,
  );
}

double _toDouble(dynamic v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

class _RecipesTab extends ConsumerStatefulWidget {
  const _RecipesTab();

  @override
  ConsumerState<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<_RecipesTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notifier = ref.read(comparisonProvider.notifier);
    final state = ref.watch(comparisonProvider);
    final userCurrency = ref.watch(displayCurrencyProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ---- 菜谱 ----
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Text(l10n.compareRecipesSection, style: theme.textTheme.titleSmall),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: state.selectedRegionIds.length < 2 ? null : _openRecipePicker,
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.compareSelectRecipes, style: theme.textTheme.labelMedium),
              ),
            ],
          ),
        ),
        if (state.selectedRecipeIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final rid in state.selectedRecipeIds)
                  InputChip(
                    label: Text(_recipeName(state, rid), style: theme.textTheme.labelMedium),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => notifier.toggleRecipe(rid),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        RegionPriceMatrix(
          columns: [
            for (final r in state.summary?.regions ?? const <RegionSummary>[])
              RegionMatrixColumn(regionId: r.regionId, label: r.displayName),
          ],
          rows: [
            for (final row in state.recipeRows) _rowToEntity(row, 'total_cost'),
          ],
          loading: state.loadingRecipes,
          emptyText: state.selectedRecipeIds.isEmpty
              ? l10n.compareNoMatrixData
              : (state.selectedRegionIds.length < 2 ? l10n.compareNeedTwoRegions : l10n.compareNoRegionData),
          unassignedNote: l10n.compareUnassignedNote,
          userCurrency: userCurrency,
        ),

        const Divider(height: 32),

        // ---- 试算 ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(l10n.comparePlansSection, style: theme.textTheme.titleSmall),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: state.selectedRegionIds.length < 2 ? _openPlanPicker : null,
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.compareSelectPlans, style: theme.textTheme.labelMedium),
              ),
            ],
          ),
        ),
        if (state.selectedPlanIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final pid in state.selectedPlanIds)
                  InputChip(
                    label: Text(_planName(state, pid), style: theme.textTheme.labelMedium),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => notifier.togglePlan(pid),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        RegionPriceMatrix(
          columns: [
            for (final r in state.summary?.regions ?? const <RegionSummary>[])
              RegionMatrixColumn(regionId: r.regionId, label: r.displayName),
          ],
          rows: [
            for (final row in state.planRows) _rowToEntity(row, 'cost'),
          ],
          loading: state.loadingPlans,
          emptyText: state.selectedPlanIds.isEmpty
              ? l10n.compareNoMatrixData
              : (state.selectedRegionIds.length < 2 ? l10n.compareNeedTwoRegions : l10n.compareNoRegionData),
          unassignedNote: l10n.compareUnassignedNote,
          userCurrency: userCurrency,
        ),
      ],
    );
  }

  String _recipeName(ComparisonState state, int rid) {
    for (final o in state.recipeOptions) {
      if (o.id == rid) return o.name;
    }
    for (final row in state.recipeRows) {
      if ((row['recipe_id'] as num?)?.toInt() == rid) return (row['name'] as String?) ?? '#$rid';
    }
    return '#$rid';
  }

  String _planName(ComparisonState state, int pid) {
    for (final o in state.planOptions) {
      if (o.id == pid) return o.name;
    }
    for (final row in state.planRows) {
      if ((row['plan_id'] as num?)?.toInt() == pid) return (row['name'] as String?) ?? '#$pid';
    }
    return '#$pid';
  }

  Future<void> _openRecipePicker() async {
    final state = ref.read(comparisonProvider);
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SimpleSearchPickerSheet(
        title: AppLocalizations.of(ctx).compareSelectRecipes,
        options: state.recipeOptions,
        selected: state.selectedRecipeIds,
        onSearch: (kw) => ref.read(comparisonProvider.notifier).searchRecipes(keyword: kw),
      ),
    );
    if (picked == null || !mounted) return;
    final notifier = ref.read(comparisonProvider.notifier);
    for (final id in state.selectedRecipeIds) {
      if (!picked.contains(id)) notifier.toggleRecipe(id);
    }
    for (final id in picked) {
      if (!state.selectedRecipeIds.contains(id)) notifier.toggleRecipe(id);
    }
  }

  Future<void> _openPlanPicker() async {
    final state = ref.read(comparisonProvider);
    if (state.planOptions.isEmpty) {
      await ref.read(comparisonProvider.notifier).loadPlanOptions();
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final fresh = ref.read(comparisonProvider).planOptions;
        return _SimpleSearchPickerSheet(
          title: AppLocalizations.of(ctx).compareSelectPlans,
          options: fresh,
          selected: state.selectedPlanIds,
          onSearch: null,
        );
      },
    );
    if (picked == null || !mounted) return;
    final notifier = ref.read(comparisonProvider.notifier);
    for (final id in state.selectedPlanIds) {
      if (!picked.contains(id)) notifier.togglePlan(id);
    }
    for (final id in picked) {
      if (!state.selectedPlanIds.contains(id)) notifier.togglePlan(id);
    }
  }
}

/// 通用「搜索 + 多选」底部弹层（菜谱/方案共用；onSearch 为空 = 客户端过滤）。
class _SimpleSearchPickerSheet extends StatefulWidget {
  final String title;
  final List<EntityOption> options;
  final List<int> selected;
  final ValueChanged<String>? onSearch;

  const _SimpleSearchPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    this.onSearch,
  });

  @override
  State<_SimpleSearchPickerSheet> createState() => _SimpleSearchPickerSheetState();
}

class _SimpleSearchPickerSheetState extends State<_SimpleSearchPickerSheet> {
  late final Set<int> _temp;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _temp = Set<int>.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.options
        .where((o) => _keyword.isEmpty || o.name.contains(_keyword))
        .toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(widget.title),
            subtitle: Text('${_temp.length}', style: theme.textTheme.labelSmall),
            trailing: TextButton(
              onPressed: () => Navigator.pop(context, _temp.toList()),
              child: Text(AppLocalizations.of(context).commonDone),
            ),
          ),
          if (widget.onSearch != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  setState(() => _keyword = v.trim());
                  widget.onSearch!(v.trim());
                },
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final o = filtered[i];
                return CheckboxListTile(
                  value: _temp.contains(o.id),
                  title: Text(o.name),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _temp.add(o.id);
                      } else {
                        _temp.remove(o.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 热力图（三期） ============

class _HeatmapTab extends ConsumerStatefulWidget {
  const _HeatmapTab();

  @override
  ConsumerState<_HeatmapTab> createState() => _HeatmapTabState();
}

class _HeatmapTabState extends ConsumerState<_HeatmapTab> {
  String _mode = 'item'; // 'item' | 'overall'
  String _entityType = 'ingredient';
  EntityOption? _selectedEntity;
  List<HeatmapPoint> _points = const [];
  HeatmapBuckets? _buckets;
  bool _loading = false;
  String? _error;
  int _seq = 0;
  int _searchSeq = 0;
  List<EntityOption> _entityOptions = const [];
  String _lastRegionSignature = '';
  bool _initialLoaded = false;

  Future<void> _load() async {
    final state = ref.read(comparisonProvider);
    final rids = state.selectedRegionIds;
    if (rids.isEmpty) return;
    if (_mode == 'item' && _selectedEntity == null) {
      setState(() { _points = const []; _buckets = null; });
      return;
    }
    final seq = ++_seq;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _heatmapRepo.getHeatmap(
        mode: _mode,
        regionIds: rids,
        entityType: _entityType,
        entityId: _selectedEntity?.id,
      );
      final points = ((data['items'] as List?) ?? const [])
          .map((e) => HeatmapPoint.fromJson(e as Map<String, dynamic>))
          .toList();
      final rawBuckets = (data['buckets'] as Map?) ?? const {};
      final buckets = HeatmapBuckets.fromJson(
          rawBuckets.map((k, v) => MapEntry(k.toString(), v)));
      if (seq == _seq && mounted) {
        setState(() { _points = points; _buckets = buckets; _loading = false; });
      }
    } catch (e) {
      if (seq == _seq && mounted) {
        setState(() { _points = const []; _buckets = null; _loading = false; _error = '$e'; });
      }
    }
  }

  Future<void> _searchEntities(String keyword) async {
    final seq = ++_searchSeq;
    try {
      final options = await _heatmapRepo.searchEntities(
        entityType: _entityType, keyword: keyword);
      if (seq == _searchSeq && mounted) setState(() => _entityOptions = options);
    } catch (_) {
      if (seq == _searchSeq && mounted) setState(() => _entityOptions = const []);
    }
  }

  Future<void> _openEntityPicker() async {
    await _searchEntities('');
    if (!mounted) return;
    final picked = await showModalBottomSheet<EntityOption>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EntityOptionPickerSheet(
        options: _entityOptions,
        onSearch: (kw) => _searchEntities(kw),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedEntity = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(comparisonProvider);
    final userCurrency = ref.watch(displayCurrencyProvider);

    // 地区变化（或首次进入 tab 地区已就绪）时重拉；overall 模式无需选实体
    final regionSignature = state.selectedRegionIds.join(',');
    if (regionSignature.isNotEmpty && regionSignature != _lastRegionSignature) {
      _lastRegionSignature = regionSignature;
      if (_mode == 'overall' || _selectedEntity != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load();
        });
      }
    } else if (!_initialLoaded && regionSignature.isNotEmpty) {
      _initialLoaded = true;
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 模式切换：下拉（与趋势图模式切换同形态，窄屏不溢出）
              DropdownButton<String>(
                value: _mode,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: 'item', child: Text(l10n.compareHeatmapModeItem)),
                  DropdownMenuItem(value: 'overall', child: Text(l10n.compareHeatmapModeOverall)),
                ],
                onChanged: (v) {
                  if (v == null || v == _mode) return;
                  setState(() {
                    _mode = v;
                    _points = const [];
                    _buckets = null;
                    _error = null;
                  });
                  _load();
                },
              ),
              if (_mode == 'item') ...[
                DropdownButton<String>(
                  value: _entityType,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(value: 'ingredient', child: Text(l10n.compareEntityTypeIngredient)),
                    DropdownMenuItem(value: 'product', child: Text(l10n.compareEntityTypeProduct)),
                  ],
                  onChanged: (v) {
                    if (v == null || v == _entityType) return;
                    setState(() {
                      _entityType = v;
                      _selectedEntity = null;
                      _entityOptions = const [];
                      _points = const [];
                      _buckets = null;
                      _error = null;
                    });
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _openEntityPicker,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    _selectedEntity?.name ?? l10n.compareHeatmapPickEntity,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ] else
                Text(
                  l10n.compareHeatmapOverallNote,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: HeatmapCanvas(
            points: _points,
            buckets: _buckets,
            loading: _loading,
            overallMode: _mode == 'overall',
            userCurrency: userCurrency,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}

/// 单品选择弹层（搜索 + 单选）。
class _EntityOptionPickerSheet extends StatefulWidget {
  final List<EntityOption> options;
  final ValueChanged<String>? onSearch;

  const _EntityOptionPickerSheet({required this.options, this.onSearch});

  @override
  State<_EntityOptionPickerSheet> createState() =>
      _EntityOptionPickerSheetState();
}

class _EntityOptionPickerSheetState extends State<_EntityOptionPickerSheet> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((o) => _keyword.isEmpty || o.name.contains(_keyword))
        .toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => _keyword = v.trim());
                widget.onSearch?.call(v.trim());
              },
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final o = filtered[i];
                return ListTile(
                  title: Text(o.name),
                  onTap: () => Navigator.pop(ctx, o),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

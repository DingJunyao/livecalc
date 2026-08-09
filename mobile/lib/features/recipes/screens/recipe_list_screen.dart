import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/recipe_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../models/recipe_summary.dart';
import '../repositories/recipe_repository.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/empty_state.dart';

/// 菜谱分类（对齐 Web 端 FilterBar 分类选项）
const _recipeCategories = <String>[
  '荤菜',
  '素菜',
  '水产',
  '主食',
  '汤与羹',
  '早餐',
  '甜品',
  '调料',
  '半成品',
  '小食',
];

const _recipeDifficulties = <(String, String)>[
  ('simple', '简单'),
  ('easy', '简易'),
  ('medium', '中等'),
  ('hard', '困难'),
  ('expert', '专家'),
];

const _recipeSpecialConditions = <(String, String)>[
  ('has_unpriced_ingredient', '存在原料没有维护价格'),
  ('has_unnourished_ingredient', '存在原料没有维护营养成分'),
];

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(recipeListProvider.notifier).loadRecipes());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(recipeListProvider.notifier);
      if (notifier.canLoadMore) {
        notifier.loadRecipes(loadMore: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(recipeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('菜谱'),
      ),
      body: Column(
        children: [
          _buildSearchBar(theme, state),
          Expanded(child: _buildContent(theme, state)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, RecipeListState state) {
    final notifier = ref.read(recipeListProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索菜谱...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearch('');
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                notifier.setSearch(v);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: Badge(
              isLabelVisible: notifier.activeFilterCount > 0,
              label: Text('${notifier.activeFilterCount}'),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.tune),
                tooltip: '筛选',
                onPressed: () => _showFilterSheet(theme),
                style: notifier.activeFilterCount > 0
                    ? IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, RecipeListState state) {
    if (state.loading && state.recipes.isEmpty) {
      return const LoadingIndicator(message: '加载菜谱...');
    }
    if (state.error != null && state.recipes.isEmpty) {
      return ErrorDisplay(
        message: state.error!,
        onRetry: () => ref.read(recipeListProvider.notifier).loadRecipes(),
      );
    }
    if (state.recipes.isEmpty) {
      return const EmptyState(
        icon: Icons.restaurant,
        title: '暂无菜谱',
        subtitle: '在 Web 端创建菜谱后即可查看',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(recipeListProvider.notifier).loadRecipes(),
      // 用 Wrap + 固定宽度卡片：高度由内容决定，彻底消除单元格固定高度导致的溢出
      child: LayoutBuilder(
        builder: (context, constraints) {
          const padding = 12.0;
          const spacing = 12.0;
          final columns = _columnCountFor(constraints.maxWidth);
          final cardWidth = (constraints.maxWidth -
                  padding * 2 -
                  spacing * (columns - 1)) /
              columns;
          return SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.start,
                  runAlignment: WrapAlignment.start,
                  spacing: spacing,
                  runSpacing: spacing,
                  children: state.recipes.map((r) {
                    return SizedBox(
                      width: cardWidth,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => context.push('/recipes/${r.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Container(
                                  width: double.infinity,
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.3),
                                  child: r.imageUrl != null
                                      ? Image.network(r.imageUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity)
                                      : Icon(Icons.restaurant,
                                          size: 48,
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.5)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(r.name,
                                        style: theme.textTheme.titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    _buildPriceCalories(
                                        theme, r, state.loadingCosts),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (state.hasMore || state.loadingMore) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: state.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton(
                            onPressed: () => ref
                                .read(recipeListProvider.notifier)
                                .loadRecipes(loadMore: true),
                            child: const Text('加载更多'),
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      ), // 关闭 LayoutBuilder
    ); // 关闭 RefreshIndicator
  }

  /// 每行卡片数：对齐 Web 端栅格阈值（cols=6/6/4/3/2）
  /// <960 两列，960-1279 三列，1280-1919 四列，≥1920 六列
  int _columnCountFor(double width) {
    if (width >= 1920) return 6;
    if (width >= 1280) return 4;
    if (width >= 960) return 3;
    return 2;
  }

  Widget _buildPriceCalories(ThemeData theme, RecipeSummary r, bool loading) {
    final servings = r.servings > 0 ? r.servings : 1;
    final hasCost = r.estimatedCost != null;
    final hasCal = r.calories != null;
    // 价格/热量懒加载中：显示占位，避免跳变
    if (!hasCost && !hasCal) {
      return Text(
        loading ? '--' : '${r.servings} 人份',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.outline),
      );
    }
    final children = <Widget>[];
    if (hasCost) {
      children.add(
        Text(
          '¥${r.estimatedCost!.toStringAsFixed(2)} / $servings 人份',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (hasCost && hasCal) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('·',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ));
    }
    if (hasCal) {
      final perServing = (r.calories! / servings).round();
      children.add(
        Text(
          '$perServing kcal/份',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  // ---- 筛选 ----
  void _showFilterSheet(ThemeData theme) {
    final state = ref.read(recipeListProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RecipeFilterSheet(
        initialCategories: state.filterCategories,
        initialDifficulties: state.filterDifficulties,
        initialIngredientIds: state.filterIngredientIds,
        initialConditions: state.filterConditions,
        onApply: (categories, difficulties, ingredientIds, conditions) {
          ref.read(recipeListProvider.notifier).applyFilters(
                categories: categories,
                difficulties: difficulties,
                ingredientIds: ingredientIds,
                conditions: conditions,
              );
        },
      ),
    );
  }
}

class _RecipeFilterSheet extends ConsumerStatefulWidget {
  final List<String> initialCategories;
  final List<String> initialDifficulties;
  final List<int> initialIngredientIds;
  final List<String> initialConditions;
  final void Function(
      List<String>, List<String>, List<int>, List<String>) onApply;

  const _RecipeFilterSheet({
    required this.initialCategories,
    required this.initialDifficulties,
    required this.initialIngredientIds,
    required this.initialConditions,
    required this.onApply,
  });

  @override
  ConsumerState<_RecipeFilterSheet> createState() =>
      _RecipeFilterSheetState();
}

class _RecipeFilterSheetState extends ConsumerState<_RecipeFilterSheet> {
  final _ingredientController = TextEditingController();
  Timer? _debounce;
  late final Set<String> _categories;
  late final Set<String> _difficulties;
  late final Set<int> _ingredientIds;
  late final Set<String> _conditions;
  String _ingredientQuery = '';

  @override
  void initState() {
    super.initState();
    _categories = widget.initialCategories.toSet();
    _difficulties = widget.initialDifficulties.toSet();
    _ingredientIds = widget.initialIngredientIds.toSet();
    _conditions = widget.initialConditions.toSet();
    _ingredientController.addListener(_onIngredientChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ingredientController.dispose();
    super.dispose();
  }

  void _onIngredientChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _ingredientQuery = _ingredientController.text.trim());
      }
    });
  }

  bool get _hasActive =>
      _categories.isNotEmpty ||
      _difficulties.isNotEmpty ||
      _ingredientIds.isNotEmpty ||
      _conditions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = ref
            .watch(recipeIngredientOptionsProvider(_ingredientQuery))
            .value ??
        const <IngredientOption>[];
    final selectedNames = <int, String>{
      for (final id in _ingredientIds)
        id: options
            .firstWhere((o) => o.id == id,
                orElse: () => IngredientOption(id: id, name: '食材 $id'))
            .name,
    };

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Text('筛选条件',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_hasActive)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _categories.clear();
                      _difficulties.clear();
                      _ingredientIds.clear();
                      _conditions.clear();
                    }),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('清除'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('分类', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _recipeCategories)
                        FilterChip(
                          label: Text(c),
                          selected: _categories.contains(c),
                          onSelected: (_) => setState(() {
                            if (!_categories.add(c)) {
                              _categories.remove(c);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('难度', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (value, label) in _recipeDifficulties)
                        FilterChip(
                          label: Text(label),
                          selected: _difficulties.contains(value),
                          onSelected: (_) => setState(() {
                            if (!_difficulties.add(value)) {
                              _difficulties.remove(value);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('所用食材', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ingredientController,
                    decoration: InputDecoration(
                      hintText: '搜索食材（可多选）',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (selectedNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in selectedNames.entries)
                          Chip(
                            label: Text(entry.value),
                            visualDensity: VisualDensity.compact,
                            onDeleted: () => setState(() {
                              _ingredientIds.remove(entry.key);
                            }),
                          ),
                      ],
                    ),
                  ],
                  if (options.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (ctx, i) {
                          final o = options[i];
                          final selected = _ingredientIds.contains(o.id);
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              selected
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 20,
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                            title: Text(o.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => setState(() {
                              if (!_ingredientIds.add(o.id)) {
                                _ingredientIds.remove(o.id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('特殊条件', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (value, label) in _recipeSpecialConditions)
                        FilterChip(
                          label: Text(label),
                          selected: _conditions.contains(value),
                          onSelected: (_) => setState(() {
                            if (!_conditions.add(value)) {
                              _conditions.remove(value);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(
                    _categories.toList()..sort(),
                    _difficulties.toList()..sort(),
                    _ingredientIds.toList()..sort(),
                    _conditions.toList()..sort(),
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('确定'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

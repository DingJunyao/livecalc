import 'package:flutter/material.dart';
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/sparkline.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../merchants/providers/merchant_provider.dart';
import '../../prices/screens/price_record_form_screen.dart';
import '../../products/repositories/product_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../models/ingredient.dart';
import 'ingredient_form_screen.dart' show IngredientFormResult;
import '../providers/ingredient_provider.dart';

const _specialConditions = <String>[
  'no_price',
  'no_nutrition',
  'single_price',
  'single_merchant',
  'no_recipe',
  'no_product',
];

class IngredientListScreen extends ConsumerStatefulWidget {
  const IngredientListScreen({super.key});

  @override
  ConsumerState<IngredientListScreen> createState() =>
      _IngredientListScreenState();
}

class _IngredientListScreenState extends ConsumerState<IngredientListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(ingredientListProvider.notifier).load();
      final merchants = ref.read(merchantListProvider);
      if (merchants.items.isEmpty && !merchants.loading) {
        ref.read(merchantListProvider.notifier).load();
      }
    });
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
      final notifier = ref.read(ingredientListProvider.notifier);
      if (notifier.canLoadMore) {
        notifier.load(loadMore: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 会话级临时覆盖（地区/范围/币种）变化后刷新当前页数据
    ref.listen(calcContextProvider, (_, __) {
      ref.read(ingredientListProvider.notifier).load();
    });
    final theme = Theme.of(context);
    final state = ref.watch(ingredientListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ingredientTitle),
        leading: const AppBackButton(),
        actions: [
          const CalcContextMenuButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.journeyRefresh,
            onPressed: state.loading
                ? null
                : () => ref.read(ingredientListProvider.notifier).load(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(theme, state),
          Expanded(child: _buildBody(theme, state)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, IngredientListState state) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(ingredientListProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.ingredientSearch,
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
                tooltip: l10n.journeyFilters,
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

  Widget _buildBody(ThemeData theme, IngredientListState state) {
    final l10n = AppLocalizations.of(context);
    if (state.loading && state.items.isEmpty) {
      return LoadingIndicator(message: l10n.commonLoading);
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorDisplay(
        message: state.error!,
        onRetry: () => ref.read(ingredientListProvider.notifier).load(),
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.science,
        title: l10n.ingredientEmptyTitle,
        subtitle: l10n.ingredientEmptySubtitle,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(ingredientListProvider.notifier).load(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= state.items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: state.loadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => ref
                            .read(ingredientListProvider.notifier)
                            .load(loadMore: true),
                        child: Text(l10n.journeyLoadMore),
                      ),
              ),
            );
          }
          return _IngredientCard(
            item: state.items[i],
            latest: state.latestPrices[state.items[i].id],
            sparkline: state.sparklines[state.items[i].id],
            onTap: () => context.push('/ingredients/${state.items[i].id}'),
            onQuickPrice: () => _quickPrice(state.items[i]),
            userCurrency: ref.read(displayCurrencyProvider),
          );
        },
      ),
    );
  }

  // ---- 快捷记价 ----
  Future<void> _quickPrice(Ingredient item) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await ProductRepository().search(
        ingredientId: item.id,
        limit: 50,
      );
      if (result.items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.ingredientNoLinkedProducts)),
          );
        }
        return;
      }
      final products = result.items;
      final matched = products.firstWhere(
        (p) => p.name == item.name,
        orElse: () => products.first,
      );
      if (!mounted) return;
      final saved = await context.push<bool>(
        '/prices/record',
        extra: PriceRecordFormPrefill(
          product: matched,
          ingredientId: item.id,
        ),
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.ingredientPriceRecorded)),
        );
        ref.read(ingredientListProvider.notifier).load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.ingredientRecordPriceFailed)),
        );
      }
    }
  }

  // ---- 筛选 ----
  void _showFilterSheet(ThemeData theme) {
    final state = ref.read(ingredientListProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _IngredientFilterSheet(
        initialCategoryIds: state.filterCategoryIds,
        initialConditions: state.conditions,
        onApply: (categoryIds, conditions) {
          ref
              .read(ingredientListProvider.notifier)
              .applyFilters(categoryIds: categoryIds, conditions: conditions);
        },
      ),
    );
  }

  // ---- 添加原料 ----
  Future<void> _openAddForm() async {
    final saved = await context.push<IngredientFormResult>('/ingredients/new');
    if (saved?.saved == true && mounted) {
      ref.read(ingredientListProvider.notifier).load();
    }
  }
}

class _IngredientCard extends ConsumerWidget {
  final Ingredient item;
  final LatestPriceInfo? latest;
  final List<double>? sparkline;
  final VoidCallback onTap;
  final VoidCallback onQuickPrice;
  final String userCurrency;

  const _IngredientCard({
    required this.item,
    required this.latest,
    required this.sparkline,
    required this.onTap,
    required this.onQuickPrice,
    this.userCurrency = 'CNY',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(ingredientCategoriesProvider).valueOrNull;
    final matchedCategory = categories?.where(
      (category) => category.id == item.categoryId,
    );
    final category = matchedCategory?.firstOrNull?.localizedDisplayName(l10n) ??
        item.category;
    final price = latest?.price ?? item.latestPrice;
    final unit = latest?.unit ?? item.unit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                radius: 20,
                child: Text(
                  item.name.isNotEmpty ? item.name.characters.first : '?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (price != null)
                          Flexible(
                            child: Text(
                              '${formatMoney(price, userCurrency)}'
                              '${unit == null ? '' : ' / $unit'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
              if (sparkline != null && sparkline!.length >= 2) ...[
                Sparkline(data: sparkline!),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(Icons.add_chart),
                tooltip: l10n.journeyRecordPrice,
                visualDensity: VisualDensity.compact,
                onPressed: onQuickPrice,
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientFilterSheet extends ConsumerStatefulWidget {
  final List<int> initialCategoryIds;
  final List<String> initialConditions;
  final void Function(List<int>, List<String>) onApply;

  const _IngredientFilterSheet({
    required this.initialCategoryIds,
    required this.initialConditions,
    required this.onApply,
  });

  @override
  ConsumerState<_IngredientFilterSheet> createState() =>
      _IngredientFilterSheetState();
}

class _IngredientFilterSheetState
    extends ConsumerState<_IngredientFilterSheet> {
  late final Set<int> _categoryIds;
  late final Set<String> _conditions;

  @override
  void initState() {
    super.initState();
    _categoryIds = widget.initialCategoryIds.toSet();
    _conditions = widget.initialConditions.toSet();
  }

  bool get _hasActive => _categoryIds.isNotEmpty || _conditions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final categories =
        ref.watch(ingredientCategoriesProvider).value ?? const [];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Text(l10n.journeyFilters,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_hasActive)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _categoryIds.clear();
                      _conditions.clear();
                    }),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: Text(l10n.journeyClear),
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
                  Text(l10n.ingredientCategory,
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  if (categories.isEmpty)
                    Text(l10n.ingredientNoCategories,
                        style: theme.textTheme.bodySmall)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories)
                          FilterChip(
                            label: Text(c.localizedDisplayName(l10n)),
                            selected: _categoryIds.contains(c.id),
                            onSelected: (_) => setState(() {
                              if (!_categoryIds.add(c.id)) {
                                _categoryIds.remove(c.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Text(l10n.ingredientSpecialConditions,
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value in _specialConditions)
                        FilterChip(
                          label: Text(
                            _conditionLabel(value, l10n),
                          ),
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
                    _categoryIds.toList()..sort(),
                    _conditions.toList()..sort(),
                  );
                  Navigator.of(context).pop();
                },
                child: Text(l10n.journeyConfirm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _conditionLabel(String value, AppLocalizations l10n) =>
      switch (value) {
        'no_price' => l10n.ingredientConditionNoPrice,
        'no_nutrition' => l10n.ingredientConditionNoNutrition,
        'single_price' => l10n.ingredientConditionSinglePrice,
        'single_merchant' => l10n.ingredientConditionSingleMerchant,
        'no_recipe' => l10n.ingredientConditionNoRecipe,
        'no_product' => l10n.ingredientConditionNoProduct,
        _ => value,
      };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/hierarchy_relation.dart';
import '../../../shared/models/ingredient_recipe.dart';
import '../../../shared/models/merchant_price.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/entity_units_card.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/merchant_price_list.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/widgets/nutrition_card.dart';
import '../../../shared/widgets/pending_change_banner.dart';
import '../../../shared/screens/price_record_edit_screen.dart';
import '../../merchants/providers/merchant_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../prices/models/price_record.dart';
import '../../prices/screens/price_record_form_screen.dart';
import '../../products/models/product.dart';
import '../../recipes/widgets/cost_trend_chart.dart';
import '../models/ingredient.dart';
import '../models/ingredient_category.dart';
import '../repositories/ingredient_repository.dart'
    show IngredientHierarchyData;
import '../widgets/hierarchy_graph.dart';
import 'ingredient_form_screen.dart' show IngredientFormResult;
import 'ingredient_hierarchy_screen.dart';
import '../providers/ingredient_provider.dart';

class IngredientDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const IngredientDetailScreen({super.key, required this.id});

  @override
  ConsumerState<IngredientDetailScreen> createState() =>
      _IngredientDetailScreenState();
}

class _IngredientDetailScreenState
    extends ConsumerState<IngredientDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(ingredientDetailPageProvider(widget.id).notifier)
          .load(initialDays: 30);
      final merchants = ref.read(merchantListProvider);
      if (merchants.items.isEmpty && !merchants.loading) {
        ref.read(merchantListProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(ingredientDetailPageProvider(widget.id));
    final ingredient = state.ingredient?.mergedWithPending();

    if (state.error != null && ingredient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('原料详情')),
        body: ErrorDisplay(
          message: state.error!,
          onRetry: () =>
              ref.read(ingredientDetailPageProvider(widget.id).notifier).load(),
        ),
      );
    }
    if (ingredient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('原料详情')),
        body: const LoadingIndicator(message: '加载中...'),
      );
    }

    final notifier = ref.read(ingredientDetailPageProvider(widget.id).notifier);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin ?? false;
    final userCurrency = user?.currency ?? 'CNY';
    final modifications = <String>{
      ...ingredient.pendingModificationLabels,
      if (state.nutrition?.pendingProposal != null) '营养成分',
      if (state.units.any((unit) => unit.isPending)) '自定义单位',
      if (state.densities.any((density) => density.isPending)) '密度',
      if (_hasPendingHierarchy(state)) '层级关系',
    };
    final deletions = <String>{
      if (ingredient.pendingProposal?.action == 'delete') '基本信息',
      if (state.deletedUnitIds.isNotEmpty) '自定义单位',
      if (state.deletedDensityIds.isNotEmpty) '密度',
      if (state.deletedHierarchyIds.isNotEmpty) '层级关系',
    };
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(ingredient.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('原料',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: '记录价格',
            onPressed: () => _openRecordPrice(notifier, state, ingredient),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed:
                state.loading ? null : () => notifier.load(initialDays: 30),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.load(initialDays: 30),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (modifications.isNotEmpty || deletions.isNotEmpty) ...[
              PendingChangeBanner(
                modifications: modifications,
                deletions: deletions,
              ),
              const SizedBox(height: 16),
            ],
            _BasicInfoCard(
              ingredient: ingredient,
              categoriesAsync: ref.watch(ingredientCategoriesProvider),
              onEdit: () => _openEditBasicPage(notifier, ingredient),
            ),
            const SizedBox(height: 16),
            _LatestPriceCard(
              latest: state.latestPrice,
              merchantPrices: state.merchantPrices,
              loadingLatest: state.loadingLatest,
              loadingMerchants: state.loadingMerchants,
              currency: userCurrency,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CostTrendChart(
                  points: state.chartPoints,
                  loading: state.loadingChart,
                  userCurrency: userCurrency,
                  onRangeChange: (days) => notifier.reloadChart(days),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _RelatedProductsCard(
              products: state.products,
              productPrices: state.productPrices,
              loading: state.loadingProducts,
              currency: userCurrency,
              onLoadPrice: notifier.loadProductPrice,
              onAdd: () => _openAddProductPage(notifier, ingredient),
              onEdit: (p) => _openEditProductPage(notifier, ingredient, p),
              onDelete: (p) => _confirmDeleteProduct(notifier, p),
            ),
            const SizedBox(height: 16),
            _PriceRecordsCard(
              records: state.records,
              loading: state.loadingRecords,
              hasMore: state.recordsHasMore,
              products: state.products,
              currency: userCurrency,
              onLoadMore: notifier.loadMoreRecords,
              onAdd: () => _openAddRecord(notifier, state, ingredient),
              onEdit: (r) => _openEditRecord(notifier, state, r),
              onDelete: (r) => _confirmDeleteRecord(notifier, r),
            ),
            const SizedBox(height: 16),
            _RelatedRecipesCard(
              recipes: state.recipes,
              loading: state.loadingRecipes,
              hasMore: state.recipesHasMore,
              onLoadMore: notifier.loadMoreRecipes,
            ),
            const SizedBox(height: 16),
            NutritionCard(
              entityType: 'ingredient',
              entityId: widget.id,
              entityName: ingredient.name,
              nutrition: state.nutrition,
              loading: state.loadingNutrition,
              saving: state.savingNutrition,
              onRefresh: notifier.refreshNutrition,
              onSave: notifier.saveNutrition,
            ),
            const SizedBox(height: 16),
            EntityUnitsCard(
              entityType: 'ingredient',
              entityId: widget.id,
              entityName: ingredient.name,
              units: state.units,
              unmappedUnits: state.unmappedUnits,
              densities: state.densities,
              loading: state.loadingUnits,
              isAdmin: isAdmin,
              onAddUnit: (input) => notifier.addUnit(
                unitName: input.unitName,
                conversionFactor: input.conversionFactor,
                weightPerUnit: input.weightPerUnit,
                isDefault: input.isDefault,
                isAdmin: isAdmin,
              ),
              onEditUnit: (unitId, input) => notifier.updateUnit(
                unitId,
                unitName: input.unitName,
                conversionFactor: input.conversionFactor,
                weightPerUnit: input.weightPerUnit,
                isDefault: input.isDefault,
                isAdmin: isAdmin,
              ),
              onDeleteUnit: notifier.deleteUnit,
              onQuickAddUnmapped: (unit) =>
                  notifier.quickAddUnmappedUnit(unit, isAdmin: isAdmin),
              onAddDensity: (input) => notifier.addDensity(
                density: input.density,
                condition: input.condition,
                isAdmin: isAdmin,
              ),
              onDeleteDensity: notifier.deleteDensity,
            ),
            const SizedBox(height: 16),
            _HierarchyCard(
              currentId: widget.id,
              currentName: ingredient.name,
              data: state.hierarchy,
              loading: state.loadingHierarchy,
              onAdd: () => _openHierarchyPage(notifier, isAdmin),
              onEditStrength: (relation) =>
                  _openHierarchyPage(notifier, isAdmin),
              onDelete: (relation) => _openHierarchyPage(notifier, isAdmin),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 记录价格 ----
  bool _hasPendingHierarchy(IngredientDetailPageState state) {
    final hierarchy = state.hierarchy;
    if (hierarchy == null) return false;
    return [
      ...hierarchy.parentRelations,
      ...hierarchy.childRelations,
    ].any((relation) => relation.isPending);
  }

  Future<void> _openRecordPrice(
    IngredientDetailPageNotifier notifier,
    IngredientDetailPageState state,
    Ingredient ingredient,
  ) async {
    if (state.products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该原料暂无关联商品，请先添加商品')),
        );
      }
      return;
    }
    await _openAddRecord(notifier, state, ingredient);
  }

  Future<void> _openAddRecord(
    IngredientDetailPageNotifier notifier,
    IngredientDetailPageState state,
    Ingredient ingredient,
  ) async {
    if (!mounted) return;
    final matched = state.products.firstWhere(
      (product) => product.name == ingredient.name,
      orElse: () => state.products.first,
    );
    final saved = await context.push<bool>(
      '/prices/record',
      extra: PriceRecordFormPrefill(
        product: matched,
        ingredientId: widget.id,
      ),
    );
    if (saved == true && mounted) {
      await notifier.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('价格已记录')),
        );
      }
    }
  }

  Future<void> _openEditRecord(
    IngredientDetailPageNotifier notifier,
    IngredientDetailPageState state,
    PriceRecord record,
  ) async {
    if (!mounted) return;
    final merchants = ref.read(merchantListProvider).items;
    final result = await context.push<PriceRecordFormResult>(
      '/prices/record/edit',
      extra: PriceRecordFormArguments(
        merchants: merchants,
        products: [
          for (final p in state.products) ProductOption(p.id, p.name),
        ],
        fixedProductId: record.productId,
        initialPrice: record.price,
        initialQuantity: record.quantity,
        initialUnit: record.unit,
        initialMerchantId: record.merchantId,
        initialRecordType: record.recordType,
        initialRecordedAt: DateTime.tryParse(record.recordedAt),
        initialNotes: record.notes,
        initialCurrency: record.currency,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await notifier.updateRecord(
        record.id,
        price: result.price,
        quantity: result.quantity,
        unit: result.unit,
        merchantId: result.merchantId,
        recordType: result.recordType,
        recordedAt: result.recordedAt,
        notes: result.notes,
        currency: result.currency,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已更新')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新失败，请重试')),
        );
      }
    }
  }

  Future<void> _confirmDeleteRecord(
    IngredientDetailPageNotifier notifier,
    PriceRecord record,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除「${record.productName}」这条价格记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await notifier.deleteRecord(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请重试')),
        );
      }
    }
  }

  // ---- 基本信息编辑 ----
  Future<void> _openEditBasicPage(
    IngredientDetailPageNotifier notifier,
    Ingredient ingredient,
  ) async {
    final result = await context.push<IngredientFormResult>(
      '/ingredients/${ingredient.id}/edit',
      extra: ingredient,
    );
    if (result?.saved == true && mounted) {
      await notifier.load(initialDays: 30);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result!.pending
                  ? (result.message.isEmpty ? '修改已提交，待管理员审核' : result.message)
                  : '基本信息已保存',
            ),
          ),
        );
      }
    }
  }

  // ---- 关联商品添加/编辑/删除 ----
  Future<void> _openAddProductPage(
    IngredientDetailPageNotifier notifier,
    Ingredient ingredient,
  ) async {
    final saved = await context.push<bool>(
      '/products/new',
      extra: ingredient,
    );
    if (saved == true && mounted) {
      await notifier.refreshProducts();
    }
  }

  Future<void> _openEditProductPage(
    IngredientDetailPageNotifier notifier,
    Ingredient ingredient,
    Product product,
  ) async {
    final saved = await context.push<bool>(
      '/products/${product.id}/edit',
      extra: product,
    );
    if (saved == true && mounted) {
      await notifier.refreshProducts();
    }
  }

  Future<void> _confirmDeleteProduct(
    IngredientDetailPageNotifier notifier,
    Product product,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除商品'),
        content: Text('确定删除商品「${product.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final review = await notifier.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            review.pending
                ? (review.message.isEmpty ? '删除提议已提交，待管理员审核' : review.message)
                : '商品已删除',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请重试')),
        );
      }
    }
  }

  // ---- 层级关系 ----

  Future<void> _openHierarchyPage(
    IngredientDetailPageNotifier notifier,
    bool isAdmin,
  ) async {
    final state = ref.read(ingredientDetailPageProvider(widget.id));
    final ingredient = state.ingredient?.mergedWithPending();
    if (ingredient == null || !mounted) return;
    await context.push<bool>(
      '/ingredients/${widget.id}/hierarchy',
      extra: IngredientHierarchyArguments(
        ingredientId: widget.id,
        ingredientName: ingredient.name,
        hierarchyData: state.hierarchy,
        loading: state.loadingHierarchy,
        isAdmin: isAdmin,
        onAdd: (input) => notifier.addHierarchyRelation(
          parentId: widget.id,
          childId: input.targetId,
          relationType: input.relationType,
          strength: input.strength,
          isAdmin: isAdmin,
        ),
        onUpdateStrength: (relationId, strength) =>
            notifier.updateHierarchyRelation(
          relationId,
          strength: strength,
          isAdmin: isAdmin,
        ),
        onDelete: notifier.deleteHierarchyRelation,
      ),
    );
  }
}

// ---- 基本信息卡 ----

class _BasicInfoCard extends StatelessWidget {
  final Ingredient ingredient;
  final AsyncValue<List<IngredientCategory>> categoriesAsync;
  final VoidCallback onEdit;

  const _BasicInfoCard({
    required this.ingredient,
    required this.categoriesAsync,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = categoriesAsync.valueOrNull;
    final matchedCategory = categories?.where(
      (item) => item.id == ingredient.categoryId,
    );
    final category =
        matchedCategory?.firstOrNull?.displayName ?? ingredient.category;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('基本信息',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: '编辑',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              ],
            ),
            const Divider(height: 8),
            if (category != null)
              _InfoRow(
                icon: Icons.folder_outlined,
                label: '分类',
                value: category,
              ),
            if (ingredient.makingRecipeName != null)
              _InfoRow(
                icon: Icons.soup_kitchen_outlined,
                label: '制作来源',
                value: '由「${ingredient.makingRecipeName}」制作',
              ),
            if (ingredient.aliases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tag_outlined,
                        size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final alias in ingredient.aliases)
                            Chip(
                              label: Text(alias),
                              labelStyle: theme.textTheme.bodySmall,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (ingredient.createdAt != null)
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: '创建时间',
                value: _fmtDateTime(ingredient.createdAt!),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Text('$label：',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ---- 最新价格卡 ----

class _LatestPriceCard extends StatelessWidget {
  final LatestPriceInfo? latest;
  final List<MerchantPrice> merchantPrices;
  final bool loadingLatest;
  final bool loadingMerchants;
  final String currency;

  const _LatestPriceCard({
    required this.latest,
    required this.merchantPrices,
    required this.loadingLatest,
    required this.loadingMerchants,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    color: theme.colorScheme.tertiary, size: 20),
                const SizedBox(width: 8),
                Text('最新价格',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 16),
            if (loadingLatest && latest == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (latest?.price == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('暂无价格数据',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              )
            else ...[
              Text(
                '${formatMoney(latest!.price!, currency)}'
                '${latest!.unit == null ? '' : ' / ${latest!.unit}'}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              if (latest!.date != null)
                Text(
                  _fmtDate(latest!.date!),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
            const SizedBox(height: 8),
            MerchantPriceList(
              prices: merchantPrices,
              loading: loadingMerchants,
              userCurrency: currency,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- 关联商品卡 ----

class _RelatedProductsCard extends StatelessWidget {
  final List<Product> products;
  final Map<int, LatestPriceInfo> productPrices;
  final bool loading;
  final String currency;
  final ValueChanged<int> onLoadPrice;
  final VoidCallback onAdd;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  const _RelatedProductsCard({
    required this.products,
    required this.productPrices,
    required this.loading,
    required this.currency,
    required this.onLoadPrice,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('关联商品',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (products.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${products.length}'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
            const Divider(height: 8),
            if (loading && products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 40, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 8),
                      Text('暂无关联商品',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              )
            else
              for (final p in products) ...[
                _RelatedProductRow(
                  product: p,
                  latest: productPrices[p.id],
                  currency: currency,
                  onTap: () => context.push('/products/${p.id}'),
                  onLoadPrice: () => onLoadPrice(p.id),
                  onEdit: () => onEdit(p),
                  onDelete: () => onDelete(p),
                ),
                const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }
}

class _RelatedProductRow extends StatefulWidget {
  final Product product;
  final LatestPriceInfo? latest;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onLoadPrice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RelatedProductRow({
    required this.product,
    required this.latest,
    required this.currency,
    required this.onTap,
    required this.onLoadPrice,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_RelatedProductRow> createState() => _RelatedProductRowState();
}

class _RelatedProductRowState extends State<_RelatedProductRow> {
  @override
  void initState() {
    super.initState();
    Future.microtask(widget.onLoadPrice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.product;
    final latest = widget.latest;
    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              radius: 18,
              child: Text(
                p.name.isNotEmpty ? p.name.characters.first : '?',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (p.brand != null)
                    Text(p.brand!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            if (latest != null && latest.price != null)
              Text(
                '${formatMoney(latest.price!, widget.currency)}'
                '${latest.unit == null ? '' : ' / ${latest.unit}'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: '编辑',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: '删除',
              visualDensity: VisualDensity.compact,
              color: theme.colorScheme.error,
              onPressed: widget.onDelete,
            ),
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ---- 价格记录卡 ----

class _PriceRecordsCard extends StatelessWidget {
  final List<PriceRecord> records;
  final bool loading;
  final bool hasMore;
  final List<Product> products;
  final String currency;
  final VoidCallback onLoadMore;
  final VoidCallback onAdd;
  final ValueChanged<PriceRecord> onEdit;
  final ValueChanged<PriceRecord> onDelete;

  const _PriceRecordsCard({
    required this.records,
    required this.loading,
    required this.hasMore,
    required this.products,
    required this.currency,
    required this.onLoadMore,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('价格记录',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (products.isNotEmpty)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加记录'),
                  ),
              ],
            ),
            const Divider(height: 8),
            if (loading && records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('暂无价格记录',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
              )
            else ...[
              for (final r in records)
                _RecordRow(
                  record: r,
                  currency: currency,
                  onEdit: () => onEdit(r),
                  onDelete: () => onDelete(r),
                ),
              if (hasMore)
                Center(
                  child: TextButton(
                    onPressed: loading ? null : onLoadMore,
                    child: Text(loading ? '加载中...' : '加载更多'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final PriceRecord record;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordRow({
    required this.record,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = record;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            foregroundColor: theme.colorScheme.onTertiaryContainer,
            radius: 18,
            child: const Icon(Icons.receipt_long, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${formatMoney(r.price, currency)} / ${_fmtQty(r.quantity)}'
                  '${r.unit.isEmpty ? '' : ' ${r.unit}'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.merchantName ?? '未知商家'} · ${_fmtDateTime(r.recordedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- 关联菜谱卡 ----

class _RelatedRecipesCard extends StatelessWidget {
  final List<IngredientRecipeRef> recipes;
  final bool loading;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const _RelatedRecipesCard({
    required this.recipes,
    required this.loading,
    required this.hasMore,
    required this.onLoadMore,
  });

  /// 一个菜谱里该食材的全部用量文本，对齐 Web formatUsages：
  /// 数值类（精确值或区间）加「/ N 份」，模糊量不加；多条用分号合并
  String _usageText(IngredientRecipeRef r) {
    final servings = r.servings > 0 ? r.servings : 1;
    return r.usages.map((u) {
      final text = u.display;
      final isNumeric = u.quantity > 0 || u.quantityRange != null;
      return isNumeric ? '$text / $servings 份' : text;
    }).join('；');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('相关菜谱',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (recipes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${recipes.length}+'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
            const Divider(height: 8),
            if (loading && recipes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (recipes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('暂无相关菜谱',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
              )
            else ...[
              for (final r in recipes) ...[
                InkWell(
                  onTap: () => context.push('/recipes/${r.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          radius: 18,
                          child: Text(
                            r.name.isNotEmpty ? r.name.characters.first : '?',
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              if (r.usages.isNotEmpty || r.category != null)
                                Text(
                                  [
                                    if (r.usages.isNotEmpty)
                                      '用量 ${_usageText(r)}',
                                    r.category ?? '',
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
              if (hasMore)
                Center(
                  child: TextButton(
                    onPressed: loading ? null : onLoadMore,
                    child: Text(loading ? '加载中...' : '加载更多'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---- 层级关系卡 ----

class _HierarchyCard extends StatelessWidget {
  final int currentId;
  final String currentName;
  final IngredientHierarchyData? data;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<HierarchyRelation> onEditStrength;
  final ValueChanged<HierarchyRelation> onDelete;

  const _HierarchyCard({
    required this.currentId,
    required this.currentName,
    required this.data,
    required this.loading,
    required this.onAdd,
    required this.onEditStrength,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hierarchy = data;
    final relations = [
      ...?hierarchy?.childRelations,
      ...?hierarchy?.parentRelations,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_outlined,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('层级关系',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
            const Divider(height: 8),
            if (loading && hierarchy == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (hierarchy == null || hierarchy.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('暂无层级关系',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
              )
            else ...[
              HierarchyGraph(
                ingredientId: currentId,
                ingredientName: currentName,
                hierarchyData: hierarchy,
              ),
              const SizedBox(height: 8),
              for (final r in relations) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.parentName} → ${r.childName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.typeLabel} · 强度 ${r.strength}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, size: 18),
                        tooltip: '调整强度',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onEditStrength(r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: '删除',
                        visualDensity: VisualDensity.compact,
                        color: theme.colorScheme.error,
                        onPressed: () => onDelete(r),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---- 工具函数 ----

String _fmtQty(double q) {
  if (q == q.truncateToDouble()) return q.toInt().toString();
  var s = q.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}

String _fmtDateTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
}

String _fmtDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('yyyy-MM-dd').format(dt.toLocal());
}

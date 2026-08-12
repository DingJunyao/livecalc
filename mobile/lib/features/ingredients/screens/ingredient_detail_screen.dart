import 'dart:async';
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
import '../../../shared/widgets/nutrition_card.dart';
import '../../../shared/widgets/price_record_form_sheet.dart';
import '../../merchants/providers/merchant_provider.dart';
import '../../prices/models/price_record.dart';
import '../../products/models/product.dart';
import '../../products/repositories/product_repository.dart';
import '../../recipes/widgets/cost_trend_chart.dart';
import '../models/ingredient.dart';
import '../models/ingredient_category.dart';
import '../providers/ingredient_provider.dart';
import '../repositories/ingredient_repository.dart';

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
    final ingredient = state.ingredient;

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
            _BasicInfoCard(
              ingredient: ingredient,
              categoriesAsync: ref.watch(ingredientCategoriesProvider),
              onEdit: () => _showEditBasicDialog(notifier, ingredient),
            ),
            const SizedBox(height: 16),
            _LatestPriceCard(
              latest: state.latestPrice,
              merchantPrices: state.merchantPrices,
              loadingLatest: state.loadingLatest,
              loadingMerchants: state.loadingMerchants,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CostTrendChart(
                  points: state.chartPoints,
                  loading: state.loadingChart,
                  onRangeChange: (days) => notifier.reloadChart(days),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _RelatedProductsCard(
              products: state.products,
              productPrices: state.productPrices,
              loading: state.loadingProducts,
              onLoadPrice: notifier.loadProductPrice,
              onAdd: () => _showAddProductDialog(notifier, ingredient),
              onEdit: (p) => _showEditProductDialog(notifier, ingredient, p),
              onDelete: (p) => _confirmDeleteProduct(notifier, p),
            ),
            const SizedBox(height: 16),
            _PriceRecordsCard(
              records: state.records,
              loading: state.loadingRecords,
              hasMore: state.recordsHasMore,
              products: state.products,
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
              nutrition: state.nutrition,
              loading: state.loadingNutrition,
              saving: state.savingNutrition,
              onSave: notifier.saveNutrition,
            ),
            const SizedBox(height: 16),
            EntityUnitsCard(
              units: state.units,
              unmappedUnits: state.unmappedUnits,
              densities: state.densities,
              loading: state.loadingUnits,
              onAddUnit: notifier.addUnit,
              onEditUnit: notifier.updateUnit,
              onDeleteUnit: (id) => _confirmDeleteUnit(notifier, id),
              onQuickAddUnmapped: notifier.quickAddUnmappedUnit,
              onAddDensity: notifier.addDensity,
              onDeleteDensity: (id) => _confirmDeleteDensity(notifier, id),
            ),
            const SizedBox(height: 16),
            _HierarchyCard(
              currentId: widget.id,
              data: state.hierarchy,
              loading: state.loadingHierarchy,
              onAdd: () => _showAddHierarchyDialog(notifier),
              onEditStrength: (relation) =>
                  _showEditHierarchyDialog(notifier, relation),
              onDelete: (relation) =>
                  _confirmDeleteHierarchy(notifier, relation),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 记录价格 ----
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
    final merchants = ref.read(merchantListProvider).items;
    final result = await showPriceRecordFormSheet(
      context,
      merchants: merchants,
      products: [
        for (final p in state.products) ProductOption(p.id, p.name),
      ],
    );
    if (result == null || result.productId == null || !mounted) return;
    try {
      await notifier.addRecord(
        productId: result.productId!,
        price: result.price,
        quantity: result.quantity,
        unit: result.unit,
        merchantId: result.merchantId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('价格已记录')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
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
    final result = await showPriceRecordFormSheet(
      context,
      merchants: merchants,
      products: [
        for (final p in state.products) ProductOption(p.id, p.name),
      ],
      fixedProductId: record.productId,
      initialPrice: record.price,
      initialQuantity: record.quantity,
      initialUnit: record.unit,
      initialMerchantId: record.merchantId,
    );
    if (result == null || !mounted) return;
    try {
      await notifier.updateRecord(
        record.id,
        price: result.price,
        quantity: result.quantity,
        unit: result.unit,
        merchantId: result.merchantId,
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
  Future<void> _showEditBasicDialog(
    IngredientDetailPageNotifier notifier,
    Ingredient ingredient,
  ) async {
    final categories =
        ref.read(ingredientCategoriesProvider).value ?? <IngredientCategory>[];
    if (!mounted) return;
    final nameController = TextEditingController(text: ingredient.name);
    final aliasController = TextEditingController(
      text: ingredient.aliases.join(', '),
    );
    int? categoryId = ingredient.categoryId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑基本信息'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '原料名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aliasController,
                  decoration: const InputDecoration(
                    labelText: '别名（逗号或空格分隔）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('未分类')),
                    for (final c in categories)
                      DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.displayName)),
                  ],
                  onChanged: (v) => setDialogState(() => categoryId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final aliases = aliasController.text
        .split(RegExp(r'[,，\s]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    try {
      await notifier.updateBasic(
        name: name,
        categoryId: categoryId,
        aliases: aliases,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('基本信息已保存')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    }
  }

  // ---- 关联商品添加/编辑/删除 ----
  Future<void> _showAddProductDialog(
    IngredientDetailPageNotifier notifier,
    Ingredient ingredient,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(
        ingredient: ingredient,
        title: '添加商品',
      ),
    );
    if (saved == true && mounted) {
      await notifier.refreshProducts();
    }
  }

  Future<void> _showEditProductDialog(
    IngredientDetailPageNotifier notifier,
    Ingredient ingredient,
    Product product,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductFormDialog(
        ingredient: ingredient,
        title: '编辑商品',
        product: product,
      ),
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
      await notifier.deleteProduct(product.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请重试')),
        );
      }
    }
  }

  Future<void> _confirmDeleteUnit(
    IngredientDetailPageNotifier notifier,
    int unitId,
  ) async {
    final ok = await _confirm('删除单位', '确定删除该自定义单位吗？');
    if (ok != true || !mounted) return;
    try {
      await notifier.deleteUnit(unitId);
    } catch (_) {
      _toast('删除失败，请重试');
    }
  }

  Future<void> _confirmDeleteDensity(
    IngredientDetailPageNotifier notifier,
    int densityId,
  ) async {
    final ok = await _confirm('删除密度', '确定删除该密度记录吗？');
    if (ok != true || !mounted) return;
    try {
      await notifier.deleteDensity(densityId);
    } catch (_) {
      _toast('删除失败，请重试');
    }
  }

  // ---- 层级关系 ----

  Future<void> _showAddHierarchyDialog(
    IngredientDetailPageNotifier notifier,
  ) async {
    final ingredient =
        ref.read(ingredientDetailPageProvider(widget.id)).ingredient;
    if (ingredient == null || !mounted) return;
    final result = await showDialog<_HierarchyFormResult>(
      context: context,
      builder: (_) => _HierarchyFormDialog(
        currentName: ingredient.name,
        excludeId: ingredient.id,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await notifier.addHierarchyRelation(
        parentId: widget.id,
        childId: result.targetId,
        relationType: result.relationType,
        strength: result.strength,
      );
      _toast('已添加关系');
    } catch (_) {
      _toast('添加失败，请重试');
    }
  }

  Future<void> _showEditHierarchyDialog(
    IngredientDetailPageNotifier notifier,
    HierarchyRelation relation,
  ) async {
    var strength = relation.strength;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('调整关系强度'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${relation.parentName} → ${relation.childName}'
                  '（${relation.typeLabel}）'),
              const SizedBox(height: 8),
              Text('强度：$strength'),
              Slider(
                value: strength.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '$strength',
                onChanged: (v) => setDialogState(() => strength = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await notifier.updateHierarchyRelation(relation.id, strength: strength);
      _toast('已更新');
    } catch (_) {
      _toast('更新失败，请重试');
    }
  }

  Future<void> _confirmDeleteHierarchy(
    IngredientDetailPageNotifier notifier,
    HierarchyRelation relation,
  ) async {
    final ok = await _confirm('删除关系', '确定删除该层级关系吗？');
    if (ok != true || !mounted) return;
    try {
      await notifier.deleteHierarchyRelation(relation.id);
      _toast('已删除');
    } catch (_) {
      _toast('删除失败，请重试');
    }
  }

  Future<bool?> _confirm(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            if (ingredient.category != null)
              _InfoRow(
                icon: Icons.folder_outlined,
                label: '分类',
                value: ingredient.category!,
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

  const _LatestPriceCard({
    required this.latest,
    required this.merchantPrices,
    required this.loadingLatest,
    required this.loadingMerchants,
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
                Icon(Icons.currency_yen,
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
                '¥${latest!.price!.toStringAsFixed(2)}'
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
  final ValueChanged<int> onLoadPrice;
  final VoidCallback onAdd;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;

  const _RelatedProductsCard({
    required this.products,
    required this.productPrices,
    required this.loading,
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
  final VoidCallback onTap;
  final VoidCallback onLoadPrice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RelatedProductRow({
    required this.product,
    required this.latest,
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
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
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
                '¥${latest.price!.toStringAsFixed(2)}'
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
  final VoidCallback onLoadMore;
  final VoidCallback onAdd;
  final ValueChanged<PriceRecord> onEdit;
  final ValueChanged<PriceRecord> onDelete;

  const _PriceRecordsCard({
    required this.records,
    required this.loading,
    required this.hasMore,
    required this.products,
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordRow({
    required this.record,
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
                  '¥${r.price.toStringAsFixed(2)} / ${_fmtQty(r.quantity)}'
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

// ---- 商品表单（添加/编辑，原料固定） ----

class _ProductFormDialog extends StatefulWidget {
  final Ingredient ingredient;
  final String title;
  final Product? product;

  const _ProductFormDialog({
    required this.ingredient,
    required this.title,
    this.product,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _aliasController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _aliasController =
        TextEditingController(text: (p?.aliases ?? const []).join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: !isEdit,
              decoration: const InputDecoration(
                labelText: '商品名称 *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.science_outlined, size: 16),
                label: Text('关联原料：${widget.ingredient.name}'),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: '品牌',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: '条码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: '别名（逗号或空格分隔）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('请输入商品名称');
      return;
    }
    setState(() => _saving = true);
    final aliases = _aliasController.text
        .split(RegExp(r'[,，\s]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final repo = ProductRepository();
    try {
      if (widget.product == null) {
        await repo.createProduct(
          name: name,
          ingredientId: widget.ingredient.id,
          brand: _brandController.text.trim(),
          barcode: _barcodeController.text.trim(),
          aliases: aliases,
        );
      } else {
        await repo.updateProduct(
          widget.product!.id,
          name: name,
          brand: _brandController.text.trim(),
          barcode: _barcodeController.text.trim(),
          aliases: aliases,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('保存失败，请重试');
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
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
  final IngredientHierarchyData? data;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<HierarchyRelation> onEditStrength;
  final ValueChanged<HierarchyRelation> onDelete;

  const _HierarchyCard({
    required this.currentId,
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
            else
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
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline),
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
        ),
      ),
    );
  }
}

class _HierarchyFormResult {
  final int targetId;
  final String relationType;
  final int strength;
  const _HierarchyFormResult({
    required this.targetId,
    required this.relationType,
    required this.strength,
  });
}

class _HierarchyFormDialog extends ConsumerStatefulWidget {
  final String currentName;
  final int excludeId;
  const _HierarchyFormDialog({
    required this.currentName,
    required this.excludeId,
  });

  @override
  ConsumerState<_HierarchyFormDialog> createState() =>
      _HierarchyFormDialogState();
}

class _HierarchyFormDialogState extends ConsumerState<_HierarchyFormDialog> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Ingredient> _options = const [];
  bool _searching = false;
  Ingredient? _selected;
  String _relationType = 'contains';
  int _strength = 50;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = _searchController.text.trim();
      if (q.isEmpty) {
        setState(() {
          _options = const [];
          _searching = false;
        });
        return;
      }
      setState(() => _searching = true);
      try {
        final result =
            await IngredientRepository().search(search: q, limit: 20);
        if (mounted) {
          setState(() {
            _options =
                result.items.where((i) => i.id != widget.excludeId).toList();
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _save() {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择关联原料')),
      );
      return;
    }
    Navigator.of(context).pop(_HierarchyFormResult(
      targetId: _selected!.id,
      relationType: _relationType,
      strength: _strength,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('添加层级关系'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '搜索关联原料 *',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.check_circle, size: 16),
                    label: Text(_selected!.name),
                    onDeleted: () => setState(() => _selected = null),
                  ),
                ),
              ),
            if (_options.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _options.length,
                  itemBuilder: (ctx, i) {
                    final ing = _options[i];
                    return ListTile(
                      dense: true,
                      title: Text(ing.name),
                      subtitle:
                          ing.category == null ? null : Text(ing.category!),
                      onTap: () {
                        setState(() {
                          _selected = ing;
                          _searchController.text = ing.name;
                          _options = const [];
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _relationType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '关系类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'contains', child: Text('包含')),
                DropdownMenuItem(value: 'substitutable', child: Text('可替代')),
                DropdownMenuItem(value: 'fallback', child: Text('回退')),
              ],
              onChanged: (v) => setState(() => _relationType = v ?? 'contains'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('强度：$_strength', style: theme.textTheme.bodyMedium),
                Expanded(
                  child: Slider(
                    value: _strength.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '$_strength',
                    onChanged: (v) => setState(() => _strength = v.round()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
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

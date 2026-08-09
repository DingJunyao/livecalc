import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/models/merchant_price.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/entity_units_card.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/merchant_price_list.dart';
import '../../../shared/widgets/nutrition_card.dart';
import '../../../shared/widgets/price_record_form_sheet.dart';
import '../../ingredients/models/ingredient.dart';
import '../../ingredients/repositories/ingredient_repository.dart';
import '../../merchants/providers/merchant_provider.dart';
import '../../prices/models/price_record.dart';
import '../../recipes/widgets/cost_trend_chart.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../repositories/product_repository.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const ProductDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(productDetailPageProvider(widget.id).notifier)
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
    final state = ref.watch(productDetailPageProvider(widget.id));
    final product = state.product;

    if (state.error != null && product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('商品详情')),
        body: ErrorDisplay(
          message: state.error!,
          onRetry: () =>
              ref.read(productDetailPageProvider(widget.id).notifier).load(),
        ),
      );
    }
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('商品详情')),
        body: const LoadingIndicator(message: '加载中...'),
      );
    }

    final notifier = ref.read(productDetailPageProvider(widget.id).notifier);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(product.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('商品',
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
            onPressed: () => _openAddRecord(notifier),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                _showEditBasicDialog(notifier, product);
              } else if (v == 'delete') {
                _confirmDelete(notifier, product);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑基本信息')),
              PopupMenuItem(value: 'delete', child: Text('删除商品')),
            ],
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
            _ProductBasicInfoCard(
              product: product,
              onEdit: () => _showEditBasicDialog(notifier, product),
              onIngredientTap: product.ingredientId == null
                  ? null
                  : () => context.push('/ingredients/${product.ingredientId}'),
            ),
            const SizedBox(height: 16),
            _ProductLatestPriceCard(
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
            _ProductPriceRecordsCard(
              records: state.records,
              loading: state.loadingRecords,
              hasMore: state.recordsHasMore,
              onLoadMore: notifier.loadMoreRecords,
              onAdd: () => _openAddRecord(notifier),
              onEdit: (r) => _openEditRecord(notifier, r),
              onDelete: (r) => _confirmDeleteRecord(notifier, r),
            ),
            const SizedBox(height: 16),
            NutritionCard(
              nutrition: state.nutrition,
              loading: state.loadingNutrition,
              saving: state.savingNutrition,
              allowClear: true,
              onSave: notifier.saveNutrition,
              onClear: notifier.clearNutrition,
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
              onDeleteDensity: (id) =>
                  _confirmDeleteDensity(notifier, id),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 记录价格 ----
  Future<void> _openAddRecord(ProductDetailPageNotifier notifier) async {
    if (!mounted) return;
    final merchants = ref.read(merchantListProvider).items;
    final result = await showPriceRecordFormSheet(
      context,
      merchants: merchants,
      fixedProductId: widget.id,
      fixedProductName:
          ref.read(productDetailPageProvider(widget.id)).product?.name,
    );
    if (result == null || !mounted) return;
    try {
      await notifier.addRecord(
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
    ProductDetailPageNotifier notifier,
    PriceRecord record,
  ) async {
    if (!mounted) return;
    final merchants = ref.read(merchantListProvider).items;
    final result = await showPriceRecordFormSheet(
      context,
      merchants: merchants,
      fixedProductId: widget.id,
      fixedProductName:
          ref.read(productDetailPageProvider(widget.id)).product?.name,
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
    ProductDetailPageNotifier notifier,
    PriceRecord record,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定删除这条价格记录吗？'),
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

  // ---- 编辑基本信息 ----
  Future<void> _showEditBasicDialog(
    ProductDetailPageNotifier notifier,
    Product product,
  ) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (_) => _ProductEditDialog(product: product),
    );
    if (result != null && mounted) {
      await notifier.updateBasic(
        name: result.name,
        ingredientId: result.ingredientId,
        brand: result.brand,
        barcode: result.barcode,
        aliases: result.aliases,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('基本信息已保存')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    ProductDetailPageNotifier notifier,
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
      await ProductRepository().deleteProduct(widget.id);
      if (mounted) context.go('/products');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请重试')),
        );
      }
    }
  }

  Future<void> _confirmDeleteUnit(
    ProductDetailPageNotifier notifier,
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
    ProductDetailPageNotifier notifier,
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

class _ProductBasicInfoCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback? onIngredientTap;

  const _ProductBasicInfoCard({
    required this.product,
    required this.onEdit,
    this.onIngredientTap,
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
            if (product.brand != null && product.brand!.isNotEmpty)
              _ProductInfoRow(
                icon: Icons.tag_outlined,
                label: '品牌',
                value: product.brand!,
              ),
            if (product.barcode != null && product.barcode!.isNotEmpty)
              _ProductInfoRow(
                icon: Icons.barcode_reader,
                label: '条码',
                value: product.barcode!,
              ),
            if (product.ingredientName != null)
              InkWell(
                onTap: onIngredientTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined,
                          size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 12),
                      Text('关联原料：',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          product.ingredientName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward,
                          size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            if (product.aliases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.file_copy_outlined,
                        size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final alias in product.aliases)
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
            if (product.tags.isNotEmpty)
              _ProductInfoRow(
                icon: Icons.sell_outlined,
                label: '标签',
                value: product.tags.join('、'),
              ),
            if (product.createdAt != null)
              _ProductInfoRow(
                icon: Icons.calendar_today_outlined,
                label: '创建时间',
                value: _fmtDateTime(product.createdAt!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProductInfoRow({
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

class _ProductLatestPriceCard extends StatelessWidget {
  final LatestPriceInfo? latest;
  final List<MerchantPrice> merchantPrices;
  final bool loadingLatest;
  final bool loadingMerchants;

  const _ProductLatestPriceCard({
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
                '${latest!.unit == null ? '' : '/${latest!.unit}'}',
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

// ---- 价格记录卡 ----

class _ProductPriceRecordsCard extends StatelessWidget {
  final List<PriceRecord> records;
  final bool loading;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final VoidCallback onAdd;
  final ValueChanged<PriceRecord> onEdit;
  final ValueChanged<PriceRecord> onDelete;

  const _ProductPriceRecordsCard({
    required this.records,
    required this.loading,
    required this.hasMore,
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
                Icon(Icons.history,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('价格记录',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
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
                _ProductRecordRow(
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

class _ProductRecordRow extends StatelessWidget {
  final PriceRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductRecordRow({
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
                Text(
                  '¥${r.price.toStringAsFixed(2)} / ${_fmtQty(r.quantity)}${r.unit}',
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

// ---- 商品编辑对话框 ----

class _ProductEditDialog extends ConsumerStatefulWidget {
  final Product product;
  const _ProductEditDialog({required this.product});

  @override
  ConsumerState<_ProductEditDialog> createState() =>
      _ProductEditDialogState();
}

class _ProductEditDialogState extends ConsumerState<_ProductEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _aliasController;
  late final TextEditingController _tagController;
  late final TextEditingController _ingredientSearchController;
  Timer? _debounce;
  List<Ingredient> _ingredientOptions = const [];
  bool _searching = false;
  Ingredient? _selectedIngredient;
  List<String> _tags = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _brandController = TextEditingController(text: p.brand ?? '');
    _barcodeController = TextEditingController(text: p.barcode ?? '');
    _aliasController =
        TextEditingController(text: p.aliases.join(', '));
    _tagController = TextEditingController();
    _tags = List.of(p.tags);
    _ingredientSearchController = TextEditingController(
      text: p.ingredientName ?? '',
    );
    _selectedIngredient = p.ingredientId == null
        ? null
        : Ingredient(
            id: p.ingredientId!,
            name: p.ingredientName ?? '',
          );
    _ingredientSearchController.addListener(_onIngredientSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _aliasController.dispose();
    _tagController.dispose();
    _ingredientSearchController.dispose();
    super.dispose();
  }

  void _onIngredientSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = _ingredientSearchController.text.trim();
      if (q.isEmpty) {
        setState(() {
          _ingredientOptions = const [];
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
            _ingredientOptions = result.items;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('请输入商品名称');
      return;
    }
    if (_selectedIngredient == null) {
      _toast('请选择关联的原料');
      return;
    }
    setState(() => _saving = true);
    final aliases = _aliasController.text
        .split(RegExp(r'[,，\s]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    try {
      final updated = await ProductRepository().updateProduct(
        widget.product.id,
        name: name,
        ingredientId: _selectedIngredient!.id,
        brand: _brandController.text.trim(),
        barcode: _barcodeController.text.trim(),
        aliases: aliases,
        tags: _tags,
      );
      if (mounted) Navigator.of(context).pop(updated);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑基本信息'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '商品名称 *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ingredientSearchController,
              decoration: InputDecoration(
                labelText: '搜索并选择关联原料 *',
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
            if (_selectedIngredient != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.check_circle, size: 16),
                    label: Text(_selectedIngredient!.name),
                    onDeleted: () =>
                        setState(() => _selectedIngredient = null),
                  ),
                ),
              ),
            if (_ingredientOptions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _ingredientOptions.length,
                  itemBuilder: (ctx, i) {
                    final ing = _ingredientOptions[i];
                    return ListTile(
                      dense: true,
                      title: Text(ing.name),
                      subtitle:
                          ing.category == null ? null : Text(ing.category!),
                      onTap: () {
                        setState(() {
                          _selectedIngredient = ing;
                          _ingredientSearchController.text = ing.name;
                          _ingredientOptions = const [];
                        });
                      },
                    );
                  },
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    onSubmitted: (_) => _addTag(),
                    decoration: const InputDecoration(
                      labelText: '添加标签',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _tags)
                        Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () =>
                              setState(() => _tags = _tags.where((x) => x != t).toList()),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags = [..._tags, tag];
      _tagController.clear();
    });
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

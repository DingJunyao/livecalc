import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/price_record_form_sheet.dart';
import '../../../shared/widgets/sparkline.dart';
import '../../ingredients/models/ingredient.dart';
import '../../ingredients/providers/ingredient_provider.dart';
import '../../ingredients/repositories/ingredient_repository.dart';
import '../../merchants/providers/merchant_provider.dart';
import '../../prices/repositories/price_repository.dart';
import '../repositories/product_repository.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';

const _productConditions = <(String, String)>[
  ('no_price', '没有维护过价格'),
  ('single_price', '仅有一条价格记录'),
  ('single_merchant', '仅有一家商家有其价格'),
];

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() =>
      _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<String> _brandOptions = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productListProvider.notifier).load();
      _loadBrands();
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

  Future<void> _loadBrands() async {
    try {
      final result = await ProductRepository().search(
        sortBy: 'created_at',
        limit: 1000,
      );
      final brands = result.items
          .map((p) => p.brand)
          .whereType<String>()
          .where((b) => b.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (mounted) setState(() => _brandOptions = brands);
    } catch (_) {
      // 品牌选项加载失败不阻塞列表
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(productListProvider.notifier);
      if (notifier.canLoadMore) {
        notifier.load(loadMore: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(productListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('商品'),
        leading: const AppBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: state.loading
                ? null
                : () => ref.read(productListProvider.notifier).load(),
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
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ProductListState state) {
    final notifier = ref.read(productListProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索商品...',
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

  Widget _buildBody(ThemeData theme, ProductListState state) {
    if (state.loading && state.items.isEmpty) {
      return const LoadingIndicator(message: '加载中...');
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorDisplay(
        message: state.error!,
        onRetry: () => ref.read(productListProvider.notifier).load(),
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2,
        title: '暂无商品',
        subtitle: '点击右下角按钮添加第一个商品',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(productListProvider.notifier).load(),
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
                            .read(productListProvider.notifier)
                            .load(loadMore: true),
                        child: const Text('加载更多'),
                      ),
              ),
            );
          }
          return _ProductCard(
            item: state.items[i],
            latest: state.latestPrices[state.items[i].id],
            sparkline: state.sparklines[state.items[i].id],
            onTap: () => context.push('/products/${state.items[i].id}'),
            onQuickPrice: () => _quickPrice(state.items[i]),
          );
        },
      ),
    );
  }

  Future<void> _quickPrice(Product item) async {
    if (!mounted) return;
    final merchants = ref.read(merchantListProvider).items;
    final formResult = await showPriceRecordFormSheet(
      context,
      merchants: merchants,
      fixedProductId: item.id,
      fixedProductName: item.name,
    );
    if (formResult == null || !mounted) return;
    try {
      await PriceRepository().createRecord(
        productId: item.id,
        price: formResult.price,
        quantity: formResult.quantity,
        unit: formResult.unit,
        merchantId: formResult.merchantId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('价格已记录')),
        );
      }
      ref.read(productListProvider.notifier).load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记录失败，请重试')),
        );
      }
    }
  }

  void _showFilterSheet(ThemeData theme) {
    final state = ref.read(productListProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductFilterSheet(
        initialIngredientId: state.filterIngredientId,
        initialCategoryIds: state.filterCategoryIds,
        initialBrand: state.filterBrand,
        initialConditions: state.conditions,
        brandOptions: _brandOptions,
        onApply: (ingredientId, categoryIds, brand, conditions) {
          ref.read(productListProvider.notifier).applyFilters(
                ingredientId: ingredientId,
                categoryIds: categoryIds,
                brand: brand,
                conditions: conditions,
              );
        },
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddProductDialog(),
    );
    if (added == true && mounted) {
      ref.read(productListProvider.notifier).load();
    }
  }
}

class _ProductCard extends StatelessWidget {
  final Product item;
  final LatestPriceInfo? latest;
  final List<double>? sparkline;
  final VoidCallback onTap;
  final VoidCallback onQuickPrice;

  const _ProductCard({
    required this.item,
    required this.latest,
    required this.sparkline,
    required this.onTap,
    required this.onQuickPrice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
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
                        Flexible(
                          child: Text(
                            item.brand ?? '无品牌',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        if (item.ingredientName != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              item.ingredientName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                        if (price != null) ...[
                          const Spacer(),
                          Text(
                            '¥${price.toStringAsFixed(2)}'
                            '${unit == null ? '' : '/$unit'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (sparkline != null && sparkline!.length >= 2) ...[
                Sparkline(
                  data: sparkline!,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(Icons.add_chart),
                tooltip: '记录价格',
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

// ---- 筛选 ----

class _ProductFilterSheet extends ConsumerStatefulWidget {
  final int? initialIngredientId;
  final List<int> initialCategoryIds;
  final String? initialBrand;
  final List<String> initialConditions;
  final List<String> brandOptions;
  final void Function(int?, List<int>, String?, List<String>) onApply;

  const _ProductFilterSheet({
    required this.initialIngredientId,
    required this.initialCategoryIds,
    required this.initialBrand,
    required this.initialConditions,
    required this.brandOptions,
    required this.onApply,
  });

  @override
  ConsumerState<_ProductFilterSheet> createState() =>
      _ProductFilterSheetState();
}

class _ProductFilterSheetState
    extends ConsumerState<_ProductFilterSheet> {
  late int? _ingredientId;
  late Set<int> _categoryIds;
  late String? _brand;
  late Set<String> _conditions;

  @override
  void initState() {
    super.initState();
    _ingredientId = widget.initialIngredientId;
    _categoryIds = widget.initialCategoryIds.toSet();
    _brand = widget.initialBrand;
    _conditions = widget.initialConditions.toSet();
  }

  bool get _hasActive =>
      _ingredientId != null ||
      _categoryIds.isNotEmpty ||
      _brand != null ||
      _conditions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingredients =
        ref.watch(ingredientOptionsProvider).value ?? const <Ingredient>[];
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
                Text('筛选条件',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_hasActive)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _ingredientId = null;
                      _categoryIds.clear();
                      _brand = null;
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
                  Text('关联原料', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: _ingredientId,
                    isExpanded: true,
                    decoration: _fieldDecoration(),
                    hint: const Text('全部原料'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('全部原料')),
                      for (final i in ingredients)
                        DropdownMenuItem<int?>(
                            value: i.id, child: Text(i.name)),
                    ],
                    onChanged: (v) => setState(() => _ingredientId = v),
                  ),
                  const SizedBox(height: 20),
                  Text('原料分类', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  if (categories.isEmpty)
                    Text('暂无分类', style: theme.textTheme.bodySmall)
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in categories)
                          FilterChip(
                            label: Text(c.displayName),
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
                  Text('品牌', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _brand,
                    isExpanded: true,
                    decoration: _fieldDecoration(),
                    hint: const Text('全部品牌'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('全部品牌')),
                      for (final b in widget.brandOptions)
                        DropdownMenuItem<String?>(value: b, child: Text(b)),
                    ],
                    onChanged: (v) => setState(() => _brand = v),
                  ),
                  const SizedBox(height: 20),
                  Text('特殊条件', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (value, label) in _productConditions)
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
                    _ingredientId,
                    _categoryIds.toList()..sort(),
                    _brand,
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

  InputDecoration _fieldDecoration() => InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}

// ---- 添加商品 ----

class _AddProductDialog extends ConsumerStatefulWidget {
  const _AddProductDialog();

  @override
  ConsumerState<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<_AddProductDialog> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _aliasController = TextEditingController();
  final _ingredientSearchController = TextEditingController();
  Timer? _debounce;
  List<Ingredient> _ingredientOptions = const [];
  bool _searching = false;
  Ingredient? _selectedIngredient;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ingredientSearchController.addListener(_onIngredientSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _aliasController.dispose();
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
    try {
      final aliases = _aliasController.text
          .split(RegExp(r'[,，\s]+'))
          .where((s) => s.isNotEmpty)
          .toList();
      await ref.read(productListProvider.notifier).addProduct(
            name: name,
            ingredientId: _selectedIngredient!.id,
            brand: _brandController.text.trim(),
            barcode: _barcodeController.text.trim(),
            aliases: aliases,
          );
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加商品'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
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
                      subtitle: ing.category == null
                          ? null
                          : Text(ing.category!),
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
}

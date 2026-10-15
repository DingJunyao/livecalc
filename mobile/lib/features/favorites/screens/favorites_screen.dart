import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/repositories/favorites_repository.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/widgets/directional_icons.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/sparkline.dart';
import '../../ingredients/models/ingredient.dart';
import '../../ingredients/repositories/ingredient_repository.dart';
import '../../merchants/models/merchant.dart';
import '../../merchants/repositories/merchant_repository.dart';
import '../../products/models/product.dart';
import '../../products/repositories/product_repository.dart';
import '../../recipes/models/recipe_summary.dart';
import '../../recipes/repositories/recipe_repository.dart';

/// 我的收藏：原料 / 商品 / 菜谱 / 商家（四类聚合）。
///
/// 数据取自各列表端点（favorites_only），与对应列表页展示同样的信息
/// （原料/商品：最新价与迷你图；菜谱：成本与热量；商家：地址与营业状态）。
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _loading = true;
  String? _error;

  List<Ingredient> _ingredients = const [];
  List<Product> _products = const [];
  List<RecipeSummary> _recipes = const [];
  List<Merchant> _merchants = const [];

  final Map<int, LatestPriceInfo> _ingredientPrices = {};
  final Map<int, List<double>> _ingredientSparklines = {};
  final Map<int, LatestPriceInfo> _productPrices = {};
  final Map<int, List<double>> _productSparklines = {};

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
      final ingredientRepo = IngredientRepository();
      final productRepo = ProductRepository();
      final recipeRepo = RecipeRepository();
      final merchantRepo = MerchantRepository();

      final ingredients = await ingredientRepo.search(
        favoritesOnly: true,
        favoritesFirst: true,
        limit: 100,
      );
      final products = await productRepo.search(
        favoritesOnly: true,
        favoritesFirst: true,
        limit: 100,
      );
      final recipes = await recipeRepo.getRecipes(
        favoritesOnly: true,
        favoritesFirst: true,
        pageSize: 100,
      );
      final merchants = await merchantRepo.getFavorites();

      // 富化（与对应列表页同口径）；失败不阻断展示
      final ingredientIds = ingredients.items.map((e) => e.id).toList();
      final productIds = products.items.map((e) => e.id).toList();
      final recipeIds = recipes.items.map((e) => e.id).toList();

      final ingredientPrices = ingredientIds.isEmpty
          ? <int, LatestPriceInfo>{}
          : await ingredientRepo.getLatestPrices(ingredientIds);
      final ingredientSparklines = ingredientIds.isEmpty
          ? <int, List<double>>{}
          : await ingredientRepo.getSparklines(ingredientIds);
      final productSparklines = productIds.isEmpty
          ? <int, List<double>>{}
          : await productRepo.getSparklines(productIds);
      final productPrices = <int, LatestPriceInfo>{};
      for (final id in productIds) {
        try {
          productPrices[id] = await productRepo.getLatestPrice(id);
        } on Exception {
          // 单个商品取价失败忽略
        }
      }
      var recipeItems = recipes.items;
      if (recipeIds.isNotEmpty) {
        try {
          final costs = await recipeRepo.getRecipesBatchCost(recipeIds);
          recipeItems = recipeItems
              .map((r) => costs.containsKey(r.id)
                  ? r.copyWith(
                      estimatedCost: costs[r.id]!.estimatedCost,
                      calories: costs[r.id]!.calories,
                    )
                  : r)
              .toList();
        } on Exception {
          // 成本加载失败仅缺少价格/热量
        }
      }

      if (!mounted) return;
      setState(() {
        _ingredients = ingredients.items;
        _products = products.items;
        _recipes = recipeItems;
        _merchants = merchants;
        _ingredientPrices
          ..clear()
          ..addAll(ingredientPrices);
        _ingredientSparklines
          ..clear()
          ..addAll(ingredientSparklines);
        _productPrices
          ..clear()
          ..addAll(productPrices);
        _productSparklines
          ..clear()
          ..addAll(productSparklines);
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _unfavorite(String type, int id) async {
    final l10n = AppLocalizations.of(context);
    try {
      await FavoritesRepository().remove(type, id);
      if (!mounted) return;
      setState(() {
        if (type == 'ingredient') {
          _ingredients = _ingredients.where((e) => e.id != id).toList();
        } else if (type == 'product') {
          _products = _products.where((e) => e.id != id).toList();
        } else if (type == 'recipe') {
          _recipes = _recipes.where((e) => e.id != id).toList();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.favoritesRemoved)),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.favoritesRemoveFailed)),
      );
    }
  }

  Future<void> _unfavoriteMerchant(int id) async {
    final l10n = AppLocalizations.of(context);
    try {
      await MerchantRepository().removeFavorite(id);
      if (!mounted) return;
      setState(() {
        _merchants = _merchants.where((e) => e.id != id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.favoritesRemoved)),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.favoritesRemoveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navFavorites),
          leading: const AppBackButton(),
          actions: [
            const CalcContextMenuButton(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.journeyRefresh,
              onPressed: _loading ? null : _load,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.favoritesTabIngredients),
              Tab(text: l10n.favoritesTabProducts),
              Tab(text: l10n.favoritesTabRecipes),
              Tab(text: l10n.favoritesTabMerchants),
            ],
          ),
        ),
        body: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return ErrorDisplay(message: _error!, onRetry: _load);
    }
    return TabBarView(
      children: [
        _buildIngredientList(l10n),
        _buildProductList(l10n),
        _buildRecipeList(l10n),
        _buildMerchantList(l10n),
      ],
    );
  }

  Widget _listFrame(AppLocalizations l10n, List<Widget> children) {
    if (children.isEmpty) {
      return EmptyState(
        icon: Icons.favorite_outline,
        title: l10n.favoritesEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: children,
      ),
    );
  }

  Widget _buildIngredientList(AppLocalizations l10n) {
    return _listFrame(
      l10n,
      [
        for (final item in _ingredients)
          _FavoriteTile(
            leading: _InitialAvatar(
              name: item.name,
              background: Theme.of(context).colorScheme.secondaryContainer,
            ),
            title: item.name,
            subtitleWidget: _priceLine(
              l10n,
              price: _ingredientPrices[item.id]?.price ?? item.latestPrice,
              unit: _ingredientPrices[item.id]?.unit ?? item.unit,
              category: item.category,
            ),
            sparkline: _ingredientSparklines[item.id],
            sparklineColor: Theme.of(context).colorScheme.secondary,
            onTap: () => context.push('/ingredients/${item.id}'),
            onToggleFavorite: () => _unfavorite('ingredient', item.id),
          ),
      ],
    );
  }

  Widget _buildProductList(AppLocalizations l10n) {
    return _listFrame(
      l10n,
      [
        for (final item in _products)
          _FavoriteTile(
            leading: _InitialAvatar(
              name: item.name,
              background: Theme.of(context).colorScheme.primaryContainer,
            ),
            title: item.name,
            subtitleWidget: _priceLine(
              l10n,
              price: _productPrices[item.id]?.price ?? item.latestPrice,
              unit: _productPrices[item.id]?.unit ?? item.unit,
              category: item.brand ?? item.ingredientName,
            ),
            sparkline: _productSparklines[item.id],
            sparklineColor: Theme.of(context).colorScheme.primary,
            onTap: () => context.push('/products/${item.id}'),
            onToggleFavorite: () => _unfavorite('product', item.id),
          ),
      ],
    );
  }

  Widget _buildRecipeList(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return _listFrame(
      l10n,
      [
        for (final item in _recipes)
          _FavoriteTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: item.imageUrl != null
                    ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        child: Icon(Icons.restaurant,
                            size: 20, color: theme.colorScheme.primary),
                      ),
              ),
            ),
            title: item.name,
            subtitleWidget: _recipeCostLine(theme, l10n, item),
            onTap: () => context.push('/recipes/${item.id}'),
            onToggleFavorite: () => _unfavorite('recipe', item.id),
          ),
      ],
    );
  }

  Widget _buildMerchantList(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return _listFrame(
      l10n,
      [
        for (final item in _merchants)
          _FavoriteTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.tertiaryContainer,
              foregroundColor: theme.colorScheme.onTertiaryContainer,
              child: const Icon(Icons.store, size: 20),
            ),
            title: item.name,
            titleBadge: item.isOpen
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.merchantClosed,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600)),
                  ),
            subtitleWidget: Text(
              item.address ?? l10n.merchantNoAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            onTap: () => context.push('/merchants/${item.id}'),
            onToggleFavorite: () => _unfavoriteMerchant(item.id),
          ),
      ],
    );
  }

  Widget _priceLine(
    AppLocalizations l10n, {
    double? price,
    String? unit,
    String? category,
  }) {
    final theme = Theme.of(context);
    final userCurrency = ref.read(displayCurrencyProvider);
    return Row(
      children: [
        if (category != null && category.isNotEmpty) ...[
          Flexible(
            child: Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (price != null)
          Text(
            '${formatMoney(price, userCurrency)}'
            '${unit == null ? '' : ' / $unit'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _recipeCostLine(
    ThemeData theme,
    AppLocalizations l10n,
    RecipeSummary item,
  ) {
    final userCurrency = ref.read(displayCurrencyProvider);
    final servings = item.servings > 0 ? item.servings : 1;
    final parts = <String>[];
    if (item.estimatedCost != null) {
      parts.add(l10n.recipeCostPerServings(
        formatMoney(item.estimatedCost!, userCurrency),
        formatNumber(servings),
      ));
    }
    if (item.calories != null) {
      parts.add(l10n.recipeCaloriesPerServing(
        formatNumber((item.calories! / servings).round()),
      ));
    }
    if (parts.isEmpty) {
      return Text(
        l10n.recipeServingsCount(formatNumber(servings)),
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.outline),
      );
    }
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium
          ?.copyWith(color: theme.colorScheme.primary),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final Color background;

  const _InitialAvatar({required this.name, required this.background});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: background,
      child: Text(
        name.isNotEmpty ? name.characters.first : '?',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 通用收藏条目：与各列表页条目同构（头像/缩略图 + 名称 + 副信息 + 迷你图 + 心形）。
class _FavoriteTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget subtitleWidget;
  final List<double>? sparkline;
  final Color? sparklineColor;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  /// 标题行末尾的徽标（如商家的「已关闭」），可选。
  final Widget? titleBadge;

  const _FavoriteTile({
    required this.leading,
    required this.title,
    required this.subtitleWidget,
    required this.onTap,
    required this.onToggleFavorite,
    this.sparkline,
    this.sparklineColor,
    this.titleBadge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (titleBadge != null) ...[
                          const SizedBox(width: 6),
                          titleBadge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    subtitleWidget,
                  ],
                ),
              ),
              if (sparkline != null && sparkline!.length >= 2) ...[
                Sparkline(
                  data: sparkline!,
                  color: sparklineColor ??
                      Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: theme.colorScheme.error,
                ),
                tooltip: l10n.favoritesRemove,
                visualDensity: VisualDensity.compact,
                onPressed: onToggleFavorite,
              ),
              Icon(DirectionalIcons.forwardChevron(context),
                  color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

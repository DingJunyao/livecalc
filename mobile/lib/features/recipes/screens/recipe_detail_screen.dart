import 'package:flutter/material.dart';
import '../../../shared/providers/calc_context_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../models/recipe_detail.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../repositories/recipe_repository.dart';
import '../utils/nutrition_labels.dart';
import '../widgets/cost_trend_chart.dart';
import 'recipe_form_screen.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/pending_change_banner.dart';
import '../../../shared/utils/currency_fmt.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const RecipeDetailScreen({super.key, required this.id});
  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _showAllNutrients = false;
  int _selectedImageIndex = 0;
  final RecipeRepository _repository = RecipeRepository();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(recipeDetailPageProvider(widget.id).notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(recipeDetailPageProvider(widget.id));
    final detail = state.detail?.mergedWithPending();

    if (state.error != null && detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.recipeDetailTitle)),
        body: ErrorDisplay(
          message: state.error!,
          onRetry: () =>
              ref.read(recipeDetailPageProvider(widget.id).notifier).load(),
        ),
      );
    }
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.recipeDetailTitle)),
        body: LoadingIndicator(message: l10n.commonLoading),
      );
    }

    final ratio = state.displayServings / detail.servings;
    final imageUrls = detail.imageUrls;
    final hasImages = imageUrls.isNotEmpty;
    final isAdmin = ref.read(authProvider).user?.isAdmin == true;
    final appBarActions = [
      IconButton(
        icon: const Icon(Icons.analytics_outlined),
        tooltip: l10n.recipeAnalysisTitle,
        onPressed: () => context.push('/recipes/${widget.id}/analysis'),
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'publish') _confirmPublish();
          if (value == 'delete') _confirmDelete();
        },
        itemBuilder: (context) => [
          if (!detail.isPublic)
            PopupMenuItem(
              value: 'publish',
              child: ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text(l10n.recipePublish),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (isAdmin || !detail.isPublic)
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.recipeDelete),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (hasImages)
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              title: Text(detail.name),
              actions: appBarActions,
              flexibleSpace: FlexibleSpaceBar(
                background: GestureDetector(
                  onTap: () =>
                      _openLightbox(context, imageUrls, _selectedImageIndex),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(imageUrls[_selectedImageIndex],
                          fit: BoxFit.cover),
                      if (imageUrls.length > 1)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_outlined,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${imageUrls.length}',
                                  style: theme.textTheme.labelMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverAppBar(
              pinned: true,
              title: Text(detail.name),
              actions: appBarActions,
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrls.length > 1) ...[
                    _buildImageGallery(theme, imageUrls, _selectedImageIndex),
                    const SizedBox(height: 16),
                  ],
                  if (detail.pendingProposals.isNotEmpty) ...[
                    PendingChangeBanner(
                      modifications: _pendingModificationLabels(detail, l10n),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildHeader(theme, detail),
                  const SizedBox(height: 16),
                  _buildCostCard(theme, state, ratio),
                  const SizedBox(height: 16),
                  _buildIngredientsCard(theme, detail, state, ratio),
                  const SizedBox(height: 16),
                  _buildStepsCard(theme, detail),
                  const SizedBox(height: 16),
                  _buildNutritionCard(theme, state, ratio),
                  const SizedBox(height: 16),
                  _buildTipsCard(theme, detail.tips),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSection(RecipeFormSection section) async {
    final detail = ref.read(recipeDetailPageProvider(widget.id)).detail;
    final result = await context.push<RecipeFormResult>(
      '/recipes/${widget.id}/edit/${section.name}',
      extra: detail,
    );
    if (result?.saved != true || !mounted) return;
    await ref.read(recipeDetailPageProvider(widget.id).notifier).load();
    if (!mounted) return;
    if (result?.message.isNotEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result!.message)),
      );
    }
  }

  Future<void> _confirmPublish() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recipePublishTitle),
        content: Text(l10n.recipePublishDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.recipeConfirmPublish),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await _repository.publishRecipe(widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.pending
              ? (result.message.isEmpty
                  ? l10n.recipePublishPending
                  : result.message)
              : l10n.recipePublished),
        ),
      );
      await ref.read(recipeDetailPageProvider(widget.id).notifier).load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recipeDelete),
        content: Text(l10n.recipeDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repository.deleteRecipe(widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.recipeDeleted)));
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // ---- 图片缩略图 + 灯箱 ----
  Widget _buildImageGallery(
      ThemeData theme, List<String> urls, int selectedIndex) {
    return Column(
      key: const ValueKey('recipe-detail-image-gallery'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < urls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImageIndex = i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: i == selectedIndex
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.network(
                          urls[i],
                          width: 88,
                          height: 88 * 0.33,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openLightbox(
      BuildContext context, List<String> urls, int initialIndex) async {
    final l10n = AppLocalizations.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.commonClose,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) =>
          _RecipeLightbox(urls: urls, initialIndex: initialIndex),
    );
  }

  // ---- 头部：分类 / 难度 / 份数 ----
  Widget _sectionEditButton(RecipeFormSection section, String tooltip) {
    return IconButton(
      icon: const Icon(Icons.edit_outlined),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: () => _editSection(section),
    );
  }

  Widget _buildHeader(ThemeData theme, RecipeDetail detail) {
    final l10n = AppLocalizations.of(context);
    final chips = <Widget>[];
    if (detail.category != null && detail.category!.isNotEmpty) {
      chips.add(_chip(
          theme,
          _categoryLabel(detail.category!, l10n),
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer));
    }
    final diffLabel = _difficultyLabel(detail.difficulty, l10n);
    if (diffLabel != null) {
      chips.add(_chip(theme, diffLabel, theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer));
    }
    chips.add(_chip(
        theme,
        l10n.recipeServingsCount(detail.servings),
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer));
    if (!detail.isPublic) {
      chips.add(_chip(
          theme,
          l10n.recipeUnpublished,
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer));
    }
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
                Expanded(
                  child: Text(l10n.recipeBasicInfoTitle,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                _sectionEditButton(
                    RecipeFormSection.basic, l10n.recipeEditBasicInfo),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.description != null &&
                detail.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(detail.description!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child:
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: fg)),
    );
  }

  String? _difficultyLabel(String? d, AppLocalizations l10n) {
    return switch (d) {
      'simple' => l10n.recipeDifficultySimple,
      'easy' => l10n.recipeDifficultyEasy,
      'medium' => l10n.recipeDifficultyMedium,
      'hard' => l10n.recipeDifficultyHard,
      'expert' => l10n.recipeDifficultyExpert,
      _ => null,
    };
  }

  Set<String> _pendingModificationLabels(
      RecipeDetail detail, AppLocalizations l10n) {
    return {
      for (final proposal in detail.pendingProposals)
        for (final field in proposal.updateData.keys)
          switch (field) {
            'name' => l10n.recipeName,
            'source' => l10n.recipeSource,
            'category' => l10n.recipeCategory,
            'tags' => l10n.recipeTags,
            'cooking_steps' => l10n.recipeSteps,
            'total_time_minutes' => l10n.recipeTotalTime,
            'difficulty' => l10n.recipeDifficulty,
            'servings' => l10n.recipeServingsField,
            'tips' => l10n.recipeTips,
            'description' => l10n.recipeIntroduction,
            'images' => l10n.recipeImages,
            'ingredients' => l10n.recipeIngredients,
            'result_ingredient_id' => l10n.recipeResultIngredient,
            _ => field,
          },
    };
  }

  String _categoryLabel(String category, AppLocalizations l10n) {
    return switch (category) {
      '荤菜' => l10n.recipeCategoryMeatDish,
      '素菜' => l10n.recipeCategoryVegetableDish,
      '水产' => l10n.recipeCategorySeafood,
      '主食' => l10n.recipeCategoryStaple,
      '汤与羹' || '汤与粥' => l10n.recipeCategorySoupPorridge,
      '早餐' => l10n.recipeCategoryBreakfast,
      '甜品' => l10n.recipeCategoryDessert,
      '调料' => l10n.recipeCategorySeasoning,
      '半成品' => l10n.recipeCategorySemiFinished,
      '小食' => l10n.recipeCategorySnack,
      _ => category,
    };
  }

  // ---- 成本估算 + 成本趋势 ----
  Widget _buildCostCard(
      ThemeData theme, RecipeDetailPageState state, double ratio) {
    final l10n = AppLocalizations.of(context);
    final userCurrency = ref.read(displayCurrencyProvider);
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
                Text(l10n.recipeCostEstimate,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: state.loadingCost
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : state.cost == null
                      ? Text(l10n.recipeNoCostData,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline))
                      : Text(
                          formatMoney(
                              state.cost!.totalCost * ratio, userCurrency),
                          style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.tertiary),
                        ),
            ),
            const SizedBox(height: 16),
            CostTrendChart(
              points: state.costHistory.map((p) => p.scaled(ratio)).toList(),
              loading: state.loadingHistory,
              userCurrency: userCurrency,
              onRangeChange: (days) => ref
                  .read(recipeDetailPageProvider(widget.id).notifier)
                  .reloadHistory(days),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 原料列表 ----
  Widget _buildIngredientsCard(ThemeData theme, RecipeDetail detail,
      RecipeDetailPageState state, double ratio) {
    final l10n = AppLocalizations.of(context);
    final costMap = <int, CostBreakdownItem>{};
    if (state.cost != null) {
      for (final c in state.cost!.breakdown) {
        if (c.recipeIngredientId != null) {
          costMap[c.recipeIngredientId!] = c;
        }
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.recipeIngredients,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                _ServingsStepper(
                  value: state.displayServings,
                  onChanged: (v) => ref
                      .read(recipeDetailPageProvider(widget.id).notifier)
                      .setServings(v),
                  canReset: state.displayServings != detail.servings,
                  onReset: () => ref
                      .read(recipeDetailPageProvider(widget.id).notifier)
                      .setServings(detail.servings),
                ),
                _sectionEditButton(
                    RecipeFormSection.ingredients, l10n.recipeEditIngredients),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.ingredients.isEmpty)
              Text(l10n.recipeNoIngredients,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline))
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FixedColumnWidth(104),
                  2: FixedColumnWidth(92),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (final ing in detail.ingredients)
                    _buildIngredientRow(theme, ing, costMap[ing.id], ratio),
                ],
              ),
          ],
        ),
      ),
    );
  }

  TableRow _buildIngredientRow(ThemeData theme, RecipeIngredient ing,
      CostBreakdownItem? cb, double ratio) {
    final l10n = AppLocalizations.of(context);
    final userCurrency = ref.read(displayCurrencyProvider);
    final qtyText = _scaledQuantity(ing, ratio, l10n);
    final recommendedText = _scaledRecommendedQuantity(ing, ratio, l10n);
    final hasFallback =
        cb != null && cb.fallbackChain != null && cb.fallbackChain!.isNotEmpty;
    final canNavigate = ing.ingredientId != null;
    final onTap = canNavigate
        ? () => context.push('/ingredients/${ing.ingredientId}')
        : null;
    return TableRow(
      children: [
        // 名称（含可选标记、备注）
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(ing.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500)),
                    ),
                    if (canNavigate)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(Icons.chevron_right,
                            size: 16, color: theme.colorScheme.outline),
                      ),
                    if (ing.isOptional) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(l10n.recipeOptional,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer)),
                      ),
                    ],
                  ],
                ),
                if (ing.note != null && ing.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(ing.note!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
              ],
            ),
          ),
        ),
        // 用量
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(qtyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
              if (recommendedText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(recommendedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
            ],
          ),
        ),
        // 价格（桌面悬停查看，移动端点击查看）
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasFallback)
                Tooltip(
                  message:
                      '${l10n.recipeCalculatedFromIngredientsCost}\n${cb.fallbackChain}',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(24, 24),
                      maximumSize: const Size(24, 24),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    iconSize: 16,
                    icon: Icon(Icons.info_outline,
                        color: theme.colorScheme.tertiary),
                    onPressed: () => _showFallbackChain(
                      context,
                      ing.name,
                      cb.fallbackChain!,
                    ),
                  ),
                ),
              if (cb != null && cb.cost > 0) ...[
                if (hasFallback) const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(cb.cost * ratio, userCurrency),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showFallbackChain(
    BuildContext context,
    String ingredientName,
    String fallbackChain,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recipeCalculatedFromIngredientsCost),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ingredientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(fallbackChain),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.recipeGotIt),
          ),
        ],
      ),
    );
  }

  /// 按份数比例缩放用量，与 Web 端 scaleQuantity 逻辑一致
  String _scaledQuantity(
      RecipeIngredient ing, double ratio, AppLocalizations l10n) {
    if (ing.quantityRange != null && ing.quantityRange!.min > 0) {
      final min = (ing.quantityRange!.min * ratio);
      final max = (ing.quantityRange!.max * ratio);
      return '${_fmt(min)}~${_fmt(max)}${ing.unit != null ? ' ${ing.unit}' : ''}';
    }
    final num = double.tryParse(ing.quantity ?? '');
    if (num != null && num > 0) {
      return '${_fmt(num * ratio)}${ing.unit != null ? ' ${ing.unit}' : ''}';
    }
    if (ing.quantity != null && ing.quantity!.isNotEmpty) return ing.quantity!;
    final original = ing.originalQuantity;
    if (original != null && original.isNotEmpty) {
      return switch (original) {
        '适量' => l10n.recipeQuantityToTaste,
        '少许' => l10n.recipeQuantitySmall,
        _ => original,
      };
    }
    return l10n.recipeQuantityToTaste;
  }

  String? _scaledRecommendedQuantity(
      RecipeIngredient ing, double ratio, AppLocalizations l10n) {
    final range = ing.quantityRange;
    if (range == null || range.min <= 0) return null;

    final quantity = double.tryParse(ing.quantity ?? '');
    if (quantity == null || quantity <= 0) return null;

    return l10n.recipeRecommendedQuantity(
      _fmt(quantity * ratio),
      ing.unit ?? '',
    );
  }

  String _fmt(double n) {
    return formatNumber(n, maximumFractionDigits: 1);
  }

  // ---- 做法步骤 ----
  Widget _buildStepsCard(ThemeData theme, RecipeDetail detail) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.recipeSteps,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                _sectionEditButton(
                    RecipeFormSection.steps, l10n.recipeEditSteps),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.steps.isEmpty)
              Text(l10n.recipeNoSteps,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline))
            else
              ...detail.steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final num = step.stepNumber > 0 ? step.stepNumber : index + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle),
                        child: Center(
                            child: Text('$num',
                                style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(step.content,
                                style: theme.textTheme.bodyLarge),
                            if (step.durationMinutes != null &&
                                step.durationMinutes! > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined,
                                      size: 14,
                                      color: theme.colorScheme.outline),
                                  const SizedBox(width: 4),
                                  Text(
                                      l10n.recipeStepMinutes(
                                        formatNumber(
                                          step.durationMinutes!,
                                          maximumFractionDigits:
                                              step.durationMinutes! ==
                                                      step.durationMinutes!
                                                          .roundToDouble()
                                                  ? 0
                                                  : 1,
                                        ),
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color:
                                                  theme.colorScheme.outline)),
                                ],
                              ),
                            ],
                            if (step.tips != null && step.tips!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.lightbulb_outline,
                                        size: 14,
                                        color: theme.colorScheme.tertiary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                        child: Text(step.tips!,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onTertiaryContainer))),
                                  ],
                                ),
                              ),
                            ],
                            if (step.imageUrl != null) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(step.imageUrl!,
                                    height: 150, fit: BoxFit.cover),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ---- 营养成分（表格 + 展开折叠 + NRV）----
  Widget _buildNutritionCard(
      ThemeData theme, RecipeDetailPageState state, double ratio) {
    final l10n = AppLocalizations.of(context);
    final nutrition = state.nutrition;
    final core =
        nutrition?.perServingNutrients ?? const <String, NutritionItem>{};
    final otherCount =
        core.keys.where((k) => !defaultNutrientKeys.contains(k)).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.recipeNutritionPerServing,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                if (!state.loadingNutrition && otherCount > 0)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAllNutrients = !_showAllNutrients),
                    icon: Icon(
                        _showAllNutrients
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18),
                    label: Text(_showAllNutrients
                        ? l10n.nutritionCollapse
                        : l10n.nutritionExpand(otherCount)),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
              ],
            ),
            const Divider(height: 20),
            if (state.loadingNutrition)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))))
            else if (nutrition == null || core.isEmpty)
              Text(l10n.nutritionNoData,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline))
            else
              _buildNutritionTable(theme, core, ratio),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionTable(
      ThemeData theme, Map<String, NutritionItem> core, double ratio) {
    final l10n = AppLocalizations.of(context);
    // 构造行：默认 5 项优先，其余按排序顺序
    final rows = <String>[];
    // 能量键兼容（能量 / 热量）
    if (core.containsKey('能量')) {
      rows.add('能量');
    } else if (core.containsKey('热量')) {
      rows.add('热量');
    }
    for (final k in ['蛋白质', '脂肪', '碳水化合物', '钠']) {
      if (core.containsKey(k)) rows.add(k);
    }
    if (_showAllNutrients) {
      final otherKeys = core.keys
          .where((k) => !defaultNutrientKeys.contains(k) && k != '热量')
          .toList()
        ..sort(compareNutrients);
      rows.addAll(otherKeys);
    }

    const valueW = 70.0;
    const nrvW = 56.0;
    return Column(
      children: [
        // 表头
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(l10n.nutritionNutrient)),
              SizedBox(
                  width: valueW,
                  child:
                      Text(l10n.nutritionQuantity, textAlign: TextAlign.right)),
              const SizedBox(
                  width: nrvW, child: Text('NRV%', textAlign: TextAlign.right)),
            ],
          ),
        ),
        // 数据行
        ...rows.asMap().entries.map((entry) {
          final key = entry.value;
          final item = core[key]!;
          final isLast = entry.key == rows.length - 1;
          final displayKey =
              localizedNutrientLabel(nutrientDisplayLabel(key), l10n);
          final valueStr =
              '${formatNumber(item.value * ratio, maximumFractionDigits: 1)}'
              ' ${item.unit}';
          final nrv = _formatNrv(item);
          return Container(
            decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                            width: 0.5))),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(displayKey)),
                SizedBox(
                    width: valueW,
                    child: Text(valueStr, textAlign: TextAlign.right)),
                SizedBox(
                    width: nrvW, child: Text(nrv, textAlign: TextAlign.right)),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(l10n.nutritionNrvExplanation,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }

  String _formatNrv(NutritionItem item) {
    if (item.standard == '无标准' || item.standard == '无标准值') return '-';
    if (item.nrpPct == 0) return '-';
    return formatPercentValue(item.nrpPct);
  }

  // ---- 小贴士 ----
  Widget _buildTipsCard(ThemeData theme, List<String> tips) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: theme.colorScheme.tertiary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.recipeTips,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                _sectionEditButton(RecipeFormSection.tips, l10n.recipeEditTips),
              ],
            ),
            const SizedBox(height: 12),
            if (tips.isEmpty)
              Text(l10n.recipeNoTips,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline))
            else
              ...tips.map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: theme.colorScheme.tertiary,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(tip, style: theme.textTheme.bodyLarge)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ---- 份数增减器 ----
class _ServingsStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool canReset;
  final VoidCallback onReset;
  const _ServingsStepper(
      {required this.value,
      required this.onChanged,
      required this.canReset,
      required this.onReset});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn(theme, Icons.remove, () => onChanged(value - 1), value <= 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(l10n.recipeServingsCount(value),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        _stepBtn(theme, Icons.add, () => onChanged(value + 1), false),
        if (canReset) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onReset,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.restart_alt,
                  size: 16, color: theme.colorScheme.outline),
            ),
          ),
        ],
      ],
    );
  }

  Widget _stepBtn(
      ThemeData theme, IconData icon, VoidCallback onTap, bool disabled) {
    return Material(
      color: disabled
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: disabled ? null : onTap,
        child: Padding(
            padding: const EdgeInsets.all(4), child: Icon(icon, size: 18)),
      ),
    );
  }
}

// ---- 图片灯箱（支持左右切换 + 双指缩放）----
class _RecipeLightbox extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _RecipeLightbox({required this.urls, required this.initialIndex});

  @override
  State<_RecipeLightbox> createState() => _RecipeLightboxState();
}

class _RecipeLightboxState extends State<_RecipeLightbox> {
  late final PageController _controller;
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _prev() {
    if (_index > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpToPage(widget.urls.length - 1);
    }
  }

  void _next() {
    if (_index < widget.urls.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (ctx, i) => InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.urls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 64, color: Colors.white54),
                    ),
                    loadingBuilder: (ctx, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white54),
                          ),
                  ),
                ),
              ),
            ),
          ),
          // 关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              tooltip: l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // 图片计数
          if (widget.urls.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.urls.length}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          // 左右切换
          if (widget.urls.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 36),
                  tooltip: l10n.recipePreviousImage,
                  onPressed: _prev,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 36),
                  tooltip: l10n.recipeNextImage,
                  onPressed: _next,
                ),
              ),
            ),
          ],
          // 底部缩略图导航
          if (widget.urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.urls.length,
                  itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () => _controller.jumpToPage(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              i == _index ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          widget.urls[i],
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.white12,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 20, color: Colors.white38),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../models/meal_recommendation.dart';
import '../../../shared/utils/nutrition_display.dart';
import '../../../shared/utils/currency_fmt.dart';
import 'nutrient_grid.dart';

class MealCard extends StatelessWidget {
  final MealRecommendation meal;
  /// 单道菜点按：传入该菜谱 id（进菜谱详情）
  final void Function(int recipeId)? onDishTap;
  /// 方案条目点按：进对应实体详情
  final void Function(MealPlanItemBrief item)? onPlanItemTap;
  /// 方案名点按（移动端暂无方案独立详情路由，先落到试算页）
  final VoidCallback? onPlanTap;
  final bool isRefreshing;
  final VoidCallback? onRefresh;
  /// 单道换：传入被换菜的 recipeId（null = 整餐重搭）
  final void Function(int recipeId)? onSwapDish;
  final String userCurrency;
  /// 能量显示单位（kcal / kJ，随用户偏好，与 web 一致）
  final String energyUnit;

  const MealCard({
    super.key,
    required this.meal,
    this.onDishTap,
    this.onPlanItemTap,
    this.onPlanTap,
    this.isRefreshing = false,
    this.onRefresh,
    this.onSwapDish,
    this.userCurrency = 'CNY',
    this.energyUnit = 'kcal',
  });

  IconData _mealIcon(String type) {
    switch (type) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }

  String _mealLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'breakfast':
        return l10n.homeBreakfast;
      case 'lunch':
        return l10n.homeLunch;
      case 'dinner':
        return l10n.homeDinner;
      default:
        return type;
    }
  }

  /// 方案来源餐：方案名 + 逐条目成本 + 合计与营养（与多道菜块同格式）
  Widget _buildPlanSection(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined,
                  size: 16, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: onPlanTap,
                  child: Text(
                    meal.planName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Text(
                meal.planKind == 'day'
                    ? l10n.plansKindDay
                    : l10n.plansKindMeal,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 2),
          for (final item in meal.planItems)
            _buildItemRow(
              theme,
              name: item.name ?? '-',
              trailing: item.cost != null
                  ? formatMoney(item.cost!, userCurrency)
                  : '--',
              onTap: onPlanItemTap == null ? null : () => onPlanItemTap!(item),
            ),
          _buildTotalsFooter(theme, l10n, meal.planNutrients,
              cost: meal.planCost),
        ],
      ),
    );
  }

  /// 条目行：菜名 + 成本（多道菜块与方案块共用，行距一致）
  Widget _buildItemRow(
    ThemeData theme, {
    required String name,
    required String trailing,
    Widget? action,
    VoidCallback? onTap,
  }) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(trailing, style: theme.textTheme.bodyMedium),
          if (action != null) action,
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }

  /// 块尾：分割线 + 成本合计 + 四项营养素（各带 NRV%），与 web 餐卡同格式
  Widget _buildTotalsFooter(
    ThemeData theme,
    AppLocalizations l10n,
    MealNutrients nutrients, {
    double? cost,
  }) {
    final labelStyle =
        theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.plansTotalCost, style: labelStyle),
            Text(cost != null ? formatMoney(cost, userCurrency) : '--',
                style: labelStyle),
          ],
        ),
        const SizedBox(height: 4),
        // 四项营养素 2×2 宫格（NRV 单独一行），与 web 餐卡同口径
        NutrientGrid(items: [
          NutrientGridItem(
            icon: Icons.local_fire_department,
            label: l10n.plansCalories,
            value:
                '${formatNumber(toDisplayCalorie(nutrients.energy, energyUnit))} '
                '$energyUnit',
            nrv: _nrvSuffix('energy', nutrients.energy),
          ),
          NutrientGridItem(
            icon: Icons.egg_outlined,
            label: l10n.plansProtein,
            value:
                '${formatNumber(nutrients.protein, maximumFractionDigits: 1)} g',
            nrv: _nrvSuffix('protein', nutrients.protein),
          ),
          NutrientGridItem(
            icon: Icons.water_drop_outlined,
            label: l10n.plansFat,
            value: '${formatNumber(nutrients.fat, maximumFractionDigits: 1)} g',
            nrv: _nrvSuffix('fat', nutrients.fat),
          ),
          NutrientGridItem(
            icon: Icons.grain,
            label: l10n.nutritionNutrientCarbohydrate,
            value:
                '${formatNumber(nutrients.carbohydrate, maximumFractionDigits: 1)} g',
            nrv: _nrvSuffix('carbohydrate', nutrients.carbohydrate),
          ),
        ]),
      ],
    );
  }

  String? _nrvSuffix(String key, double value) {
    final pct = nrvPct(key, value);
    return pct == null
        ? null
        : 'NRV ${formatPercentValue(pct, maximumFractionDigits: 2)}%';
  }

  bool get _hasDishes => meal.dishes.isNotEmpty;

  bool get _isPlan => meal.planName != null;
  bool get _isAi => meal.isAiSource;

  /// 标题/封面行是否还要再写一遍菜名：多道菜清单或方案条目已逐项列出名字时不再重复。
  bool get _showHeaderNames => !_isPlan && !_hasDishes;

  /// 首图行：有图的菜谱才出图，有几张就并排几张（与 web 同口径）。
  List<String> get _headerImageUrls {
    final urls = _isPlan
        ? meal.planItems.map((item) => item.imageUrl)
        : _hasDishes
            ? meal.dishes.map((dish) => dish.imageUrl)
            : <String?>[meal.imageUrl];
    return urls
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  /// 兼容单道菜/空数据时的名称（多道菜与方案的名字见下方清单）。
  String get _dishNames => meal.recipeName ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final headerImages = _headerImageUrls;
    final hasBody = _isPlan || _hasDishes ||
        meal.calories != null ||
        meal.proteinG != null ||
        meal.carbsG != null ||
        meal.fatG != null ||
        meal.estimatedCost != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerImages.isNotEmpty)
            _buildImageHeader(theme, l10n, headerImages)
          else
            _buildTitleHeader(theme, l10n),
          if (_isPlan)
            _buildPlanSection(theme, l10n)
          else if (_hasDishes)
            _buildDishList(theme, l10n)
          else if (hasBody)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (meal.estimatedCost != null)
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          formatMoney(meal.estimatedCost!, userCurrency),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  NutrientGrid(items: [
                    if (meal.calories != null)
                      NutrientGridItem(
                        icon: Icons.local_fire_department,
                        label: l10n.plansCalories,
                        value:
                            '${formatNumber(meal.calories!.round())} kcal',
                      ),
                    if (meal.proteinG != null)
                      NutrientGridItem(
                        icon: Icons.egg_outlined,
                        label: l10n.homeProtein,
                        value:
                            '${formatNumber(meal.proteinG!, maximumFractionDigits: 1)} g',
                      ),
                    if (meal.fatG != null)
                      NutrientGridItem(
                        icon: Icons.water_drop_outlined,
                        label: l10n.homeFat,
                        value:
                            '${formatNumber(meal.fatG!, maximumFractionDigits: 1)} g',
                      ),
                    if (meal.carbsG != null)
                      NutrientGridItem(
                        icon: Icons.grain,
                        label: l10n.homeCarbs,
                        value:
                            '${formatNumber(meal.carbsG!, maximumFractionDigits: 1)} g',
                      ),
                  ]),
                ],
              ),
            ),
          if (_hasDishes && (meal.reason != null || meal.preference != null))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meal.reason != null)
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 12, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            meal.reason!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ),
                      ],
                    ),
                  if (meal.preference != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.mealsPreferenceChip}${meal.preference}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.outline.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (onRefresh != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: isRefreshing ? null : onRefresh,
                    icon: isRefreshing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.mealsChangeMeal),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 多道菜清单：role 徽标 + 名称 + 成本·热量 + 换这道
  Widget _buildDishList(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final dish in meal.dishes)
            _buildItemRow(
              theme,
              name: dish.name,
              trailing: dish.estimatedCost != null
                  ? formatMoney(dish.estimatedCost!,
                      dish.currency ?? userCurrency)
                  : '--',
              action: onSwapDish == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.swap_horiz, size: 20),
                      tooltip: l10n.mealsChangeDish,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: 32, height: 32),
                      onPressed: isRefreshing
                          ? null
                          : () => onSwapDish!(dish.recipeId),
              ),
              onTap: onDishTap == null
                  ? null
                  : () => onDishTap!(dish.recipeId),
            ),
          _buildTotalsFooter(theme, l10n, meal.dishNutrients,
              cost: meal.dishCost),
          if (_isAi) _buildAiBadge(theme, l10n),
        ],
      ),
    );
  }

  /// AI 标识：整张卡只在块尾保留这一处（头部不再重复写一遍）
  Widget _buildAiBadge(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 12, color: theme.colorScheme.tertiary),
          const SizedBox(width: 4),
          Text(
            l10n.mealsAiGenerated,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.tertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader(
      ThemeData theme, AppLocalizations l10n, List<String> imageUrls) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              for (final imageUrl in imageUrls)
                Expanded(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          _mealIcon(meal.mealType),
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _mealLabel(meal.mealType, l10n),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  if (_showHeaderNames) ...[
                    const SizedBox(height: 2),
                    Text(
                      _dishNames.isNotEmpty ? _dishNames : l10n.homeNotSet,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleHeader(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(
            _mealIcon(meal.mealType),
            size: 32,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mealLabel(meal.mealType, l10n),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                if (_showHeaderNames) ...[
                  const SizedBox(height: 2),
                  Text(
                    _dishNames.isNotEmpty ? _dishNames : l10n.homeNotSet,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

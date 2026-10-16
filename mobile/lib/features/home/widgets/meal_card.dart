import 'package:flutter/material.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../l10n/app_localizations.dart';
import '../models/meal_recommendation.dart';
import '../../../shared/utils/currency_fmt.dart';

class MealCard extends StatelessWidget {
  final MealRecommendation meal;
  final VoidCallback? onTap;
  final bool isRefreshing;
  final VoidCallback? onRefresh;
  /// 单道换：传入被换菜的 recipeId（null = 整餐重搭）
  final void Function(int recipeId)? onSwapDish;
  final String userCurrency;

  const MealCard({
    super.key,
    required this.meal,
    this.onTap,
    this.isRefreshing = false,
    this.onRefresh,
    this.onSwapDish,
    this.userCurrency = 'CNY',
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

  String _roleLabel(String role, AppLocalizations l10n) {
    switch (role) {
      case 'staple':
        return l10n.mealsRoleStaple;
      case 'main':
        return l10n.mealsRoleMain;
      case 'side':
        return l10n.mealsRoleSide;
      case 'soup':
        return l10n.mealsRoleSoup;
      case 'drink':
        return l10n.mealsRoleDrink;
      default:
        return role;
    }
  }

  /// 方案来源餐：方案名 + 逐条目成本 + 合计与营养
  Widget _buildPlanSection(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined,
                  size: 16, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meal.planName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
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
          const SizedBox(height: 6),
          for (final item in meal.planItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    item.cost != null
                        ? formatMoney(item.cost!, userCurrency)
                        : '--',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.plansTotalCost,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(formatMoney(meal.planCost ?? 0, userCurrency),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _nutrientChip(
                Icons.local_fire_department,
                '${formatNumber((meal.planCalories ?? 0).round())} kcal',
                theme,
              ),
              _nutrientChip(
                Icons.egg_outlined,
                '${formatNumber(meal.planProteinG ?? 0, maximumFractionDigits: 1)} g ${l10n.homeProtein}',
                theme,
              ),
              _nutrientChip(
                Icons.water_drop_outlined,
                '${formatNumber(meal.planFatG ?? 0, maximumFractionDigits: 1)} g ${l10n.homeFat}',
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nutrientChip(IconData icon, String text, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  bool get _hasDishes => meal.dishes.isNotEmpty;

  bool get _isPlan => meal.planName != null;
  bool get _isAi => meal.isAiSource;

  /// 标题/封面行是否还要再写一遍菜名：多道菜清单或方案条目已逐项列出名字时不再重复。
  bool get _showHeaderNames => !_isPlan && !_hasDishes;

  /// 封面图：staple（无则首道）有图者
  RecommendedDish? get _coverDish {
    if (!_hasDishes) return null;
    return meal.dishes.firstWhere(
      (d) => d.imageUrl != null && d.imageUrl!.isNotEmpty,
      orElse: () => meal.dishes.first,
    );
  }

  /// 兼容单道菜/空数据时的名称（多道菜与方案的名字见下方清单）。
  String get _dishNames => meal.recipeName ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cover = _coverDish;
    final hasImage = _hasDishes
        ? (cover?.imageUrl?.isNotEmpty ?? false)
        : (meal.imageUrl != null && meal.imageUrl!.isNotEmpty);
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
          if (hasImage)
            _buildImageHeader(theme, l10n,
                _hasDishes ? cover!.imageUrl! : meal.imageUrl!)
          else
            _buildTitleHeader(theme, l10n),
          if (_isPlan)
            _buildPlanSection(theme, l10n)
          else if (_hasDishes)
            _buildDishList(theme, l10n)
          else if (hasBody)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (meal.estimatedCost != null)
                    _nutrientChip(
                      Icons.payments_outlined,
                      formatMoney(meal.estimatedCost!, userCurrency),
                      theme,
                    ),
                  if (meal.calories != null)
                    _nutrientChip(
                      Icons.local_fire_department,
                      '${formatNumber(meal.calories!.round())} kcal',
                      theme,
                    ),
                  if (meal.proteinG != null)
                    _nutrientChip(
                      Icons.egg_outlined,
                      '${formatNumber(meal.proteinG!, maximumFractionDigits: 1)} g ${l10n.homeProtein}',
                      theme,
                    ),
                  if (meal.carbsG != null)
                    _nutrientChip(
                      Icons.grain,
                      '${formatNumber(meal.carbsG!, maximumFractionDigits: 1)} g ${l10n.homeCarbs}',
                      theme,
                    ),
                  if (meal.fatG != null)
                    _nutrientChip(
                      Icons.water_drop_outlined,
                      '${formatNumber(meal.fatG!, maximumFractionDigits: 1)} g ${l10n.homeFat}',
                      theme,
                    ),
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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        children: [
          for (final dish in meal.dishes)
            ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              onTap: onTap,
              title: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: dish.role == 'staple'
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _roleLabel(dish.role, l10n),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: dish.role == 'staple'
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                '${dish.estimatedCost != null ? formatMoney(dish.estimatedCost!, dish.currency ?? userCurrency) : '--'}'
                '${dish.calories != null ? ' · ${formatNumber(dish.calories!.round())} kcal' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.tertiary),
              ),
              trailing: onSwapDish != null
                  ? IconButton(
                      icon: const Icon(Icons.swap_horiz, size: 20),
                      tooltip: l10n.mealsChangeDish,
                      onPressed: isRefreshing
                          ? null
                          : () => onSwapDish!(dish.recipeId),
                    )
                  : null,
            ),
          if (_isAi)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 12, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.mealsAiGenerated,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.tertiary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageHeader(
      ThemeData theme, AppLocalizations l10n, String imageUrl) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
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
                  Row(
                    children: [
                      Text(
                        _mealLabel(meal.mealType, l10n),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                      if (_isAi) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.auto_awesome,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(
                          l10n.mealsAiGenerated,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ],
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
                Row(
                  children: [
                    Text(
                      _mealLabel(meal.mealType, l10n),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    if (_isAi) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.auto_awesome,
                          size: 12, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 2),
                      Text(l10n.mealsAiGenerated,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.tertiary)),
                    ],
                  ],
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

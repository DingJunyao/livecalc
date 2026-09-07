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
  final String userCurrency;

  const MealCard({
    super.key,
    required this.meal,
    this.onTap,
    this.isRefreshing = false,
    this.onRefresh,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasImage = meal.imageUrl != null && meal.imageUrl!.isNotEmpty;
    final hasNutrition = meal.calories != null ||
        meal.proteinG != null ||
        meal.carbsG != null ||
        meal.fatG != null;
    final hasBody = hasNutrition || meal.estimatedCost != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              _buildImageHeader(theme, l10n)
            else
              _buildTitleHeader(theme, l10n),
            if (hasBody)
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
                        '${meal.calories!.round()} kcal',
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
                      label: Text(l10n.homeSwap),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeader(ThemeData theme, AppLocalizations l10n) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            meal.imageUrl!,
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
                  Text(
                    _mealLabel(meal.mealType, l10n),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meal.recipeName ?? l10n.homeNotSet,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                const SizedBox(height: 2),
                Text(
                  meal.recipeName ?? l10n.homeNotSet,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

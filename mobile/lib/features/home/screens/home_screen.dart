import 'package:flutter/material.dart';
import '../../../core/i18n/app_formatters.dart' hide formatMoney;
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/utils/currency_fmt.dart';
import '../../../shared/utils/nutrition_display.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../models/meal_recommendation.dart';
import '../providers/home_provider.dart';
import '../widgets/meal_card.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_display.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _preferenceController = TextEditingController();
  /// 一句话偏好的应用范围：current / breakfast / lunch / dinner / all
  String _preferenceTarget = 'current';
  bool _applyingPreference = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(homeProvider.notifier).loadToday());
  }

  /// 应用一句话偏好：按所选范围整餐重搭（还没生成就先跑一次生成，与 web 同口径）
  Future<void> _applyPreference() async {
    final state = ref.read(homeProvider);
    if (state.preferenceInput.isEmpty || _applyingPreference) return;
    FocusScope.of(context).unfocus();
    setState(() => _applyingPreference = true);
    try {
      final meals = state.recommendation?.meals ?? const <MealRecommendation>[];
      final hasAnyMeal = meals.any((meal) =>
          meal.dishes.isNotEmpty || meal.recipeId != null || meal.planName != null);
      if (!hasAnyMeal) {
        await ref.read(homeProvider.notifier).loadToday();
      } else {
        final current = meals.firstWhere((meal) => meal.isCurrentMeal,
            orElse: () => meals.first);
        final targets = switch (_preferenceTarget) {
          'all' => const ['breakfast', 'lunch', 'dinner'],
          'current' => [current.mealType],
          final other => [other],
        };
        for (final mealType in targets) {
          await ref.read(homeProvider.notifier).refreshMeal(mealType);
        }
      }
      if (!mounted) return;
      // 失败时由 state 监听统一弹错误提示，这里就不再说「已重新组合」
      if (ref.read(homeProvider).lastError != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).mealsPreferenceApplied),
        ),
      );
    } finally {
      if (mounted) setState(() => _applyingPreference = false);
    }
  }

  /// 今日预估：成本 + 热量/蛋白质/碳水化合物/脂肪（各带 NRV%），优先一行、放不下换行
  Widget _buildSummaryBar(
    ThemeData theme,
    AppLocalizations l10n,
    Map<String, dynamic>? totals,
    String userCurrency,
    String energyUnit,
  ) {
    if (totals == null) return const SizedBox.shrink();
    // 宽容取值：后端是数字，但本地模式 / 旧响应可能给字符串，别让类型转换把首页打崩
    double numOf(String key) {
      final value = totals[key];
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }
    final calories = numOf('calories');
    final protein = numOf('protein_g');
    final carbs = numOf('carbs_g');
    final fat = numOf('fat_g');
    String nrv(String key, double value) {
      final pct = nrvPct(key, value);
      return pct == null
          ? ''
          : ' (NRV ${formatNumber(pct, maximumFractionDigits: 2)}%)';
    }

    // 用 Wrap（而非 Row）承载「标签 + 数值」：窄屏放不下时换行，不产生 RenderFlex 溢出
    Widget item(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(right: 12, top: 2),
          child: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.outline),
              Text(
                '$label ',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              Text(value, style: theme.textTheme.bodySmall),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 4,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            item(
              Icons.payments_outlined,
              l10n.mealsEstimatedToday,
              formatMoney(numOf('cost'),
                  (totals['currency'] as String?) ?? userCurrency),
            ),
            item(
              Icons.local_fire_department,
              l10n.plansCalories,
              '${formatNumber(toDisplayCalorie(calories, energyUnit))} '
                  '$energyUnit${nrv('energy', calories)}',
            ),
            item(
              Icons.egg_outlined,
              l10n.plansProtein,
              '${formatNumber(protein, maximumFractionDigits: 1)} g'
                  '${nrv('protein', protein)}',
            ),
            item(
              Icons.grain,
              l10n.nutritionNutrientCarbohydrate,
              '${formatNumber(carbs, maximumFractionDigits: 1)} g'
                  '${nrv('carbohydrate', carbs)}',
            ),
            item(
              Icons.water_drop_outlined,
              l10n.plansFat,
              '${formatNumber(fat, maximumFractionDigits: 1)} g'
                  '${nrv('fat', fat)}',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _preferenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 会话级临时覆盖（地区/范围/币种）变化后刷新当前页数据
    ref.listen(calcContextProvider, (_, __) {
      ref.read(homeProvider.notifier).loadToday();
    });
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(homeProvider);
    final energyUnit =
        ref.watch(authProvider).user?.unitPreferences?.energyUnit ?? 'kcal';

    ref.listen(homeProvider, (previous, next) {
      if (next.lastError != null && next.lastError != previous?.lastError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_homeErrorText(l10n, next.lastError!))),
        );
        ref.read(homeProvider.notifier).clearLastError();
      }
    });

    Widget recArea;
    if (state.loading) {
      recArea = Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: LoadingIndicator(message: l10n.commonLoading),
      );
    } else if (state.generating) {
      recArea = Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: LoadingIndicator(message: l10n.homeGenerating),
      );
    } else if (state.error != null) {
      recArea = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ErrorDisplay(
          message: _homeErrorText(l10n, state.error!),
          onRetry: () => ref.read(homeProvider.notifier).loadToday(),
        ),
      );
    } else if (state.recommendation != null &&
        state.recommendation!.meals.isNotEmpty) {
      recArea = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 今日预估（成本 + 四项营养素 NRV%，与 web DailySummaryBar 同口径）
          if (state.recommendation?.totals != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _buildSummaryBar(
                theme,
                l10n,
                state.recommendation!.totals,
                ref.read(displayCurrencyProvider),
                energyUnit,
              ),
            ),
          // 一句话偏好输入（可指定应用到哪一餐）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: _preferenceController,
                  decoration: InputDecoration(
                    labelText: l10n.mealsPreferencePlaceholder,
                    prefixIcon: const Icon(Icons.chat_bubble_outline),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: TextButton(
                        onPressed: state.preferenceInput.isEmpty ||
                                _applyingPreference
                            ? null
                            : _applyPreference,
                        child: Text(l10n.mealsApplyPreference),
                      ),
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      ref.read(homeProvider.notifier).setPreference(v),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DropdownButton<String>(
                    value: _preferenceTarget,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    onChanged: _applyingPreference
                        ? null
                        : (value) => setState(
                            () => _preferenceTarget = value ?? 'current'),
                    items: [
                      DropdownMenuItem(
                        value: 'current',
                        child: Text(l10n.mealsPreferenceTargetCurrent),
                      ),
                      DropdownMenuItem(
                        value: 'breakfast',
                        child: Text(l10n.homeBreakfast),
                      ),
                      DropdownMenuItem(
                        value: 'lunch',
                        child: Text(l10n.homeLunch),
                      ),
                      DropdownMenuItem(
                        value: 'dinner',
                        child: Text(l10n.homeDinner),
                      ),
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(l10n.mealsPreferenceTargetAll),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...state.recommendation!.meals.map((meal) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: MealCard(
                  meal: meal,
                  isRefreshing: state.refreshLoading[meal.mealType] ?? false,
                  onDishTap: (recipeId) => context.push('/recipes/$recipeId'),
                  onPlanItemTap: (item) => _openPlanItem(context, item),
                  onPlanTap: meal.planId == null
                      ? null
                      : () => context.push('/plans/${meal.planId}'),
                  onSwapDish: (recipeId) => ref
                      .read(homeProvider.notifier)
                      .refreshMeal(meal.mealType, recipeId: recipeId),
                  onRefresh: () => ref
                      .read(homeProvider.notifier)
                      .refreshMeal(meal.mealType),
                  userCurrency: ref.read(displayCurrencyProvider),
                  energyUnit: energyUnit,
                ),
              )),
        ],
      );
    } else {
      recArea = Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text(l10n.homeEmpty)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appBrandShort),
        actions: [
          const CalcContextMenuButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                (state.generating || state.refreshLoading.values.any((v) => v))
                    ? null
                    : () => ref.read(homeProvider.notifier).refresh(),
            tooltip: l10n.homeSwapAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Icon(Icons.today, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.homeTodayTitle,
                          style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
              ),
              recArea,
            ],
          ),
        ),
      ),
    );
  }
}

/// 方案条目 → 对应实体详情（菜谱 / 原料 / 商品）
void _openPlanItem(BuildContext context, MealPlanItemBrief item) {
  final path = switch (item.itemType) {
    'recipe' when item.recipeId != null => '/recipes/${item.recipeId}',
    'ingredient' when item.ingredientId != null =>
      '/ingredients/${item.ingredientId}',
    'product' when item.productId != null => '/products/${item.productId}',
    _ => null,
  };
  if (path != null) context.push(path);
}

String _homeErrorText(AppLocalizations l10n, HomeErrorCode code) {
  return switch (code) {
    HomeErrorCode.connectionTimeout => l10n.homeConnectionTimeout,
    HomeErrorCode.connectionFailed => l10n.homeConnectionFailed,
    HomeErrorCode.serverBusy => l10n.homeServerBusy,
    HomeErrorCode.resourceNotFound => l10n.homeResourceNotFound,
    HomeErrorCode.loadFailed => l10n.homeLoadFailed,
    HomeErrorCode.generatingTimeout => l10n.homeGeneratingTimeout,
    HomeErrorCode.mealSwapTooMany => l10n.homeSwapLimit,
    HomeErrorCode.mealSwapFailed => l10n.homeSwapFailed,
    HomeErrorCode.mealSwapTimeout => l10n.homeSwapTimeout,
    HomeErrorCode.swapAllTooMany => l10n.homeSwapAllLimit,
    HomeErrorCode.refreshFailed => l10n.homeRefreshFailed,
    HomeErrorCode.refreshTimeout => l10n.homeRefreshTimeout,
  };
}

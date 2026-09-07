import 'package:flutter/material.dart';
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(homeProvider.notifier).loadToday());
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
          ...state.recommendation!.meals.map((meal) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: MealCard(
                  meal: meal,
                  isRefreshing: state.refreshLoading[meal.mealType] ?? false,
                  onTap: meal.recipeId != null
                      ? () => context.push('/recipes/${meal.recipeId}')
                      : null,
                  onRefresh: () => ref
                      .read(homeProvider.notifier)
                      .refreshMeal(meal.mealType),
                  userCurrency: ref.read(displayCurrencyProvider),
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

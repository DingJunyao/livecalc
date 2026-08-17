import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe_summary.dart';
import '../models/recipe_detail.dart';
import '../repositories/recipe_repository.dart';

class RecipeListState {
  final List<RecipeSummary> recipes;
  final bool loading;
  final bool loadingMore;
  final bool loadingCosts;
  final String? error;
  final String searchQuery;
  final List<String> filterCategories;
  final List<String> filterDifficulties;
  final List<int> filterIngredientIds;
  final List<String> filterConditions;
  final int total;
  final int currentPage;
  final bool hasMore;

  const RecipeListState({
    this.recipes = const [],
    this.loading = false,
    this.loadingMore = false,
    this.loadingCosts = false,
    this.error,
    this.searchQuery = '',
    this.filterCategories = const [],
    this.filterDifficulties = const [],
    this.filterIngredientIds = const [],
    this.filterConditions = const [],
    this.total = 0,
    this.currentPage = 1,
    this.hasMore = true,
  });

  RecipeListState copyWith({
    List<RecipeSummary>? recipes,
    bool? loading,
    bool? loadingMore,
    bool? loadingCosts,
    String? error,
    bool clearError = false,
    String? searchQuery,
    List<String>? filterCategories,
    List<String>? filterDifficulties,
    List<int>? filterIngredientIds,
    List<String>? filterConditions,
    int? total,
    int? currentPage,
    bool? hasMore,
  }) {
    return RecipeListState(
      recipes: recipes ?? this.recipes,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      loadingCosts: loadingCosts ?? this.loadingCosts,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      filterCategories: filterCategories ?? this.filterCategories,
      filterDifficulties: filterDifficulties ?? this.filterDifficulties,
      filterIngredientIds: filterIngredientIds ?? this.filterIngredientIds,
      filterConditions: filterConditions ?? this.filterConditions,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class RecipeListNotifier extends StateNotifier<RecipeListState> {
  final RecipeRepository _repository;
  // 防止旧请求的成本数据覆盖新搜索结果
  int _costToken = 0;
  Timer? _debounce;

  RecipeListNotifier(this._repository) : super(const RecipeListState());

  static const int pageSize = 20;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int get activeFilterCount =>
      (state.filterCategories.isNotEmpty ? 1 : 0) +
      (state.filterDifficulties.isNotEmpty ? 1 : 0) +
      (state.filterIngredientIds.isNotEmpty ? 1 : 0) +
      (state.filterConditions.isNotEmpty ? 1 : 0);

  bool get canLoadMore => state.hasMore && !state.loading && !state.loadingMore;

  Future<void> loadRecipes({bool loadMore = false, String? search}) async {
    if (loadMore && !canLoadMore) return;
    final page = loadMore ? state.currentPage + 1 : 1;
    state = state.copyWith(
      loading: !loadMore,
      loadingMore: loadMore,
      clearError: true,
      searchQuery: search,
    );
    try {
      // 第一阶段：尽快展示列表（不含价格/热量）
      final result = await _repository.getRecipes(
        search: search ?? state.searchQuery,
        categories: state.filterCategories,
        difficulties: state.filterDifficulties,
        ingredientIds: state.filterIngredientIds,
        conditions: state.filterConditions,
        page: page,
        pageSize: pageSize,
      );
      final recipes =
          loadMore ? [...state.recipes, ...result.items] : result.items;
      state = RecipeListState(
        recipes: recipes,
        searchQuery: search ?? state.searchQuery,
        filterCategories: state.filterCategories,
        filterDifficulties: state.filterDifficulties,
        filterIngredientIds: state.filterIngredientIds,
        filterConditions: state.filterConditions,
        total: result.total,
        currentPage: page,
        hasMore: recipes.length < result.total,
      );
      // 第二阶段：后台懒加载价格与热量
      _loadCosts(recipes);
    } on Exception catch (e) {
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: e.toString(),
      );
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => loadRecipes());
  }

  void applyFilters({
    required List<String> categories,
    required List<String> difficulties,
    required List<int> ingredientIds,
    required List<String> conditions,
  }) {
    state = state.copyWith(
      filterCategories: categories,
      filterDifficulties: difficulties,
      filterIngredientIds: ingredientIds,
      filterConditions: conditions,
    );
    loadRecipes();
  }

  Future<void> _loadCosts(List<RecipeSummary> recipes) async {
    final token = ++_costToken;
    state = state.copyWith(loadingCosts: true);
    try {
      final ids = recipes.map((r) => r.id).toList(growable: false);
      final costMap = await _repository.getRecipesBatchCost(ids);
      // 若期间用户发起新搜索/刷新，丢弃本次过期结果
      if (token != _costToken) return;
      final merged = costMap.isEmpty
          ? recipes
          : recipes
              .map((r) => costMap.containsKey(r.id)
                  ? r.copyWith(
                      estimatedCost: costMap[r.id]!.estimatedCost,
                      calories: costMap[r.id]!.calories,
                    )
                  : r)
              .toList();
      state = state.copyWith(recipes: merged, loadingCosts: false);
    } on Exception catch (_) {
      // batch-cost 失败不阻断列表展示，仅缺少价格/热量
      if (token == _costToken) {
        state = state.copyWith(loadingCosts: false);
      }
    }
  }
}

final recipeListProvider =
    StateNotifierProvider<RecipeListNotifier, RecipeListState>((ref) {
  return RecipeListNotifier(RecipeRepository());
});

/// 菜谱筛选“所用食材”选项：按关键词搜索食材（对齐 Web 端自动补全）
final recipeIngredientOptionsProvider = FutureProvider.autoDispose
    .family<List<IngredientOption>, String>((ref, query) async {
  final repo = RecipeRepository();
  return repo.getIngredientOptions(query);
});

// Individual recipe detail
final recipeDetailProvider =
    FutureProvider.family<RecipeDetail, int>((ref, id) async {
  final repo = RecipeRepository();
  return repo.getRecipe(id);
});
// ---------- 菜谱详情页聚合状态 ----------

class RecipeDetailPageState {
  final RecipeDetail? detail;
  final RecipeCost? cost;
  final RecipeNutrition? nutrition;
  final List<CostHistoryPoint> costHistory;
  final bool loadingCost;
  final bool loadingNutrition;
  final bool loadingHistory;
  final RecipeMerchantCost? merchantCosts;
  final List<MerchantPriceItem> merchantPrices;
  final bool loadingMerchantCosts;
  final bool loadingMerchantPrices;
  final int displayServings;
  final String? error;
  const RecipeDetailPageState({
    this.detail,
    this.cost,
    this.nutrition,
    this.costHistory = const [],
    this.loadingCost = false,
    this.loadingNutrition = false,
    this.loadingHistory = false,
    this.merchantCosts,
    this.merchantPrices = const [],
    this.loadingMerchantCosts = false,
    this.loadingMerchantPrices = false,
    this.displayServings = 1,
    this.error,
  });
  RecipeDetailPageState copyWith({
    RecipeDetail? detail,
    RecipeCost? cost,
    RecipeNutrition? nutrition,
    List<CostHistoryPoint>? costHistory,
    bool? loadingCost,
    bool? loadingNutrition,
    bool? loadingHistory,
    RecipeMerchantCost? merchantCosts,
    List<MerchantPriceItem>? merchantPrices,
    bool? loadingMerchantCosts,
    bool? loadingMerchantPrices,
    int? displayServings,
    String? error,
  }) {
    return RecipeDetailPageState(
      detail: detail ?? this.detail,
      cost: cost ?? this.cost,
      nutrition: nutrition ?? this.nutrition,
      costHistory: costHistory ?? this.costHistory,
      loadingCost: loadingCost ?? this.loadingCost,
      loadingNutrition: loadingNutrition ?? this.loadingNutrition,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      merchantCosts: merchantCosts ?? this.merchantCosts,
      merchantPrices: merchantPrices ?? this.merchantPrices,
      loadingMerchantCosts: loadingMerchantCosts ?? this.loadingMerchantCosts,
      loadingMerchantPrices:
          loadingMerchantPrices ?? this.loadingMerchantPrices,
      displayServings: displayServings ?? this.displayServings,
      // 与 RecipeListState.copyWith 一致：未显式传 error 时保留原值。
      // 否则任何子加载完成（如 reloadHistory 的 loadingHistory: false）都会
      // 把 load() 失败写入的 error 清成 null，错误页闪一下退回无限加载。
      error: error ?? this.error,
    );
  }
}

class RecipeDetailPageNotifier extends StateNotifier<RecipeDetailPageState> {
  final RecipeRepository _repo;
  final int recipeId;
  RecipeDetailPageNotifier(this._repo, this.recipeId)
      : super(const RecipeDetailPageState());

  /// [initialDays] 指定趋势图初始天数：分析页传 90 对齐 web
  /// loadCostHistory('quarter')；详情页无参调用默认 30 保持「月」初始一致。
  /// 趋势初始由 load 内部单次请求完成，避免外部再发 reloadHistory 造成
  /// 双请求竞态（load 整态重建会清空先写入的 costHistory）。
  Future<void> load({int initialDays = 30}) async {
    try {
      final detail = await _repo.getRecipe(recipeId);
      state = RecipeDetailPageState(
          detail: detail, displayServings: detail.servings);
      _loadCost();
      _loadNutrition();
      _loadHistory(days: initialDays);
      _loadMerchantCosts();
      _loadMerchantPrices();
    } on Exception catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _loadCost() async {
    state = state.copyWith(loadingCost: true);
    try {
      final cost = await _repo.getRecipeCost(recipeId);
      state = state.copyWith(cost: cost, loadingCost: false);
    } on Exception catch (_) {
      state = state.copyWith(loadingCost: false);
    }
  }

  Future<void> _loadNutrition() async {
    state = state.copyWith(loadingNutrition: true);
    try {
      final nutrition = await _repo.getRecipeNutrition(recipeId);
      state = state.copyWith(nutrition: nutrition, loadingNutrition: false);
    } on Exception catch (_) {
      state = state.copyWith(loadingNutrition: false);
    }
  }

  Future<void> _loadHistory({int days = 30}) async {
    state = state.copyWith(loadingHistory: true);
    try {
      final history = await _repo.getRecipeCostHistory(recipeId, days: days);
      state = state.copyWith(costHistory: history, loadingHistory: false);
    } on Exception catch (_) {
      state = state.copyWith(loadingHistory: false);
    }
  }

  Future<void> _loadMerchantCosts() async {
    state = state.copyWith(loadingMerchantCosts: true);
    try {
      final costs = await _repo.getRecipeMerchantCosts(recipeId);
      state = state.copyWith(merchantCosts: costs, loadingMerchantCosts: false);
    } on Exception catch (_) {
      state = state.copyWith(loadingMerchantCosts: false);
    }
  }

  Future<void> _loadMerchantPrices() async {
    final detail = state.detail;
    if (detail == null) return;
    final ingredients =
        detail.ingredients.where((i) => i.ingredientId != null).toList();
    if (ingredients.isEmpty) return;
    state = state.copyWith(loadingMerchantPrices: true);
    try {
      // 并发控制对齐 web：每批 3 个 + 全局 35s 超时，保留已有部分结果
      final results = <MerchantPriceItem>[];
      final start = DateTime.now();
      const concurrency = 3;
      const globalTimeout = Duration(seconds: 35);
      for (var i = 0; i < ingredients.length; i += concurrency) {
        if (DateTime.now().difference(start) > globalTimeout) break;
        final batch = ingredients.sublist(
            i, (i + concurrency).clamp(0, ingredients.length));
        final futures = batch.map((ing) async {
          final q = resolveIngredientQuantity(ing);
          try {
            return await _repo.getIngredientMerchantPrice(ing.ingredientId!,
                recipeIngredientId: ing.id,
                ingredientName: ing.name,
                quantity: q.qty,
                quantityUnit: q.qtyUnit);
          } catch (_) {
            return null;
          }
        });
        final settled = await Future.wait(futures);
        results.addAll(settled.whereType<MerchantPriceItem>());
      }
      state =
          state.copyWith(merchantPrices: results, loadingMerchantPrices: false);
    } on Exception catch (_) {
      state = state.copyWith(loadingMerchantPrices: false);
    }
  }

  /// 切换成本趋势时间范围（周/月/季）
  Future<void> reloadHistory(int days) async {
    state = state.copyWith(loadingHistory: true);
    try {
      final history = await _repo.getRecipeCostHistory(recipeId, days: days);
      state = state.copyWith(costHistory: history, loadingHistory: false);
    } on Exception catch (_) {
      state = state.copyWith(loadingHistory: false);
    }
  }

  void setServings(int servings) {
    if (servings < 1) return;
    state = state.copyWith(displayServings: servings);
  }
}

final recipeDetailPageProvider = StateNotifierProvider.family<
    RecipeDetailPageNotifier, RecipeDetailPageState, int>((ref, id) {
  return RecipeDetailPageNotifier(RecipeRepository(), id);
});

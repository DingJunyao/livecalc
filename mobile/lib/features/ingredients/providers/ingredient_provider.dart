import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/entity_unit.dart';
import '../../../shared/models/ingredient_recipe.dart';
import '../../../shared/models/merchant_price.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/models/nutrition.dart';
import '../../entities/repositories/entity_repository.dart';
import '../../nutrition/repositories/nutrition_repository.dart';
import '../../nutrition/models/usda_models.dart';
import '../../prices/models/price_record.dart';
import '../../prices/repositories/price_repository.dart';
import '../../prices/utils/price_trend.dart';
import '../../products/models/product.dart';
import '../../products/repositories/product_repository.dart';
import '../../recipes/repositories/recipe_repository.dart'
    show CostHistoryPoint;
import '../models/ingredient.dart';
import '../models/ingredient_category.dart';
import '../repositories/ingredient_repository.dart';

const int ingredientPageSize = 20;
const _absent = Object();

class IngredientListState {
  final List<Ingredient> items;
  final bool loading;
  final bool loadingMore;
  final bool loadingDetails;
  final String? error;
  final String searchQuery;
  final List<int> filterCategoryIds;
  final List<String> conditions;
  final int total;
  final int currentPage;
  final bool hasMore;
  final Map<int, LatestPriceInfo> latestPrices;
  final Map<int, List<double>> sparklines;

  const IngredientListState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.loadingDetails = false,
    this.error,
    this.searchQuery = '',
    this.filterCategoryIds = const [],
    this.conditions = const [],
    this.total = 0,
    this.currentPage = 1,
    this.hasMore = true,
    this.latestPrices = const {},
    this.sparklines = const {},
  });

  IngredientListState copyWith({
    List<Ingredient>? items,
    bool? loading,
    bool? loadingMore,
    bool? loadingDetails,
    String? error,
    bool clearError = false,
    String? searchQuery,
    List<int>? filterCategoryIds,
    List<String>? conditions,
    int? total,
    int? currentPage,
    bool? hasMore,
    Map<int, LatestPriceInfo>? latestPrices,
    Map<int, List<double>>? sparklines,
  }) {
    return IngredientListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      loadingDetails: loadingDetails ?? this.loadingDetails,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      filterCategoryIds: filterCategoryIds ?? this.filterCategoryIds,
      conditions: conditions ?? this.conditions,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      latestPrices: latestPrices ?? this.latestPrices,
      sparklines: sparklines ?? this.sparklines,
    );
  }
}

class IngredientListNotifier extends StateNotifier<IngredientListState> {
  final IngredientRepository _repo;
  Timer? _debounce;

  IngredientListNotifier([IngredientRepository? repository])
      : _repo = repository ?? IngredientRepository(),
        super(const IngredientListState());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int get activeFilterCount =>
      (state.filterCategoryIds.isNotEmpty ? 1 : 0) +
      (state.conditions.isNotEmpty ? 1 : 0);

  bool get canLoadMore => state.hasMore && !state.loading && !state.loadingMore;

  Future<void> load({bool loadMore = false}) async {
    if (loadMore && !state.hasMore) return;
    final page = loadMore ? state.currentPage + 1 : 1;
    state = state.copyWith(
      loading: !loadMore,
      loadingMore: loadMore,
      clearError: true,
    );
    try {
      final result = await _repo.search(
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        categoryIds:
            state.filterCategoryIds.isEmpty ? null : state.filterCategoryIds,
        conditions: state.conditions.isEmpty ? null : state.conditions,
        skip: (page - 1) * ingredientPageSize,
        limit: ingredientPageSize,
      );
      final items = loadMore ? [...state.items, ...result.items] : result.items;
      state = state.copyWith(
        items: items,
        total: result.total,
        currentPage: page,
        hasMore: items.length < result.total,
        loading: false,
        loadingMore: false,
      );
      _loadDetails(items);
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
    _debounce = Timer(const Duration(milliseconds: 400), () => load());
  }

  void applyFilters({
    required List<int> categoryIds,
    required List<String> conditions,
  }) {
    state = state.copyWith(
      filterCategoryIds: categoryIds,
      conditions: conditions,
    );
    load();
  }

  Future<void> addIngredient({
    required String name,
    int? categoryId,
    List<String> aliases = const [],
  }) async {
    await _repo.createIngredient(
      name: name,
      categoryId: categoryId,
      aliases: aliases,
    );
    await load();
  }

  /// 后台批量加载最新价与迷你图（与 Web 端 loadLatestPrices/Sparklines 对应）。
  Future<void> _loadDetails(List<Ingredient> items) async {
    if (items.isEmpty) return;
    state = state.copyWith(loadingDetails: true);
    try {
      final priceMap = await _repo.getLatestPrices(
        items.map((i) => i.id).toList(),
      );
      final sparkMap = await _repo.getSparklines(
        items.map((i) => i.id).toList(),
      );
      state = state.copyWith(
        loadingDetails: false,
        latestPrices: priceMap,
        sparklines: sparkMap,
      );
    } on Exception {
      state = state.copyWith(loadingDetails: false);
    }
  }
}

final ingredientListProvider =
    StateNotifierProvider<IngredientListNotifier, IngredientListState>((ref) {
  return IngredientListNotifier(IngredientRepository());
});

/// 分类选项（列表筛选与添加/编辑表单共用）。
final ingredientCategoriesProvider = FutureProvider<List<IngredientCategory>>(
    (ref) => IngredientRepository().getCategories());

final ingredientDetailProvider =
    FutureProvider.family<Ingredient, int>((ref, id) async {
  return IngredientRepository().getIngredient(id);
});

/// 原料下拉选项（商品筛选/添加表单共用，取前 100 条）。
final ingredientOptionsProvider =
    FutureProvider.autoDispose<List<Ingredient>>((ref) async {
  final result = await IngredientRepository().search(
    limit: 100,
    sortBy: 'name',
  );
  return result.items;
});

// ---------- 原料详情页聚合状态 ----------

class IngredientDetailPageState {
  final Ingredient? ingredient;
  final LatestPriceInfo? latestPrice;
  final List<MerchantPrice> merchantPrices;
  final List<Product> products;
  final Map<int, LatestPriceInfo> productPrices;
  final List<PriceRecord> records;
  final List<CostHistoryPoint> chartPoints;
  final bool loading;
  final bool loadingLatest;
  final bool loadingMerchants;
  final bool loadingProducts;
  final bool loadingRecords;
  final bool loadingChart;
  final int recordsPage;
  final bool recordsHasMore;
  final NutritionInfo? nutrition;
  final bool loadingNutrition;
  final bool savingNutrition;
  final List<EntityUnit> units;
  final List<UnmappedUnit> unmappedUnits;
  final List<EntityDensity> densities;
  final bool loadingUnits;
  final List<IngredientRecipeRef> recipes;
  final bool loadingRecipes;
  final int recipesPage;
  final bool recipesHasMore;
  final IngredientHierarchyData? hierarchy;
  final bool loadingHierarchy;
  final String? error;

  const IngredientDetailPageState({
    this.ingredient,
    this.latestPrice,
    this.merchantPrices = const [],
    this.products = const [],
    this.productPrices = const {},
    this.records = const [],
    this.chartPoints = const [],
    this.loading = false,
    this.loadingLatest = false,
    this.loadingMerchants = false,
    this.loadingProducts = false,
    this.loadingRecords = false,
    this.loadingChart = false,
    this.recordsPage = 1,
    this.recordsHasMore = false,
    this.nutrition,
    this.loadingNutrition = false,
    this.savingNutrition = false,
    this.units = const [],
    this.unmappedUnits = const [],
    this.densities = const [],
    this.loadingUnits = false,
    this.recipes = const [],
    this.loadingRecipes = false,
    this.recipesPage = 1,
    this.recipesHasMore = false,
    this.hierarchy,
    this.loadingHierarchy = false,
    this.error,
  });

  IngredientDetailPageState copyWith({
    Ingredient? ingredient,
    Object? latestPrice = _absent,
    List<MerchantPrice>? merchantPrices,
    List<Product>? products,
    Map<int, LatestPriceInfo>? productPrices,
    List<PriceRecord>? records,
    List<CostHistoryPoint>? chartPoints,
    bool? loading,
    bool? loadingLatest,
    bool? loadingMerchants,
    bool? loadingProducts,
    bool? loadingRecords,
    bool? loadingChart,
    int? recordsPage,
    bool? recordsHasMore,
    Object? nutrition = _absent,
    bool? loadingNutrition,
    bool? savingNutrition,
    List<EntityUnit>? units,
    List<UnmappedUnit>? unmappedUnits,
    List<EntityDensity>? densities,
    bool? loadingUnits,
    List<IngredientRecipeRef>? recipes,
    bool? loadingRecipes,
    int? recipesPage,
    bool? recipesHasMore,
    Object? hierarchy = _absent,
    bool? loadingHierarchy,
    String? error,
    bool clearError = false,
  }) {
    return IngredientDetailPageState(
      ingredient: ingredient ?? this.ingredient,
      latestPrice: identical(latestPrice, _absent)
          ? this.latestPrice
          : latestPrice as LatestPriceInfo?,
      merchantPrices: merchantPrices ?? this.merchantPrices,
      products: products ?? this.products,
      productPrices: productPrices ?? this.productPrices,
      records: records ?? this.records,
      chartPoints: chartPoints ?? this.chartPoints,
      loading: loading ?? this.loading,
      loadingLatest: loadingLatest ?? this.loadingLatest,
      loadingMerchants: loadingMerchants ?? this.loadingMerchants,
      loadingProducts: loadingProducts ?? this.loadingProducts,
      loadingRecords: loadingRecords ?? this.loadingRecords,
      loadingChart: loadingChart ?? this.loadingChart,
      recordsPage: recordsPage ?? this.recordsPage,
      recordsHasMore: recordsHasMore ?? this.recordsHasMore,
      nutrition: identical(nutrition, _absent)
          ? this.nutrition
          : nutrition as NutritionInfo?,
      loadingNutrition: loadingNutrition ?? this.loadingNutrition,
      savingNutrition: savingNutrition ?? this.savingNutrition,
      units: units ?? this.units,
      unmappedUnits: unmappedUnits ?? this.unmappedUnits,
      densities: densities ?? this.densities,
      loadingUnits: loadingUnits ?? this.loadingUnits,
      recipes: recipes ?? this.recipes,
      loadingRecipes: loadingRecipes ?? this.loadingRecipes,
      recipesPage: recipesPage ?? this.recipesPage,
      recipesHasMore: recipesHasMore ?? this.recipesHasMore,
      hierarchy: identical(hierarchy, _absent)
          ? this.hierarchy
          : hierarchy as IngredientHierarchyData?,
      loadingHierarchy: loadingHierarchy ?? this.loadingHierarchy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class IngredientDetailPageNotifier
    extends StateNotifier<IngredientDetailPageState> {
  final IngredientRepository _ingRepo;
  final ProductRepository _productRepo;
  final PriceRepository _priceRepo;
  final NutritionRepository _nutritionRepo;
  final EntityRepository _entityRepo;
  final int ingredientId;

  IngredientDetailPageNotifier(this.ingredientId)
      : _ingRepo = IngredientRepository(),
        _productRepo = ProductRepository(),
        _priceRepo = PriceRepository(),
        _nutritionRepo = NutritionRepository(),
        _entityRepo = EntityRepository(),
        super(const IngredientDetailPageState());

  String _startDateFor(int days) {
    if (days >= 3650) return '';
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> load({int initialDays = 30}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final ingredient = await _ingRepo.getIngredient(ingredientId);
      state = state.copyWith(ingredient: ingredient, loading: false);
      await Future.wait([
        _loadLatestPrice(),
        _loadMerchantPrices(),
        _loadProducts(),
        _loadRecords(),
        _loadChart(days: initialDays),
        _loadNutrition(),
        _loadUnits(),
        _loadRecipes(),
        _loadHierarchy(),
      ]);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> _loadLatestPrice() async {
    state = state.copyWith(loadingLatest: true);
    try {
      final info = await _ingRepo.getLatestPrice(ingredientId);
      state = state.copyWith(latestPrice: info, loadingLatest: false);
    } on Exception {
      state = state.copyWith(loadingLatest: false);
    }
  }

  Future<void> _loadMerchantPrices() async {
    state = state.copyWith(loadingMerchants: true);
    try {
      final prices = await _ingRepo.getLatestPricesByMerchant(ingredientId);
      state = state.copyWith(merchantPrices: prices, loadingMerchants: false);
    } on Exception {
      state = state.copyWith(loadingMerchants: false);
    }
  }

  Future<void> _loadProducts() async {
    state = state.copyWith(loadingProducts: true);
    try {
      final result = await _productRepo.search(
        ingredientId: ingredientId,
        sortBy: 'price_records',
        limit: 50,
      );
      state = state.copyWith(products: result.items, loadingProducts: false);
    } on Exception {
      state = state.copyWith(loadingProducts: false);
    }
  }

  Future<void> refreshProducts() => _loadProducts();

  /// 加载单个关联商品的最新价（详情页关联商品行展示用）。
  Future<void> loadProductPrice(int productId) async {
    try {
      final info = await _productRepo.getLatestPrice(productId);
      state = state.copyWith(productPrices: {
        ...state.productPrices,
        productId: info,
      });
    } on Exception {
      // 忽略单个商品价格加载失败
    }
  }

  Future<void> _loadRecords() async {
    state = state.copyWith(loadingRecords: true);
    try {
      final result = await _priceRepo.getRecords(
        ingredientId: ingredientId,
        page: 1,
        pageSize: 10,
      );
      state = state.copyWith(
        records: result.records,
        recordsPage: 1,
        recordsHasMore: result.records.length < result.total,
        loadingRecords: false,
      );
    } on Exception {
      state = state.copyWith(loadingRecords: false);
    }
  }

  Future<void> loadMoreRecords() async {
    if (state.loadingRecords || !state.recordsHasMore) return;
    state = state.copyWith(loadingRecords: true);
    try {
      final next = state.recordsPage + 1;
      final result = await _priceRepo.getRecords(
        ingredientId: ingredientId,
        page: next,
        pageSize: 10,
      );
      state = state.copyWith(
        records: [...state.records, ...result.records],
        recordsPage: next,
        recordsHasMore:
            state.records.length + result.records.length < result.total,
        loadingRecords: false,
      );
    } on Exception {
      state = state.copyWith(loadingRecords: false);
    }
  }

  Future<void> reloadChart(int days) => _loadChart(days: days);

  Future<void> _loadChart({required int days}) async {
    state = state.copyWith(loadingChart: true);
    try {
      final startDate = _startDateFor(days);
      final result = await _priceRepo.getRecords(
        ingredientId: ingredientId,
        startDate: startDate.isEmpty ? null : startDate,
        page: 1,
        pageSize: 500,
      );
      state = state.copyWith(
        chartPoints: buildPriceTrendPoints(result.records),
        loadingChart: false,
      );
    } on Exception {
      state = state.copyWith(loadingChart: false);
    }
  }

  // ---- 营养成分 ----

  Future<void> _loadNutrition() async {
    state = state.copyWith(loadingNutrition: true);
    try {
      final info = await _nutritionRepo.getIngredientNutrition(ingredientId);
      state = state.copyWith(nutrition: info, loadingNutrition: false);
    } on Exception {
      state = state.copyWith(loadingNutrition: false);
    }
  }

  Future<Object?> saveNutrition(List<NutrientEntry> nutrients) async {
    state = state.copyWith(savingNutrition: true);
    try {
      final result =
          await _nutritionRepo.saveIngredientNutrition(ingredientId, nutrients);
      if (!result.pending) await _loadNutrition();
      return result;
    } finally {
      state = state.copyWith(savingNutrition: false);
    }
  }

  // ---- 单位与密度 ----

  Future<void> _loadUnits() async {
    state = state.copyWith(loadingUnits: true);
    try {
      final units = await _entityRepo.listUnits('ingredient', ingredientId);
      final unmapped =
          await _entityRepo.listUnmappedUnits('ingredient', ingredientId);
      final densities =
          await _entityRepo.listDensities('ingredient', ingredientId);
      state = state.copyWith(
        units: units,
        unmappedUnits: unmapped,
        densities: densities,
        loadingUnits: false,
      );
    } on Exception {
      state = state.copyWith(loadingUnits: false);
    }
  }

  Future<Object?> addUnit({
    required String unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool isDefault = false,
    bool isAdmin = true,
  }) async {
    final result = await _entityRepo.createUnit(
      'ingredient',
      ingredientId,
      unitName: unitName,
      conversionFactor: conversionFactor,
      weightPerUnit: weightPerUnit,
      isDefault: isDefault,
      isAdmin: isAdmin,
    );
    if (result.applied) await _loadUnits();
    return result;
  }

  Future<Object?> updateUnit(
    int unitId, {
    String? unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool? isDefault,
    bool isAdmin = true,
  }) async {
    final result = await _entityRepo.updateUnit(
      'ingredient',
      ingredientId,
      unitId,
      unitName: unitName,
      conversionFactor: conversionFactor,
      weightPerUnit: weightPerUnit,
      isDefault: isDefault,
      isAdmin: isAdmin,
    );
    if (result.applied) await _loadUnits();
    return result;
  }

  Future<Object?> deleteUnit(int unitId) async {
    final result =
        await _entityRepo.deleteUnit('ingredient', ingredientId, unitId);
    if (result.applied) await _loadUnits();
    return result;
  }

  /// 快捷添加未映射单位（默认 1 个 = 100g）。
  Future<Object?> quickAddUnmappedUnit(
    UnmappedUnit unit, {
    bool isAdmin = true,
  }) async {
    final result = await _entityRepo.createUnit(
      'ingredient',
      ingredientId,
      unitName: unit.unitName,
      weightPerUnit: 100,
      isAdmin: isAdmin,
    );
    if (result.applied) await _loadUnits();
    return result;
  }

  Future<Object?> addDensity({
    required double density,
    String? condition,
    bool isAdmin = true,
  }) async {
    final result = await _entityRepo.upsertDensity(
      'ingredient',
      ingredientId,
      density: density,
      condition: condition,
      isAdmin: isAdmin,
    );
    if (result.applied) await _loadUnits();
    return result;
  }

  Future<Object?> deleteDensity(int densityId) async {
    final result = await _entityRepo.deleteDensity(
      'ingredient',
      ingredientId,
      densityId,
    );
    if (result.applied) await _loadUnits();
    return result;
  }

  // ---- 关联菜谱 ----

  Future<void> _loadRecipes() async {
    state = state.copyWith(loadingRecipes: true);
    try {
      final result = await _ingRepo.getRelatedRecipes(ingredientId, limit: 10);
      state = state.copyWith(
        recipes: result.items,
        recipesPage: 1,
        recipesHasMore: result.items.length < result.total,
        loadingRecipes: false,
      );
    } on Exception {
      state = state.copyWith(loadingRecipes: false);
    }
  }

  Future<void> loadMoreRecipes() async {
    if (state.loadingRecipes || !state.recipesHasMore) return;
    state = state.copyWith(loadingRecipes: true);
    try {
      final next = state.recipesPage + 1;
      final result = await _ingRepo.getRelatedRecipes(
        ingredientId,
        skip: next * 10 - 10,
        limit: 10,
      );
      state = state.copyWith(
        recipes: [...state.recipes, ...result.items],
        recipesPage: next,
        recipesHasMore:
            state.recipes.length + result.items.length < result.total,
        loadingRecipes: false,
      );
    } on Exception {
      state = state.copyWith(loadingRecipes: false);
    }
  }

  // ---- 层级关系 ----

  Future<void> _loadHierarchy() async {
    state = state.copyWith(loadingHierarchy: true);
    try {
      final data = await _ingRepo.getHierarchy(ingredientId);
      state = state.copyWith(hierarchy: data, loadingHierarchy: false);
    } on Exception {
      state = state.copyWith(loadingHierarchy: false);
    }
  }

  Future<Object?> addHierarchyRelation({
    required int parentId,
    required int childId,
    required String relationType,
    int strength = 50,
    bool isAdmin = true,
  }) async {
    final result = await _ingRepo.createHierarchyRelation(
      parentId: parentId,
      childId: childId,
      relationType: relationType,
      strength: strength,
      isAdmin: isAdmin,
    );
    if (result.applied) await _loadHierarchy();
    return result;
  }

  Future<Object?> updateHierarchyRelation(
    int relationId, {
    required int strength,
    bool isAdmin = true,
  }) async {
    final result = await _ingRepo.updateHierarchyRelation(
      relationId,
      strength: strength,
      isAdmin: isAdmin,
    );
    if (result.applied) await _loadHierarchy();
    return result;
  }

  Future<Object?> deleteHierarchyRelation(int relationId) async {
    final result = await _ingRepo.deleteHierarchyRelation(relationId);
    if (result.applied) await _loadHierarchy();
    return result;
  }

  Future<void> addRecord({
    required int productId,
    required double price,
    required double quantity,
    required String unit,
    int? merchantId,
  }) async {
    await _priceRepo.createRecord(
      productId: productId,
      price: price,
      quantity: quantity,
      unit: unit,
      merchantId: merchantId,
    );
    await _refreshAfterRecordChange();
  }

  Future<void> updateRecord(
    int recordId, {
    required double price,
    required double quantity,
    required String unit,
    int? merchantId,
  }) async {
    await _priceRepo.updateRecord(
      recordId,
      price: price,
      quantity: quantity,
      unit: unit,
      merchantId: merchantId,
    );
    await _refreshAfterRecordChange();
  }

  Future<void> deleteRecord(int recordId) async {
    await _priceRepo.deleteRecord(recordId);
    await _refreshAfterRecordChange();
  }

  Future<void> _refreshAfterRecordChange() async {
    await Future.wait([
      _loadLatestPrice(),
      _loadMerchantPrices(),
      _loadRecords(),
      _loadChart(days: 30),
    ]);
  }

  Future<void> addProduct({
    required String name,
    required int ingredientId,
    String? brand,
    String? barcode,
    List<String> aliases = const [],
  }) async {
    await _productRepo.createProduct(
      name: name,
      ingredientId: ingredientId,
      brand: brand,
      barcode: barcode,
      aliases: aliases,
    );
    await _loadProducts();
  }

  Future<MutationReviewResult> deleteProduct(int productId) async {
    final review = await _productRepo.deleteProduct(productId);
    if (review.applied) await _loadProducts();
    return review;
  }
}

final ingredientDetailPageProvider = StateNotifierProvider.autoDispose
    .family<IngredientDetailPageNotifier, IngredientDetailPageState, int>(
  (ref, id) => IngredientDetailPageNotifier(id),
);

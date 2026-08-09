import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/entity_unit.dart';
import '../../../shared/models/merchant_price.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/models/nutrition.dart';
import '../../entities/repositories/entity_repository.dart';
import '../../nutrition/repositories/nutrition_repository.dart';
import '../../prices/models/price_record.dart';
import '../../prices/repositories/price_repository.dart';
import '../../prices/utils/price_trend.dart';
import '../../recipes/repositories/recipe_repository.dart' show CostHistoryPoint;
import '../models/product.dart';
import '../repositories/product_repository.dart';

const int productPageSize = 20;

class ProductListState {
  final List<Product> items;
  final bool loading;
  final bool loadingMore;
  final bool loadingDetails;
  final String? error;
  final String searchQuery;
  final int? filterIngredientId;
  final List<int> filterCategoryIds;
  final String? filterBrand;
  final List<String> conditions;
  final int total;
  final int currentPage;
  final bool hasMore;
  final Map<int, LatestPriceInfo> latestPrices;
  final Map<int, List<double>> sparklines;

  const ProductListState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.loadingDetails = false,
    this.error,
    this.searchQuery = '',
    this.filterIngredientId,
    this.filterCategoryIds = const [],
    this.filterBrand,
    this.conditions = const [],
    this.total = 0,
    this.currentPage = 1,
    this.hasMore = true,
    this.latestPrices = const {},
    this.sparklines = const {},
  });

  ProductListState copyWith({
    List<Product>? items,
    bool? loading,
    bool? loadingMore,
    bool? loadingDetails,
    String? error,
    bool clearError = false,
    String? searchQuery,
    Object? filterIngredientId = _absent,
    List<int>? filterCategoryIds,
    Object? filterBrand = _absent,
    List<String>? conditions,
    int? total,
    int? currentPage,
    bool? hasMore,
    Map<int, LatestPriceInfo>? latestPrices,
    Map<int, List<double>>? sparklines,
  }) {
    return ProductListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      loadingDetails: loadingDetails ?? this.loadingDetails,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      filterIngredientId: identical(filterIngredientId, _absent)
          ? this.filterIngredientId
          : filterIngredientId as int?,
      filterCategoryIds: filterCategoryIds ?? this.filterCategoryIds,
      filterBrand: identical(filterBrand, _absent)
          ? this.filterBrand
          : filterBrand as String?,
      conditions: conditions ?? this.conditions,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      latestPrices: latestPrices ?? this.latestPrices,
      sparklines: sparklines ?? this.sparklines,
    );
  }
}

const _absent = Object();

class ProductListNotifier extends StateNotifier<ProductListState> {
  final ProductRepository _repo;
  Timer? _debounce;

  ProductListNotifier(this._repo) : super(const ProductListState());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int get activeFilterCount =>
      (state.filterIngredientId != null ? 1 : 0) +
      (state.filterCategoryIds.isNotEmpty ? 1 : 0) +
      (state.filterBrand != null ? 1 : 0) +
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
        ingredientId: state.filterIngredientId,
        ingredientCategoryIds: state.filterCategoryIds.isEmpty
            ? null
            : state.filterCategoryIds,
        brands: state.filterBrand == null ? null : [state.filterBrand!],
        conditions: state.conditions.isEmpty ? null : state.conditions,
        skip: (page - 1) * productPageSize,
        limit: productPageSize,
      );
      final items =
          loadMore ? [...state.items, ...result.items] : result.items;
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
    int? ingredientId,
    List<int> categoryIds = const [],
    String? brand,
    List<String> conditions = const [],
  }) {
    state = state.copyWith(
      filterIngredientId: ingredientId,
      filterCategoryIds: categoryIds,
      filterBrand: brand,
      conditions: conditions,
    );
    load();
  }

  Future<void> addProduct({
    required String name,
    required int ingredientId,
    String? brand,
    String? barcode,
    List<String> aliases = const [],
  }) async {
    await _repo.createProduct(
      name: name,
      ingredientId: ingredientId,
      brand: brand,
      barcode: barcode,
      aliases: aliases,
    );
    await load();
  }

  Future<void> _loadDetails(List<Product> items) async {
    if (items.isEmpty) return;
    state = state.copyWith(loadingDetails: true);
    try {
      final prices = await Future.wait(
        items.map((p) => _repo.getLatestPrice(p.id)),
      );
      final priceMap = <int, LatestPriceInfo>{
        for (var i = 0; i < items.length; i++) items[i].id: prices[i],
      };
      final sparkMap = await _repo.getSparklines(
        items.map((p) => p.id).toList(),
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

final productListProvider = StateNotifierProvider<ProductListNotifier,
    ProductListState>((ref) {
  return ProductListNotifier(ProductRepository());
});

final productDetailProvider =
    FutureProvider.family<Product, int>((ref, id) async {
  return ProductRepository().getProduct(id);
});

// ---------- 商品详情页聚合状态 ----------

class ProductDetailPageState {
  final Product? product;
  final LatestPriceInfo? latestPrice;
  final List<MerchantPrice> merchantPrices;
  final List<PriceRecord> records;
  final List<CostHistoryPoint> chartPoints;
  final bool loading;
  final bool loadingLatest;
  final bool loadingMerchants;
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
  final String? error;

  const ProductDetailPageState({
    this.product,
    this.latestPrice,
    this.merchantPrices = const [],
    this.records = const [],
    this.chartPoints = const [],
    this.loading = false,
    this.loadingLatest = false,
    this.loadingMerchants = false,
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
    this.error,
  });

  ProductDetailPageState copyWith({
    Product? product,
    Object? latestPrice = _absent,
    List<MerchantPrice>? merchantPrices,
    List<PriceRecord>? records,
    List<CostHistoryPoint>? chartPoints,
    bool? loading,
    bool? loadingLatest,
    bool? loadingMerchants,
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
    String? error,
    bool clearError = false,
  }) {
    return ProductDetailPageState(
      product: product ?? this.product,
      latestPrice: identical(latestPrice, _absent)
          ? this.latestPrice
          : latestPrice as LatestPriceInfo?,
      merchantPrices: merchantPrices ?? this.merchantPrices,
      records: records ?? this.records,
      chartPoints: chartPoints ?? this.chartPoints,
      loading: loading ?? this.loading,
      loadingLatest: loadingLatest ?? this.loadingLatest,
      loadingMerchants: loadingMerchants ?? this.loadingMerchants,
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
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ProductDetailPageNotifier extends StateNotifier<ProductDetailPageState> {
  final ProductRepository _productRepo;
  final PriceRepository _priceRepo;
  final NutritionRepository _nutritionRepo;
  final EntityRepository _entityRepo;
  final int productId;

  ProductDetailPageNotifier(this.productId)
      : _productRepo = ProductRepository(),
        _priceRepo = PriceRepository(),
        _nutritionRepo = NutritionRepository(),
        _entityRepo = EntityRepository(),
        super(const ProductDetailPageState());

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
      final product = await _productRepo.getProduct(productId);
      state = state.copyWith(product: product, loading: false);
      await Future.wait([
        _loadLatestPrice(),
        _loadMerchantPrices(),
        _loadRecords(),
        _loadChart(days: initialDays),
        _loadNutrition(),
        _loadUnits(),
      ]);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> _loadLatestPrice() async {
    state = state.copyWith(loadingLatest: true);
    try {
      final info = await _productRepo.getLatestPrice(productId);
      state = state.copyWith(latestPrice: info, loadingLatest: false);
    } on Exception {
      state = state.copyWith(loadingLatest: false);
    }
  }

  Future<void> _loadMerchantPrices() async {
    state = state.copyWith(loadingMerchants: true);
    try {
      final prices = await _productRepo.getLatestPricesByMerchant(productId);
      state = state.copyWith(merchantPrices: prices, loadingMerchants: false);
    } on Exception {
      state = state.copyWith(loadingMerchants: false);
    }
  }

  Future<void> _loadRecords() async {
    state = state.copyWith(loadingRecords: true);
    try {
      final result = await _priceRepo.getRecords(
        productId: productId,
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
        productId: productId,
        page: next,
        pageSize: 10,
      );
      state = state.copyWith(
        records: [...state.records, ...result.records],
        recordsPage: next,
        recordsHasMore: state.records.length + result.records.length <
            result.total,
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
        productId: productId,
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
      final info = await _nutritionRepo.getProductNutrition(productId);
      state = state.copyWith(nutrition: info, loadingNutrition: false);
    } on Exception {
      state = state.copyWith(loadingNutrition: false);
    }
  }

  Future<void> saveNutrition(List<NutrientEntry> nutrients) async {
    state = state.copyWith(savingNutrition: true);
    try {
      await _nutritionRepo.saveProductNutrition(productId, nutrients);
      await _loadNutrition();
    } finally {
      state = state.copyWith(savingNutrition: false);
    }
  }

  Future<void> clearNutrition() async {
    state = state.copyWith(savingNutrition: true);
    try {
      await _nutritionRepo.clearProductNutrition(productId);
      await _loadNutrition();
    } finally {
      state = state.copyWith(savingNutrition: false);
    }
  }

  // ---- 单位与密度 ----

  Future<void> _loadUnits() async {
    state = state.copyWith(loadingUnits: true);
    try {
      final units = await _entityRepo.listUnits('product', productId);
      final unmapped =
          await _entityRepo.listUnmappedUnits('product', productId);
      final densities = await _entityRepo.listDensities('product', productId);
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

  Future<void> addUnit({
    required String unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool isDefault = false,
  }) async {
    await _entityRepo.createUnit(
      'product',
      productId,
      unitName: unitName,
      conversionFactor: conversionFactor,
      weightPerUnit: weightPerUnit,
      isDefault: isDefault,
    );
    await _loadUnits();
  }

  Future<void> updateUnit(
    int unitId, {
    String? unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool? isDefault,
  }) async {
    await _entityRepo.updateUnit(
      'product',
      productId,
      unitId,
      unitName: unitName,
      conversionFactor: conversionFactor,
      weightPerUnit: weightPerUnit,
      isDefault: isDefault,
    );
    await _loadUnits();
  }

  Future<void> deleteUnit(int unitId) async {
    await _entityRepo.deleteUnit('product', productId, unitId);
    await _loadUnits();
  }

  Future<void> quickAddUnmappedUnit(UnmappedUnit unit) async {
    await _entityRepo.createUnit(
      'product',
      productId,
      unitName: unit.unitName,
      weightPerUnit: 100,
    );
    await _loadUnits();
  }

  Future<void> addDensity({
    required double density,
    String? condition,
  }) async {
    await _entityRepo.upsertDensity(
      'product',
      productId,
      density: density,
      condition: condition,
    );
    await _loadUnits();
  }

  Future<void> deleteDensity(int densityId) async {
    await _entityRepo.deleteDensity('product', productId, densityId);
    await _loadUnits();
  }

  Future<void> addRecord({
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

  Future<void> updateBasic({
    String? name,
    int? ingredientId,
    String? brand,
    String? barcode,
    List<String>? aliases,
  }) async {
    final updated = await _productRepo.updateProduct(
      productId,
      name: name,
      ingredientId: ingredientId,
      brand: brand,
      barcode: barcode,
      aliases: aliases,
    );
    state = state.copyWith(product: updated);
  }
}

final productDetailPageProvider =
    StateNotifierProvider.autoDispose.family<
        ProductDetailPageNotifier, ProductDetailPageState, int>(
  (ref, id) => ProductDetailPageNotifier(id),
);

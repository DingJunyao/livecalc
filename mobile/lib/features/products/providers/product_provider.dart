import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/entity_unit.dart';
import '../../../shared/models/merchant_price.dart';
import '../../../shared/models/latest_price.dart';
import '../../../shared/models/nutrition.dart';
import '../../../shared/models/entity_pending_proposal.dart';
import '../../entities/repositories/entity_repository.dart';
import '../../nutrition/repositories/nutrition_repository.dart';
import '../../nutrition/repositories/usda_repository.dart';
import '../../profile/models/proposal.dart';
import '../../profile/repositories/profile_repository.dart';
import '../../prices/models/price_record.dart';
import '../../prices/repositories/price_repository.dart';
import '../../prices/utils/price_trend.dart';
import '../../recipes/repositories/recipe_repository.dart'
    show CostHistoryPoint;
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
        ingredientCategoryIds:
            state.filterCategoryIds.isEmpty ? null : state.filterCategoryIds,
        brands: state.filterBrand == null ? null : [state.filterBrand!],
        conditions: state.conditions.isEmpty ? null : state.conditions,
        skip: (page - 1) * productPageSize,
        limit: productPageSize,
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

final productListProvider =
    StateNotifierProvider<ProductListNotifier, ProductListState>((ref) {
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
  final List<Proposal> pendingProposals;
  final Set<int> deletedUnitIds;
  final Set<int> deletedDensityIds;
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
    this.pendingProposals = const [],
    this.deletedUnitIds = const {},
    this.deletedDensityIds = const {},
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
    List<Proposal>? pendingProposals,
    Set<int>? deletedUnitIds,
    Set<int>? deletedDensityIds,
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
      pendingProposals: pendingProposals ?? this.pendingProposals,
      deletedUnitIds: deletedUnitIds ?? this.deletedUnitIds,
      deletedDensityIds: deletedDensityIds ?? this.deletedDensityIds,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ProductDetailPageNotifier extends StateNotifier<ProductDetailPageState> {
  final ProductRepository _productRepo;
  final PriceRepository _priceRepo;
  final NutritionRepository _nutritionRepo;
  final UsdaRepository _usdaRepo;
  final EntityRepository _entityRepo;
  final ProfileRepository _proposalRepo;
  final int productId;
  int? _regionId;

  ProductDetailPageNotifier(
    this.productId, {
    ProfileRepository? proposalRepository,
  })  : _productRepo = ProductRepository(),
        _priceRepo = PriceRepository(),
        _nutritionRepo = NutritionRepository(),
        _usdaRepo = UsdaRepository(),
        _entityRepo = EntityRepository(),
        _proposalRepo = proposalRepository ?? ProfileRepository(),
        super(const ProductDetailPageState());

  String _startDateFor(int days) {
    if (days >= 3650) return '';
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> load({int initialDays = 30, int? regionId}) async {
    _regionId = regionId;
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
      await _loadPendingProposals();
      _applyPendingDrafts();
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> setRegion(int? regionId) async {
    if (_regionId == regionId) return;
    _regionId = regionId;
    await Future.wait([_loadLatestPrice(), _loadMerchantPrices()]);
  }

  Future<void> _loadLatestPrice() async {
    state = state.copyWith(loadingLatest: true);
    try {
      final info =
          await _productRepo.getLatestPrice(productId, regionId: _regionId);
      state = state.copyWith(latestPrice: info, loadingLatest: false);
    } on Exception {
      state = state.copyWith(loadingLatest: false);
    }
  }

  Future<void> _loadMerchantPrices() async {
    state = state.copyWith(loadingMerchants: true);
    try {
      final prices = await _productRepo.getLatestPricesByMerchant(productId,
          regionId: _regionId);
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
        recordsHasMore:
            state.records.length + result.records.length < result.total,
        loadingRecords: false,
      );
    } on Exception {
      state = state.copyWith(loadingRecords: false);
    }
  }

  Future<void> reloadChart(int days) => _loadChart(days: days);

  Future<void> _loadPendingProposals() async {
    try {
      final proposals = await _proposalRepo.getProposals(
        status: 'pending',
        limit: 200,
      );
      state = state.copyWith(pendingProposals: proposals);
    } on Exception {
      // Draft display is supplementary and must not block official data.
    }
  }

  void _applyPendingDrafts() {
    final proposals = state.pendingProposals
        .where((proposal) => proposal.status == 'pending')
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final unitProposals = proposals
        .where((proposal) => proposal.entityType == 'entity_unit_override')
        .toList();
    final densityProposals = proposals
        .where((proposal) => proposal.entityType == 'entity_density')
        .toList();

    final deletedUnits = <int>{};
    final deletedDensities = <int>{};
    var units = state.units;
    var densities = state.densities;

    for (final proposal in unitProposals) {
      if (!_targetsProduct(proposal) && !_targetsLoadedUnit(proposal, units)) {
        continue;
      }
      if (proposal.action == 'delete') {
        final id = proposal.entityId;
        if (id != null) deletedUnits.add(id);
        units = units.where((unit) => unit.id != id).toList();
        continue;
      }
      final data = proposal.payload;
      if (proposal.action == 'create') {
        if (_payloadTargetsProduct(data) &&
            units.every(
                (unit) => unit.unitName != data['unit_name']?.toString())) {
          units = [
            ...units,
            EntityUnit(
              id: -proposal.id,
              unitName: data['unit_name']?.toString() ?? '',
              conversionFactor: _toDouble(data['conversion_factor']),
              weightPerUnit: _toDouble(data['weight_per_unit']),
              isDefault: data['is_default'] == true,
              source: 'pending',
              isPending: true,
            ),
          ];
        }
        continue;
      }
      units = [
        for (final unit in units)
          if (unit.id == proposal.entityId)
            EntityUnit(
              id: unit.id,
              unitName: data['unit_name']?.toString() ?? unit.unitName,
              conversionFactor: data.containsKey('conversion_factor')
                  ? _toDouble(data['conversion_factor'])
                  : unit.conversionFactor,
              weightPerUnit: data.containsKey('weight_per_unit')
                  ? _toDouble(data['weight_per_unit'])
                  : unit.weightPerUnit,
              isDefault: data.containsKey('is_default')
                  ? data['is_default'] == true
                  : unit.isDefault,
              source: 'pending',
              isPending: true,
            )
          else
            unit,
      ];
    }

    for (final proposal in densityProposals) {
      if (!_targetsProduct(proposal) &&
          !_targetsLoadedDensity(proposal, densities)) {
        continue;
      }
      if (proposal.action == 'delete') {
        final id = proposal.entityId;
        if (id != null) deletedDensities.add(id);
        densities = densities.where((density) => density.id != id).toList();
        continue;
      }
      final data = proposal.payload;
      if (proposal.action == 'create') {
        if (_payloadTargetsProduct(data)) {
          densities = [
            ...densities,
            EntityDensity(
              id: -proposal.id,
              density: _toDouble(data['density']) ?? 0,
              temperature: _toDouble(data['temperature']),
              condition: data['condition']?.toString(),
              source: 'pending',
              isPending: true,
            ),
          ];
        }
        continue;
      }
      densities = [
        for (final density in densities)
          if (density.id == proposal.entityId)
            EntityDensity(
              id: density.id,
              density: data.containsKey('density')
                  ? _toDouble(data['density']) ?? density.density
                  : density.density,
              temperature: data.containsKey('temperature')
                  ? _toDouble(data['temperature'])
                  : density.temperature,
              condition: data.containsKey('condition')
                  ? data['condition']?.toString()
                  : density.condition,
              source: 'pending',
              isPending: true,
            )
          else
            density,
      ];
    }

    state = state.copyWith(
      units: units,
      densities: densities,
      deletedUnitIds: deletedUnits,
      deletedDensityIds: deletedDensities,
    );
  }

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
        chartPoints: buildPriceTrendPoints(
          result.records,
          useStandardQuantity: true,
        ),
        loadingChart: false,
      );
    } on Exception {
      state = state.copyWith(loadingChart: false);
    }
  }

  // ---- 营养成分 ----

  Future<void> _loadNutrition() async {
    state = state.copyWith(loadingNutrition: true);
    final NutritionInfo? info;
    try {
      info = await _nutritionRepo.getProductNutrition(productId);
    } on Exception {
      state = state.copyWith(loadingNutrition: false);
      return;
    }

    await _loadPendingProposals();
    var merged = info?.mergedWithPending() ??
        _pendingManualNutrition(entityType: 'product_nutrition');
    try {
      final usda = await _loadPendingUsdaNutrition();
      if (usda != null &&
          (merged?.pendingProposal?.id ?? 0) < usda.pendingProposal!.id) {
        merged = usda;
      }
    } on Exception {
      // Official data remains visible if USDA draft enrichment fails.
    }
    state = state.copyWith(nutrition: merged, loadingNutrition: false);
  }

  Future<void> refreshNutrition() => _loadNutrition();

  Future<NutritionInfo?> _loadPendingUsdaNutrition() async {
    final proposal = state.pendingProposals
        .where((item) =>
            item.entityType == 'usda_product_match' &&
            item.entityId == productId &&
            item.status == 'pending')
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (proposal.isEmpty) return null;
    final fdcId = _toInt(proposal.last.payload['fdc_id']);
    if (fdcId == null) return null;
    final food = await _usdaRepo.getFood(fdcId);
    return NutritionInfo(
      entityId: productId,
      baseQuantity: 100,
      baseUnit: 'g',
      source: 'USDA（待审）',
      nutrients: [
        for (final nutrient in food.nutrients)
          if (nutrient.amount > 0)
            NutrientEntry(
              key: nutrient.displayName,
              label: nutrient.displayName,
              value: nutrient.amount,
              unit: nutrient.unit,
            ),
      ],
      pendingProposal: EntityPendingProposal(
        id: proposal.last.id,
        action: 'update',
        payload: proposal.last.payload,
      ),
    );
  }

  NutritionInfo? _pendingManualNutrition({
    required String entityType,
  }) {
    final proposals = state.pendingProposals
        .where((item) =>
            item.entityType == entityType &&
            item.entityId == productId &&
            item.status == 'pending' &&
            item.action == 'update')
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (proposals.isEmpty) return null;
    final proposal = proposals.last;
    return NutritionInfo.fromPendingProposal(
      entityId: productId,
      proposal: EntityPendingProposal(
        id: proposal.id,
        action: proposal.action,
        payload: proposal.payload,
      ),
    );
  }

  Future<Object?> saveNutrition(List<NutrientEntry> nutrients) async {
    state = state.copyWith(savingNutrition: true);
    try {
      final result =
          await _nutritionRepo.saveProductNutrition(productId, nutrients);
      await _loadNutrition();
      return result;
    } finally {
      state = state.copyWith(savingNutrition: false);
    }
  }

  Future<Object?> clearNutrition() async {
    state = state.copyWith(savingNutrition: true);
    try {
      final result = await _nutritionRepo.clearProductNutrition(productId);
      await _loadNutrition();
      return result;
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

  Future<void> _refreshUnitsAndPendingDrafts() async {
    await _loadUnits();
    await _loadPendingProposals();
    _applyPendingDrafts();
  }

  bool _targetsProduct(Proposal proposal) =>
      _payloadTargetsProduct(proposal.payload) ||
      _payloadTargetsProduct(proposal.snapshot);

  bool _payloadTargetsProduct(Map<String, dynamic> data) =>
      data['entity_type']?.toString() == 'product' &&
      _toInt(data['entity_id']) == productId;

  bool _targetsLoadedUnit(Proposal proposal, List<EntityUnit> units) =>
      proposal.entityId != null &&
      !proposal.payload.containsKey('entity_id') &&
      units.any((unit) => unit.id == proposal.entityId);

  bool _targetsLoadedDensity(
    Proposal proposal,
    List<EntityDensity> densities,
  ) =>
      proposal.entityId != null &&
      !proposal.payload.containsKey('entity_id') &&
      densities.any((density) => density.id == proposal.entityId);

  Future<Object?> addUnit({
    required String unitName,
    double? conversionFactor,
    double? weightPerUnit,
    bool isDefault = false,
    bool isAdmin = true,
  }) async {
    final result = await _entityRepo.createUnit(
      'product',
      productId,
      unitName: unitName,
      conversionFactor: conversionFactor,
      weightPerUnit: weightPerUnit,
      isDefault: isDefault,
      isAdmin: isAdmin,
    );
    await _refreshUnitsAndPendingDrafts();
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
      'product',
      productId,
      unitId,
      unitName: unitName,
      conversionFactor: conversionFactor,
      weightPerUnit: weightPerUnit,
      isDefault: isDefault,
      isAdmin: isAdmin,
    );
    await _refreshUnitsAndPendingDrafts();
    return result;
  }

  Future<Object?> deleteUnit(int unitId) async {
    final result = await _entityRepo.deleteUnit('product', productId, unitId);
    await _refreshUnitsAndPendingDrafts();
    return result;
  }

  Future<Object?> quickAddUnmappedUnit(
    UnmappedUnit unit, {
    bool isAdmin = true,
  }) async {
    final result = await _entityRepo.createUnit(
      'product',
      productId,
      unitName: unit.unitName,
      weightPerUnit: 100,
      isAdmin: isAdmin,
    );
    await _refreshUnitsAndPendingDrafts();
    return result;
  }

  Future<Object?> addDensity({
    required double density,
    String? condition,
    bool isAdmin = true,
  }) async {
    final result = await _entityRepo.upsertDensity(
      'product',
      productId,
      density: density,
      condition: condition,
      isAdmin: isAdmin,
    );
    await _refreshUnitsAndPendingDrafts();
    return result;
  }

  Future<Object?> deleteDensity(int densityId) async {
    final result =
        await _entityRepo.deleteDensity('product', productId, densityId);
    await _refreshUnitsAndPendingDrafts();
    return result;
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
    String recordType = 'purchase',
    DateTime? recordedAt,
    String? notes,
  }) async {
    await _priceRepo.updateRecord(
      recordId,
      price: price,
      quantity: quantity,
      unit: unit,
      merchantId: merchantId,
      recordType: recordType,
      recordedAt: recordedAt,
      notes: notes,
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
}

final productDetailPageProvider = StateNotifierProvider.autoDispose
    .family<ProductDetailPageNotifier, ProductDetailPageState, int>(
  (ref, id) => ProductDetailPageNotifier(id),
);

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

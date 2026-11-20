// comparison_provider.dart — 跨地区物价对比状态（StateNotifier，与项目其余模块同构）。
// 每个子资源独立 loading 标志；子请求失败静默不阻塞整页；请求序号防竞态。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/comparison_repository.dart';

class ComparisonState {
  final List<RegionCandidate> candidates;
  /// 用户自定义计算范围（可作为独立对比项加入，负 id 表示）
  final List<CalcScopeOption> calcScopes;
  final List<int> selectedRegionIds;
  final ComparisonSummary? summary;
  final bool loadingSummary;
  final String? summaryError;

  final String entityType; // 'ingredient' | 'product'
  final List<EntityOption> entityOptions;
  final bool searching;
  final List<int> selectedEntityIds;
  /// id → 实体类型（'ingredient' | 'product'；原料/商品可同时参与对比）
  final Map<int, String> selectedEntityTypes;
  final EntityPrices? entityPrices;
  /// 混合类型分段结果（原料段 + 商品段；RegionPriceMatrix 逐段合并行）
  final List<EntityPrices> entityPriceParts;
  final bool loadingEntityPrices;

  // 二期：菜谱·试算 tab
  final List<int> selectedRecipeIds;
  final List<EntityOption> recipeOptions;
  final List<Map<String, dynamic>> recipeRows;
  final bool loadingRecipes;
  final List<int> selectedPlanIds;
  final List<EntityOption> planOptions;
  final List<Map<String, dynamic>> planRows;
  final bool loadingPlans;

  const ComparisonState({
    this.candidates = const [],
    this.calcScopes = const [],
    this.selectedRegionIds = const [],
    this.summary,
    this.loadingSummary = false,
    this.summaryError,
    this.entityType = 'ingredient',
    this.entityOptions = const [],
    this.searching = false,
    this.selectedEntityIds = const [],
    this.selectedEntityTypes = const {},
    this.entityPrices,
    this.entityPriceParts = const [],
    this.loadingEntityPrices = false,
    this.selectedRecipeIds = const [],
    this.recipeOptions = const [],
    this.recipeRows = const [],
    this.loadingRecipes = false,
    this.selectedPlanIds = const [],
    this.planOptions = const [],
    this.planRows = const [],
    this.loadingPlans = false,
  });

  ComparisonState copyWith({
    List<RegionCandidate>? candidates,
    List<CalcScopeOption>? calcScopes,
    List<int>? selectedRegionIds,
    ComparisonSummary? summary,
    bool clearSummary = false,
    bool? loadingSummary,
    String? summaryError,
    bool clearSummaryError = false,
    String? entityType,
    List<EntityOption>? entityOptions,
    bool clearEntityOptions = false,
    bool? searching,
    List<int>? selectedEntityIds,
    Map<int, String>? selectedEntityTypes,
    EntityPrices? entityPrices,
    List<EntityPrices>? entityPriceParts,
    bool clearEntityPrices = false,
    bool? loadingEntityPrices,
    List<int>? selectedRecipeIds,
    List<EntityOption>? recipeOptions,
    List<Map<String, dynamic>>? recipeRows,
    bool clearRecipeRows = false,
    bool? loadingRecipes,
    List<int>? selectedPlanIds,
    List<EntityOption>? planOptions,
    List<Map<String, dynamic>>? planRows,
    bool clearPlanRows = false,
    bool? loadingPlans,
  }) {
    return ComparisonState(
      candidates: candidates ?? this.candidates,
      calcScopes: calcScopes ?? this.calcScopes,
      selectedRegionIds: selectedRegionIds ?? this.selectedRegionIds,
      summary: clearSummary ? null : (summary ?? this.summary),
      loadingSummary: loadingSummary ?? this.loadingSummary,
      summaryError: clearSummaryError ? null : (summaryError ?? this.summaryError),
      entityType: entityType ?? this.entityType,
      entityOptions: clearEntityOptions ? const [] : (entityOptions ?? this.entityOptions),
      searching: searching ?? this.searching,
      selectedEntityIds: selectedEntityIds ?? this.selectedEntityIds,
      selectedEntityTypes: selectedEntityTypes ?? this.selectedEntityTypes,
      entityPrices: clearEntityPrices ? null : (entityPrices ?? this.entityPrices),
      entityPriceParts: entityPriceParts ?? this.entityPriceParts,
      loadingEntityPrices: loadingEntityPrices ?? this.loadingEntityPrices,
      selectedRecipeIds: selectedRecipeIds ?? this.selectedRecipeIds,
      recipeOptions: recipeOptions ?? this.recipeOptions,
      recipeRows: clearRecipeRows ? const [] : (recipeRows ?? this.recipeRows),
      loadingRecipes: loadingRecipes ?? this.loadingRecipes,
      selectedPlanIds: selectedPlanIds ?? this.selectedPlanIds,
      planOptions: planOptions ?? this.planOptions,
      planRows: clearPlanRows ? const [] : (planRows ?? this.planRows),
      loadingPlans: loadingPlans ?? this.loadingPlans,
    );
  }
}

class ComparisonNotifier extends StateNotifier<ComparisonState> {
  final ComparisonRepository _repository;
  int _summarySeq = 0;
  int _matrixSeq = 0;
  int _searchSeq = 0;
  int _recipeSeq = 0;
  int _planSeq = 0;
  List<CalcScopeOption> _calcScopes = const [];

  ComparisonNotifier({ComparisonRepository? repository})
      : _repository = repository ?? ComparisonRepository(),
        super(const ComparisonState());

  /// 用户的自定义计算范围（对比地区快捷选择；会话内缓存）。
  Future<List<CalcScopeOption>> loadCalcScopes() async {
    if (_calcScopes.isNotEmpty) return _calcScopes;
    try {
      _calcScopes = await _repository.listCalcScopes();
    } catch (_) {
      _calcScopes = const [];
    }
    state = state.copyWith(calcScopes: _calcScopes);
    return _calcScopes;
  }

  /// 拉取地区候选；首次进入自动带入记录数前 3 个地区。
  Future<void> loadCandidates() async {
    try {
      final list = await _repository.getRegions();
      state = state.copyWith(candidates: list);
      if (state.selectedRegionIds.isEmpty && list.isNotEmpty) {
        final defaults = list.take(3).map((r) => r.regionId).toList();
        await selectRegions(defaults);
      }
    } catch (_) {
      // 候选失败：保持手动选择
    }
  }

  Future<void> selectRegions(List<int> ids) async {
    state = state.copyWith(selectedRegionIds: ids, clearSummary: true, clearEntityPrices: true);
    await loadSummary();
    await loadMatrix();
    await loadRecipeMatrix();
    await loadPlanMatrix();
  }

  Future<void> loadSummary() async {
    final ids = state.selectedRegionIds;
    if (ids.isEmpty) return;
    final seq = ++_summarySeq;
    state = state.copyWith(loadingSummary: true, clearSummaryError: true);
    try {
      final summary = await _repository.getSummary(regionIds: ids);
      if (seq == _summarySeq) state = state.copyWith(summary: summary, loadingSummary: false);
    } catch (e) {
      if (seq == _summarySeq) {
        state = state.copyWith(loadingSummary: false, summaryError: '$e');
      }
    }
  }

  /// 实体搜索（原料 / 商品；按当前弹层类型）。
  Future<void> searchEntities({String keyword = '', String? entityType}) async {
    final seq = ++_searchSeq;
    state = state.copyWith(searching: true);
    try {
      final options = await _repository.searchEntities(
        entityType: entityType ?? state.entityType,
        keyword: keyword,
      );
      if (seq == _searchSeq) state = state.copyWith(entityOptions: options, searching: false);
    } catch (_) {
      if (seq == _searchSeq) {
        state = state.copyWith(clearEntityOptions: true, searching: false);
      }
    }
  }

  /// 选择实体（原料/商品分开添加；types 记录 id → 类型用于混合矩阵分组）。
  void toggleEntity(int id, {String type = 'ingredient'}) {
    final current = [...state.selectedEntityIds];
    final types = Map<int, String>.from(state.selectedEntityTypes);
    if (current.contains(id)) {
      current.remove(id);
      types.remove(id);
    } else {
      current.add(id);
      types[id] = type;
    }
    state = state.copyWith(
      selectedEntityIds: current,
      selectedEntityTypes: types,
      clearEntityPrices: true,
    );
    loadMatrix();
  }

  /// 移除已选实体（chips 删除；类型记录一并清掉）。
  void removeEntity(int id) {
    final current = [...state.selectedEntityIds]..remove(id);
    final types = Map<int, String>.from(state.selectedEntityTypes)..remove(id);
    state = state.copyWith(
      selectedEntityIds: current,
      selectedEntityTypes: types,
      clearEntityPrices: true,
    );
    loadMatrix();
  }

  Future<void> setEntityType(String type) async {
    // 换弹层搜索类型（不清已选实体——原料与商品可同时参与对比）
    state = state.copyWith(
      entityType: type,
      clearEntityOptions: true,
    );
    await searchEntities();
  }

  Future<void> loadMatrix() async {
    final regionIds = state.selectedRegionIds;
    final entityIds = state.selectedEntityIds;
    if (regionIds.isEmpty || entityIds.isEmpty) return;
    final seq = ++_matrixSeq;
    state = state.copyWith(loadingEntityPrices: true);
    try {
      // 混合选择：按类型分组分别请求（原料/商品 id 空间不同），合并矩阵段
      final ingIds = entityIds
          .where((id) => state.selectedEntityTypes[id] != 'product')
          .toList();
      final prodIds = entityIds
          .where((id) => state.selectedEntityTypes[id] == 'product')
          .toList();
      final parts = <EntityPrices>[];
      if (ingIds.isNotEmpty) {
        parts.add(await _repository.getEntityPrices(
          entityType: 'ingredient', entityIds: ingIds, regionIds: regionIds));
      }
      if (prodIds.isNotEmpty) {
        parts.add(await _repository.getEntityPrices(
          entityType: 'product', entityIds: prodIds, regionIds: regionIds));
      }
      if (seq == _matrixSeq) {
        state = state.copyWith(entityPriceParts: parts, loadingEntityPrices: false);
      }
    } catch (_) {
      if (seq == _matrixSeq) state = state.copyWith(loadingEntityPrices: false);
    }
  }

  // ==================== 二期：菜谱·试算 ====================

  /// 菜谱搜索（GET /recipes，服务端 search）。
  Future<void> searchRecipes({String keyword = ''}) async {
    try {
      final options = await _repository.searchRecipes(keyword: keyword);
      state = state.copyWith(recipeOptions: options);
    } catch (_) {
      state = state.copyWith(recipeOptions: const []);
    }
  }

  void toggleRecipe(int id) {
    final current = [...state.selectedRecipeIds];
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedRecipeIds: current, clearRecipeRows: true);
    loadRecipeMatrix();
  }

  Future<void> loadRecipeMatrix() async {
    final regionIds = state.selectedRegionIds;
    final recipeIds = state.selectedRecipeIds;
    if (regionIds.isEmpty || recipeIds.isEmpty) return;
    final seq = ++_recipeSeq;
    state = state.copyWith(loadingRecipes: true);
    try {
      final data = await _repository.getRecipeCosts(recipeIds: recipeIds, regionIds: regionIds);
      final rows = ((data['recipes'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (seq == _recipeSeq) state = state.copyWith(recipeRows: rows, loadingRecipes: false);
    } catch (_) {
      if (seq == _recipeSeq) state = state.copyWith(loadingRecipes: false);
    }
  }

  /// 试算下拉全量选项（端点无分页/搜索）。
  Future<void> loadPlanOptions() async {
    try {
      final options = await _repository.listPlans();
      state = state.copyWith(planOptions: options);
    } catch (_) {
      // 下拉留空
    }
  }

  void togglePlan(int id) {
    final current = [...state.selectedPlanIds];
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedPlanIds: current, clearPlanRows: true);
    loadPlanMatrix();
  }

  Future<void> loadPlanMatrix() async {
    final regionIds = state.selectedRegionIds;
    final planIds = state.selectedPlanIds;
    if (regionIds.isEmpty || planIds.isEmpty) return;
    final seq = ++_planSeq;
    state = state.copyWith(loadingPlans: true);
    try {
      final data = await _repository.getPlanCosts(planIds: planIds, regionIds: regionIds);
      final rows = ((data['plans'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (seq == _planSeq) state = state.copyWith(planRows: rows, loadingPlans: false);
    } catch (_) {
      if (seq == _planSeq) state = state.copyWith(loadingPlans: false);
    }
  }
}

final comparisonProvider =
    StateNotifierProvider<ComparisonNotifier, ComparisonState>((ref) {
  return ComparisonNotifier();
});

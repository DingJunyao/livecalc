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
  final EntityPrices? entityPrices;
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
    this.entityPrices,
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
    EntityPrices? entityPrices,
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
      entityPrices: clearEntityPrices ? null : (entityPrices ?? this.entityPrices),
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

  /// 实体搜索（原料 / 商品）。
  Future<void> searchEntities({String keyword = ''}) async {
    final seq = ++_searchSeq;
    state = state.copyWith(searching: true);
    try {
      final options = await _repository.searchEntities(
        entityType: state.entityType,
        keyword: keyword,
      );
      if (seq == _searchSeq) state = state.copyWith(entityOptions: options, searching: false);
    } catch (_) {
      if (seq == _searchSeq) {
        state = state.copyWith(clearEntityOptions: true, searching: false);
      }
    }
  }

  void toggleEntity(int id) {
    final current = [...state.selectedEntityIds];
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedEntityIds: current, clearEntityPrices: true);
    loadMatrix();
  }

  Future<void> setEntityType(String type) async {
    // 换实体类型：清空搜索/已选实体与矩阵，重新拉默认搜索列表
    state = state.copyWith(
      entityType: type,
      selectedEntityIds: const [],
      clearEntityOptions: true,
      clearEntityPrices: true,
    );
    await searchEntities();
    await loadMatrix();
  }

  Future<void> loadMatrix() async {
    final regionIds = state.selectedRegionIds;
    final entityIds = state.selectedEntityIds;
    if (regionIds.isEmpty || entityIds.isEmpty) return;
    final seq = ++_matrixSeq;
    state = state.copyWith(loadingEntityPrices: true);
    try {
      final prices = await _repository.getEntityPrices(
        entityType: state.entityType,
        entityIds: entityIds,
        regionIds: regionIds,
      );
      if (seq == _matrixSeq) {
        state = state.copyWith(entityPrices: prices, loadingEntityPrices: false);
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

// comparison_provider.dart — 跨地区物价对比状态（StateNotifier，与项目其余模块同构）。
// 每个子资源独立 loading 标志；子请求失败静默不阻塞整页；请求序号防竞态。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/comparison_repository.dart';

class ComparisonState {
  final List<RegionCandidate> candidates;
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

  const ComparisonState({
    this.candidates = const [],
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
  });

  ComparisonState copyWith({
    List<RegionCandidate>? candidates,
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
  }) {
    return ComparisonState(
      candidates: candidates ?? this.candidates,
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
    );
  }
}

class ComparisonNotifier extends StateNotifier<ComparisonState> {
  final ComparisonRepository _repository;
  int _summarySeq = 0;
  int _matrixSeq = 0;
  int _searchSeq = 0;

  ComparisonNotifier({ComparisonRepository? repository})
      : _repository = repository ?? ComparisonRepository(),
        super(const ComparisonState());

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
}

final comparisonProvider =
    StateNotifierProvider<ComparisonNotifier, ComparisonState>((ref) {
  return ComparisonNotifier();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/planner_repository.dart';

/// 试算方案列表状态
class PlannerListState {
  final List<Map<String, dynamic>> plans;
  final bool loading;
  final String? error;
  /// plan.id → evaluate 的 totals（成本 / 热量 / 蛋白质 / 脂肪）
  final Map<int, Map<String, dynamic>> totals;
  /// plan.id → evaluate 的 nutrition（含 NRV%），供列表显示 NRV
  final Map<int, Map<String, dynamic>> nutrients;
  /// plan.id → 近 30 天成本（迷你图）
  final Map<int, List<double>> trends;

  const PlannerListState({
    this.plans = const [],
    this.loading = false,
    this.error,
    this.totals = const {},
    this.nutrients = const {},
    this.trends = const {},
  });

  PlannerListState copyWith({
    List<Map<String, dynamic>>? plans,
    bool? loading,
    String? error,
    bool clearError = false,
    Map<int, Map<String, dynamic>>? totals,
    Map<int, Map<String, dynamic>>? nutrients,
    Map<int, List<double>>? trends,
  }) {
    return PlannerListState(
      plans: plans ?? this.plans,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      totals: totals ?? this.totals,
      nutrients: nutrients ?? this.nutrients,
      trends: trends ?? this.trends,
    );
  }
}

class PlannerListNotifier extends StateNotifier<PlannerListState> {
  PlannerListNotifier() : super(const PlannerListState());

  final PlannerRepository _repo = PlannerRepository();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final plans = await _repo.list();
      state = state.copyWith(
        plans: plans,
        loading: false,
        totals: const {},
        nutrients: const {},
        trends: const {},
      );
      await _loadInsights(plans);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// 列表卡片用：逐条拉成本 / 营养 / 30 天成本迷你图（数量少；单条失败不影响其它）
  Future<void> _loadInsights(List<Map<String, dynamic>> plans) async {
    for (final plan in plans) {
      final id = plan['id'];
      if (id is! int) continue;
      final items = ((plan['items'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (items.isNotEmpty) {
        try {
          final evaluation = await _repo.evaluate(
            kind: (plan['kind'] ?? 'meal') as String,
            mealType: _mealTypeOf(items),
            items: items.map(_itemToPayload).toList(),
          );
          state = state.copyWith(
            totals: {
              ...state.totals,
              id: (evaluation['totals'] as Map<String, dynamic>?) ?? const {},
            },
            nutrients: {
              ...state.nutrients,
              id: (evaluation['nutrition'] as Map<String, dynamic>?) ?? const {},
            },
          );
        } on Exception {
          // 单条求值失败静默
        }
      }
      try {
        final trend = await _repo.costTrend(id, days: 30);
        state = state.copyWith(
          trends: {
            ...state.trends,
            id: trend
                .map((point) => ((point['total_cost'] as num?) ?? 0).toDouble())
                .toList(),
          },
        );
      } on Exception {
        // 单条趋势失败静默
      }
    }
  }

  /// 与 web 同口径：meal 方案按条目分组推餐次（other 退回午餐）
  String _mealTypeOf(List<Map<String, dynamic>> items) {
    final group = items.first['group'];
    return (group == 'breakfast' || group == 'dinner') ? group as String : 'lunch';
  }

  Map<String, dynamic> _itemToPayload(Map<String, dynamic> item) => {
        'group': item['group'] ?? 'other',
        'item_type': item['item_type'],
        'recipe_id': item['recipe_id'],
        'ingredient_id': item['ingredient_id'],
        'product_id': item['product_id'],
        'servings': item['servings'],
        'quantity': item['quantity'],
        'unit_id': item['unit_id'],
        'sort_order': item['sort_order'] ?? 0,
      };

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await load();
  }
}

final plannerListProvider =
    StateNotifierProvider<PlannerListNotifier, PlannerListState>(
        (ref) => PlannerListNotifier());

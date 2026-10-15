import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/planner_repository.dart';

/// 试算方案列表状态
class PlannerListState {
  final List<Map<String, dynamic>> plans;
  final bool loading;
  final String? error;

  const PlannerListState({
    this.plans = const [],
    this.loading = false,
    this.error,
  });

  PlannerListState copyWith({
    List<Map<String, dynamic>>? plans,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return PlannerListState(
      plans: plans ?? this.plans,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
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
      state = state.copyWith(plans: plans, loading: false);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await load();
  }
}

final plannerListProvider =
    StateNotifierProvider<PlannerListNotifier, PlannerListState>(
        (ref) => PlannerListNotifier());

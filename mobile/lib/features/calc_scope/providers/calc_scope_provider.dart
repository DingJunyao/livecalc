import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calc_scope.dart';
import '../repositories/calc_scope_repository.dart';

class CalcScopeListState {
  final List<CalcScope> items;
  final bool loading;
  final String? error;
  const CalcScopeListState(
      {this.items = const [], this.loading = false, this.error});
  CalcScopeListState copyWith(
      {List<CalcScope>? items, bool? loading, String? error}) {
    return CalcScopeListState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error);
  }
}

class CalcScopeListNotifier extends StateNotifier<CalcScopeListState> {
  final CalcScopeRepository _repo;
  CalcScopeListNotifier(this._repo) : super(const CalcScopeListState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo.listScopes();
      state = CalcScopeListState(items: items);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> add(Map<String, dynamic> body) async {
    await _repo.createScope(body);
    await load();
  }

  Future<void> update(int id, Map<String, dynamic> body) async {
    await _repo.updateScope(id, body);
    await load();
  }

  Future<void> remove(int id) async {
    await _repo.deleteScope(id);
    await load();
  }
}

final calcScopeListProvider =
    StateNotifierProvider<CalcScopeListNotifier, CalcScopeListState>((ref) {
  return CalcScopeListNotifier(CalcScopeRepository());
});

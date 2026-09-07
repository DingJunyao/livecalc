import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_recommendation.dart';
import '../repositories/home_repository.dart';

enum HomeErrorCode {
  connectionTimeout,
  connectionFailed,
  serverBusy,
  resourceNotFound,
  loadFailed,
  generatingTimeout,
  mealSwapTooMany,
  mealSwapFailed,
  mealSwapTimeout,
  swapAllTooMany,
  refreshFailed,
  refreshTimeout,
}

class HomeState {
  final DailyRecommendation? recommendation;
  final bool loading;
  final bool generating;
  final HomeErrorCode? error;
  final Map<String, bool> refreshLoading;
  final HomeErrorCode? lastError;

  const HomeState({
    this.recommendation,
    this.loading = false,
    this.generating = false,
    this.error,
    this.refreshLoading = const {},
    this.lastError,
  });

  HomeState copyWith({
    DailyRecommendation? recommendation,
    bool? loading,
    bool? generating,
    HomeErrorCode? error,
    Map<String, bool>? refreshLoading,
    HomeErrorCode? lastError,
    bool clearLastError = false,
  }) {
    return HomeState(
      recommendation: recommendation ?? this.recommendation,
      loading: loading ?? this.loading,
      generating: generating ?? this.generating,
      error: error ?? this.error,
      refreshLoading: refreshLoading ?? this.refreshLoading,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

HomeErrorCode _friendlyError(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return HomeErrorCode.connectionTimeout;
  }
  if (e.type == DioExceptionType.connectionError) {
    return HomeErrorCode.connectionFailed;
  }
  if (e.response?.statusCode == 500) {
    return HomeErrorCode.serverBusy;
  }
  if (e.response?.statusCode == 404) {
    return HomeErrorCode.resourceNotFound;
  }
  return HomeErrorCode.loadFailed;
}

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;

  HomeNotifier(this._repository) : super(const HomeState());

  /// Clear the transient snackbar error after the UI has shown it.
  void clearLastError() {
    state = state.copyWith(clearLastError: true);
  }

  Future<void> _pollUntilReady() async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final rec = await _repository.getTodayRecommendation();
      if (rec.status == 'ready') {
        state = HomeState(recommendation: rec);
        return;
      }
    }
    state = state.copyWith(
      generating: false,
      error: HomeErrorCode.generatingTimeout,
    );
  }

  Future<void> loadToday() async {
    state = state.copyWith(loading: true, clearLastError: true);
    try {
      var rec = await _repository.getTodayRecommendation();
      if (rec.status == 'not_generated') {
        rec = await _repository.triggerGenerate();
      }
      if (rec.status == 'generating') {
        state = state.copyWith(loading: false, generating: true);
        await _pollUntilReady();
        return;
      }
      state = HomeState(recommendation: rec);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _friendlyError(e));
    } on Exception catch (_) {
      state = state.copyWith(loading: false, error: HomeErrorCode.loadFailed);
    }
  }

  /// Refresh a single meal — matches the web "换一个" button.
  Future<void> refreshMeal(String mealType) async {
    state = state.copyWith(
      refreshLoading: {...state.refreshLoading, mealType: true},
      clearLastError: true,
    );
    try {
      await _repository.refreshMeal(mealType);
      await _pollRefreshMeal(mealType);
    } on DioException catch (e) {
      state = state.copyWith(
        refreshLoading: {...state.refreshLoading}..remove(mealType),
        lastError: e.response?.statusCode == 429
            ? HomeErrorCode.mealSwapTooMany
            : _friendlyError(e),
      );
    } on Exception catch (_) {
      state = state.copyWith(
        refreshLoading: {...state.refreshLoading}..remove(mealType),
        lastError: HomeErrorCode.mealSwapFailed,
      );
    }
  }

  Future<void> _pollRefreshMeal(String mealType) async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final rec = await _repository.getTodayRecommendation();
      final done = !rec.refreshingMeals.contains(mealType);
      state = state.copyWith(
        recommendation: rec,
        refreshLoading: done
            ? ({...state.refreshLoading}..remove(mealType))
            : state.refreshLoading,
      );
      if (done) return;
    }
    state = state.copyWith(
      refreshLoading: {...state.refreshLoading}..remove(mealType),
      lastError: HomeErrorCode.mealSwapTimeout,
    );
  }

  /// Regenerate all three meals — triggered by the AppBar refresh button.
  Future<void> refresh() async {
    if (state.recommendation == null || state.recommendation!.meals.isEmpty) {
      await loadToday();
      return;
    }
    final mealTypes =
        state.recommendation!.meals.map((m) => m.mealType).toList();
    state = state.copyWith(
      refreshLoading: {for (final mt in mealTypes) mt: true},
      clearLastError: true,
    );
    try {
      for (final mt in mealTypes) {
        try {
          await _repository.refreshMeal(mt);
        } on DioException catch (e) {
          if (e.response?.statusCode == 429) {
            state = state.copyWith(lastError: HomeErrorCode.swapAllTooMany);
            break;
          }
          // Other trigger errors are non-fatal; polling sorts it out.
        }
      }
      await _pollUntilAllRefreshed();
    } on DioException catch (e) {
      state = state.copyWith(
        refreshLoading: const {},
        lastError: _friendlyError(e),
      );
    } on Exception catch (_) {
      state = state.copyWith(
        refreshLoading: const {},
        lastError: HomeErrorCode.refreshFailed,
      );
    }
  }

  Future<void> _pollUntilAllRefreshed() async {
    for (var i = 0; i < 90; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final rec = await _repository.getTodayRecommendation();
      final done = rec.refreshingMeals.isEmpty;
      state = state.copyWith(
        recommendation: rec,
        refreshLoading: done ? const {} : state.refreshLoading,
      );
      if (done) return;
    }
    state = state.copyWith(
      refreshLoading: const {},
      lastError: HomeErrorCode.refreshTimeout,
    );
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(HomeRepository());
});

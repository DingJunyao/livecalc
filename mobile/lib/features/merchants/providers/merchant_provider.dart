import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/merchant.dart';
import '../models/merchant_product_price.dart';
import '../repositories/merchant_repository.dart';

const int merchantPageSize = 20;

class MerchantListState {
  final List<Merchant> items;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final String searchQuery;
  final bool includeClosed;
  final bool favoritesOnly;
  final bool noPrice;
  final int total;
  final int currentPage;
  final bool hasMore;
  final Set<int> favoriteIds;

  const MerchantListState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.searchQuery = '',
    this.includeClosed = false,
    this.favoritesOnly = false,
    this.noPrice = false,
    this.total = 0,
    this.currentPage = 1,
    this.hasMore = true,
    this.favoriteIds = const {},
  });

  MerchantListState copyWith({
    List<Merchant>? items,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? searchQuery,
    bool? includeClosed,
    bool? favoritesOnly,
    bool? noPrice,
    int? total,
    int? currentPage,
    bool? hasMore,
    Set<int>? favoriteIds,
  }) {
    return MerchantListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      includeClosed: includeClosed ?? this.includeClosed,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      noPrice: noPrice ?? this.noPrice,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      favoriteIds: favoriteIds ?? this.favoriteIds,
    );
  }
}

class MerchantListNotifier extends StateNotifier<MerchantListState> {
  final MerchantRepository _repo;
  Timer? _debounce;

  MerchantListNotifier(this._repo) : super(const MerchantListState());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  int get activeFilterCount =>
      (state.includeClosed ? 1 : 0) +
      (state.favoritesOnly ? 1 : 0) +
      (state.noPrice ? 1 : 0);

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
        includeClosed: state.includeClosed,
        noPrice: state.noPrice,
        skip: (page - 1) * merchantPageSize,
        limit: merchantPageSize,
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
    bool? includeClosed,
    bool? favoritesOnly,
    bool? noPrice,
  }) {
    state = state.copyWith(
      includeClosed: includeClosed ?? state.includeClosed,
      favoritesOnly: favoritesOnly ?? state.favoritesOnly,
      noPrice: noPrice ?? state.noPrice,
    );
    load();
  }

  /// 收藏/取消收藏（乐观更新，失败回滚）。
  Future<void> toggleFavorite(int id) async {
    final wasFav = state.favoriteIds.contains(id);
    final next = Set<int>.of(state.favoriteIds);
    if (wasFav) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(favoriteIds: next);
    try {
      if (wasFav) {
        await _repo.removeFavorite(id);
      } else {
        await _repo.addFavorite(id);
      }
      if (state.favoritesOnly) await load();
    } on Exception {
      state = state.copyWith(favoriteIds: state.favoriteIds);
    }
  }

  Future<void> loadFavorites() async {
    try {
      final favs = await _repo.getFavorites();
      state = state.copyWith(favoriteIds: favs.map((m) => m.id).toSet());
    } on Exception {
      // 收藏加载失败不影响列表
    }
  }

  Future<void> addMerchant({
    required String name,
    String? address,
    bool isOpen = true,
    double? latitude,
    double? longitude,
  }) async {
    await _repo.createMerchant(
      name: name,
      address: address,
      isOpen: isOpen,
      latitude: latitude,
      longitude: longitude,
    );
    await load();
  }

  Future<void> deleteMerchant(int id) async {
    await _repo.deleteMerchant(id);
    await load();
  }
}

final merchantListProvider =
    StateNotifierProvider<MerchantListNotifier, MerchantListState>((ref) {
  return MerchantListNotifier(MerchantRepository());
});

// ---------- 商家详情页聚合状态 ----------

class MerchantDetailPageState {
  final Merchant? merchant;
  final List<MerchantProductPrice> productPrices;
  final bool loading;
  final bool loadingPrices;
  final int pricesPage;
  final bool pricesHasMore;
  final String? error;

  const MerchantDetailPageState({
    this.merchant,
    this.productPrices = const [],
    this.loading = false,
    this.loadingPrices = false,
    this.pricesPage = 1,
    this.pricesHasMore = false,
    this.error,
  });

  MerchantDetailPageState copyWith({
    Merchant? merchant,
    List<MerchantProductPrice>? productPrices,
    bool? loading,
    bool? loadingPrices,
    int? pricesPage,
    bool? pricesHasMore,
    String? error,
    bool clearError = false,
  }) {
    return MerchantDetailPageState(
      merchant: merchant ?? this.merchant,
      productPrices: productPrices ?? this.productPrices,
      loading: loading ?? this.loading,
      loadingPrices: loadingPrices ?? this.loadingPrices,
      pricesPage: pricesPage ?? this.pricesPage,
      pricesHasMore: pricesHasMore ?? this.pricesHasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MerchantDetailPageNotifier
    extends StateNotifier<MerchantDetailPageState> {
  final MerchantRepository _repo;
  final int merchantId;

  MerchantDetailPageNotifier(this.merchantId)
      : _repo = MerchantRepository(),
        super(const MerchantDetailPageState());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final merchant = await _repo.getMerchant(merchantId);
      state = state.copyWith(merchant: merchant, loading: false);
      await _loadPrices();
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> _loadPrices() async {
    state = state.copyWith(loadingPrices: true);
    try {
      final result = await _repo.getProductPrices(merchantId, limit: 20);
      state = state.copyWith(
        productPrices: result.items,
        pricesPage: 1,
        pricesHasMore: result.items.length < result.total,
        loadingPrices: false,
      );
    } on Exception {
      state = state.copyWith(loadingPrices: false);
    }
  }

  Future<void> loadMorePrices() async {
    if (state.loadingPrices || !state.pricesHasMore) return;
    state = state.copyWith(loadingPrices: true);
    try {
      final next = state.pricesPage + 1;
      final result = await _repo.getProductPrices(
        merchantId,
        skip: next * 20 - 20,
        limit: 20,
      );
      state = state.copyWith(
        productPrices: [...state.productPrices, ...result.items],
        pricesPage: next,
        pricesHasMore:
            state.productPrices.length + result.items.length < result.total,
        loadingPrices: false,
      );
    } on Exception {
      state = state.copyWith(loadingPrices: false);
    }
  }

  Future<void> updateMerchant({
    String? name,
    String? address,
    bool? isOpen,
    double? latitude,
    double? longitude,
  }) async {
    final updated = await _repo.updateMerchant(
      merchantId,
      name: name,
      address: address,
      isOpen: isOpen,
      latitude: latitude,
      longitude: longitude,
    );
    state = state.copyWith(merchant: updated);
  }
}

final merchantDetailPageProvider =
    StateNotifierProvider.autoDispose.family<
        MerchantDetailPageNotifier, MerchantDetailPageState, int>(
  (ref, id) => MerchantDetailPageNotifier(id),
);

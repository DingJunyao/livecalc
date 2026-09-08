import 'dart:io' show Platform;
import '../../../shared/providers/calc_context_provider.dart';
import '../../../shared/widgets/calc_context_menu_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/directional_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../profile/models/user_place.dart';
import '../../profile/repositories/profile_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/merchant.dart';
import '../providers/map_config_provider.dart';
import '../providers/merchant_provider.dart';
import '../repositories/merchant_repository.dart';
import '../screens/merchant_form_screen.dart';
import '../widgets/merchant_map_view.dart';

class MerchantListScreen extends ConsumerStatefulWidget {
  final bool initialShowMap;
  final ProfileRepository? profileRepository;
  final MerchantRepository? merchantRepository;

  /// 测试注入内存瓦片，避免对话框地图的网络噪音。
  final TileProvider? mapTileProvider;

  const MerchantListScreen({
    super.key,
    this.initialShowMap = false,
    this.profileRepository,
    this.merchantRepository,
    this.mapTileProvider,
  });

  @override
  ConsumerState<MerchantListScreen> createState() => _MerchantListScreenState();
}

class _MerchantListScreenState extends ConsumerState<MerchantListScreen> {
  static const _currentPlacePrefsKey = 'merchants_map_current_place_id';

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _mapController = MapController();
  late bool _showMap;
  Merchant? _selectedMerchant;
  List<LatLng> _allCoordinates = const [];
  List<UserPlace> _places = const [];
  int? _currentPlaceId;

  @override
  void initState() {
    super.initState();
    _showMap = widget.initialShowMap;
    Future.microtask(() {
      ref.read(merchantListProvider.notifier).load();
      ref.read(merchantListProvider.notifier).loadFavorites();
      if (!Platform.isIOS) ref.read(mapConfigProvider.notifier).load();
    });
    _loadPlaces();
    _scrollController.addListener(_onScroll);
  }

  /// 加载我的地点并初始化当前选中：
  /// 上次记忆（SharedPreferences）→ 否则 null（全部商家）。
  Future<void> _loadPlaces() async {
    try {
      final places =
          await (widget.profileRepository ?? ProfileRepository()).getPlaces();
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_currentPlacePrefsKey);
      setState(() {
        _places = places;
        // 默认「全部商家」（null），仅在已有记忆时恢复具体地点。
        _currentPlaceId = saved;
      });
    } catch (_) {
      // 地点加载失败不阻塞列表
    }
  }

  Future<void> _onPlaceChanged(int? id) async {
    setState(() => _currentPlaceId = id);
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_currentPlacePrefsKey);
    } else {
      await prefs.setInt(_currentPlacePrefsKey, id);
    }
  }

  Future<void> _loadCoordinates(MerchantListState state) async {
    try {
      final coords = await (widget.merchantRepository ?? MerchantRepository())
          .getAllCoordinates(
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        includeClosed: state.includeClosed,
        includeOtherRegions: state.includeOtherRegions,
      );
      if (mounted) {
        setState(() {
          _allCoordinates = [
            for (final c in coords)
              if (c.latitude != 0 && c.longitude != 0)
                LatLng(c.latitude, c.longitude),
          ];
        });
      }
    } catch (_) {
      // 坐标加载失败不影响列表
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(merchantListProvider.notifier);
      if (notifier.canLoadMore) {
        notifier.load(loadMore: true);
      }
    }
  }

  void _locateMerchant(Merchant item) {
    if (item.latitude == null || item.longitude == null) return;
    setState(() {
      _selectedMerchant = item;
      _showMap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 会话级临时覆盖（地区/范围/币种）变化后刷新当前页数据
    ref.listen(calcContextProvider, (_, __) {
      ref.read(merchantListProvider.notifier).load();
    });
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(merchantListProvider);
    final mapConfig = ref.watch(mapConfigProvider);
    final mapReady = Platform.isIOS || mapConfig.loaded;
    ref.listen(merchantListProvider, (prev, next) {
      if (prev == null ||
          (prev.items.isEmpty && next.items.isNotEmpty) ||
          prev.searchQuery != next.searchQuery ||
          prev.includeClosed != next.includeClosed ||
          prev.favoritesOnly != next.favoritesOnly ||
          prev.noPrice != next.noPrice ||
          prev.includeOtherRegions != next.includeOtherRegions) {
        _loadCoordinates(next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.merchantTitle),
        leading: const AppBackButton(),
        actions: [
          const CalcContextMenuButton(),
          IconButton(
            icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
            tooltip: _showMap ? l10n.merchantHideMap : l10n.merchantShowMap,
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.journeyRefresh,
            onPressed: state.loading
                ? null
                : () => ref.read(merchantListProvider.notifier).load(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(theme, state),
          if (_showMap)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                height: 260,
                child: mapReady
                    ? MerchantMapView(
                        merchants: state.items,
                        selectedId: _selectedMerchant?.id,
                        controller: _mapController,
                        allCoordinates: _allCoordinates,
                        mapConfig: mapConfig,
                        places: _places,
                        currentPlaceId: _currentPlaceId,
                        onPlaceChanged: _onPlaceChanged,
                        showControls: true,
                        tileProvider: widget.mapTileProvider,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
              ),
            ),
          Expanded(child: _buildBody(theme, state)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMerchantForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, MerchantListState state) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(merchantListProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.merchantSearch,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearch('');
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                notifier.setSearch(v);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: Badge(
              isLabelVisible: notifier.activeFilterCount > 0,
              label: Text('${notifier.activeFilterCount}'),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.tune),
                tooltip: l10n.journeyFilters,
                onPressed: () => _showFilterSheet(theme),
                style: notifier.activeFilterCount > 0
                    ? IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, MerchantListState state) {
    final l10n = AppLocalizations.of(context);
    if (state.loading && state.items.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.error != null && state.items.isEmpty) {
      return ErrorDisplay(
        message: state.error!,
        onRetry: () => ref.read(merchantListProvider.notifier).load(),
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.store,
        title: state.favoritesOnly
            ? l10n.merchantNoFavoriteMerchants
            : l10n.merchantNoMerchants,
        subtitle: state.favoritesOnly
            ? l10n.merchantNoFavoriteMerchantsHint
            : l10n.merchantNoMerchantsHint,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(merchantListProvider.notifier).load(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= state.items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: state.loadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => ref
                            .read(merchantListProvider.notifier)
                            .load(loadMore: true),
                        child: Text(l10n.journeyLoadMore),
                      ),
              ),
            );
          }
          final item = state.items[i];
          return _MerchantCard(
            item: item,
            isFavorite: state.favoriteIds.contains(item.id),
            onTap: () => context.push('/merchants/${item.id}'),
            onFavorite: () =>
                ref.read(merchantListProvider.notifier).toggleFavorite(item.id),
            onLocate: () => _locateMerchant(item),
            onEdit: () => _openMerchantForm(item: item),
            onDelete: () => _confirmDelete(item),
          );
        },
      ),
    );
  }

  // ---- 筛选 ----

  void _showFilterSheet(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(merchantListProvider);
    var includeClosed = state.includeClosed;
    var favoritesOnly = state.favoritesOnly;
    var noPrice = state.noPrice;
    var includeOtherRegions = state.includeOtherRegions;
    showModalBottomSheet<void>(
      context: context,
      // 控件较多（4 开关+chip+按钮）：允许占满屏高，内容超高时滚动
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            void update() {
              setSheetState(() {});
            }

            // 控件较多（4 开关+chip+按钮），矮屏可滚动，避免溢出
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Text(l10n.merchantFilterTitle,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (includeClosed ||
                            favoritesOnly ||
                            noPrice ||
                            includeOtherRegions)
                          TextButton.icon(
                            onPressed: () {
                              includeClosed = false;
                              favoritesOnly = false;
                              noPrice = false;
                              includeOtherRegions = false;
                              update();
                            },
                            icon: const Icon(Icons.clear_all, size: 18),
                            label: Text(l10n.journeyClear),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.merchantShowClosed),
                          value: includeClosed,
                          onChanged: (v) {
                            includeClosed = v;
                            update();
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.merchantShowOtherRegions),
                          subtitle: Text(l10n.merchantShowOtherRegionsHint),
                          value: includeOtherRegions,
                          onChanged: (v) {
                            includeOtherRegions = v;
                            update();
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.merchantFavoritesOnly),
                          value: favoritesOnly,
                          onChanged: (v) {
                            favoritesOnly = v;
                            update();
                          },
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FilterChip(
                            label: Text(l10n.merchantNoMaintainedPrice),
                            selected: noPrice,
                            onSelected: (v) {
                              noPrice = v;
                              update();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          ref.read(merchantListProvider.notifier).applyFilters(
                                includeClosed: includeClosed,
                                favoritesOnly: favoritesOnly,
                                noPrice: noPrice,
                                includeOtherRegions: includeOtherRegions,
                              );
                          Navigator.of(ctx).pop();
                        },
                        child: Text(l10n.journeyConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- 添加/编辑商家 ----

  Future<void> _openMerchantForm({Merchant? item}) async {
    final l10n = AppLocalizations.of(context);
    final result = await context.push<MerchantFormResult>(
      item == null ? '/merchants/new' : '/merchants/${item.id}/edit',
      extra: MerchantFormArguments(
        merchant: item,
        isAdmin: ref.read(authProvider).user?.isAdmin == true,
        repository: widget.merchantRepository,
        mapTileProvider: widget.mapTileProvider,
      ),
    );
    if (result?.saved == true && mounted) {
      await ref.read(merchantListProvider.notifier).load();
      _toast(
        result!.pending
            ? (result.message.isEmpty
                ? l10n.commonSubmittedPendingReview
                : result.message)
            : (result.message.isEmpty ? l10n.merchantSaved : result.message),
      );
    }
  }

  Future<void> _confirmDelete(Merchant item) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.merchantDeleteTitle),
        content: Text(l10n.merchantDeleteMessage(_displayName(item, l10n))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final review =
          await ref.read(merchantListProvider.notifier).deleteMerchant(item.id);
      _toast(
        review.pending
            ? (review.message.isEmpty
                ? l10n.journeyDeleteProposalSubmitted
                : review.message)
            : l10n.merchantDeleted,
      );
    } catch (_) {
      _toast(l10n.journeyDeleteFailed);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 商家名可能为空（只填国家/地区创建的商家），显示回退文案。
String _displayName(Merchant m, AppLocalizations l10n) =>
    m.name.trim().isEmpty ? l10n.merchantUnnamed : m.name;

class _MerchantCard extends StatelessWidget {
  final Merchant item;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onLocate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MerchantCard({
    required this.item,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    required this.onLocate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasLocation = item.latitude != null && item.longitude != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.tertiaryContainer,
                foregroundColor: theme.colorScheme.onTertiaryContainer,
                radius: 20,
                child: const Icon(Icons.store, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName(item, l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!item.isOpen) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(l10n.merchantClosed,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.address ?? l10n.merchantNoAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? theme.colorScheme.error : null,
                ),
                tooltip: isFavorite
                    ? l10n.merchantRemoveFavorite
                    : l10n.merchantFavorite,
                visualDensity: VisualDensity.compact,
                onPressed: onFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.near_me_outlined),
                tooltip: hasLocation
                    ? l10n.merchantLocateOnMap
                    : l10n.merchantNoLocationSet,
                visualDensity: VisualDensity.compact,
                color: hasLocation
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.outlineVariant,
                onPressed: hasLocation ? onLocate : null,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'edit') {
                    onEdit();
                  } else if (v == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
                  PopupMenuItem(
                      value: 'delete', child: Text(l10n.commonDelete)),
                ],
              ),
              Icon(DirectionalIcons.forwardChevron(context),
                  color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

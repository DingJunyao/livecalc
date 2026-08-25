import 'dart:io' show Platform;

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
    final theme = Theme.of(context);
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
        title: const Text('商家'),
        leading: const AppBackButton(),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
            tooltip: _showMap ? '收起地图' : '显示地图',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
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
    final notifier = ref.read(merchantListProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索商家...',
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
                tooltip: '筛选',
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
    if (state.loading && state.items.isEmpty) {
      return const LoadingIndicator(message: '加载中...');
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
        title: state.favoritesOnly ? '暂无收藏商家' : '暂无商家',
        subtitle: state.favoritesOnly ? '收藏的商家会显示在这里' : '点击右下角按钮添加第一个商家',
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
                        child: const Text('加载更多'),
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      Text('筛选条件',
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
                          label: const Text('清除'),
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
                        title: const Text('显示已关闭商家'),
                        value: includeClosed,
                        onChanged: (v) {
                          includeClosed = v;
                          update();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('显示其他地区的商家'),
                        subtitle: const Text('含全部地区，不受计算范围限制'),
                        value: includeOtherRegions,
                        onChanged: (v) {
                          includeOtherRegions = v;
                          update();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('仅看我的收藏'),
                        value: favoritesOnly,
                        onChanged: (v) {
                          favoritesOnly = v;
                          update();
                        },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilterChip(
                          label: const Text('未维护过价格'),
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
                      child: const Text('确定'),
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
            ? (result.message.isEmpty ? '已提交，待管理员审核' : result.message)
            : (result.message.isEmpty ? '已保存' : result.message),
      );
    }
  }

  Future<void> _confirmDelete(Merchant item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除商家'),
        content: Text('确定删除商家「${_displayName(item)}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
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
            ? (review.message.isEmpty ? '删除提议已提交，待管理员审核' : review.message)
            : '已删除',
      );
    } catch (_) {
      _toast('删除失败，请重试');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 商家名可能为空（只填国家/地区创建的商家），显示回退文案。
String _displayName(Merchant m) => m.name.trim().isEmpty ? '未命名商家' : m.name;

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
                            _displayName(item),
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
                            child: Text('已关闭',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.address ?? '暂无地址',
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
                tooltip: isFavorite ? '取消收藏' : '收藏',
                visualDensity: VisualDensity.compact,
                onPressed: onFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.near_me_outlined),
                tooltip: hasLocation ? '在地图上定位' : '未设置位置',
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
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

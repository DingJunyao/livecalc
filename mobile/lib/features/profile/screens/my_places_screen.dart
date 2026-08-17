import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_place.dart';
import '../providers/profile_provider.dart';
import 'user_place_form_screen.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/empty_state.dart';

/// 我的地点：列表 + 独立维护页（名称/类型/视野/地址/地图选点），
/// 对齐 web UserPlacesView。
class MyPlacesScreen extends ConsumerStatefulWidget {
  /// 测试注入内存瓦片，避免对话框地图的网络噪音。
  final TileProvider? mapTileProvider;

  const MyPlacesScreen({super.key, this.mapTileProvider});

  @override
  ConsumerState<MyPlacesScreen> createState() => _MyPlacesScreenState();
}

const _placeKinds = [
  (label: '家', value: 'home'),
  (label: '公司', value: 'work'),
  (label: '其他', value: 'custom'),
];

class _MyPlacesScreenState extends ConsumerState<MyPlacesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(placeListProvider.notifier).load());
  }

  String _kindLabel(String? kind) {
    for (final k in _placeKinds) {
      if (k.value == kind) return k.label;
    }
    return '其他';
  }

  IconData _kindIcon(String? kind) {
    switch (kind) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.business;
      default:
        return Icons.place;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() op, String errMsg) async {
    try {
      await op();
    } catch (e) {
      _toast(placeWriteError(e));
    }
  }

  Future<void> _confirmDelete(UserPlace place) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除地点'),
        content: Text('确定删除「${place.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => ref.read(placeListProvider.notifier).remove(place.id),
      '删除失败',
    );
  }

  Future<void> _openEditor({UserPlace? place}) async {
    final result = await context.push<UserPlaceFormResult>(
      place == null
          ? '/profile/places/new'
          : '/profile/places/${place.id}/edit',
      extra: UserPlaceFormArguments(
        place: place,
        mapTileProvider: widget.mapTileProvider,
      ),
    );
    if (result?.saved == true && mounted) {
      _toast(place == null ? '已添加地点' : '已保存');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(placeListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的地点')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: '添加地点',
        child: const Icon(Icons.add),
      ),
      body: state.loading && state.items.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.items.isEmpty
              ? ErrorDisplay(
                  message: state.error!,
                  onRetry: () => ref.read(placeListProvider.notifier).load(),
                )
              : state.items.isEmpty
                  ? const EmptyState(
                      icon: Icons.place_outlined,
                      title: '暂无地点',
                      subtitle: '点右下角 + 添加（家、公司等）')
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(placeListProvider.notifier).load(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final place = state.items[i];
                          return ListTile(
                            leading: Icon(
                              _kindIcon(place.kind),
                              color: place.isDefault
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(place.name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (place.isDefault) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.star,
                                      size: 16,
                                      color: theme.colorScheme.primary),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((place.address ?? '').isNotEmpty)
                                  Text(place.address!,
                                      style: theme.textTheme.bodySmall),
                                Text(
                                  '${_kindLabel(place.kind)} · 视野 ${(place.viewRadiusKm ?? 5).round()} km · '
                                  '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: '更多操作',
                              onSelected: (v) async {
                                switch (v) {
                                  case 'default':
                                    await _run(
                                      () => ref
                                          .read(placeListProvider.notifier)
                                          .setDefault(place.id),
                                      '设置默认失败',
                                    );
                                  case 'edit':
                                    _openEditor(place: place);
                                  case 'delete':
                                    _confirmDelete(place);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  enabled: !place.isDefault,
                                  value: 'default',
                                  child: const Text('设为默认'),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('编辑'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

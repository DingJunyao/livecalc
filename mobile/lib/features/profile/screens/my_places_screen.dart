import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_formatters.dart';
import '../../../l10n/app_localizations.dart';
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

class _MyPlacesScreenState extends ConsumerState<MyPlacesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(placeListProvider.notifier).load());
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

  Future<void> _run(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      if (!mounted) return;
      _toast(placeWriteError(e, AppLocalizations.of(context)));
    }
  }

  Future<void> _confirmDelete(UserPlace place) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.placeDeleteTitle),
        content: Text(l10n.placeDeleteMessage(place.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => ref.read(placeListProvider.notifier).remove(place.id),
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
      final l10n = AppLocalizations.of(context);
      _toast(place == null ? l10n.placeAdded : l10n.placeSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(placeListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileMyPlaces)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: l10n.placeAdd,
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
                  ? EmptyState(
                      icon: Icons.place_outlined,
                      title: l10n.placeEmptyTitle,
                      subtitle: l10n.placeEmptySubtitle)
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
                                  l10n.placeSubtitle(
                                    savedPlaceKindLabel(
                                      place.kind ?? 'custom',
                                      l10n,
                                    ),
                                    (place.viewRadiusKm ?? 5).round(),
                                    '${formatCoordinate(place.latitude, fractionDigits: 4)}, '
                                    '${formatCoordinate(place.longitude, fractionDigits: 4)}',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: l10n.placeMoreActions,
                              onSelected: (v) async {
                                switch (v) {
                                  case 'default':
                                    await _run(
                                      () => ref
                                          .read(placeListProvider.notifier)
                                          .setDefault(place.id),
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
                                  child: Text(l10n.placeSetDefault),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(l10n.commonEdit),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n.commonDelete),
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

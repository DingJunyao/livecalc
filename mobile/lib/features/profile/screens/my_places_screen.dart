import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../merchants/widgets/map_point_picker.dart';
import '../models/user_place.dart';
import '../providers/profile_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/empty_state.dart';

/// 我的地点：列表 + 添加/编辑对话框（名称/类型/视野/地址/地图选点），
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
const _placeRadii = [1, 2, 5, 10, 20, 50];

/// 地图关闭（403）或校验失败等写操作错误统一提示。
String _placeWriteError(Object e) {
  if (e is DioException && e.response?.statusCode == 403) {
    return '地图功能已关闭，无法维护常用地点';
  }
  if (e is DioException &&
      e.response?.data is Map &&
      (e.response!.data as Map)['detail'] is String) {
    return (e.response!.data as Map)['detail'] as String;
  }
  return '操作失败，请重试';
}

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
      _toast(_placeWriteError(e));
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PlaceFormDialog(
        place: place,
        notifier: ref.read(placeListProvider.notifier),
        tileProvider: widget.mapTileProvider,
      ),
    );
    if (saved == true && mounted) {
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
                  onRetry: () =>
                      ref.read(placeListProvider.notifier).load(),
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
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                          color:
                                              theme.colorScheme.outline),
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

/// 添加/编辑地点对话框。位置在地图上选点（对齐 web MapPicker）。
class _PlaceFormDialog extends StatefulWidget {
  final UserPlace? place;
  final PlaceListNotifier notifier;
  final TileProvider? tileProvider;
  const _PlaceFormDialog({
    this.place,
    required this.notifier,
    this.tileProvider,
  });

  @override
  State<_PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<_PlaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;

  /// 地图选中的位置（WGS84）。
  LatLng? _picked;
  String _kind = 'custom';
  int _radius = 5;
  bool _saving = false;

  bool get _isEdit => widget.place != null;

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    _name = TextEditingController(text: p?.name ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    if (p != null) {
      _picked = LatLng(p.latitude, p.longitude);
    }
    _kind = p?.kind ?? 'custom';
    _radius = (p?.viewRadiusKm ?? 5).round();
    if (!_placeRadii.contains(_radius)) _radius = 5;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '请填写$label' : null;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final picked = _picked;
    if (picked == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请在地图上选择位置')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'kind': _kind,
        'address': _address.text.trim().isEmpty
            ? null
            : _address.text.trim(),
        'latitude': picked.latitude,
        'longitude': picked.longitude,
        'view_radius_km': _radius,
      };
      final p = widget.place;
      if (p == null) {
        await widget.notifier.add(body);
      } else {
        await widget.notifier.update(p.id, body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_placeWriteError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? '编辑地点' : '添加地点'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '名称（如：家、公司）',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, '名称'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: '类型',
                  border: OutlineInputBorder(),
                ),
                items: _placeKinds
                    .map((k) => DropdownMenuItem(
                        value: k.value, child: Text(k.label)))
                    .toList(),
                onChanged: (v) => setState(() => _kind = v ?? 'custom'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _radius,
                decoration: const InputDecoration(
                  labelText: '地图视野范围（聚焦时缩放）',
                  border: OutlineInputBorder(),
                ),
                items: _placeRadii
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text('$r km')))
                    .toList(),
                onChanged: (v) => setState(() => _radius = v ?? 5),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: '地址（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('位置（点击地图选择）',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              MapPointPicker(
                // 固定宽度：短路 AlertDialog 的 intrinsic 宽度查询
                width: 300,
                initialValue: _picked,
                onChanged: (v) => setState(() => _picked = v),
                tileProvider: widget.tileProvider,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}

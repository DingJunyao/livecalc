import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../merchants/widgets/map_point_picker.dart';
import '../models/user_place.dart';
import '../providers/profile_provider.dart';

const _placeKinds = [
  (label: '家', value: 'home'),
  (label: '公司', value: 'work'),
  (label: '其他', value: 'custom'),
];
const _placeRadii = [1, 2, 5, 10, 20, 50];

String placeWriteError(Object e) {
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

class UserPlaceFormResult {
  final bool saved;

  const UserPlaceFormResult({required this.saved});
}

class UserPlaceFormArguments {
  final UserPlace? place;
  final TileProvider? mapTileProvider;

  const UserPlaceFormArguments({this.place, this.mapTileProvider});
}

class UserPlaceFormScreen extends ConsumerStatefulWidget {
  final UserPlace? place;
  final TileProvider? mapTileProvider;

  const UserPlaceFormScreen({
    super.key,
    this.place,
    this.mapTileProvider,
  });

  @override
  ConsumerState<UserPlaceFormScreen> createState() =>
      _UserPlaceFormScreenState();
}

class _UserPlaceFormScreenState extends ConsumerState<UserPlaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  LatLng? _coordinate;
  String _kind = 'custom';
  int _radius = 5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final place = widget.place;
    _nameController = TextEditingController(text: place?.name ?? '');
    _addressController = TextEditingController(text: place?.address ?? '');
    if (place != null) _coordinate = LatLng(place.latitude, place.longitude);
    _kind = place?.kind ?? 'custom';
    _radius = (place?.viewRadiusKm ?? 5).round();
    if (!_placeRadii.contains(_radius)) _radius = 5;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final coordinate = _coordinate;
    if (coordinate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请在地图上选择位置')),
      );
      return;
    }
    setState(() => _saving = true);
    final body = {
      'name': _nameController.text.trim(),
      'kind': _kind,
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      'latitude': coordinate.latitude,
      'longitude': coordinate.longitude,
      'view_radius_km': _radius,
    };
    try {
      final notifier = ref.read(placeListProvider.notifier);
      final place = widget.place;
      if (place == null) {
        await notifier.add(body);
      } else {
        await notifier.update(place.id, body);
      }
      if (!mounted) return;
      context.pop(const UserPlaceFormResult(saved: true));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(placeWriteError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.place != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? '编辑地点' : '添加地点')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '名称（如：家、公司）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? '请填写名称' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    border: OutlineInputBorder(),
                  ),
                  items: _placeKinds
                      .map((kind) => DropdownMenuItem(
                            value: kind.value,
                            child: Text(kind.label),
                          ))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _kind = value ?? 'custom'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _radius,
                  decoration: const InputDecoration(
                    labelText: '地图视野范围（聚焦时缩放）',
                    border: OutlineInputBorder(),
                  ),
                  items: _placeRadii
                      .map((radius) => DropdownMenuItem(
                            value: radius,
                            child: Text('$radius km'),
                          ))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _radius = value ?? 5),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '地址（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '位置（点击地图选择）',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                MapPointPicker(
                  initialValue: _coordinate,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _coordinate = value),
                  tileProvider: widget.mapTileProvider,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(editing ? '保存' : '添加'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

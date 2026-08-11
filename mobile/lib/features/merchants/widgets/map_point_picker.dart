import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo/coordinate_transform.dart';
import '../providers/map_config_provider.dart';
import 'apple_map_picker.dart';

/// 地图选点组件：点击地图选择位置，回调返回 **WGS84** 坐标。
///
/// 对齐 web [MapPicker.vue]：地图内点击/选点 → 当前地图坐标系坐标 →
/// 逆转换为 WGS84（数据库存储坐标系）→ [onChanged] 回调。
/// 底图坐标系由 [mapConfigProvider] 决定（高德/腾讯 GCJ02，OSM WGS84）。
class MapPointPicker extends ConsumerStatefulWidget {
  /// 初始选中点（WGS84）。
  final LatLng? initialValue;

  /// 选中变化回调（WGS84）。
  final ValueChanged<LatLng>? onChanged;

  /// 地图区域高度。
  final double height;

  /// 地图区域宽度。AlertDialog 会做 intrinsic 宽度查询，若为
  /// `double.infinity` 会穿透到 FlutterMap 内部的 LayoutBuilder 抛错
  /// （LayoutBuilder does not support returning intrinsic dimensions），
  /// 对话框场景须传固定宽度短路查询。
  final double width;

  /// 测试注入内存瓦片，避免网络噪音。
  final TileProvider? tileProvider;

  const MapPointPicker({
    super.key,
    this.initialValue,
    this.onChanged,
    this.height = 240,
    this.width = double.infinity,
    this.tileProvider,
  });

  @override
  ConsumerState<MapPointPicker> createState() => _MapPointPickerState();
}

class _MapPointPickerState extends ConsumerState<MapPointPicker> {
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);

  late final MapController _controller;

  /// 选中点（WGS84）。
  LatLng? _wgs;
  MapLayerOption? _layer;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
    _wgs = widget.initialValue;
    _layer = _pickLayer(ref.read(mapConfigProvider));
    // 对话框内容超高时地图在视口外：打开后自动滚到地图可见（选点是核心操作）。
    // 无 Scrollable 祖先（非对话框场景）时 ensureVisible 直接返回。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 300));
    });
  }

  @override
  void didUpdateWidget(MapPointPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _wgs = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  MapLayerOption? _pickLayer(MapConfigState cfg) {
    for (final o in cfg.layers) {
      if (o.id == cfg.defaultId) return o;
    }
    return cfg.layers.isNotEmpty ? cfg.layers.first : null;
  }

  /// 显示坐标：GCJ02 底图把 WGS84 转 GCJ02，OSM 原样。
  LatLng _toDisplay(LatLng wgs) {
    final layer = _layer;
    if (layer == null || !layer.gcj02) return wgs;
    final (lat, lng) = wgs84ToGcj02(wgs.latitude, wgs.longitude);
    return LatLng(lat, lng);
  }

  /// 地图坐标 → 存储 WGS84（底图 GCJ02 时逆转换）。
  LatLng _toWgs84(LatLng display) {
    final layer = _layer;
    if (layer == null || !layer.gcj02) return display;
    final (lat, lng) = gcj02ToWgs84(display.latitude, display.longitude);
    return LatLng(lat, lng);
  }

  void _handleTap(TapPosition tapPosition, LatLng latLng) {
    final wgs = _toWgs84(latLng);
    setState(() => _wgs = wgs);
    widget.onChanged?.call(wgs);
  }

  @override
  Widget build(BuildContext context) {
    // iOS 走原生 MapKit（apple_maps_flutter），Android 走 flutter_map 瓦片。
    if (Platform.isIOS) {
      return AppleMapPicker(
        initialValue: widget.initialValue,
        onChanged: widget.onChanged,
        height: widget.height,
        width: widget.width,
      );
    }
    final theme = Theme.of(context);
    final mapConfig = ref.watch(mapConfigProvider);
    final layer = _layer;
    final wgs = _wgs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          width: widget.width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _toDisplay(wgs ?? _defaultCenter),
                  initialZoom: 12,
                  backgroundColor: const Color(0xFFE8EAED),
                  onTap: _handleTap,
                ),
                children: [
                  if (layer != null)
                    TileLayer(
                      urlTemplate: layer.urlTemplate,
                      subdomains: layer.subdomains,
                      tms: layer.tms,
                      userAgentPackageName: 'livecalc_mobile',
                      tileProvider: widget.tileProvider,
                    ),
                  if (wgs != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _toDisplay(wgs),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 36,
                        ),
                      ),
                    ]),
                ],
              ),
              // 底图切换（右上角小按钮）
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: theme.colorScheme.surface,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: PopupMenuButton<MapLayerOption>(
                    key: const ValueKey('picker-layer-switch'),
                    tooltip: '切换底图',
                    icon: const Icon(Icons.layers_outlined, size: 20),
                    onSelected: (v) => setState(() => _layer = v),
                    itemBuilder: (ctx) => [
                      for (final o in mapConfig.layers)
                        PopupMenuItem(
                          value: o,
                          child: Row(children: [
                            if (layer?.id == o.id)
                              const Icon(Icons.check, size: 16),
                            const SizedBox(width: 8),
                            Text(o.label),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        if (wgs == null)
          Text('点击地图选择位置',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline))
        else
          Text(
            '纬度: ${wgs.latitude.toStringAsFixed(6)} · '
            '经度: ${wgs.longitude.toStringAsFixed(6)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
      ],
    );
  }
}

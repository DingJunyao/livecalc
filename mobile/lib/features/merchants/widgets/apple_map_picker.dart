import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo/coordinate_transform.dart';

/// iOS 原生 MapKit 版选点组件（仅 iOS 运行时实例化）。回调返回 WGS84。
///
/// TODO(定标): 真机验证 onTap 返回坐标方向，必要时翻转 _appleNeedsGcj02。
class AppleMapPicker extends StatefulWidget {
  final LatLng? initialValue;
  final ValueChanged<LatLng>? onChanged;
  final double height;
  final double width;

  const AppleMapPicker({
    super.key,
    this.initialValue,
    this.onChanged,
    this.height = 240,
    this.width = double.infinity,
  });

  @override
  State<AppleMapPicker> createState() => _AppleMapPickerState();
}

/// 定标开关：true=显示坐标需 WGS84→GCJ02（同 Android 高德瓦片）。
/// 真机定标后若 MapKit 自动处理则改 false。
const bool _appleNeedsGcj02 = true;

class _AppleMapPickerState extends State<AppleMapPicker> {
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);

  LatLng? _wgs;
  apple.MapType _mapType = apple.MapType.standard;

  @override
  void initState() {
    super.initState();
    _wgs = widget.initialValue;
  }

  @override
  void didUpdateWidget(AppleMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _wgs = widget.initialValue;
    }
  }

  LatLng _toDisplay(LatLng wgs) {
    if (!_appleNeedsGcj02) return wgs;
    final (lat, lng) = wgs84ToGcj02(wgs.latitude, wgs.longitude);
    return LatLng(lat, lng);
  }

  LatLng _toWgs84(LatLng display) {
    if (!_appleNeedsGcj02) return display;
    final (lat, lng) = gcj02ToWgs84(display.latitude, display.longitude);
    return LatLng(lat, lng);
  }

  /// latlong2 → apple_maps_flutter（两库 LatLng 类型不同，API 边界转换）。
  apple.LatLng _toApple(LatLng l) => apple.LatLng(l.latitude, l.longitude);

  void _onTap(apple.LatLng pos) {
    final wgs = _toWgs84(LatLng(pos.latitude, pos.longitude));
    setState(() => _wgs = wgs);
    widget.onChanged?.call(wgs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              apple.AppleMap(
                initialCameraPosition: apple.CameraPosition(
                  target: _toApple(_toDisplay(wgs ?? _defaultCenter)),
                  zoom: 12,
                ),
                mapType: _mapType,
                onTap: _onTap,
                annotations: wgs == null
                    ? null
                    : {
                        apple.Annotation(
                          annotationId: apple.AnnotationId('picked'),
                          icon: apple.BitmapDescriptor.markerAnnotation,
                          position: _toApple(_toDisplay(wgs)),
                        ),
                      },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: theme.colorScheme.surface,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: PopupMenuButton<apple.MapType>(
                    key: const ValueKey('apple-picker-layer-switch'),
                    tooltip: '切换底图样式',
                    icon: const Icon(Icons.layers_outlined, size: 20),
                    onSelected: (v) => setState(() => _mapType = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: apple.MapType.standard, child: Text('标准')),
                      PopupMenuItem(
                          value: apple.MapType.satellite, child: Text('卫星')),
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

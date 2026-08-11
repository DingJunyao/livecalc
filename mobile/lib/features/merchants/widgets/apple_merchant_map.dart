import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo/coordinate_transform.dart';
import '../../../core/geo/map_zoom.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../profile/models/user_place.dart';
import '../models/merchant.dart';
import 'merchant_map_logic.dart';

/// iOS 原生 MapKit 版商家地图（仅 iOS 运行时实例化，Android 编译安全）。
///
/// 坐标转换：MapKit 中国底图为 GCJ02，Annotation/中心点坐标过 [_toDisplay]。
/// TODO(定标): 真机验证 MapKit 传入/返回坐标方向，必要时翻转 _appleNeedsGcj02。
class AppleMerchantMap extends StatefulWidget {
  final List<Merchant> merchants;
  final int? selectedId;
  final List<LatLng> allCoordinates;
  final List<UserPlace> places;
  final int? currentPlaceId;
  final ValueChanged<int?>? onPlaceChanged;
  final bool showControls;

  const AppleMerchantMap({
    super.key,
    required this.merchants,
    this.selectedId,
    this.allCoordinates = const [],
    this.places = const [],
    this.currentPlaceId,
    this.onPlaceChanged,
    this.showControls = false,
  });

  @override
  State<AppleMerchantMap> createState() => _AppleMerchantMapState();
}

/// 定标开关：true=显示坐标需 WGS84→GCJ02（同 Android 高德瓦片）。
/// 真机定标后若 MapKit 自动处理则改 false。
const bool _appleNeedsGcj02 = true;

class _AppleMerchantMapState extends State<AppleMerchantMap> {
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);

  apple.MapType _mapType = apple.MapType.standard;

  /// WGS84 → 显示坐标（GCJ02 底图转换，待定标）。
  LatLng _toDisplay(LatLng wgs) {
    if (!_appleNeedsGcj02) return wgs;
    final (lat, lng) = wgs84ToGcj02(wgs.latitude, wgs.longitude);
    return LatLng(lat, lng);
  }

  /// latlong2 → apple_maps_flutter（两库 LatLng 类型不同，API 边界转换）。
  apple.LatLng _toApple(LatLng l) => apple.LatLng(l.latitude, l.longitude);

  List<Merchant> get _validMerchants => widget.merchants
      .where((m) =>
          m.latitude != null && m.longitude != null && m.latitude != 0 && m.longitude != 0)
      .toList();

  List<LatLng> get _points {
    if (widget.allCoordinates.isNotEmpty) return widget.allCoordinates;
    return [for (final m in _validMerchants) LatLng(m.latitude!, m.longitude!)];
  }

  /// 当前选中的「我的地点」坐标与聚焦缩放（优先级最高，缩放与 Android 一致）。
  (LatLng, double)? get _focusPlace {
    final id = widget.currentPlaceId;
    if (id == null) return null;
    for (final p in widget.places) {
      if (p.id == id) {
        return (LatLng(p.latitude, p.longitude),
            radiusKmToZoom(p.viewRadiusKm ?? 5));
      }
    }
    return null;
  }

  LatLng? get _selectedPoint {
    final id = widget.selectedId;
    if (id == null) return null;
    for (final m in _validMerchants) {
      if (m.id == id) return LatLng(m.latitude!, m.longitude!);
    }
    return null;
  }

  /// 平台无关视角决策（与 Android merchant_map_view 同源纯函数）。
  MapViewDecision _decision() {
    final focus = _focusPlace;
    return computeMapView(
      points: _points,
      selectedPoint: _selectedPoint,
      focusPlace: focus?.$1,
      focusZoom: focus?.$2,
    );
  }

  apple.CameraPosition get _initialCamera {
    final decision = _decision();
    final target = decision.useDefaultCenter
        ? _defaultCenter
        : decision.center ?? centroid(decision.boundsPoints);
    final zoom = decision.useDefaultCenter ? kDefaultZoom : decision.zoom;
    return apple.CameraPosition(
        target: _toApple(_toDisplay(target)), zoom: zoom);
  }

  Set<apple.Annotation> get _annotations => {
        for (final m in _validMerchants)
          apple.Annotation(
            annotationId: apple.AnnotationId('merchant-${m.id}'),
            icon: apple.BitmapDescriptor.markerAnnotation,
            position: _toApple(_toDisplay(LatLng(m.latitude!, m.longitude!))),
            infoWindow: apple.InfoWindow(title: m.name),
            onTap: () => _showInfo(m),
          ),
      };

  void _showInfo(Merchant m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${m.name}${m.address == null || m.address!.isEmpty ? '' : '\n${m.address}'}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_validMerchants.isEmpty) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: '暂无商家位置',
        subtitle: '商家缺少坐标信息时无法在地图显示',
      );
    }
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: apple.AppleMap(
          initialCameraPosition: _initialCamera,
          mapType: _mapType,
          annotations: _annotations,
          myLocationEnabled: false,
        ),
      ),
      if (widget.showControls)
        Positioned(top: 8, right: 8, child: _buildStyleSwitch(context)),
    ]);
  }

  /// 标准/卫星切换（替代 Android 的底图切换菜单）。
  Widget _buildStyleSwitch(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: PopupMenuButton<apple.MapType>(
        key: const ValueKey('apple-layer-switch'),
        tooltip: '切换底图样式',
        icon: const Icon(Icons.layers_outlined),
        onSelected: (v) => setState(() => _mapType = v),
        itemBuilder: (_) => const [
          PopupMenuItem(value: apple.MapType.standard, child: Text('标准')),
          PopupMenuItem(value: apple.MapType.satellite, child: Text('卫星')),
        ],
      ),
    );
  }
}

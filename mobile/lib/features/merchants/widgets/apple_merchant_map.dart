import 'dart:async';
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  /// 「全部商家」（不选择任何常用地点）的哨兵值。
  /// PopupMenuButton 选中 null 值不会回调 onSelected（视为取消），故用 -1 占位。
  static const int _allMerchantsPlaceId = -1;

  apple.MapType _mapType = apple.MapType.standard;
  apple.AppleMapController? _mapController;
  LatLng? _currentLocation;
  bool _locating = false;

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
          m.latitude != null &&
          m.longitude != null &&
          m.latitude != 0 &&
          m.longitude != 0)
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
        return (
          LatLng(p.latitude, p.longitude),
          radiusKmToZoom(p.viewRadiusKm ?? 5)
        );
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
    final zoom = decision.useDefaultCenter
        ? kDefaultZoom
        : decision.center != null
            ? decision.zoom
            : computeBoundsZoom(decision.boundsPoints);
    return apple.CameraPosition(
        target: _toApple(_toDisplay(target)), zoom: zoom);
  }

  @override
  void didUpdateWidget(AppleMerchantMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.merchants != widget.merchants ||
        oldWidget.selectedId != widget.selectedId ||
        oldWidget.allCoordinates != widget.allCoordinates ||
        oldWidget.places != widget.places ||
        oldWidget.currentPlaceId != widget.currentPlaceId) {
      // 延迟到帧末：apple.AppleMap 可能在 build 中重建原生 MapKit 视图，
      // 此时 onMapCreated 尚未回调，_mapController 是旧值或 null；
      // postFrame 后 controller 已就绪。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refitCamera();
      });
    }
  }

  void _refitCamera() {
    final ctrl = _mapController;
    if (ctrl == null || !mounted) return;
    // 定位中时不被数据变化拉走（对齐 Android）。
    if (_currentLocation != null) return;
    final decision = _decision();
    final target = decision.useDefaultCenter
        ? _defaultCenter
        : decision.center ?? centroid(decision.boundsPoints);
    final zoom = decision.useDefaultCenter
        ? kDefaultZoom
        : decision.center != null
            ? decision.zoom
            : computeBoundsZoom(decision.boundsPoints);
    ctrl.animateCamera(apple.CameraUpdate.newCameraPosition(
      apple.CameraPosition(target: _toApple(_toDisplay(target)), zoom: zoom),
    ));
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
          myLocationEnabled: _currentLocation != null,
          onMapCreated: (c) => _mapController = c,
        ),
      ),
      if (widget.showControls)
        Positioned(top: 8, right: 8, child: _buildControls()),
    ]);
  }

  String? get _selectedPlaceName {
    final id = widget.currentPlaceId;
    if (id == null) return null;
    for (final p in widget.places) {
      if (p.id == id) return p.name;
    }
    return null;
  }

  /// 右上控件列：图层切换 + 常用地点 + 定位（对齐 Android merchant_map_view）。
  Widget _buildControls() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // 图层切换
        PopupMenuButton<apple.MapType>(
          key: const ValueKey('apple-layer-switch'),
          tooltip: '切换底图样式',
          icon: const Icon(Icons.layers_outlined),
          onSelected: (v) => setState(() => _mapType = v),
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: apple.MapType.standard, child: Text('标准')),
            const PopupMenuItem(
                value: apple.MapType.satellite, child: Text('卫星')),
          ],
        ),
        // 常用地点菜单
        if (widget.places.isNotEmpty) ...[
          PopupMenuButton<int?>(
            key: const ValueKey('apple-place-menu'),
            tooltip: _selectedPlaceName ?? '选择常用地点',
            icon: Icon(
              widget.currentPlaceId != null ? Icons.star : Icons.star_border,
              color: widget.currentPlaceId != null
                  ? theme.colorScheme.primary
                  : null,
            ),
            onSelected: (v) {
              final id = v == _allMerchantsPlaceId ? null : v;
              // 选择常用地点与定位互斥：选地点时清除定位。
              if (id != null && _currentLocation != null) {
                setState(() => _currentLocation = null);
              }
              widget.onPlaceChanged?.call(id);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<int?>(
                value: _allMerchantsPlaceId,
                child: Row(children: [
                  if (widget.currentPlaceId == null)
                    const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  const Text('全部商家'),
                ]),
              ),
              for (final p in widget.places)
                PopupMenuItem<int?>(
                  value: p.id,
                  child: Row(children: [
                    if (widget.currentPlaceId == p.id)
                      const Icon(Icons.check, size: 16),
                    const SizedBox(width: 8),
                    Text(p.name),
                  ]),
                ),
            ],
          ),
        ],
        // 定位
        IconButton(
          key: const ValueKey('apple-locate-button'),
          tooltip: _currentLocation != null ? '清除定位' : '定位当前位置',
          icon: _locating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _currentLocation != null
                      ? Icons.my_location
                      : Icons.my_location_outlined,
                  color: _currentLocation != null
                      ? theme.colorScheme.primary
                      : null,
                ),
          onPressed: _locating ? null : _locate,
        ),
      ]),
    );
  }

  Future<void> _locate() async {
    // 已定位 → 清除定位、回到原视角（toggle 语义，对齐 Android）。
    if (_currentLocation != null) {
      setState(() => _currentLocation = null);
      _refitCamera();
      return;
    }
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast('定位服务未开启，请在系统设置中打开');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _toast('位置权限被拒绝');
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _toast('位置权限已被永久拒绝，请到系统设置中开启');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = loc);
      // 定位与选择常用地点互斥：开启定位时清除已选地点。
      if (widget.currentPlaceId != null) {
        widget.onPlaceChanged?.call(null);
      }
      _mapController?.animateCamera(apple.CameraUpdate.newCameraPosition(
        apple.CameraPosition(
            target: _toApple(_toDisplay(loc)), zoom: kPointZoom),
      ));
    } on TimeoutException {
      _toast('定位超时，请重试');
    } catch (_) {
      _toast('定位失败，请重试');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/geo/coordinate_transform.dart';
import '../../../core/geo/map_zoom.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../profile/models/user_place.dart';
import '../models/merchant.dart';
import '../providers/map_config_provider.dart';
import 'apple_merchant_map.dart';
import 'merchant_map_logic.dart';

bool _isValidCoordinate(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  return lat != 0 && lng != 0;
}

String _shortName(String name) =>
    name.length > 8 ? '${name.substring(0, 8)}…' : name;

/// 商家地图（列表内嵌 / 详情位置卡共用）。
///
/// 初始视角直接通过 [MapOptions.initialCameraFit] / [initialCenter] 计算，
/// 避免在 onMapReady 里调用 fitCamera/move 导致首帧底图瓦片不加载
/// （flutter_map 6 的已知问题：底图初始化不出现，用户缩放/拖动后才加载）。
///
/// [mapConfig] 提供底图列表与默认图层；[places]/[currentPlaceId]/[onPlaceChanged]
/// 是「常用地点」弹出菜单；[showControls] 控制右上控件列（底图/地点/定位）。
class MerchantMapView extends StatefulWidget {
  final List<Merchant> merchants;
  final int? selectedId;
  final MapController? controller;
  final List<LatLng> allCoordinates;
  final MapConfigState mapConfig;
  final List<UserPlace> places;
  final int? currentPlaceId;
  final ValueChanged<int?>? onPlaceChanged;
  final bool showControls;
  final TileProvider? tileProvider; // 测试注入内存瓦片，避免网络噪音

  const MerchantMapView({
    super.key,
    required this.merchants,
    this.selectedId,
    this.controller,
    this.allCoordinates = const [],
    this.mapConfig = const MapConfigState(),
    this.places = const [],
    this.currentPlaceId,
    this.onPlaceChanged,
    this.showControls = false,
    this.tileProvider,
  });

  @override
  State<MerchantMapView> createState() => _MerchantMapViewState();
}

class _MerchantMapViewState extends State<MerchantMapView> {
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);

  /// 「全部商家」（不选择任何常用地点）的哨兵值。
  /// PopupMenuButton 选中 null 值不会回调 onSelected（视为取消），故用 -1 占位。
  static const int _allMerchantsPlaceId = -1;

  late final MapController _internalController;

  MapController get _controller => widget.controller ?? _internalController;

  MapLayerOption? _layer;
  LatLng? _currentLocation;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _internalController = MapController();
    _layer = _pickLayer(widget.mapConfig);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  MapLayerOption? _pickLayer(MapConfigState cfg) {
    for (final o in cfg.layers) {
      if (o.id == cfg.defaultId) return o;
    }
    return cfg.layers.isNotEmpty ? cfg.layers.first : null;
  }

  @override
  void didUpdateWidget(MerchantMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 底图配置变化：当前图层不在新列表时重置为默认。
    if (oldWidget.mapConfig.layers != widget.mapConfig.layers ||
        oldWidget.mapConfig.defaultId != widget.mapConfig.defaultId) {
      final layer = _layer;
      if (layer == null ||
          !widget.mapConfig.layers.contains(layer) ||
          (oldWidget.mapConfig.defaultId != widget.mapConfig.defaultId &&
              layer.id == oldWidget.mapConfig.defaultId)) {
        _layer = _pickLayer(widget.mapConfig);
      }
    }
    if (oldWidget.merchants != widget.merchants ||
        oldWidget.selectedId != widget.selectedId ||
        oldWidget.allCoordinates != widget.allCoordinates ||
        oldWidget.places != widget.places ||
        oldWidget.currentPlaceId != widget.currentPlaceId) {
      // 首次初始化交给 initialCameraFit；这里只处理挂载后的数据变化。
      // initialCameraFit 通过 postFrame 异步应用（flutter_map 内部），可能晚于本帧；
      // 再等一帧重新应用视角，避免 fit-all 覆盖地点聚焦。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitView();
          });
        }
      });
    }
  }

  List<Merchant> get _validMerchants => widget.merchants
      .where((m) => _isValidCoordinate(m.latitude, m.longitude))
      .toList();

  /// 地图上要覆盖的全部坐标点（优先用列表页加载的全量坐标）。
  List<LatLng> get _points {
    if (widget.allCoordinates.isNotEmpty) return widget.allCoordinates;
    return [
      for (final m in _validMerchants) LatLng(m.latitude!, m.longitude!),
    ];
  }

  /// 选中的商家坐标。
  LatLng? get _selectedPoint {
    final id = widget.selectedId;
    if (id == null) return null;
    for (final m in _validMerchants) {
      if (m.id == id) return LatLng(m.latitude!, m.longitude!);
    }
    return null;
  }

  /// 当前选中的「我的地点」坐标与聚焦缩放（优先级最高）。
  (LatLng?, double) get _focusPlace {
    final id = widget.currentPlaceId;
    if (id == null) return (null, 12);
    for (final p in widget.places) {
      if (p.id == id) {
        return (
          LatLng(p.latitude, p.longitude),
          radiusKmToZoom(p.viewRadiusKm ?? 5)
        );
      }
    }
    return (null, 12);
  }

  /// 统一坐标出口：GCJ02 底图（高德/腾讯）把 WGS84 转 GCJ02，OSM 原样。
  /// 所有进 MarkerLayer/CircleLayer/move/fit/initialCenter 的坐标都必须过这里。
  LatLng _toDisplay(LatLng wgs) {
    final layer = _layer;
    if (layer == null || !layer.gcj02) return wgs;
    final (lat, lng) = wgs84ToGcj02(wgs.latitude, wgs.longitude);
    return LatLng(lat, lng);
  }

  /// 平台无关的视角决策（WGS84 层面），坐标转换与本平台 API 在此落地。
  MapViewDecision _decision() {
    final (focus, focusZoom) = _focusPlace;
    return computeMapView(
      points: _points,
      selectedPoint: _selectedPoint,
      focusPlace: focus,
      focusZoom: focusZoom,
    );
  }

  MapOptions _buildOptions() {
    final decision = _decision();
    final bounds = decision.boundsPoints;
    return MapOptions(
      initialCenter: _toDisplay(decision.center ?? _defaultCenter),
      initialZoom: decision.useDefaultCenter ? kDefaultZoom : decision.zoom,
      // 有地点聚焦时以地点为初始视角，不传 fit，避免 fit-all 覆盖地点中心。
      initialCameraFit: bounds.isEmpty
          ? null
          : CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(bounds.map(_toDisplay).toList()),
              padding: const EdgeInsets.all(48),
              maxZoom: kBoundsMaxZoom,
            ),
      backgroundColor: const Color(0xFFE8EAED),
    );
  }

  void _fitView() {
    final controller = _controller;
    if (!mounted) return;
    // 定位开启时视角由定位控制，避免清除地点触发的 rebuild 把镜头拉走。
    if (_currentLocation != null) return;
    final decision = _decision();
    final center = decision.center;
    if (center != null) {
      controller.move(_toDisplay(center), decision.zoom);
      return;
    }
    final bounds = decision.boundsPoints;
    if (bounds.isEmpty) return;
    try {
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(bounds.map(_toDisplay).toList()),
          padding: const EdgeInsets.all(48),
          maxZoom: kBoundsMaxZoom,
        ),
      );
    } catch (_) {
      final points = bounds.map(_toDisplay).toList();
      final lat =
          points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
      final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) /
          points.length;
      controller.move(LatLng(lat, lng), 12);
    }
  }

  // ---- 定位 ----

  Future<void> _locate() async {
    // 已定位：再次点击清除蓝点并回到原视角（web toggle 语义）。
    if (_currentLocation != null) {
      setState(() => _currentLocation = null);
      _fitView();
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
      // 开启定位与选择常用地点互斥：开启定位时清除已选地点。
      if (widget.currentPlaceId != null) {
        widget.onPlaceChanged?.call(null);
      }
      _controller.move(_toDisplay(loc), kPointZoom);
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

  // ---- 控件 ----

  /// 当前选中的「常用地点」名称（未选中或找不到时返回 null）。
  String? get _selectedPlaceName {
    final id = widget.currentPlaceId;
    if (id == null) return null;
    for (final p in widget.places) {
      if (p.id == id) return p.name;
    }
    return null;
  }

  Widget _buildControls() {
    final theme = Theme.of(context);
    final layer = _layer;
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // 底图切换
        PopupMenuButton<MapLayerOption>(
          key: const ValueKey('layer-switch'),
          tooltip: '切换底图',
          icon: const Icon(Icons.layers_outlined),
          onSelected: (v) => setState(() => _layer = v),
          itemBuilder: (ctx) => [
            for (final o in widget.mapConfig.layers)
              PopupMenuItem(
                value: o,
                child: Row(children: [
                  if (layer?.id == o.id) const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  Text(o.label),
                ]),
              ),
          ],
        ),
        if (widget.places.isNotEmpty) ...[
          // 常用地点：单个图标按钮，弹出菜单选择；选中时高亮
          PopupMenuButton<int?>(
            key: const ValueKey('place-menu'),
            tooltip: _selectedPlaceName ?? '选择常用地点',
            icon: Icon(
              widget.currentPlaceId != null ? Icons.star : Icons.star_border,
              color: widget.currentPlaceId != null
                  ? theme.colorScheme.primary
                  : null,
            ),
            // PopupMenuButton 选中 null 不会回调 onSelected（视为取消），
            // 因此「全部商家」用哨兵值 -1，回调时再转回 null。
            onSelected: (v) {
              final id = v == _allMerchantsPlaceId ? null : v;
              // 选择常用地点与开启定位互斥：选中地点时清除定位。
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
          key: const ValueKey('locate-button'),
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

  @override
  Widget build(BuildContext context) {
    // iOS 走原生 MapKit（apple_maps_flutter），Android 走 flutter_map 瓦片。
    if (Platform.isIOS) {
      return AppleMerchantMap(
        merchants: widget.merchants,
        selectedId: widget.selectedId,
        allCoordinates: widget.allCoordinates,
        places: widget.places,
        currentPlaceId: widget.currentPlaceId,
        onPlaceChanged: widget.onPlaceChanged,
        showControls: widget.showControls,
      );
    }
    final markers = _validMerchants;
    if (markers.isEmpty) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: '暂无商家位置',
        subtitle: '商家缺少坐标信息时无法在地图显示',
      );
    }
    final layer = _layer;
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _controller,
          options: _buildOptions(),
          children: [
            if (layer != null)
              TileLayer(
                urlTemplate: layer.urlTemplate,
                subdomains: layer.subdomains,
                tms: layer.tms,
                userAgentPackageName: 'livecalc_mobile',
                tileProvider: widget.tileProvider,
              ),
            if (_currentLocation != null) ...[
              CircleLayer(circles: [
                CircleMarker(
                  point: _toDisplay(_currentLocation!),
                  radius: 5000,
                  useRadiusInMeter: true,
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderColor: Colors.blue.withValues(alpha: 0.3),
                ),
              ]),
              MarkerLayer(markers: [
                Marker(
                  key: const ValueKey('current-location-marker'),
                  point: _toDisplay(_currentLocation!),
                  width: 18,
                  height: 18,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1976D2),
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
            MarkerLayer(
              markers: [
                for (final m in markers)
                  Marker(
                    point: _toDisplay(LatLng(m.latitude!, m.longitude!)),
                    width: 110,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: _MerchantMarker(
                      name: m.name,
                      address: m.address,
                      isOpen: m.isOpen,
                      selected: m.id == widget.selectedId,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (widget.showControls)
        Positioned(top: 8, right: 8, child: _buildControls()),
    ]);
  }
}

/// 与 Web 一致的名称标签标记：药丸 + 底部三角指针。
class _MerchantMarker extends StatelessWidget {
  final String name;
  final String? address;
  final bool isOpen;
  final bool selected;

  const _MerchantMarker({
    required this.name,
    required this.address,
    required this.isOpen,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = !isOpen
        ? const Color(0xFF757575)
        : selected
            ? const Color(0xFFD32F2F)
            : const Color(0xFF1976D2);
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name${isOpen ? '' : '（已关闭）'}'
              '${address == null || address!.isEmpty ? '' : '\n$address'}',
            ),
          ),
        );
      },
      // Marker 的整块区域位于坐标点上方，底部对齐让三角指针正好指向商家位置。
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _shortName(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -1),
              child: Icon(Icons.arrow_drop_down, color: bg, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}

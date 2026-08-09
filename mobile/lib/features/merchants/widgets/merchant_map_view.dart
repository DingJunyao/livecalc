import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/widgets/empty_state.dart';
import '../models/merchant.dart';

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
class MerchantMapView extends StatefulWidget {
  final List<Merchant> merchants;
  final int? selectedId;
  final MapController? controller;
  final List<LatLng> allCoordinates;

  const MerchantMapView({
    super.key,
    required this.merchants,
    this.selectedId,
    this.controller,
    this.allCoordinates = const [],
  });

  @override
  State<MerchantMapView> createState() => _MerchantMapViewState();
}

class _MerchantMapViewState extends State<MerchantMapView> {
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);
  static const double _defaultZoom = 11.0;
  static const double _pointZoom = 15.0;

  late final MapController _internalController;

  MapController get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = MapController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(MerchantMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.merchants != widget.merchants ||
        oldWidget.selectedId != widget.selectedId ||
        oldWidget.allCoordinates != widget.allCoordinates) {
      // 首次初始化交给 initialCameraFit；这里只处理挂载后的数据变化。
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
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

  /// 单点视角：选中商家、只有一个坐标点，或所有点重合。
  LatLng? get _singleCenter {
    final selected = _selectedPoint;
    if (selected != null) return selected;
    final points = _points;
    if (points.length == 1) return points.first;
    if (points.length > 1) {
      final first = points.first;
      var minLat = first.latitude;
      var maxLat = first.latitude;
      var minLng = first.longitude;
      var maxLng = first.longitude;
      for (final p in points.skip(1)) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      if (minLat == maxLat && minLng == maxLng) {
        return LatLng(minLat, minLng);
      }
    }
    return null;
  }

  /// 多点范围视角（fit 全部坐标）。
  CameraFit? get _boundsFit {
    if (_singleCenter != null) return null;
    final points = _points;
    if (points.length < 2) return null;
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(48),
      maxZoom: 16,
    );
  }

  MapOptions _buildOptions() {
    final center = _singleCenter;
    return MapOptions(
      initialCenter: center ?? _defaultCenter,
      initialZoom: center != null ? _pointZoom : _defaultZoom,
      initialCameraFit: _boundsFit,
      backgroundColor: const Color(0xFFE8EAED),
    );
  }

  void _fitView() {
    final controller = _controller;
    if (!mounted) return;
    final center = _singleCenter;
    if (center != null) {
      controller.move(center, _pointZoom);
      return;
    }
    final fit = _boundsFit;
    if (fit == null) return;
    try {
      controller.fitCamera(fit);
    } catch (_) {
      final points = _points;
      final lat =
          points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
      final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) /
          points.length;
      controller.move(LatLng(lat, lng), 12);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = _validMerchants;
    if (markers.isEmpty) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: '暂无商家位置',
        subtitle: '商家缺少坐标信息时无法在地图显示',
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        mapController: _controller,
        options: _buildOptions(),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'livecalc_mobile',
          ),
          MarkerLayer(
            markers: [
              for (final m in markers)
                Marker(
                  point: LatLng(m.latitude!, m.longitude!),
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
    );
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
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

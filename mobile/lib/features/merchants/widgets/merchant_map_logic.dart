import 'package:latlong2/latlong.dart';

/// 视角缩放常量（从 merchant_map_view 既有魔法数提取，平台共享）。
const double kDefaultZoom = 11.0;
const double kPointZoom = 15.0;
const double kDefaultFocusZoom = 12.0;
const double kBoundsMaxZoom = 16.0;

/// 平台无关的视角决策（全部 WGS84，不含坐标转换）。
///
/// 各平台 widget 拿到此决策后，自行做 GCJ02 转换 + 喂各自地图 API：
/// - Android flutter_map：useDefaultCenter→initialCenter；center→initialCenter+zoom；
///   boundsPoints→CameraFit.bounds
/// - iOS apple_maps_flutter：center 或 centroid(boundsPoints)→CameraPosition(target, zoom)
class MapViewDecision {
  /// 单点中心（WGS84）。null 表示多点（用 [boundsPoints]）或默认。
  final LatLng? center;

  /// 多点边界点（WGS84）。单点/默认时为空。
  final List<LatLng> boundsPoints;

  final double zoom;

  /// 无任何有效点时为 true，调用方用默认中心。
  final bool useDefaultCenter;

  const MapViewDecision({
    this.center,
    this.boundsPoints = const [],
    this.zoom = kDefaultZoom,
    this.useDefaultCenter = false,
  });
}

/// 计算地图视角决策（优先级：focusPlace > selectedPoint > 单点 > 多点 bounds > 默认）。
///
/// [points] 为全部有效坐标（WGS84）。[selectedPoint] 为选中商家坐标。
/// [focusPlace]/[focusZoom] 为「常用地点」聚焦。
MapViewDecision computeMapView({
  required List<LatLng> points,
  LatLng? selectedPoint,
  LatLng? focusPlace,
  double? focusZoom,
}) {
  // 1. 常用地点聚焦（最高优先级）
  if (focusPlace != null) {
    return MapViewDecision(
      center: focusPlace,
      zoom: focusZoom ?? kDefaultFocusZoom,
    );
  }

  // 2. 选中商家
  if (selectedPoint != null) {
    return MapViewDecision(center: selectedPoint, zoom: kPointZoom);
  }

  // 3. 无点
  if (points.isEmpty) {
    return const MapViewDecision(useDefaultCenter: true);
  }

  // 4. 单点
  if (points.length == 1) {
    return MapViewDecision(center: points.first, zoom: kPointZoom);
  }

  // 5. 多点重合 → 视为单点
  if (_allSame(points)) {
    return MapViewDecision(center: points.first, zoom: kPointZoom);
  }

  // 6. 多点 bounds
  return MapViewDecision(boundsPoints: points, zoom: kDefaultZoom);
}

bool _allSame(List<LatLng> pts) {
  final first = pts.first;
  for (final p in pts.skip(1)) {
    if (p.latitude != first.latitude || p.longitude != first.longitude) {
      return false;
    }
  }
  return true;
}

/// 多点质心（WGS84）。iOS 多点视角用（apple_maps_flutter 无 bounds fit）。
LatLng centroid(List<LatLng> points) {
  final lat =
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
  final lng =
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
  return LatLng(lat, lng);
}

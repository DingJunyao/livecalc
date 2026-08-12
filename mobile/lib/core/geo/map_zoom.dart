import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// 视野半径（km）→ 缩放级别，直接抄 web 商家地图的聚焦逻辑。
double radiusKmToZoom(double km) {
  if (km <= 1) return 14;
  if (km <= 2) return 13;
  if (km <= 5) return 12;
  if (km <= 10) return 11;
  if (km <= 20) return 10;
  if (km <= 50) return 9;
  return 8;
}

/// 计算能容纳一组 WGS84 坐标点的缩放级别。
///
/// iOS MapKit 没有 CameraFit.bounds 等价 API，用此函数
/// 根据坐标点跨度和地图组件尺寸估算合适缩放级别，替代固定 kDefaultZoom。
///
/// [points] 是待容纳的点集（至少 2 个不同点），[mapWidth]/[mapHeight]
/// 是地图组件像素尺寸估算值，[padding] 是边缘内边距（像素）。
double computeBoundsZoom(
  List<LatLng> points, {
  double mapWidth = 360,
  double mapHeight = 260,
  double padding = 48,
}) {
  if (points.length < 2) return radiusKmToZoom(5);

  double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  final latDiff = (maxLat - minLat).abs();
  final lngDiff = (maxLng - minLng).abs();
  if (latDiff < 1e-7 && lngDiff < 1e-7) return radiusKmToZoom(1);

  const tileSize = 256.0;
  final effectiveW = (mapWidth - 2 * padding).clamp(1, 4096);
  final effectiveH = (mapHeight - 2 * padding).clamp(1, 4096);

  final lngZoom = _log2(effectiveW * 360 / (tileSize * lngDiff));
  final latZoom = _log2(effectiveH * 180 / (tileSize * latDiff));

  return math.min(lngZoom, latZoom).clamp(2.0, 18.0);
}

double _log2(double x) => math.log(x) / math.ln2;

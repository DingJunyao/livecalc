import 'dart:math' as math;

/// 坐标系转换（WGS84 ↔ GCJ02），1:1 移植 web
/// [coordinateTransform.ts](frontend/src/utils/coordinateTransform.ts)。
/// 高德/腾讯瓦片是 GCJ02，数据库存 WGS84，显示前必须转换，否则偏移数百米。

// 中国区域椭球参数（与 web 常量一致）
const double _ee = 0.006693421622965943;

double _transformLat(double lat, double lng) {
  var ret = -100.0 +
      2.0 * lat +
      3.0 * lng +
      0.2 * lng * lng +
      0.1 * lat * lng +
      0.2 * math.sqrt(lat.abs());
  ret += (20.0 * math.sin(6.0 * lat * math.pi) +
          20.0 * math.sin(2.0 * lat * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(lng * math.pi) + 40.0 * math.sin(lng / 3.0 * math.pi)) *
          2.0 /
          3.0;
  ret += (160.0 * math.sin(lng / 12.0 * math.pi) +
          320.0 * math.sin(lng * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLng(double lat, double lng) {
  var ret = 300.0 +
      lat +
      2.0 * lng +
      0.1 * lat * lat +
      0.1 * lat * lng +
      0.1 * math.sqrt(lat.abs());
  ret += (20.0 * math.sin(6.0 * lat * math.pi) +
          20.0 * math.sin(2.0 * lat * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(lat * math.pi) + 40.0 * math.sin(lat / 3.0 * math.pi)) *
          2.0 /
          3.0;
  ret += (150.0 * math.sin(lat / 12.0 * math.pi) +
          300.0 * math.sin(lat / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return ret;
}

/// WGS84 → GCJ02（GPS → 国测局，高德/腾讯瓦片坐标）。
/// 返回 (lat, lng)。
(double, double) wgs84ToGcj02(double lat, double lng) {
  var dlat = _transformLat(lng - 105.0, lat - 35.0);
  var dlng = _transformLng(lng - 105.0, lat - 35.0);
  final radlat = lat / 180.0 * math.pi;
  var magic = math.sin(radlat);
  magic = 1 - _ee * magic * magic;
  final sqrtmagic = math.sqrt(magic);
  dlat = (dlat * 180.0) / ((6336242.6562 / magic) * sqrtmagic * math.pi);
  dlng = (dlng * 180.0) / (6378245.0 / sqrtmagic * math.cos(radlat) * math.pi);
  return (lat + dlat, lng + dlng);
}

/// GCJ02 → WGS84（国测局 → GPS）。
(double, double) gcj02ToWgs84(double lat, double lng) {
  var dlat = _transformLat(lng - 105.0, lat - 35.0);
  var dlng = _transformLng(lng - 105.0, lat - 35.0);
  final radlat = lat / 180.0 * math.pi;
  var magic = math.sin(radlat);
  magic = 1 - _ee * magic * magic;
  final sqrtmagic = math.sqrt(magic);
  dlat = (dlat * 180.0) / ((6336242.6562 / magic) * sqrtmagic * math.pi);
  dlng = (dlng * 180.0) / (6378245.0 / sqrtmagic * math.cos(radlat) * math.pi);
  return (lat - dlat, lng - dlng);
}

/// 是否 GCJ02 瓦片（高德/腾讯）。
bool isGcj02Map(String mapId) => mapId == 'amap' || mapId == 'tencent';

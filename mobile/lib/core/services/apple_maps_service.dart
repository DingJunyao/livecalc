import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../geo/coordinate_transform.dart';

/// 地图默认中心（北京）。各 picker / 商家地图视图与占位坐标判定共用。
const LatLng kMapDefaultCenter = LatLng(39.9042, 116.4074);

/// 占位/默认坐标判定：null、(0,0) 或地图默认中心。
/// 这类值不视为「已有」，商家表单的名称/地址匹配结果可以覆盖它们。
bool isPlaceholderCoordinate(LatLng? point) {
  if (point == null) return true;
  bool near(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-9 &&
      (a.longitude - b.longitude).abs() < 1e-9;
  return near(point, kMapDefaultCenter) || near(point, const LatLng(0, 0));
}

/// MKLocalSearch / CLGeocoder 返回的地点信息（原生 dict → Dart 模型）。
///
/// 坐标统一折算为 WGS84：MapKit 在中国大陆返回 GCJ-02（countryCode 为 CN
/// 或缺失时折算，境外坐标 `gcj02ToWgs84` 自动原样返回）。与
/// apple_map_picker.dart 的 `_appleNeedsGcj02` 同口径，真机定标后一并调整。
class ApplePlace {
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String country;
  final String countryCode;
  final String administrativeArea;
  final String locality;
  final String subLocality;
  final String thoroughfare;

  const ApplePlace({
    this.name = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.country = '',
    this.countryCode = '',
    this.administrativeArea = '',
    this.locality = '',
    this.subLocality = '',
    this.thoroughfare = '',
  });

  factory ApplePlace.fromChannel(Map<Object?, Object?> raw) {
    final countryCode = _s(raw['countryCode']);
    double? lat = _d(raw['latitude']);
    double? lng = _d(raw['longitude']);
    if (lat != null &&
        lng != null &&
        (countryCode == 'CN' || countryCode.isEmpty)) {
      final (wLat, wLng) = gcj02ToWgs84(lat, lng);
      lat = wLat;
      lng = wLng;
    }
    return ApplePlace(
      name: _s(raw['name']),
      address: _s(raw['address']),
      latitude: lat,
      longitude: lng,
      country: _s(raw['country']),
      countryCode: countryCode,
      administrativeArea: _s(raw['administrativeArea']),
      locality: _s(raw['locality']),
      subLocality: _s(raw['subLocality']),
      thoroughfare: _s(raw['thoroughfare']),
    );
  }

  static String _s(Object? v) => v?.toString() ?? '';

  static double? _d(Object? v) => (v is num) ? v.toDouble() : null;
}

/// iOS Apple Maps（MapKit）地理编码服务：名称/地址搜索 + 坐标逆编码。
/// 原生实现仅 iOS 提供（AppDelegate.swift 的 AppleMapsPlugin），
/// 其他平台 isAvailable=false，调用方据此静默降级。
class AppleMapsService {
  AppleMapsService({MethodChannel? channel, bool? available})
      : _channel =
              channel ?? const MethodChannel('com.a4ding.livecalc/apple_maps'),
        _availableOverride = available;

  final MethodChannel _channel;
  final bool? _availableOverride;

  /// 仅 iOS 提供原生实现；商家表单据此决定是否触发匹配候选。
  /// [available] 参数供测试在非 iOS 宿主强制开启走 mock 通道。
  bool get isAvailable => _availableOverride ?? Platform.isIOS;

  /// 按名称/地址搜地点（POI + 地址），失败/不可用返回空列表（表单静默降级）。
  /// [center] 用于偏置搜索区域（当前选点），缺省由系统按用户位置偏置。
  Future<List<ApplePlace>> searchPlaces(
    String query, {
    LatLng? center,
    double radiusMeters = 50000,
  }) async {
    if (!isAvailable) return const [];
    try {
      final response = await _channel.invokeMethod(
        'searchPlaces',
        <String, Object>{
          'query': query,
          if (center != null) 'centerLat': center.latitude,
          if (center != null) 'centerLng': center.longitude,
          'radiusMeters': radiusMeters,
        },
      );
      final list = (response as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => ApplePlace.fromChannel(Map<Object?, Object?>.from(e)))
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  /// 坐标（WGS84）→ 行政区划。中国区自动转回 GCJ02 再调原生（MapKit 在
  /// 中国大陆以 GCJ02 为基准，避免区县级边界偏差），失败/无结果返回 null。
  Future<ApplePlace?> reverseGeocodeForWgs84(
    double latitude,
    double longitude,
  ) async {
    if (!isAvailable) return null;
    final (gLat, gLng) = wgs84ToGcj02(latitude, longitude);
    try {
      final response = await _channel.invokeMethod(
        'reverseGeocode',
        <String, Object>{'latitude': gLat, 'longitude': gLng},
      );
      if (response is! Map) return null;
      return ApplePlace.fromChannel(Map<Object?, Object?>.from(response));
    } on PlatformException {
      return null;
    }
  }
}

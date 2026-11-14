import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:com_a4ding_livecalc/core/services/apple_maps_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'test.com.a4ding.livecalc/apple_maps';
  late AppleMapsService service;
  late MethodChannel channel;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    channel = const MethodChannel(channelName);
    // available: true 强制开启（Windows 宿主 Platform.isIOS=false）。
    service = AppleMapsService(channel: channel, available: true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('isPlaceholderCoordinate', () {
    test('null / (0,0) / 地图默认中心视为占位', () {
      expect(isPlaceholderCoordinate(null), isTrue);
      expect(isPlaceholderCoordinate(const LatLng(0, 0)), isTrue);
      expect(isPlaceholderCoordinate(kMapDefaultCenter), isTrue);
    });

    test('真实坐标（含与默认中心仅差一点的值）非占位', () {
      expect(isPlaceholderCoordinate(const LatLng(34.77, 111.2)), isFalse);
      expect(
        isPlaceholderCoordinate(const LatLng(39.9042, 116.4075)),
        isFalse,
      );
    });
  });

  test('searchPlaces 透传 query/center，CN 结果折算 WGS84', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return [
        {
          'name': '蜜雪冰城（人民路店）',
          'address': '河南省三门峡市湖滨区人民路1号',
          'latitude': 34.7811,
          'longitude': 111.19,
          'country': '中国',
          'countryCode': 'CN',
          'administrativeArea': '河南省',
          'locality': '三门峡市',
          'subLocality': '湖滨区',
          'thoroughfare': '人民路',
        },
        {
          'name': 'Starbucks',
          'address': '1st Ave',
          'latitude': 40.7411,
          'longitude': -73.9897,
          'country': 'United States',
          'countryCode': 'US',
          'administrativeArea': 'New York',
          'locality': 'New York',
          'subLocality': 'Manhattan',
          'thoroughfare': '1st Ave',
        },
      ];
    });

    final results =
        await service.searchPlaces('蜜雪冰城', center: const LatLng(34.77, 111.2));

    expect(calls, hasLength(1));
    expect(calls.single.method, 'searchPlaces');
    expect(calls.single.arguments['query'], '蜜雪冰城');
    expect(calls.single.arguments['centerLat'], 34.77);
    expect(calls.single.arguments['centerLng'], 111.2);

    expect(results, hasLength(2));
    // CN 结果（GCJ02）折算为 WGS84：有偏移且在合理幅度内。
    final cnShift = (results[0].latitude! - 34.7811).abs();
    expect(cnShift, greaterThan(0.0001));
    expect(cnShift, lessThan(0.01));
    expect(results[0].administrativeArea, '河南省');
    expect(results[0].locality, '三门峡市');
    // 非 CN 结果原样保留。
    expect(results[1].latitude, 40.7411);
    expect(results[1].longitude, -73.9897);
  });

  test('searchPlaces 缺 countryCode 的结果同样折算（境外坐标自动原样）', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return [
        {'name': '境外店', 'latitude': 40.7411, 'longitude': -73.9897},
      ];
    });

    final results = await service.searchPlaces('store');
    expect(results, hasLength(1));
    // 境外坐标不在 GCJ02 生效范围，折算恒等。
    expect(results[0].latitude, 40.7411);
    expect(results[0].countryCode, isEmpty);
  });

  test('searchPlaces 原生报错静默返回空列表', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'searchFailed', message: 'boom');
    });
    expect(await service.searchPlaces('x'), isEmpty);
  });

  test('searchPlaces 查询结果缺坐标时 latitude/longitude 为 null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return [
        {'name': '只有名字'},
      ];
    });
    final results = await service.searchPlaces('x');
    expect(results.single.latitude, isNull);
    expect(results.single.longitude, isNull);
  });

  test('reverseGeocodeForWgs84 中国区入参转回 GCJ02 再调原生', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {
        'name': '湖滨区',
        'address': '河南省三门峡市湖滨区',
        'latitude': 34.78,
        'longitude': 111.19,
        'country': '中国',
        'countryCode': 'CN',
        'administrativeArea': '河南省',
        'locality': '三门峡市',
        'subLocality': '湖滨区',
        'thoroughfare': '',
      };
    });

    final place = await service.reverseGeocodeForWgs84(34.77, 111.2);
    expect(place, isNotNull);
    expect(place!.administrativeArea, '河南省');
    // WGS84 → GCJ02 后入参相对原值有偏移（偏移方向随位置可正可负）。
    final gLat = calls.single.arguments['latitude'] as double;
    final shift = (gLat - 34.77).abs();
    expect(shift, greaterThan(0.0001));
    expect(shift, lessThan(0.01));
  });

  test('reverseGeocodeForWgs84 无结果 / 报错返回 null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    expect(await service.reverseGeocodeForWgs84(34.77, 111.2), isNull);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'reverseFailed', message: 'boom');
    });
    expect(await service.reverseGeocodeForWgs84(34.77, 111.2), isNull);
  });

  test('isAvailable 显式关闭时不触通道', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return <Object>[];
    });
    final off = AppleMapsService(channel: channel, available: false);
    expect(off.isAvailable, isFalse);
    expect(await off.searchPlaces('x'), isEmpty);
    expect(await off.reverseGeocodeForWgs84(34.77, 111.2), isNull);
    expect(calls, isEmpty);
  });
}

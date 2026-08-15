import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:com_a4ding_livecalc/core/geo/coordinate_transform.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/apple_map_picker.dart';

class _FakeGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      Position(
        latitude: 31.25,
        longitude: 121.5,
        timestamp: DateTime(2026, 8, 15),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

void main() {
  late GeolocatorPlatform original;

  setUp(() {
    original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FakeGeolocator();
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
  });

  testWidgets('定位按钮：选当前为 WGS84 并更新标注', (tester) async {
    LatLng? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 300,
            child: AppleMapPicker(onChanged: (point) => picked = point),
          ),
        ),
      ),
    ));

    final layerRect = tester.getRect(
      find.byKey(const ValueKey('apple-picker-layer-switch')),
    );
    final locateRect = tester.getRect(
      find.byKey(const ValueKey('map-locate-button')),
    );
    expect(locateRect.left, greaterThanOrEqualTo(layerRect.right));

    await tester.tap(find.byKey(const ValueKey('map-locate-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(picked, isNotNull);
    expect(picked!.latitude, closeTo(31.25, 1e-9));
    expect(picked!.longitude, closeTo(121.5, 1e-9));

    final map = tester.widget<apple.AppleMap>(find.byType(apple.AppleMap));
    final annotation = map.annotations!.single;
    final (displayLat, displayLng) = wgs84ToGcj02(31.25, 121.5);
    expect(annotation.position.latitude, closeTo(displayLat, 1e-6));
    expect(annotation.position.longitude, closeTo(displayLng, 1e-6));
  });
}

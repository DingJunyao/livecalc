import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/map_locate_button.dart';

class _SuccessfulGeolocator extends GeolocatorPlatform {
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

class _DeniedGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.deniedForever;
}

void main() {
  late GeolocatorPlatform original;

  setUp(() {
    original = GeolocatorPlatform.instance;
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
  });

  testWidgets('locates and returns WGS84 point', (tester) async {
    GeolocatorPlatform.instance = _SuccessfulGeolocator();
    LatLng? located;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MapLocateButton(onLocated: (point) => located = point),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('map-locate-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(located, isNotNull);
    expect(located!.latitude, 31.25);
    expect(located!.longitude, 121.5);
  });

  testWidgets('shows feedback when permission is permanently denied',
      (tester) async {
    GeolocatorPlatform.instance = _DeniedGeolocator();
    LatLng? located;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MapLocateButton(onLocated: (point) => located = point),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('map-locate-button')));
    await tester.pump();

    expect(located, isNull);
    expect(find.text('位置权限已被永久拒绝，请到系统设置中开启'), findsOneWidget);
  });
}

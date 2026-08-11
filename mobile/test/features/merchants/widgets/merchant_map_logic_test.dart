import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:com_a4ding_livecalc/features/merchants/widgets/merchant_map_logic.dart';

void main() {
  group('computeMapView', () {
    test('无点：返回默认中心', () {
      final d = computeMapView(points: const []);
      expect(d.center, isNull);
      expect(d.useDefaultCenter, isTrue);
    });

    test('单点：中心=该点，zoom=点缩放', () {
      const p = LatLng(31.23, 121.47);
      final d = computeMapView(points: [p]);
      expect(d.center, p);
      expect(d.zoom, kPointZoom);
      expect(d.useDefaultCenter, isFalse);
    });

    test('多点：center=null，提供 boundsPoints 供 fit/centroid', () {
      const pts = [LatLng(31.20, 121.40), LatLng(31.30, 121.50)];
      final d = computeMapView(points: pts);
      expect(d.center, isNull);
      expect(d.boundsPoints, pts);
      expect(d.useDefaultCenter, isFalse);
    });

    test('focusPlace 优先级最高：覆盖 selectedPoint 与多点', () {
      final d = computeMapView(
        points: const [LatLng(31.2, 121.4), LatLng(31.3, 121.5)],
        focusPlace: const LatLng(30, 120),
        focusZoom: 13,
      );
      expect(d.center, const LatLng(30, 120));
      expect(d.zoom, 13);
    });

    test('selectedPoint 次优先：覆盖多点 bounds', () {
      final d = computeMapView(
        points: const [LatLng(31.2, 121.4), LatLng(31.3, 121.5)],
        selectedPoint: const LatLng(31.25, 121.45),
      );
      expect(d.center, const LatLng(31.25, 121.45));
      expect(d.zoom, kPointZoom);
    });

    test('多点重合：视为单点', () {
      const p = LatLng(31.2, 121.4);
      final d = computeMapView(points: const [p, p, p]);
      expect(d.center, p);
    });
  });

  group('centroid', () {
    test('多点质心', () {
      final c = centroid(const [LatLng(30, 120), LatLng(32, 122)]);
      expect(c.latitude, closeTo(31, 1e-9));
      expect(c.longitude, closeTo(121, 1e-9));
    });
  });
}

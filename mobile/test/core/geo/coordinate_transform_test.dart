import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/geo/coordinate_transform.dart';

/// 参考值由同一公式独立计算（Python 实现）得出：
/// 上海 (31.2304, 121.4737) → GCJ02 (31.228454448, 121.478223059)，偏移 ~481m
/// 北京 (39.9042, 116.4074) → GCJ02 (39.905607, 116.413642)
void main() {
  group('wgs84ToGcj02', () {
    test('上海坐标：与参考值一致（防移植笔误）', () {
      final (lat, lng) = wgs84ToGcj02(31.2304, 121.4737);
      expect(lat, closeTo(31.228454448, 1e-6));
      expect(lng, closeTo(121.478223059, 1e-6));
    });

    test('北京坐标：与参考值一致', () {
      final (lat, lng) = wgs84ToGcj02(39.9042, 116.4074);
      expect(lat, closeTo(39.905607, 1e-6));
      expect(lng, closeTo(116.413642, 1e-6));
    });

    test('国内坐标偏移量级为百米级（非零、非微小）', () {
      final (lat, lng) = wgs84ToGcj02(31.2304, 121.4737);
      final dLat = (lat - 31.2304).abs();
      final dLng = (lng - 121.4737).abs();
      expect(dLat, greaterThan(0.0005)); // 偏移必须真实存在
      expect(dLng, greaterThan(0.0005));
      expect(dLat + dLng, lessThan(0.05)); // 但不应是粗大错误（如半径混用）
    });

    test('往返一致性：gcj02ToWgs84(wgs84ToGcj02(p)) ≈ p（单步近似逆，容差 1e-4）', () {
      // 逆变换是单步近似（web 同，不迭代），固有误差 ~1e-5 度（米级），
      // 对地图显示（偏移数百米量级）完全可忽略。
      const points = [
        (31.2304, 121.4737),
        (39.9042, 116.4074),
        (23.1291, 113.2644),
        (29.5630, 106.5516),
      ];
      for (final (lat, lng) in points) {
        final (gLat, gLng) = wgs84ToGcj02(lat, lng);
        final (wLat, wLng) = gcj02ToWgs84(gLat, gLng);
        expect(wLat, closeTo(lat, 1e-4));
        expect(wLng, closeTo(lng, 1e-4));
      }
    });
  });

  test('isGcj02Map：仅高德/腾讯', () {
    expect(isGcj02Map('amap'), isTrue);
    expect(isGcj02Map('tencent'), isTrue);
    expect(isGcj02Map('osm'), isFalse);
    expect(isGcj02Map('baidu'), isFalse);
  });
}

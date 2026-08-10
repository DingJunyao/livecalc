import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/geo/map_zoom.dart';

void main() {
  test('视野半径 → 缩放级别（对齐 web radiusToZoom）', () {
    expect(radiusKmToZoom(1), 14);
    expect(radiusKmToZoom(2), 13);
    expect(radiusKmToZoom(5), 12);
    expect(radiusKmToZoom(10), 11);
    expect(radiusKmToZoom(20), 10);
    expect(radiusKmToZoom(50), 9);
    expect(radiusKmToZoom(100), 8);
  });

  test('边界值：<= 与 > 的分界', () {
    expect(radiusKmToZoom(1.5), 13); // >1 → 13
    expect(radiusKmToZoom(2.1), 12); // >2 → 12
    expect(radiusKmToZoom(51), 8); // >50 → 8
  });
}

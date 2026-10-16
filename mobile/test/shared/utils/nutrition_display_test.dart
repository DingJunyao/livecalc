import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/utils/nutrition_display.dart';

void main() {
  test('NRV 百分比与 web / 后端同口径（保留 2 位小数）', () {
    expect(nrvPct('protein', 25.2), 42);
    expect(nrvPct('carbohydrate', 99.7), 33.23);
    expect(nrvPct('fat', 13.8), 23);
    expect(nrvPct('energy', 590.2), 29.51);
  });

  test('没有标准值或数值非法时返回 null', () {
    expect(nrvPct('unknown_key', 10), isNull);
    expect(nrvPct('protein', null), isNull);
    expect(nrvPct('protein', double.nan), isNull);
  });

  test('能量单位换算：kJ 时 ×4.184 取整，可逆', () {
    expect(toDisplayCalorie(590.2, 'kcal'), 590.2);
    expect(toDisplayCalorie(590.2, 'kJ'), 2469);
    expect(fromDisplayCalorie(2469, 'kJ'), 590);
    expect(fromDisplayCalorie(590, 'kcal'), 590);
  });
}

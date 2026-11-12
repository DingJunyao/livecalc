import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/models/calc_scope.dart';

void main() {
  group('CalcScope.fromJson', () {
    test('解析 region_ids / regions / is_default', () {
      final scope = CalcScope.fromJson({
        'id': 7,
        'name': '老家周边',
        'region_ids': [12, 34, 12],
        'regions': [
          {
            'id': 12,
            'name': '灵宝市',
            'display_name': '河南 / 三门峡 / 灵宝市',
            'level': 3,
          },
          {
            'id': 34,
            'name': '三门峡市',
            'display_name': '河南 / 三门峡市',
            'level': 2,
          },
        ],
        'is_default': true,
      });

      expect(scope.id, 7);
      expect(scope.name, '老家周边');
      expect(scope.regionIds, [12, 34, 12]);
      expect(scope.regions.length, 2);
      expect(scope.regions.first.displayName, '河南 / 三门峡 / 灵宝市');
      expect(scope.isDefault, isTrue);
    });

    test('缺字段兜底：regions 空、is_default false', () {
      final scope = CalcScope.fromJson({'id': 1, 'name': 'x'});
      expect(scope.regionIds, isEmpty);
      expect(scope.regions, isEmpty);
      expect(scope.isDefault, isFalse);
      expect(scope.regionsSummary, isEmpty);
    });

    test('regionsSummary 用 display_name 优先拼接', () {
      final scope = CalcScope.fromJson({
        'id': 1,
        'name': 'x',
        'region_ids': [1, 2],
        'regions': [
          {'id': 1, 'name': 'a', 'display_name': 'A 显示名', 'level': 2},
          {'id': 2, 'name': 'b', 'display_name': '', 'level': 3},
        ],
      });
      expect(scope.regionsSummary, 'A 显示名、b');
    });
  });
}

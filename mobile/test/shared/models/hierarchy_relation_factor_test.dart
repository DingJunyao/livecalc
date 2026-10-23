import 'package:com_a4ding_livecalc/shared/models/hierarchy_relation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('层级关系换算系数', () {
    test('fromJson 解析 4 个系数字段与 hasFactor', () {
      final relation = HierarchyRelation.fromJson({
        'id': 1,
        'parent_id': 2,
        'parent_name': '干',
        'child_id': 3,
        'child_name': '鲜',
        'relation_type': 'fallback',
        'strength': 60,
        'factor_parent_quantity': 1,
        'factor_parent_unit': 'kg',
        'factor_child_quantity': 3,
        'factor_child_unit': 'kg',
      });
      expect(relation.hasFactor, isTrue);
      expect(relation.factorEquation(), '1 kg = 3 kg');
    });

    test('全空系数 = 1:1，factorEquation 为 null', () {
      final relation = HierarchyRelation.fromJson({
        'id': 1,
        'parent_id': 2,
        'parent_name': '干',
        'child_id': 3,
        'child_name': '鲜',
        'relation_type': 'fallback',
        'strength': 60,
      });
      expect(relation.hasFactor, isFalse);
      expect(relation.factorEquation(), isNull);
    });

    test('formatHierarchyFactorEquation 渲染紧凑等式', () {
      expect(
        formatHierarchyFactorEquation(
          parentQuantity: 1,
          parentUnit: 'kg',
          childQuantity: 3,
          childUnit: 'kg',
        ),
        '1 kg = 3 kg',
      );
      expect(
        formatHierarchyFactorEquation(
          parentQuantity: 0.5,
          parentUnit: '斤',
          childQuantity: 1.5,
          childUnit: '斤',
        ),
        contains('0.5 斤 = 1.5 斤'),
      );
    });

    test('HierarchyFactorInput.equation 与关系等式一致', () {
      const factor = HierarchyFactorInput(
        parentQuantity: 1,
        parentUnit: 'kg',
        childQuantity: 3,
        childUnit: 'kg',
      );
      expect(factor.equation(), '1 kg = 3 kg');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_quantity_link.dart';

void main() {
  test('sentence and grams self-check', () {
    final link = EntityQuantityLink.fromJson({
      'id': 1,
      'current': {
        'type': 'product',
        'id': 1,
        'name': '五连包',
        'quantity': 1,
        'unit': '提',
      },
      'other': {
        'type': 'product',
        'id': 2,
        'name': '单包',
        'quantity': 5,
        'unit': '包',
      },
      'other_per_current': 5,
      'current_per_other': 0.2,
      'grams_per_current_unit': 425,
      'grams_per_other_unit': 85,
      'resolvable': true,
      'equivalent_current_price': 25,
    });

    expect(link.sentence, '1 提 五连包 = 5 包 单包');
    expect(link.gramsSelfCheck, '1 提 ≈ 425 g');
  });

  test('unresolvable link has no grams self-check', () {
    final link = EntityQuantityLink.fromJson({
      'id': 2,
      'current': {
        'type': 'ingredient',
        'id': 1,
        'name': '鲜香菇',
        'quantity': 3,
        'unit': 'kg',
      },
      'other': {
        'type': 'ingredient',
        'id': 2,
        'name': '干香菇',
        'quantity': 1,
        'unit': 'kg',
      },
      'other_per_current': 1 / 3,
      'current_per_other': 3,
      'resolvable': false,
    });

    expect(link.sentence, '3 kg 鲜香菇 = 1 kg 干香菇');
    expect(link.gramsSelfCheck, isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/utils/nutrition_basis.dart';

void main() {
  test('默认基准 100 g，归一化会挡掉非法值', () {
    expect(kDefaultNutritionBasisAmount, 100);
    expect(kDefaultNutritionBasisUnit, 'g');
    expect(normalizeBasisAmount(250), 250);
    expect(normalizeBasisAmount('2.5'), 2.5);
    expect(normalizeBasisAmount(0), 100);
    expect(normalizeBasisAmount(-3), 100);
    expect(normalizeBasisAmount('abc'), 100);
    expect(normalizeBasisAmount(null), 100);
    expect(normalizeBasisUnit('  '), 'g');
    expect(normalizeBasisUnit('mL'), 'mL');
    expect(formatBasisAmount(100), '100');
    expect(formatBasisAmount(2.5), '2.5');
    expect(formatBasisAmount(3.140000), '3.14');
  });

  test('从营养响应读基准：统一字段优先，其次自定义数据，最后 base_*', () {
    expect(
      readNutritionBasisFromJson({'reference_amount': 250, 'reference_unit': 'mL'}),
      const NutritionBasis(amount: 250, unit: 'mL'),
    );
    expect(
      readNutritionBasisFromJson({
        'custom_nutrition_data': {'reference_amount': 1, 'reference_unit': '袋'},
      }),
      const NutritionBasis(amount: 1, unit: '袋'),
    );
    expect(
      readNutritionBasisFromJson({'base_quantity': 30, 'base_unit': 'g'}),
      const NutritionBasis(amount: 30, unit: 'g'),
    );
    // 脏数据/缺省回落到 100 g
    expect(readNutritionBasisFromJson(null), const NutritionBasis());
    expect(
      readNutritionBasisFromJson({'reference_amount': 0, 'reference_unit': ''}),
      const NutritionBasis(),
    );
  });

  test('可折算自定义单位：有单件重量才进候选', () {
    final rows = <Map>[
      {'id': 1, 'unit_name': '袋', 'weight_per_unit': 250},
      {'id': 2, 'unit_name': '把', 'weight_per_unit': null},
    ];
    expect(resolvableBasisUnitNames(rows, const []), ['袋']);
  });

  test('可折算自定义单位：嵌套引用跟随被引用方，悬空引用看本行重量', () {
    final rows = <Map>[
      {'id': 1, 'unit_name': '袋', 'weight_per_unit': 250},
      {'id': 2, 'unit_name': '箱', 'weight_per_unit': 12, 'weight_unit_override_id': 1},
      {'id': 3, 'unit_name': '悬空箱', 'weight_per_unit': 12, 'weight_unit_override_id': 99},
      {'id': 4, 'unit_name': '环', 'weight_unit_override_id': 4},
    ];
    // 箱：引用「袋」可折算；悬空箱：引用不存在但本行另有重量 → 后端退化为「12 g」，同样可用；
    // 环：自引用且无重量 → 判为不可用
    expect(resolvableBasisUnitNames(rows, const []), ['袋', '箱', '悬空箱']);
  });

  test('可折算自定义单位：引用的全局单位必须是质量/体积', () {
    final rows = <Map>[
      {'id': 1, 'unit_name': '袋', 'weight_per_unit': 250, 'weight_unit_id': 3},
      {'id': 2, 'unit_name': '颗', 'weight_per_unit': 5, 'weight_unit_id': 49},
    ];
    final globals = <Map>[
      {'id': 3, 'unit_type': 'mass'},
      {'id': 49, 'unit_type': 'count'},
    ];
    expect(resolvableBasisUnitNames(rows, globals), ['袋']);
  });

  test('基准候选：自定义单位在前，按名去重', () {
    final options = mergeBasisUnitOptions(const ['g', 'mL', '袋'], const ['袋']);
    expect(options, ['袋', 'g', 'mL']);
    // 当前值不在候选里也要能回显
    expect(withCurrentBasisUnit(options, '已删除的单位'),
        ['已删除的单位', '袋', 'g', 'mL']);
    expect(withCurrentBasisUnit(options, 'g'), ['袋', 'g', 'mL']);
  });

  test('新建默认行包含七项核心营养素', () {
    expect(kDefaultNutrientLabels,
        ['能量', '蛋白质', '脂肪', '饱和脂肪', '碳水化合物', '糖', '钠']);
    expect(kDefaultNutrientUnits.containsKey('能量'), isFalse,
        reason: '能量不写死，走 defaultNutrientUnit 随偏好');
    expect(kDefaultNutrientUnits['钠'], 'mg');
    expect(kDefaultNutrientUnits['蛋白质'], 'g');
    expect(kDefaultNutrientUnits['饱和脂肪'], 'g');
    expect(kDefaultNutrientUnits['糖'], 'g');
  });

  test('能量默认单位跟随用户能量单位偏好，缺省 kcal', () {
    expect(defaultNutrientUnit('能量', energyUnit: 'kJ'), 'kJ');
    expect(defaultNutrientUnit('能量', energyUnit: 'kj'), 'kJ');
    expect(defaultNutrientUnit('能量', energyUnit: 'kcal'), 'kcal');
    expect(defaultNutrientUnit('能量', energyUnit: null), 'kcal');
    expect(defaultNutrientUnit('能量', energyUnit: 'garbage'), 'kcal');
    // 其余营养素不受偏好影响
    expect(defaultNutrientUnit('钠', energyUnit: 'kJ'), 'mg');
    expect(defaultNutrientUnit('蛋白质'), 'g');
  });
}

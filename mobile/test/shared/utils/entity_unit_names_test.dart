import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/utils/entity_unit_names.dart';

void main() {
  test('自定义单位排在全局单位前，且按名称去重', () {
    final merged = mergePriceUnitOptions(
      const ['桶', '斤'],
      const ['g', 'kg', '斤', '个'],
    );
    expect(merged, ['桶', '斤', 'g', 'kg', '个']);
  });

  test('空自定义单位只返回全局单位', () {
    expect(
      mergePriceUnitOptions(const [], const ['g', '个']),
      ['g', '个'],
    );
  });

  test('当前单位不在列表里时补到最前（避免下拉断言失败）', () {
    final merged = mergePriceUnitOptions(
      const ['桶'],
      const ['g', '个'],
      current: '已停用的单位',
    );
    expect(merged.first, '已停用的单位');
    expect(merged, contains('桶'));
  });

  test('当前单位已在列表里则不重复添加', () {
    final merged = mergePriceUnitOptions(
      const ['桶'],
      const ['g'],
      current: 'g',
    );
    expect(merged.where((u) => u == 'g').length, 1);
  });

  test('空白项被丢弃', () {
    expect(
      mergePriceUnitOptions(const ['  ', '桶'], const ['g', '']),
      ['桶', 'g'],
    );
  });
}

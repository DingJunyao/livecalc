import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/models/entity_unit.dart';
import 'package:com_a4ding_livecalc/shared/utils/draft_units.dart';

EntityUnit _draft({
  required int id,
  required String name,
  double? weightPerUnit,
  int? weightUnitId,
  int? weightUnitOverrideId,
  bool isDefault = false,
}) {
  return EntityUnit(
    id: id,
    unitName: name,
    conversionFactor: 1,
    weightPerUnit: weightPerUnit,
    isDefault: isDefault,
    weightUnitId: weightUnitId,
    weightUnitOverrideId: weightUnitOverrideId,
  );
}

void main() {
  test('nextDraftUnitId 生成不与既有草稿冲突的负数 id', () {
    expect(nextDraftUnitId(const []), -1);
    expect(nextDraftUnitId([_draft(id: -1, name: '盒')]), -2);
    expect(
      nextDraftUnitId([
        _draft(id: -1, name: '盒'),
        _draft(id: -3, name: '箱'),
      ]),
      -4,
    );
  });

  test('planDraftUnitWrites 把被引用的单位排在引用者之前', () {
    final box = _draft(id: -1, name: '盒', weightPerUnit: 200, weightUnitId: 1);
    final carton = _draft(
      id: -2,
      name: '箱',
      weightPerUnit: 12,
      weightUnitOverrideId: box.id,
    );
    // 故意乱序：箱在前，仍需先创建盒
    final plan = planDraftUnitWrites([carton, box]);
    expect(plan.batches.map((b) => b.map((u) => u.unitName).toList()).toList(),
        [['盒'], ['箱']]);
    expect(plan.cycles, isEmpty);
  });

  test('planDraftUnitWrites 把互不依赖的单位放进同一批', () {
    final plan = planDraftUnitWrites([
      _draft(id: -1, name: '个', weightPerUnit: 200, weightUnitId: 1),
      _draft(id: -2, name: '袋', weightPerUnit: 500, weightUnitId: 1),
    ]);
    expect(plan.batches.length, 1);
    expect(plan.batches.first.length, 2);
  });

  test('planDraftUnitWrites 识别循环引用（不创建、不丢行）', () {
    final a = _draft(id: -1, name: 'A', weightPerUnit: 2, weightUnitOverrideId: -2);
    final b = _draft(id: -2, name: 'B', weightPerUnit: 2, weightUnitOverrideId: -1);
    final plan = planDraftUnitWrites([a, b]);
    expect(plan.batches, isEmpty);
    expect(plan.cycles.map((u) => u.unitName).toList()..sort(), ['A', 'B']);
  });

  test('draftChainReaches 沿引用链判断是否会成环', () {
    final a = _draft(id: -1, name: 'A', weightPerUnit: 2, weightUnitOverrideId: -2);
    final b = _draft(id: -2, name: 'B', weightPerUnit: 3);
    expect(draftChainReaches([a, b], a.id, b.id), isTrue);
    expect(draftChainReaches([a, b], b.id, a.id), isFalse);
    expect(draftChainReaches([a, b], b.id, null), isFalse);
  });

  test('removeDraftUnit 同时清空指向它的引用（不留悬空引用）', () {
    final box = _draft(id: -1, name: '盒', weightPerUnit: 200, weightUnitId: 1);
    final carton = _draft(
      id: -2,
      name: '箱',
      weightPerUnit: 12,
      weightUnitOverrideId: box.id,
    );
    final next = removeDraftUnit([box, carton], box.id);
    expect(next.length, 1);
    expect(next.first.unitName, '箱');
    expect(next.first.weightUnitOverrideId, isNull);
    // 其它字段不丢
    expect(next.first.weightPerUnit, 12);
    expect(next.first.conversionFactor, 1);
  });
}

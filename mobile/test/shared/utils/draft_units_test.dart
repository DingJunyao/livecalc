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

  test('unresolvableUnitIds 找出引用失效（含下游）的单位', () {
    final own = [
      _draft(id: 9, name: '箱', weightPerUnit: 12, weightUnitOverrideId: 77),
      _draft(id: 10, name: '个', weightPerUnit: 200, weightUnitId: 1),
    ];
    // 新原料只提供 78，没有 77 → 「箱」失效；全局单位（weightUnitId=1）不受影响
    expect(unresolvableUnitIds(own, {78}), {9});
  });

  test('unresolvableUnitIds 引用在目标原料里存在则可解析', () {
    final own = [
      _draft(id: 9, name: '箱', weightPerUnit: 12, weightUnitOverrideId: 77),
    ];
    expect(unresolvableUnitIds(own, {77}), isEmpty);
  });

  test('unresolvableUnitIds 级联：依赖失效单位的下游同样失效', () {
    final own = [
      _draft(id: 9, name: '盒', weightPerUnit: 200, weightUnitOverrideId: 77),
      _draft(id: 10, name: '箱', weightPerUnit: 12, weightUnitOverrideId: 9),
    ];
    expect(unresolvableUnitIds(own, {78}).toSet(), {9, 10});
  });

  test('unresolvableUnitIds 自引用与悬空引用都算失效', () {
    final own = [
      _draft(id: 9, name: '自引用', weightUnitOverrideId: 9),
      _draft(id: 10, name: '悬空', weightUnitOverrideId: 999),
    ];
    expect(unresolvableUnitIds(own, const {}), {9, 10});
  });

  test('reconcileUnitsAfterIngredientChange 引用换成全局同名单位（不删行）', () {
    // 用户实测场景：商品单位「箱」引用原料包菜的「颗」(31)；换原料后 31 不存在，
    // 但全局单位里本来就有「颗」(49) → 改指向，保留这条自定义单位
    final units = [
      _draft(id: 900, name: '箱', weightPerUnit: 12, weightUnitOverrideId: 31),
    ];
    final result = reconcileUnitsAfterIngredientChange(
      units: units,
      targetIngredientIdsByName: const {},
      globalIdsByName: const {'颗': 49},
      missingRefNames: const {31: '颗'},
    );
    expect(result.removed, isEmpty);
    expect(result.retargeted.length, 1);
    expect(result.retargeted.first.weightUnitId, 49);
    expect(result.retargeted.first.weightUnitOverrideId, isNull);
    expect(result.units.single.unitName, '箱');
  });

  test('reconcileUnitsAfterIngredientChange 优先改指向新原料的同名单位', () {
    final units = [
      _draft(id: 900, name: '箱', weightPerUnit: 12, weightUnitOverrideId: 31),
    ];
    final result = reconcileUnitsAfterIngredientChange(
      units: units,
      targetIngredientIdsByName: const {'颗': 88},
      globalIdsByName: const {'颗': 49},
      missingRefNames: const {31: '颗'},
    );
    expect(result.retargeted.single.weightUnitOverrideId, 88);
    expect(result.retargeted.single.weightUnitId, isNull);
    expect(result.removed, isEmpty);
  });

  test('reconcileUnitsAfterIngredientChange 没有同名单位才移除（含下游）', () {
    final units = [
      _draft(id: 900, name: '箱', weightPerUnit: 12, weightUnitOverrideId: 31),
      _draft(id: 901, name: '大箱', weightPerUnit: 6, weightUnitOverrideId: 900),
      _draft(id: 902, name: '个', weightPerUnit: 200, weightUnitId: 18),
    ];
    final result = reconcileUnitsAfterIngredientChange(
      units: units,
      targetIngredientIdsByName: const {},
      globalIdsByName: const {'个': 18},
      missingRefNames: const {31: '哈'},
    );
    expect(result.retargeted, isEmpty);
    expect(result.removed.map((unit) => unit.id).toList()..sort(), [900, 901]);
    expect(result.units.map((unit) => unit.id).toList(), [902]);
  });

  test('reconcileUnitsAfterIngredientChange 拿不到旧单位名字时不猜（移除）', () {
    final units = [
      _draft(id: 900, name: '箱', weightPerUnit: 12, weightUnitOverrideId: 31),
    ];
    final result = reconcileUnitsAfterIngredientChange(
      units: units,
      targetIngredientIdsByName: const {},
      globalIdsByName: const {'颗': 49},
    );
    expect(result.retargeted, isEmpty);
    expect(result.removed.single.id, 900);
  });

  test('reconcileUnitsAfterIngredientChange 引用仍有效时什么都不动', () {
    final units = [
      _draft(id: 900, name: '箱', weightPerUnit: 12, weightUnitOverrideId: 88),
      _draft(id: 901, name: '个', weightPerUnit: 200, weightUnitId: 18),
    ];
    final result = reconcileUnitsAfterIngredientChange(
      units: units,
      targetIngredientIdsByName: const {'颗': 88},
      globalIdsByName: const {'个': 18},
    );
    expect(result.retargeted, isEmpty);
    expect(result.removed, isEmpty);
    expect(result.units.length, 2);
  });
}

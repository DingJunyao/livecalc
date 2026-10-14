import '../models/entity_unit.dart';

/// 「新增商品」时自定义单位的草稿规划（纯函数，无网络依赖）。
///
/// 商品还没创建（没有 id）时，草稿单位用**负数 id** 表示自己：
///   - 负数的 [EntityUnit.weightUnitOverrideId] → 同一批草稿里的另一条（嵌套，1箱 = 12 盒）；
///   - 正数的 [EntityUnit.weightUnitOverrideId] → 关联原料已存在的自定义单位。
/// 商品创建成功后按 [planDraftUnitWrites] 的批次顺序落库，并把负数 id 映射成真实 id。
class DraftUnitPlan {
  /// 批内互不依赖，批与批之间按顺序创建即可满足嵌套引用。
  final List<List<EntityUnit>> batches;

  /// 引用成环、无法落库的草稿。
  final List<EntityUnit> cycles;

  const DraftUnitPlan({required this.batches, required this.cycles});

  bool get isEmpty => batches.isEmpty && cycles.isEmpty;
}

/// 生成不与既有草稿冲突的负数 id。
int nextDraftUnitId(List<EntityUnit> units) {
  var min = 0;
  for (final unit in units) {
    if (unit.id < min) min = unit.id;
  }
  return min - 1;
}

/// 按依赖关系分批：一批内的单位只引用「更早批次」或正数（原料）引用。
DraftUnitPlan planDraftUnitWrites(List<EntityUnit> units) {
  final batches = <List<EntityUnit>>[];
  final done = <int>{};
  var remaining = List<EntityUnit>.of(units);
  var progressed = true;

  while (remaining.isNotEmpty && progressed) {
    progressed = false;
    final batch = <EntityUnit>[];
    final postponed = <EntityUnit>[];
    for (final unit in remaining) {
      final ref = unit.weightUnitOverrideId;
      if (ref != null && ref < 0 && !done.contains(ref)) {
        postponed.add(unit);
      } else {
        batch.add(unit);
      }
    }
    if (batch.isNotEmpty) {
      batches.add(batch);
      for (final unit in batch) {
        done.add(unit.id);
      }
      progressed = true;
    }
    remaining = postponed;
  }

  return DraftUnitPlan(batches: batches, cycles: remaining);
}

/// 候选草稿沿 [EntityUnit.weightUnitOverrideId] 链能否走回 [targetId]
/// （visited + 深度上限 8，与后端环检测同口径）。
bool draftChainReaches(List<EntityUnit> units, int candidateId, int? targetId) {
  if (targetId == null) return false;
  final byId = {for (final unit in units) unit.id: unit};
  int? cursor = candidateId;
  final visited = <int>{};
  for (var depth = 0; depth <= 8; depth++) {
    if (cursor == null || visited.contains(cursor)) return false;
    if (cursor == targetId) return true;
    visited.add(cursor);
    final row = byId[cursor];
    if (row == null || row.weightUnitOverrideId == null) return false;
    cursor = row.weightUnitOverrideId;
  }
  return false;
}

/// 删掉某条草稿后，清空其它草稿指向它的引用（避免留下悬空引用）。
List<EntityUnit> removeDraftUnit(List<EntityUnit> units, int unitId) {
  return [
    for (final unit in units)
      if (unit.id != unitId)
        unit.weightUnitOverrideId == unitId
            ? EntityUnit(
                id: unit.id,
                unitName: unit.unitName,
                conversionFactor: unit.conversionFactor,
                weightPerUnit: unit.weightPerUnit,
                isDefault: unit.isDefault,
                source: unit.source,
                weightUnitId: unit.weightUnitId,
                weightUnitOverrideId: null,
              )
            : unit,
  ];
}

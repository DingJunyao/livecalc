import '../../features/entities/repositories/entity_repository.dart';
import '../../features/nutrition/repositories/nutrition_repository.dart';
import '../models/entity_unit.dart';
import '../models/nutrition.dart';
import '../utils/draft_units.dart';
import '../utils/nutrition_basis.dart';

/// 一条附加数据的保存失败/跳过原因（文案由调用方按 l10n 组合）。
class EntityDraftIssue {
  /// cycle（引用成环）/ refMissing（被引用单位没落库）/ unit / nutrition
  final String kind;
  final List<String> names;
  final String detail;

  const EntityDraftIssue({
    required this.kind,
    this.names = const [],
    this.detail = '',
  });
}

class EntityDraftPersistResult {
  final int unitsCreated;
  final int unitsPending;
  final bool nutritionSaved;
  final bool nutritionPending;
  final int nutrientsSaved;
  final List<EntityDraftIssue> issues;

  const EntityDraftPersistResult({
    this.unitsCreated = 0,
    this.unitsPending = 0,
    this.nutritionSaved = false,
    this.nutritionPending = false,
    this.nutrientsSaved = 0,
    this.issues = const [],
  });

  bool get hasExtras => unitsCreated > 0 || nutrientsSaved > 0;
  bool get hasPending => unitsPending > 0 || nutritionPending;
}

/// 把「新增商品/原料」时填好的自定义单位 / 营养信息草稿写入刚创建的实体。
///
/// [entityType] 为 `product` 或 `ingredient`：
///   - 单位：`POST /entities/{entityType}/{id}/units`
///   - 营养：`POST /nutrition/{products|ingredients}/{id}/nutrition`
///
/// 失败不抛出：实体已经创建成功，附加数据失败要让用户看到具体哪一项失败。
class EntityDraftPersister {
  final EntityRepository entityRepository;
  final NutritionRepository nutritionRepository;
  final bool isAdmin;

  EntityDraftPersister({
    EntityRepository? entityRepository,
    NutritionRepository? nutritionRepository,
    this.isAdmin = true,
  })  : entityRepository = entityRepository ?? EntityRepository(),
        nutritionRepository = nutritionRepository ?? NutritionRepository();

  Future<EntityDraftPersistResult> persist({
    required String entityType,
    required int entityId,
    List<EntityUnit> units = const [],
    List<NutrientEntry> nutrients = const [],
    NutritionBasis basis = const NutritionBasis(),
  }) async {
    var unitsCreated = 0;
    var unitsPending = 0;
    var nutritionSaved = false;
    var nutritionPending = false;
    var nutrientsSaved = 0;
    final issues = <EntityDraftIssue>[];

    final createdByDraftId = <int, int>{};
    final plan = planDraftUnitWrites(units);
    if (plan.cycles.isNotEmpty) {
      issues.add(EntityDraftIssue(
        kind: 'cycle',
        names: [for (final unit in plan.cycles) unit.unitName],
      ));
    }

    for (final batch in plan.batches) {
      for (final unit in batch) {
        final ref = unit.weightUnitOverrideId;
        final refIsDraft = ref != null && ref < 0;
        if (refIsDraft && !createdByDraftId.containsKey(ref)) {
          // 被引用的草稿单位没落库（失败或待审），引用它的单位无 id 可用
          unitsPending++;
          issues.add(EntityDraftIssue(
            kind: 'refMissing',
            names: [unit.unitName],
          ));
          continue;
        }
        try {
          final result = await entityRepository.createUnit(
            entityType,
            entityId,
            unitName: unit.unitName,
            // 换算系数已从界面移除：语义由「量 + 单位」表达，固定写 1
            conversionFactor: 1,
            weightPerUnit: unit.weightPerUnit,
            weightUnitId: ref != null ? null : unit.weightUnitId,
            weightUnitOverrideId: refIsDraft ? createdByDraftId[ref] : ref,
            isDefault: unit.isDefault,
            isAdmin: isAdmin,
          );
          final createdId = result.value?.id ?? 0;
          if (!result.pending && createdId > 0) {
            createdByDraftId[unit.id] = createdId;
            unitsCreated++;
          } else {
            // 普通用户提交待审：拿不到真实 id，后续嵌套引用只能跳过
            unitsPending++;
          }
        } on Exception catch (error) {
          issues.add(EntityDraftIssue(
            kind: 'unit',
            names: [unit.unitName],
            detail: error.toString(),
          ));
        }
      }
    }

    final entries = [
      for (final entry in nutrients)
        // 显式 0 是有效记录（「没有记录」≠「记录为 0」），只过滤未填/负数
        if (entry.label.trim().isNotEmpty && entry.value >= 0) entry,
    ];
    if (entries.isNotEmpty) {
      try {
        final review = entityType == 'ingredient'
            ? await nutritionRepository.saveIngredientNutrition(entityId, entries,
                basis: basis)
            : await nutritionRepository.saveProductNutrition(entityId, entries,
                basis: basis);
        if (review.pending) {
          nutritionPending = true;
        } else {
          nutritionSaved = true;
          nutrientsSaved = entries.length;
        }
      } on Exception catch (error) {
        issues.add(EntityDraftIssue(
          kind: 'nutrition',
          detail: error.toString(),
        ));
      }
    }

    return EntityDraftPersistResult(
      unitsCreated: unitsCreated,
      unitsPending: unitsPending,
      nutritionSaved: nutritionSaved,
      nutritionPending: nutritionPending,
      nutrientsSaved: nutrientsSaved,
      issues: issues,
    );
  }
}

import '../../../shared/models/entity_unit.dart';
import '../../../shared/models/nutrition.dart';
import '../../../shared/utils/draft_units.dart';
import '../../entities/repositories/entity_repository.dart';
import '../../nutrition/repositories/nutrition_repository.dart';

/// 一条附加数据的保存失败/跳过原因（文案由调用方按 l10n 组合）。
class ProductDraftIssue {
  /// cycle（引用成环）/ refMissing（被引用单位没落库）/ unit / nutrition
  final String kind;
  final List<String> names;
  final String detail;

  const ProductDraftIssue({
    required this.kind,
    this.names = const [],
    this.detail = '',
  });
}

class ProductDraftPersistResult {
  final int unitsCreated;
  final int unitsPending;
  final bool nutritionSaved;
  final bool nutritionPending;
  final int nutrientsSaved;
  final List<ProductDraftIssue> issues;

  const ProductDraftPersistResult({
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

/// 把「新增商品」时填好的自定义单位 / 营养信息草稿写入刚创建的商品。
///
/// 失败不抛出：商品已经创建成功，附加数据失败要让用户看到具体哪一项失败。
class ProductDraftPersister {
  final EntityRepository entityRepository;
  final NutritionRepository nutritionRepository;
  final bool isAdmin;

  ProductDraftPersister({
    EntityRepository? entityRepository,
    NutritionRepository? nutritionRepository,
    this.isAdmin = true,
  })  : entityRepository = entityRepository ?? EntityRepository(),
        nutritionRepository = nutritionRepository ?? NutritionRepository();

  Future<ProductDraftPersistResult> persist({
    required int productId,
    List<EntityUnit> units = const [],
    List<NutrientEntry> nutrients = const [],
  }) async {
    var unitsCreated = 0;
    var unitsPending = 0;
    var nutritionSaved = false;
    var nutritionPending = false;
    var nutrientsSaved = 0;
    final issues = <ProductDraftIssue>[];

    final createdByDraftId = <int, int>{};
    final plan = planDraftUnitWrites(units);
    if (plan.cycles.isNotEmpty) {
      issues.add(ProductDraftIssue(
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
          issues.add(ProductDraftIssue(
            kind: 'refMissing',
            names: [unit.unitName],
          ));
          continue;
        }
        try {
          final result = await entityRepository.createUnit(
            'product',
            productId,
            unitName: unit.unitName,
            // 换算系数已从界面移除：语义由「量 + 单位」表达，固定写 1
            conversionFactor: 1,
            weightPerUnit: unit.weightPerUnit,
            weightUnitId: ref != null ? null : unit.weightUnitId,
            weightUnitOverrideId:
                refIsDraft ? createdByDraftId[ref] : ref,
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
          issues.add(ProductDraftIssue(
            kind: 'unit',
            names: [unit.unitName],
            detail: error.toString(),
          ));
        }
      }
    }

    final entries = [
      for (final entry in nutrients)
        if (entry.label.trim().isNotEmpty && entry.value > 0) entry,
    ];
    if (entries.isNotEmpty) {
      try {
        final review =
            await nutritionRepository.saveProductNutrition(productId, entries);
        if (review.pending) {
          nutritionPending = true;
        } else {
          nutritionSaved = true;
          nutrientsSaved = entries.length;
        }
      } on Exception catch (error) {
        issues.add(ProductDraftIssue(
          kind: 'nutrition',
          detail: error.toString(),
        ));
      }
    }

    return ProductDraftPersistResult(
      unitsCreated: unitsCreated,
      unitsPending: unitsPending,
      nutritionSaved: nutritionSaved,
      nutritionPending: nutritionPending,
      nutrientsSaved: nutrientsSaved,
      issues: issues,
    );
  }
}

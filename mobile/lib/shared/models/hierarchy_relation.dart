import '../../core/i18n/app_formatters.dart';

class HierarchyRelation {
  final int id;
  final int parentId;
  final String parentName;
  final int childId;
  final String childName;
  final String relationType;
  final int strength;
  final bool isPending;

  /// 换算系数：`factor_parent_quantity [unit] 父 = factor_child_quantity [unit] 子`。
  /// 全空 = 1:1。
  final double? factorParentQuantity;
  final String? factorParentUnit;
  final double? factorChildQuantity;
  final String? factorChildUnit;

  const HierarchyRelation({
    required this.id,
    required this.parentId,
    required this.parentName,
    required this.childId,
    required this.childName,
    required this.relationType,
    this.strength = 50,
    this.isPending = false,
    this.factorParentQuantity,
    this.factorParentUnit,
    this.factorChildQuantity,
    this.factorChildUnit,
  });

  factory HierarchyRelation.fromJson(Map<String, dynamic> json) {
    return HierarchyRelation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parentId: (json['parent_id'] as num?)?.toInt() ?? 0,
      parentName: json['parent_name'] as String? ?? '',
      childId: (json['child_id'] as num?)?.toInt() ?? 0,
      childName: json['child_name'] as String? ?? '',
      relationType: json['relation_type'] as String? ?? '',
      strength: (json['strength'] as num?)?.toInt() ?? 50,
      isPending: false,
      factorParentQuantity: _toDouble(json['factor_parent_quantity']),
      factorParentUnit: json['factor_parent_unit'] as String?,
      factorChildQuantity: _toDouble(json['factor_child_quantity']),
      factorChildUnit: json['factor_child_unit'] as String?,
    );
  }

  /// 四个系数字段是否齐全（后端契约：全空或全填）。
  bool get hasFactor =>
      factorParentQuantity != null &&
      (factorParentUnit ?? '').isNotEmpty &&
      factorChildQuantity != null &&
      (factorChildUnit ?? '').isNotEmpty;

  /// 紧凑等式（如「1 kg 干 = 3 kg 鲜」），无系数时为 null。
  String? factorEquation() => hasFactor
      ? formatHierarchyFactorEquation(
          parentQuantity: factorParentQuantity!,
          parentUnit: factorParentUnit!,
          childQuantity: factorChildQuantity!,
          childUnit: factorChildUnit!,
        )
      : null;

  /// 关系类型展示名。
  String get typeLabel => switch (relationType) {
        'contains' => '包含',
        'substitutable' => '可替代',
        'fallback' => '回退',
        _ => relationType,
      };

  /// 以 [ingredientId] 视角展示：该原料作为父节点（指向子级）还是子节点。
  String describeFrom(int ingredientId) {
    if (parentId == ingredientId) {
      return '包含/指向 $childName';
    }
    return '由 $parentName 指向';
  }
}

/// 创建/编辑层级关系时提交的换算系数（四字段，全空 = 1:1 / 清除）。
class HierarchyFactorInput {
  final double parentQuantity;
  final String parentUnit;
  final double childQuantity;
  final String childUnit;

  const HierarchyFactorInput({
    required this.parentQuantity,
    required this.parentUnit,
    required this.childQuantity,
    required this.childUnit,
  });

  /// 紧凑等式预览，如「1 kg 干 = 3 kg 鲜」。
  String equation() => formatHierarchyFactorEquation(
        parentQuantity: parentQuantity,
        parentUnit: parentUnit,
        childQuantity: childQuantity,
        childUnit: childUnit,
      );
}

/// 渲染「1 kg 干 = 3 kg 鲜」式紧凑等式（不带原料名，名称由调用方拼接）。
String formatHierarchyFactorEquation({
  required double parentQuantity,
  required String parentUnit,
  required double childQuantity,
  required String childUnit,
}) =>
    '${formatQuantity(parentQuantity)} $parentUnit'
    ' = ${formatQuantity(childQuantity)} $childUnit';

double? _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
}

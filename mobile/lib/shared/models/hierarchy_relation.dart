class HierarchyRelation {
  final int id;
  final int parentId;
  final String parentName;
  final int childId;
  final String childName;
  final String relationType;
  final int strength;

  const HierarchyRelation({
    required this.id,
    required this.parentId,
    required this.parentName,
    required this.childId,
    required this.childName,
    required this.relationType,
    this.strength = 50,
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
    );
  }

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

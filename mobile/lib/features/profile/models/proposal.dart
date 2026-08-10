/// 变更提议（后端 /proposals 返回形状）：
/// {id, entity_type, entity_id, entity_label, action, payload, snapshot,
///  status, review_note, created_at}
class Proposal {
  final int id;
  final String entityType;
  final int? entityId;
  final String? entityLabel;
  final String action; // create / update / delete / merge / publish
  final Map<String, dynamic> payload;
  final Map<String, dynamic> snapshot;
  final String status; // pending / approved / rejected
  final String? reviewNote;
  final String createdAt;

  const Proposal({
    required this.id,
    required this.entityType,
    this.entityId,
    this.entityLabel,
    required this.action,
    this.payload = const {},
    this.snapshot = const {},
    required this.status,
    this.reviewNote,
    required this.createdAt,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(String key) {
      final v = json[key];
      return v is Map<String, dynamic> ? v : const {};
    }

    return Proposal(
      id: json['id'] as int,
      entityType: json['entity_type'] as String? ?? '',
      entityId: (json['entity_id'] as num?)?.toInt(),
      entityLabel: json['entity_label'] as String?,
      action: json['action'] as String? ?? '',
      payload: map('payload'),
      snapshot: map('snapshot'),
      status: json['status'] as String? ?? 'pending',
      reviewNote: json['review_note'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  /// 列表标题：实体标签优先，缺失时回退 '[#id] 动作 类型'
  /// （后端无 title 字段，旧实现读 title 全为 null 导致标题空白）。
  String get title {
    final label = entityLabel;
    if (label != null && label.isNotEmpty) return label;
    return '[#$id] $action $entityType';
  }

  /// 详情展示的补充说明（审核意见）。
  String get description => reviewNote ?? '';
}

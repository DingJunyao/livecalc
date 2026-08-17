class EntityPendingProposal {
  final int id;
  final String action;
  final Map<String, dynamic> payload;

  const EntityPendingProposal({
    required this.id,
    required this.action,
    required this.payload,
  });

  factory EntityPendingProposal.fromJson(Map<String, dynamic> json) {
    return EntityPendingProposal(
      id: json['id'] is int ? json['id'] as int : 0,
      action: json['action']?.toString() ?? 'update',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : const {},
    );
  }
}

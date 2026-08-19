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

  /// Most proposal payloads are plain fields; recipe-style payloads wrap them
  /// in update_data. Both forms are accepted here so detail models can show a
  /// proposer their pending draft without waiting for review.
  Map<String, dynamic> get updateData {
    final nested = payload['update_data'];
    return nested is Map<String, dynamic> ? nested : payload;
  }
}

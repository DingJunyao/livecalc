class Merchant {
  final int id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final int? productCount;
  final bool isOpen;
  final String? createdAt;
  final MerchantPendingProposal? pendingProposal;
  final int? regionId;
  final String? defaultCurrency;
  final String? effectiveCurrency;

  const Merchant({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.productCount,
    this.isOpen = true,
    this.createdAt,
    this.pendingProposal,
    this.regionId,
    this.defaultCurrency,
    this.effectiveCurrency,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      productCount: json['product_count'] as int?,
      isOpen: _parseBool(json['is_open']),
      createdAt: json['created_at'] as String?,
      regionId: (json['region_id'] as num?)?.toInt(),
      defaultCurrency: json['default_currency'] as String?,
      effectiveCurrency: json['effective_currency'] as String?,
      pendingProposal: json['pending_proposal'] is Map<String, dynamic>
          ? MerchantPendingProposal.fromJson(
              json['pending_proposal'] as Map<String, dynamic>)
          : null,
    );
  }

  Merchant mergedWithPending() {
    final proposal = pendingProposal;
    if (proposal?.action != 'update') return this;
    final data = proposal!.payload;
    return Merchant(
      id: id,
      name: data['name']?.toString() ?? name,
      address:
          data.containsKey('address') ? data['address']?.toString() : address,
      latitude: data.containsKey('latitude')
          ? (data['latitude'] as num?)?.toDouble()
          : latitude,
      longitude: data.containsKey('longitude')
          ? (data['longitude'] as num?)?.toDouble()
          : longitude,
      phone: phone,
      productCount: productCount,
      isOpen:
          data.containsKey('is_open') ? _parseBool(data['is_open']) : isOpen,
      createdAt: createdAt,
      pendingProposal: proposal,
    );
  }

  List<String> get pendingModificationLabels {
    final proposal = pendingProposal;
    if (proposal?.action != 'update') return const [];
    return [
      for (final field in proposal!.payload.keys)
        switch (field) {
          'name' => '名称',
          'address' => '地址',
          'latitude' || 'longitude' => '位置',
          'is_open' => '营业状态',
          _ => field,
        },
    ];
  }
}

class MerchantPendingProposal {
  final int id;
  final String action;
  final Map<String, dynamic> payload;

  const MerchantPendingProposal({
    required this.id,
    required this.action,
    required this.payload,
  });

  factory MerchantPendingProposal.fromJson(Map<String, dynamic> json) {
    return MerchantPendingProposal(
      id: json['id'] is int ? json['id'] as int : 0,
      action: json['action']?.toString() ?? 'update',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : const {},
    );
  }
}

bool _parseBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return true;
}

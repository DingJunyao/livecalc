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

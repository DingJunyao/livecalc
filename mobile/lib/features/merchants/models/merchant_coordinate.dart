/// 商家坐标轻量数据（GET /merchants/coordinates）。
class MerchantCoordinate {
  final int id;
  final double latitude;
  final double longitude;
  final bool isOpen;

  const MerchantCoordinate({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.isOpen = true,
  });

  factory MerchantCoordinate.fromJson(Map<String, dynamic> json) {
    return MerchantCoordinate(
      id: (json['id'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      isOpen: json['is_open'] as bool? ?? true,
    );
  }
}

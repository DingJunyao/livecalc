class MerchantPrice {
  final int merchantId;
  final String merchantName;
  final double price;
  final String? unit;
  final bool isLowest;
  final String? recordedAt;
  final List<double>? sparklineData;

  const MerchantPrice({
    required this.merchantId,
    required this.merchantName,
    required this.price,
    this.unit,
    this.isLowest = false,
    this.recordedAt,
    this.sparklineData,
  });

  factory MerchantPrice.fromJson(Map<String, dynamic> json) {
    return MerchantPrice(
      merchantId: (json['merchant_id'] as num?)?.toInt() ?? 0,
      merchantName: json['merchant_name'] as String? ?? '',
      price: _toDouble(json['price']) ?? 0,
      unit: json['unit'] as String?,
      isLowest: json['is_lowest'] as bool? ?? false,
      recordedAt: json['recorded_at'] as String?,
      sparklineData: (json['sparkline_data'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

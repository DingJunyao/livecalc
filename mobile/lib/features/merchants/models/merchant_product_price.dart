double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// 商家各商品最新价格（GET /merchants/{id}/product-prices）。
class MerchantProductPrice {
  final int productId;
  final String productName;
  final double price;
  final double? standardUnitPrice;
  final String? standardUnitLabel;
  final double originalQuantity;
  final String recordedAt;
  final String currency;
  final double? exchangeRate;

  const MerchantProductPrice({
    required this.productId,
    required this.productName,
    required this.price,
    this.standardUnitPrice,
    this.standardUnitLabel,
    this.originalQuantity = 1,
    required this.recordedAt,
    this.currency = 'CNY',
    this.exchangeRate,
  });

  factory MerchantProductPrice.fromJson(Map<String, dynamic> json) {
    return MerchantProductPrice(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: json['product_name'] as String? ?? '',
      price: _toDouble(json['price']) ?? 0,
      standardUnitPrice: _toDouble(json['standard_unit_price']),
      standardUnitLabel: json['standard_unit_label'] as String?,
      originalQuantity: _toDouble(json['original_quantity']) ?? 1,
      recordedAt:
          json['recorded_at'] as String? ?? DateTime.now().toIso8601String(),
      currency: json['currency'] as String? ?? 'CNY',
      exchangeRate: _toDouble(json['exchange_rate']),
    );
  }

  /// 展示单价：优先标准单价（元/斤、元/L），否则总价。
  double get displayPrice => standardUnitPrice ?? price;

  /// 展示单位后缀（如 “ / 斤”），没有时为空。
  String get displayUnit {
    final label = standardUnitLabel ?? '';
    if (label.isEmpty) return '';
    var unit = label.startsWith('元') ? label.substring(1) : label;
    unit = unit.replaceFirst(RegExp(r'^[\s/]+'), '').trim();
    return unit.isEmpty ? '' : ' / $unit';
  }
}

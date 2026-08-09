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

  const MerchantProductPrice({
    required this.productId,
    required this.productName,
    required this.price,
    this.standardUnitPrice,
    this.standardUnitLabel,
    this.originalQuantity = 1,
    required this.recordedAt,
  });

  factory MerchantProductPrice.fromJson(Map<String, dynamic> json) {
    return MerchantProductPrice(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: json['product_name'] as String? ?? '',
      price: _toDouble(json['price']) ?? 0,
      standardUnitPrice: _toDouble(json['standard_unit_price']),
      standardUnitLabel: json['standard_unit_label'] as String?,
      originalQuantity: _toDouble(json['original_quantity']) ?? 1,
      recordedAt: json['recorded_at'] as String? ??
          DateTime.now().toIso8601String(),
    );
  }

  /// 展示单价：优先标准单价（元/斤、元/L），否则总价。
  double get displayPrice => standardUnitPrice ?? price;

  /// 展示单位后缀（如 “/斤”），没有时为空。
  String get displayUnit {
    final label = standardUnitLabel ?? '';
    return label.startsWith('元')
        ? '/${label.substring(1)}'
        : (label.isEmpty ? '' : '/$label');
  }
}

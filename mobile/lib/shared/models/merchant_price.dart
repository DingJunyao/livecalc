class MerchantPrice {
  final int merchantId;
  final String merchantName;
  final double price;
  final String? unit;
  final bool isLowest;
  final String? recordedAt;
  final bool isStale;
  final List<double>? sparklineData;
  final String? currency;
  final double? exchangeRate;

  /// 折算来源（direct / fallback / name_match / contains_aggregation）
  final String source;

  /// 折算链路说明（如「猪肉 ← 子食材(五花肉, …)」）
  final String? chain;

  /// 该商家没有直接价（或直接价超期被替代），此价按替代/回退/从属折算得出
  final bool isDerived;

  /// 从属聚合的区间（各子食材价格极值）
  final double? minPrice;
  final double? maxPrice;

  /// 直接价超期被折算价替代时的原直接价
  final double? directPrice;
  final bool directStale;

  const MerchantPrice({
    required this.merchantId,
    required this.merchantName,
    required this.price,
    this.unit,
    this.isLowest = false,
    this.recordedAt,
    this.isStale = false,
    this.sparklineData,
    this.currency,
    this.exchangeRate,
    this.source = 'direct',
    this.chain,
    this.isDerived = false,
    this.minPrice,
    this.maxPrice,
    this.directPrice,
    this.directStale = false,
  });

  factory MerchantPrice.fromJson(Map<String, dynamic> json) {
    return MerchantPrice(
      merchantId: (json['merchant_id'] as num?)?.toInt() ?? 0,
      merchantName: json['merchant_name'] as String? ?? '',
      price: _toDouble(json['price']) ?? 0,
      unit: json['unit'] as String?,
      isLowest: json['is_lowest'] as bool? ?? false,
      recordedAt: json['recorded_at'] as String?,
      isStale: json['is_stale'] as bool? ?? false,
      sparklineData: (json['sparkline_data'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      currency: json['currency'] as String?,
      exchangeRate: _toDouble(json['exchange_rate']),
      source: json['source'] as String? ?? 'direct',
      chain: json['chain'] as String?,
      isDerived: json['is_derived'] as bool? ?? false,
      minPrice: _toDouble(json['min_price']),
      maxPrice: _toDouble(json['max_price']),
      directPrice: _toDouble(json['direct_price']),
      directStale: json['direct_stale'] as bool? ?? false,
    );
  }
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

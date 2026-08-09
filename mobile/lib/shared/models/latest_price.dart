/// 最新价格（原料/商品统一结构）。
class LatestPriceInfo {
  final double? price;
  final String? unit;
  final String? date;

  const LatestPriceInfo({this.price, this.unit, this.date});

  factory LatestPriceInfo.fromJson(Map<String, dynamic> json) {
    return LatestPriceInfo(
      price: _toDouble(json['average_price'] ?? json['latest_price']),
      unit: (json['unit'] as String?) ??
          (json['latest_price_unit'] as String?),
      date: (json['recorded_at'] as String?) ??
          (json['latest_price_date'] as String?) ??
          (json['latest_date'] as String?),
    );
  }
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

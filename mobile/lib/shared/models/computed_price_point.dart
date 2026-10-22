/// 原料「替代/回退/半成品/从属」折算价单点。
///
/// 来自 `GET /nutrition/ingredients/{id}/price-series`：后端按菜谱成本同一降级链
/// （direct → fallback → name_match → recipe → contains）逐日 as-of 计算，
/// 返回**每克**单价；这里统一折算成「每斤」价格，与移动端趋势图口径
/// （[buildPriceTrendPoints] 的 price per jin）一致。
class ComputedPricePoint {
  final String date;
  final double min;
  final double max;
  final double avg;

  /// direct / fallback / name_match / recipe / contains_aggregation
  final String source;
  final String? chain;

  /// 该日直接价超期、已改用关系折算（原直接价见 [directAvg]）
  final bool directStale;
  final double? directAvg;

  const ComputedPricePoint({
    required this.date,
    required this.min,
    required this.max,
    required this.avg,
    required this.source,
    this.chain,
    this.directStale = false,
    this.directAvg,
  });

  /// 每克 → 每斤：1 斤 = 500 克。
  static const double gramsPerJin = 500;

  factory ComputedPricePoint.fromJson(Map<String, dynamic> json) {
    double ppg(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    final directPpg = json['direct_ppg'];
    return ComputedPricePoint(
      date: json['date'] as String? ?? '',
      min: ppg('min_ppg') * gramsPerJin,
      max: ppg('max_ppg') * gramsPerJin,
      avg: ppg('avg_ppg') * gramsPerJin,
      source: json['source'] as String? ?? 'direct',
      chain: json['chain'] as String?,
      directStale: json['direct_stale'] as bool? ?? false,
      directAvg: directPpg is num ? directPpg.toDouble() * gramsPerJin : null,
    );
  }
}

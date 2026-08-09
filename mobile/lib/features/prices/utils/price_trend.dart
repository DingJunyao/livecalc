import 'dart:math' as math;
import '../../recipes/repositories/recipe_repository.dart' show CostHistoryPoint;
import '../models/price_record.dart';

/// 将价格记录按“本地日期”聚合为日均/最低/最高单价点，
/// 供价格趋势图（CostTrendChart）使用，与 Web 端 chartData 语义一致。
List<CostHistoryPoint> buildPriceTrendPoints(List<PriceRecord> records) {
  final byDate = <String, List<double>>{};
  for (final r in records) {
    final dt = DateTime.tryParse(r.recordedAt)?.toLocal();
    if (dt == null) continue;
    final key = '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
    byDate.putIfAbsent(key, () => <double>[]).add(r.unitPrice);
  }
  final dates = byDate.keys.toList()..sort();
  return [
    for (final d in dates)
      CostHistoryPoint(
        date: d,
        minCost: byDate[d]!.reduce(math.min),
        maxCost: byDate[d]!.reduce(math.max),
        avgCost: byDate[d]!.reduce((a, b) => a + b) / byDate[d]!.length,
      ),
  ];
}

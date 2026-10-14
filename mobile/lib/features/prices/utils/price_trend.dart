import '../../recipes/repositories/recipe_repository.dart'
    show CostHistoryPoint;
import '../models/price_record.dart';

/// 价格趋势图的日点：逐日「as-of 加权综合价」。
///
/// 与 Web 端 `frontend/src/utils/priceAsOf.ts` 同口径（也与后端综合价 /
/// 原料迷你图一致）：
///   - 每个商品的当日价 = 该商品「最近有记录日」的当日均价
///   - 该价格一直有效到下一次记录（两次记录之间视为价格不变）
///   - 每日综合价 = 各商品当日有效价加权（本端暂无用户权重，各商品等权）
///   - 参与上限 [staleDays]：超过 N 天的价格不再参与；但当日全部商品都过期时
///     放开，按最近一次已知价计算（宁可显示旧价格，也不能没有价格）
///
/// 因此「所选区间内没有任何新记录」（近一个月没更新）时，图表仍会画出最近
/// 一次已知价，而不是空白。
///
/// [startDay] / [endDay] 为本地日历日（YYYY-MM-DD）：startDay 截断序列起点
/// （配合回退全量取数时，只画所选区间），endDay 默认今天。
/// [backfillSparse]：整段只有一个记录日时按最早已知价向前补齐（见函数内注释）。
List<CostHistoryPoint> buildPriceTrendPoints(
  List<PriceRecord> records, {
  bool useStandardQuantity = false,
  String? startDay,
  String? endDay,
  int staleDays = _priceStaleDays,
  bool backfillSparse = false,
}) {
  // 1) 按商品 + 本地日聚合当日均价
  final byProduct = <String, Map<String, List<double>>>{};
  for (final r in records) {
    final dt = DateTime.tryParse(r.recordedAt)?.toLocal();
    if (dt == null) continue;
    final value = _pricePerJin(r, useStandardQuantity);
    if (!value.isFinite) continue;
    byProduct
        .putIfAbsent(r.productId.toString(), () => <String, List<double>>{})
        .putIfAbsent(_dayKey(dt), () => <double>[])
        .add(value);
  }
  if (byProduct.isEmpty) return [];

  // 2) 每个商品：日升序阶梯（日期 → 当日均价），游标式推进
  final steps = <_ProductStep>[];
  String? firstDay;
  for (final dayMap in byProduct.values) {
    final days = dayMap.keys.toList()..sort();
    steps.add(_ProductStep(
      days: days,
      values: [for (final d in days) _mean(dayMap[d]!)],
      expiresOn: staleDays > 0 ? _addDays(days.last, staleDays) : null,
    ));
    if (firstDay == null || days.first.compareTo(firstDay) < 0) {
      firstDay = days.first;
    }
  }
  if (firstDay == null || steps.isEmpty) return [];

  // 整段只有「一个记录日」→ 允许把最早已知价向前补齐到 startDay（仅在调用方开启
  // backfillSparse 时）：单点序列连不成线，图表看起来是空白。有 ≥2 个记录日时
  // 一律不补写，不会凭空编造趋势。
  var backfill = false;
  if (backfillSparse) {
    final recordDays = <String>{};
    for (final step in steps) {
      recordDays.addAll(step.days);
    }
    backfill = recordDays.length < 2;
  }

  // 3) 逐日推进：每个商品取「截至当日的最新价」
  final lastDay = endDay ?? _dayKey(DateTime.now());
  final out = <CostHistoryPoint>[];
  var cur = (startDay != null && (backfill || startDay.compareTo(firstDay) > 0))
      ? startDay
      : firstDay;
  while (cur.compareTo(lastDay) <= 0) {
    var num = 0.0;
    var den = 0.0;
    var min = double.infinity;
    var max = double.negativeInfinity;
    var numAll = 0.0;
    var denAll = 0.0;
    var minAll = double.infinity;
    var maxAll = double.negativeInfinity;
    for (final step in steps) {
      while (step.next < step.days.length &&
          step.days[step.next].compareTo(cur) <= 0) {
        step.current = step.next;
        step.next += 1;
      }
      if (step.current < 0 && !backfill) continue;
      // 向前补齐时：还没有记录的日子用该商品的最早已知价
      final value =
          step.current < 0 ? step.values.first : step.values[step.current];
      // all：全部商品（当日全部过期时的放开兜底）
      numAll += value;
      denAll += 1;
      if (value < minAll) minAll = value;
      if (value > maxAll) maxAll = value;
      if (step.expiresOn != null && cur.compareTo(step.expiresOn!) > 0) {
        continue;
      }
      // fresh：staleDays 内有过记录的商品
      num += value;
      den += 1;
      if (value < min) min = value;
      if (value > max) max = value;
    }
    // 当日没有「新鲜」商品 → 放开上限，用全部商品的最近一次已知价
    final relaxed = den <= 0;
    if (denAll > 0) {
      out.add(CostHistoryPoint(
        date: cur,
        minCost: relaxed ? minAll : min,
        maxCost: relaxed ? maxAll : max,
        avgCost: (relaxed ? numAll : num) / (relaxed ? denAll : den),
      ));
    }
    cur = _addDays(cur, 1);
  }
  return out;
}

/// 区间请求结果是否需要回退「全量」取数。
///
/// as-of 序列需要「区间起点之前最近一次记录」作为携带起点，而按区间取数
/// （start_date）恰好把它挡在区间外。区间里也可能**只有今天**一条新记录
/// （陈旧实体今天刚补价），这时区间命中数不为 0，但池里最早的记录晚于区间起点
/// → 序列只剩一个点、图表看起来空白。因此判据是「池里有没有不晚于区间起点的记录」：
///   - 池为空 → 需要回退（数据整体陈旧）；
///   - 池非空但最早记录日 > 区间起点 → 需要回退（缺携带起点）。
bool needsFullPriceHistory({
  required String windowStartDay,
  required List<PriceRecord> windowRecords,
}) {
  if (windowStartDay.isEmpty) return false;
  var earliest = '';
  for (final record in windowRecords) {
    final dt = DateTime.tryParse(record.recordedAt)?.toLocal();
    if (dt == null) continue;
    final day = localDayKey(dt);
    if (earliest.isEmpty || day.compareTo(earliest) < 0) earliest = day;
  }
  if (earliest.isEmpty) return true;
  return earliest.compareTo(windowStartDay) > 0;
}

/// 参与综合价的时限（天）：与 Web 端 PRICE_STALE_DAYS / 后端
/// INGREDIENT_PRICE_STALE_DAYS 一致。
const int _priceStaleDays = 30;

class _ProductStep {
  _ProductStep({
    required this.days,
    required this.values,
    required this.expiresOn,
  });

  final List<String> days;
  final List<double> values;
  /// 超过该日视为过期（不再参与综合价）；null 表示不设上限
  final String? expiresOn;
  int next = 0;
  int current = -1;
}

String _dayKey(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

/// 本地日历日 key（YYYY-MM-DD）；供跨模块判断「记录日 vs 区间起点」复用。
String localDayKey(DateTime dt) => _dayKey(dt);

String _addDays(String day, int delta) {
  final d = DateTime.parse('${day}T00:00:00');
  return _dayKey(DateTime(d.year, d.month, d.day + delta));
}

double _mean(List<double> values) =>
    values.reduce((a, b) => a + b) / values.length;

double? _unitsPerJin(String? unit) {
  switch (unit?.trim().toLowerCase()) {
    case 'g':
    case '克':
      return 500;
    case 'kg':
    case '千克':
      return 0.5;
    case '斤':
      return 1;
    case '两':
      return 10;
    case 'mg':
    case '毫克':
      return 500000;
    default:
      return null;
  }
}

double _pricePerJin(PriceRecord record, bool useStandardQuantity) {
  if (useStandardQuantity) {
    final standardFactor = _unitsPerJin(record.standardUnit);
    if (record.standardQuantity != null &&
        record.standardQuantity! > 0 &&
        standardFactor != null) {
      return record.price / record.standardQuantity! * standardFactor;
    }
  }

  final factor = _unitsPerJin(record.unit) ?? 1;
  final quantity = record.quantity > 0 ? record.quantity : 1;
  return record.price / quantity * factor;
}

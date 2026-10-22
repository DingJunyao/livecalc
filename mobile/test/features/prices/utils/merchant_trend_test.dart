import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/utils/price_trend.dart';

PriceRecord _rec({
  required int id,
  required int merchantId,
  String merchantName = '商家',
  required String day,
  double price = 10,
  double quantity = 1,
  String unit = '斤',
}) {
  return PriceRecord(
    id: id,
    productId: 1,
    productName: '商品',
    price: price,
    quantity: quantity,
    unit: unit,
    merchantId: merchantId,
    merchantName: merchantName,
    recordedAt: '${day}T04:00:00Z',
  );
}

void main() {
  group('buildMerchantTrendSeries', () {
    test('按商家分组，各自 as-of 序列，记录数降序', () {
      final today = DateTime.now();
      String dayAgo(int n) {
        final d = today.subtract(Duration(days: n));
        return '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }

      final records = [
        _rec(id: 1, merchantId: 1, merchantName: 'A 超市', day: dayAgo(5), price: 10),
        _rec(id: 2, merchantId: 1, merchantName: 'A 超市', day: dayAgo(2), price: 12),
        _rec(id: 3, merchantId: 2, merchantName: 'B 超市', day: dayAgo(3), price: 9),
      ];

      final series = buildMerchantTrendSeries(
        records,
        useStandardQuantity: true,
        backfillSparse: true,
      );

      expect(series.length, 2);
      // A 有 2 个记录日 → 排在前面
      expect(series.first.merchantId, 1);
      expect(series.first.name, 'A 超市');
      expect(series.first.recordDays, contains(dayAgo(5)));
      expect(series.first.recordDays, contains(dayAgo(2)));
      expect(series.first.points.length, greaterThanOrEqualTo(2));

      final b = series.firstWhere((s) => s.merchantId == 2);
      expect(b.name, 'B 超市');
      expect(b.recordDays.length, 1);
      expect(b.points, isNotEmpty);
    });

    test('没有商家的记录被忽略（不会造出 #null 序列）', () {
      final records = [
        _rec(id: 1, merchantId: 1, day: '2026-10-01'),
        PriceRecord(
          id: 2,
          productId: 1,
          productName: '商品',
          price: 10,
          quantity: 1,
          unit: '斤',
          recordedAt: '2026-10-02T04:00:00Z',
        ),
      ];
      final series = buildMerchantTrendSeries(records);
      expect(series.length, 1);
      expect(series.single.merchantId, 1);
    });

    test('priceRecordDays 只收真实记录日', () {
      final days = priceRecordDays([
        _rec(id: 1, merchantId: 1, day: '2026-10-01'),
        _rec(id: 2, merchantId: 1, day: '2026-10-01'),
        _rec(id: 3, merchantId: 1, day: '2026-10-03'),
      ]);
      expect(days.length, 2);
      expect(days.contains('2026-10-03'), isTrue);
    });
  });
}

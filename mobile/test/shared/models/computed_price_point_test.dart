import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/models/computed_price_point.dart';
import 'package:com_a4ding_livecalc/shared/models/merchant_price.dart';

void main() {
  group('ComputedPricePoint', () {
    test('每克单价按 500g/斤折算', () {
      final p = ComputedPricePoint.fromJson({
        'date': '2026-10-21',
        'source': 'contains_aggregation',
        'chain': '猪肉 ← 子食材(五花肉, 肋排)',
        'min_ppg': 0.0116,
        'max_ppg': 0.0598,
        'avg_ppg': 0.02369151515151515,
        'direct_ppg': 0.01318,
        'direct_stale': true,
      });

      expect(p.date, '2026-10-21');
      expect(p.min, closeTo(5.80, 1e-9));
      expect(p.max, closeTo(29.90, 1e-9));
      expect(p.avg, closeTo(11.845757575757575, 1e-6));
      expect(p.source, 'contains_aggregation');
      expect(p.directStale, isTrue);
      expect(p.directAvg, closeTo(6.59, 1e-9));
    });

    test('缺字段时安全降级（direct 日没有 direct_ppg）', () {
      final p = ComputedPricePoint.fromJson({
        'date': '2026-10-20',
        'min_ppg': '0.01',
        'max_ppg': '0.01',
        'avg_ppg': '0.01',
      });
      expect(p.source, 'direct');
      expect(p.avg, closeTo(5, 1e-9));
      expect(p.directStale, isFalse);
      expect(p.directAvg, isNull);
    });
  });

  group('MerchantPrice 折算字段', () {
    test('解析 source/chain/is_derived/区间/原直接价', () {
      final price = MerchantPrice.fromJson({
        'merchant_id': 7,
        'merchant_name': '丹尼斯',
        'price': 6.29,
        'unit': '斤',
        'is_stale': true,
        'source': 'contains_aggregation',
        'chain': '食用油 ← 子食材(植物油, 猪油)',
        'is_derived': true,
        'min_price': 6.29,
        'max_price': 6.29,
        'direct_price': 6.59,
        'direct_stale': true,
      });
      expect(price.isDerived, isTrue);
      expect(price.source, 'contains_aggregation');
      expect(price.chain, contains('植物油'));
      expect(price.minPrice, 6.29);
      expect(price.directPrice, 6.59);
      expect(price.directStale, isTrue);
    });

    test('直接价默认不是折算行', () {
      final price = MerchantPrice.fromJson({
        'merchant_id': 3,
        'merchant_name': '美道家',
        'price': 6.58,
      });
      expect(price.isDerived, isFalse);
      expect(price.source, 'direct');
      expect(price.directPrice, isNull);
    });
  });
}

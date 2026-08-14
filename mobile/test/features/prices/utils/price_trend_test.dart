import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/utils/price_trend.dart';

void main() {
  test('builds product trend points from the backend standard quantity', () {
    final record = PriceRecord.fromJson({
      'id': 2935,
      'product_id': 119,
      'product_name': '番茄',
      'price': '1.14',
      'original_quantity': '514.0',
      'original_unit': 'g',
      'standard_quantity': '500.000',
      'standard_unit': 'g',
      'standard_unit_id': 3,
      'record_type': 'price',
      'recorded_at': '2026-08-01T13:41:00+00:00',
    });

    final points = buildPriceTrendPoints(
      [record],
      useStandardQuantity: true,
    );

    expect(points, hasLength(1));
    expect(points.single.date, '2026-08-01');
    expect(points.single.minCost, closeTo(1.14, 0.001));
    expect(points.single.maxCost, closeTo(1.14, 0.001));
    expect(points.single.avgCost, closeTo(1.14, 0.001));
  });

  test('builds ingredient trend points from the original quantity', () {
    final record = PriceRecord.fromJson({
      'id': 2935,
      'product_id': 119,
      'product_name': '番茄',
      'price': '1.14',
      'original_quantity': '514.0',
      'original_unit': 'g',
      'standard_quantity': '500.000',
      'standard_unit': 'g',
      'standard_unit_id': 3,
      'record_type': 'price',
      'recorded_at': '2026-08-01T13:41:00+00:00',
    });

    final points = buildPriceTrendPoints([record]);

    expect(points.single.avgCost, closeTo(1.1089, 0.001));
  });
}

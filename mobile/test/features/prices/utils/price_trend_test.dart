import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/utils/price_trend.dart';

PriceRecord record({
  int id = 2935,
  int productId = 119,
  String price = '1.14',
  String quantity = '514.0',
  String unit = 'g',
  String? standardQuantity = '500.000',
  String? standardUnit = 'g',
  String recordedAt = '2026-08-01T13:41:00+00:00',
}) {
  return PriceRecord.fromJson({
    'id': id,
    'product_id': productId,
    'product_name': '番茄',
    'price': price,
    'original_quantity': quantity,
    'original_unit': unit,
    'standard_quantity': standardQuantity,
    'standard_unit': standardUnit,
    'standard_unit_id': 3,
    'record_type': 'price',
    'recorded_at': recordedAt,
  });
}

void main() {
  test('builds product trend points from the backend standard quantity', () {
    final points = buildPriceTrendPoints(
      [record()],
      useStandardQuantity: true,
      endDay: '2026-08-01',
    );

    expect(points, hasLength(1));
    expect(points.single.date, '2026-08-01');
    expect(points.single.minCost, closeTo(1.14, 0.001));
    expect(points.single.maxCost, closeTo(1.14, 0.001));
    expect(points.single.avgCost, closeTo(1.14, 0.001));
  });

  test('builds ingredient trend points from the original quantity', () {
    final points = buildPriceTrendPoints([record()], endDay: '2026-08-01');

    expect(points.single.avgCost, closeTo(1.1089, 0.001));
  });

  test('区间内没有新记录时按最近一次已知价补满区间（不再空白）', () {
    // 8-01 之后再没有记录：10 月「月」视图仍要有价格线（全部超期时放开上限）
    final points = buildPriceTrendPoints(
      [record(price: '5.00', recordedAt: '2026-08-01T12:00:00+08:00')],
      useStandardQuantity: true,
      startDay: '2026-10-01',
      endDay: '2026-10-05',
    );

    expect(points.map((p) => p.date).toList(),
        ['2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05']);
    expect(points.every((p) => (p.avgCost - 5.0).abs() < 1e-9), isTrue);
  });

  test('序列起点不早于所需区间（回退全量取数时只画所选区间）', () {
    final points = buildPriceTrendPoints(
      [
        record(id: 1, price: '3.00', recordedAt: '2026-01-05T12:00:00+08:00'),
        record(id: 2, price: '4.00', recordedAt: '2026-10-02T12:00:00+08:00'),
      ],
      useStandardQuantity: true,
      startDay: '2026-10-01',
      endDay: '2026-10-03',
    );

    expect(points, hasLength(3));
    expect(points.first.date, '2026-10-01');
    expect(points.first.avgCost, closeTo(3.0, 0.001));
    expect(points.last.avgCost, closeTo(4.0, 0.001));
  });

  test('超过参与上限的商品在存在新鲜商品时被排除', () {
    final points = buildPriceTrendPoints(
      [
        // 陈旧商品：8-01 之后没记录，10 月已超过 30 天上限
        record(id: 1, productId: 1, price: '10.00',
            recordedAt: '2026-08-01T12:00:00+08:00'),
        record(id: 2, productId: 2, price: '20.00',
            recordedAt: '2026-10-01T12:00:00+08:00'),
      ],
      useStandardQuantity: true,
      startDay: '2026-10-01',
      endDay: '2026-10-03',
    );

    expect(points, hasLength(3));
    expect(points.every((p) => (p.avgCost - 20.0).abs() < 1e-9), isTrue);
  });

  test('同一商品同日多条先取当日均价再向上携带', () {
    final points = buildPriceTrendPoints(
      [
        record(id: 1, price: '10.00', recordedAt: '2026-10-01T08:00:00+08:00'),
        record(id: 2, price: '30.00', recordedAt: '2026-10-01T20:00:00+08:00'),
      ],
      useStandardQuantity: true,
      endDay: '2026-10-01',
    );

    expect(points, hasLength(1));
    expect(points.single.avgCost, closeTo(20.0, 0.001));
    // 逐日 as-of 口径：当日点 = 当日均价（min/max 是同日多商品间的区间，
    // 单商品同日多条的区间由详情页卡片单独统计）
    expect(points.single.minCost, closeTo(20.0, 0.001));
    expect(points.single.maxCost, closeTo(20.0, 0.001));
  });

  test('needsFullPriceHistory：池为空或池里最早记录晚于区间起点时要回退全量', () {
    // 区间内一条都没有（数据整体陈旧）
    expect(
      needsFullPriceHistory(windowStartDay: '2026-10-01', windowRecords: const []),
      isTrue,
    );
    // 区间内只有今天一条新记录、更早记录被 start_date 挡在区间外（用户实测场景②）
    expect(
      needsFullPriceHistory(
        windowStartDay: '2026-10-01',
        windowRecords: [record(recordedAt: '2026-10-14T11:00:00+08:00')],
      ),
      isTrue,
    );
    // 池里有不晚于区间起点的记录 → 已有 as-of 携带起点，不回退
    expect(
      needsFullPriceHistory(
        windowStartDay: '2026-10-01',
        windowRecords: [
          record(id: 1, recordedAt: '2026-09-20T11:00:00+08:00'),
          record(id: 2, recordedAt: '2026-10-14T11:00:00+08:00'),
        ],
      ),
      isFalse,
    );
    // 「全部」区间没有起点 → 不回退
    expect(
      needsFullPriceHistory(windowStartDay: '', windowRecords: const []),
      isFalse,
    );
  });

  test('只有一次记录且只有一个记录日时向前补齐成平线（backfillSparse）', () {
    // 只有今天一条记录：不补齐时只剩一个点（图表看起来空白）
    final single = buildPriceTrendPoints(
      [record(price: '5.00', recordedAt: '2026-10-14T11:00:00+08:00')],
      useStandardQuantity: true,
      startDay: '2026-10-10',
      endDay: '2026-10-14',
    );
    expect(single, hasLength(1));

    final filled = buildPriceTrendPoints(
      [record(price: '5.00', recordedAt: '2026-10-14T11:00:00+08:00')],
      useStandardQuantity: true,
      startDay: '2026-10-10',
      endDay: '2026-10-14',
      backfillSparse: true,
    );
    expect(
      filled.map((p) => p.date).toList(),
      ['2026-10-10', '2026-10-11', '2026-10-12', '2026-10-13', '2026-10-14'],
    );
    expect(filled.every((p) => (p.avgCost - 5.0).abs() < 1e-9), isTrue);
  });

  test('有两个记录日时不做向前补齐（不凭空编造趋势）', () {
    final points = buildPriceTrendPoints(
      [
        record(id: 1, price: '10.00', recordedAt: '2026-10-12T11:00:00+08:00'),
        record(id: 2, price: '20.00', recordedAt: '2026-10-14T11:00:00+08:00'),
      ],
      useStandardQuantity: true,
      startDay: '2026-10-08',
      endDay: '2026-10-14',
      backfillSparse: true,
    );

    expect(points.first.date, '2026-10-12');
    expect(points.map((p) => p.date).toList(),
        ['2026-10-12', '2026-10-13', '2026-10-14']);
  });
}

// comparison_repository_test.dart — 跨地区对比 repository 的解析与请求参数测试。
// Mock Dio：验证 GET /comparison/* 的参数拼接与模型容错解析（Decimal 字符串等）。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/comparison/repositories/comparison_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient client;
  late MockDio dio;
  late ComparisonRepository repository;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = ComparisonRepository(client: client);
  });

  test('getRegions 解析候选并保留记录数排序', () async {
    when(() => dio.get('/comparison/regions')).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'regions': [
              {
                'region_id': 1,
                'name': '北京市',
                'display_name': '北京市',
                'level': 2,
                'record_count': 120,
                'merchant_count': 3,
              },
              {
                'region_id': 2,
                'name': '广州市',
                'display_name': '广州市',
                'level': 2,
                'record_count': 45,
                'merchant_count': 1,
              },
            ],
          },
        ));

    final list = await repository.getRegions();

    expect(list, hasLength(2));
    expect(list.first.regionId, 1);
    expect(list.first.recordCount, 120);
    expect(list.last.displayName, '广州市');
  });

  test('getSummary 拼接 region_ids 并容错解析字符串数值', () async {
    when(() => dio.get('/comparison/summary', queryParameters: any(
            named: 'queryParameters', that: isA<Map<String, dynamic>>())))
        .thenAnswer((inv) async {
      final params = inv.namedArguments[#queryParameters] as Map<String, dynamic>;
      expect(params['region_ids'], '1,2');
      expect(params['days'], 30);
      return Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'currency': 'CNY',
          'base_region_id': 1,
          'basket_size': 2,
          'regions': [
            {
              'region_id': 1,
              'name': '北京市',
              'display_name': '北京市',
              'record_count': 10,
              'entity_count': 4,
              'price_index': 100.0,
              'trend': ['10.5', 11, 9.8],
            },
            {
              'region_id': 2,
              'name': '广州市',
              'display_name': '广州市',
              'record_count': 5,
              'entity_count': 3,
              'price_index': '95.4',
              'trend': [],
            },
          ],
        },
      );
    });

    final summary = await repository.getSummary(regionIds: [1, 2]);

    expect(summary.baseRegionId, 1);
    expect(summary.basketSize, 2);
    expect(summary.regions.first.priceIndex, 100.0);
    expect(summary.regions.first.trend, [10.5, 11.0, 9.8]);
    // Decimal 序列化成字符串也要容错
    expect(summary.regions.last.priceIndex, 95.4);
    expect(summary.regions.last.trend, isEmpty);
  });

  test('getEntityPrices 解析实体行与地区格（null 格保留）', () async {
    when(() => dio.get('/comparison/entity-prices', queryParameters: any(
            named: 'queryParameters', that: isA<Map<String, dynamic>>())))
        .thenAnswer((inv) async {
      final params = inv.namedArguments[#queryParameters] as Map<String, dynamic>;
      expect(params['entity_type'], 'ingredient');
      expect(params['entity_ids'], '7');
      expect(params['region_ids'], '1,3');
      return Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'currency': 'CNY',
          'trend_unit': '斤',
          'regions': [
            {'region_id': 1, 'name': '北京市', 'display_name': '北京市', 'level': 2},
            {'region_id': 3, 'name': '城市C', 'display_name': '城市C', 'level': 2},
          ],
          'entities': [
            {
              'entity_id': 7,
              'name': '鸡蛋',
              'unit': 'kg',
              'regions': {
                '1': {
                  'price': '11.20',
                  'is_stale': false,
                  'days_since_record': 2,
                  'participant_count': 2,
                  'unit': 'kg',
                  'trend': [10.0, 11.2],
                },
                '3': null,
              },
            },
          ],
        },
      );
    });

    final prices = await repository.getEntityPrices(
      entityType: 'ingredient',
      entityIds: [7],
      regionIds: [1, 3],
    );

    expect(prices.entities, hasLength(1));
    final row = prices.entities.first;
    expect(row.name, '鸡蛋');
    expect(row.unit, 'kg');
    expect(row.regions['1']?.price, 11.20);
    expect(row.regions['1']?.participantCount, 2);
    expect(row.regions['3'], isNull);
    expect(prices.regions, hasLength(2));
  });

  test('searchEntities 原料与商品走不同端点', () async {
    when(() => dio.get('/ingredients', queryParameters: any(
            named: 'queryParameters', that: isA<Map<String, dynamic>>())))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              data: {
                'items': [
                  {'id': 7, 'name': '鸡蛋'},
                  {'id': 8, 'name': '白菜'},
                ],
                'total': 2,
              },
            ));
    when(() => dio.get('/products/entity', queryParameters: any(
            named: 'queryParameters', that: isA<Map<String, dynamic>>())))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              data: {
                'items': [
                  {'id': 21, 'name': '鸡蛋 30 枚装'},
                ],
                'total': 1,
              },
            ));

    final ingredients = await repository.searchEntities(
        entityType: 'ingredient', keyword: '鸡蛋');
    final products = await repository.searchEntities(
        entityType: 'product', keyword: '鸡蛋');

    expect(ingredients.map((e) => e.name), ['鸡蛋', '白菜']);
    expect(products.single.name, '鸡蛋 30 枚装');
  });

  test('getHeatmap 单品模式带 entity 参数并透传原始值', () async {
    when(() => dio.get('/comparison/heatmap', queryParameters: any(
            named: 'queryParameters', that: isA<Map<String, dynamic>>())))
        .thenAnswer((inv) async {
      final params = inv.namedArguments[#queryParameters] as Map<String, dynamic>;
      expect(params['mode'], 'item');
      expect(params['entity_type'], 'ingredient');
      expect(params['entity_id'], 7);
      expect(params['region_ids'], '1,2');
      return Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'mode': 'item',
          'currency': 'CNY',
          'unit': '斤',
          'buckets': {'p25': '9.5', 'p50': 12, 'p75': 15.0, 'p90': null},
          'items': [
            {
              'merchant_id': 3,
              'name': '盒马',
              'latitude': '34.77',
              'longitude': 113.42,
              'price': '11.2',
              'is_stale': false,
              'sample_count': 2,
            },
          ],
        },
      );
    });

    final data = await repository.getHeatmap(
      mode: 'item',
      regionIds: [1, 2],
      entityType: 'ingredient',
      entityId: 7,
    );

    final buckets = data['buckets'] as Map;
    expect(buckets['p25'], '9.5'); // 原样透传（数值解析在 widget 层）
    final item = (data['items'] as List).first as Map;
    expect(item['name'], '盒马');
    expect(item['latitude'], '34.77');
  });

  test('getHeatmap 整体模式不带 entity 参数', () async {
    when(() => dio.get('/comparison/heatmap', queryParameters: any(
            named: 'queryParameters', that: isA<Map<String, dynamic>>())))
        .thenAnswer((inv) async {
      final params = inv.namedArguments[#queryParameters] as Map<String, dynamic>;
      expect(params['mode'], 'overall');
      expect(params.containsKey('entity_id'), isFalse);
      return Response(
        requestOptions: RequestOptions(path: ''),
        data: {'mode': 'overall', 'items': [], 'buckets': {}, 'basket_size': 3},
      );
    });

    final data = await repository.getHeatmap(mode: 'overall', regionIds: [1]);
    expect(data['basket_size'], 3);
  });
}

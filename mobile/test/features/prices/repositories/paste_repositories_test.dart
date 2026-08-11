import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
  });

  group('ProductRepository.autocomplete', () {
    test('后端返回 List → 原样解析', () async {
      when(() => mockDio.get('/products/autocomplete',
              queryParameters: {'q': '番', 'limit': 20},
              options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                statusCode: 200,
                data: [
                  {'id': 1, 'name': '番茄', 'match_type': 'name'},
                  {'id': 2, 'name': '番茄酱', 'match_type': 'name'},
                ],
              ));
      final repo = ProductRepository(client: mockClient);
      final list = await repo.autocomplete('番');
      expect(list.length, 2);
      expect(list[0]['name'], '番茄');
      expect(list[1]['id'], 2);
    });

    test('后端返回 {items:[...]} → 取 items', () async {
      when(() => mockDio.get('/products/autocomplete',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                statusCode: 200,
                data: {
                  'items': [
                    {'id': 9, 'name': '西红柿'}
                  ],
                  'total': 1,
                },
              ));
      final repo = ProductRepository(client: mockClient);
      final list = await repo.autocomplete('西红柿', limit: 5);
      expect(list.length, 1);
      expect(list.first['id'], 9);
      // 验证 limit 透传
      verify(() => mockDio.get('/products/autocomplete',
          queryParameters: {'q': '西红柿', 'limit': 5},
          options: any(named: 'options'))).called(1);
    });

    test('空列表不崩', () async {
      when(() => mockDio.get('/products/autocomplete',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                statusCode: 200,
                data: <Map<String, dynamic>>[],
              ));
      final repo = ProductRepository(client: mockClient);
      final list = await repo.autocomplete('xyz');
      expect(list, isEmpty);
    });
  });

  group('PriceRepository.addImportAlias', () {
    test('POST /products/entity/{id}/add-import-alias body {name}', () async {
      when(() => mockDio.post(
            '/products/entity/42/add-import-alias',
            data: {'name': '番茄'},
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ''),
                statusCode: 200,
                data: {'ok': true},
              ));
      final repo = PriceRepository(client: mockClient);
      await repo.addImportAlias(42, '番茄');
      verify(() => mockDio.post(
        '/products/entity/42/add-import-alias',
        data: {'name': '番茄'},
        options: any(named: 'options'),
      )).called(1);
    });
  });
}

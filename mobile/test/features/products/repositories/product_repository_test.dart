import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/products/repositories/product_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient client;
  late MockDio dio;
  late ProductRepository repository;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = ProductRepository(client: client);
  });

  test('non-admin update is pending even when backend echoes old product',
      () async {
    when(() => dio.put('/products/entity/12',
            data: any(named: 'data', that: isA<Map<String, dynamic>>())))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 200,
              data: {'id': 12, 'name': 'low-gluten flour'},
            ));

    final result = await repository.updateProduct(
      12,
      isAdmin: false,
      name: 'high-gluten flour',
    );

    expect(result.pending, isTrue);
    expect(result.product?.name, 'low-gluten flour');
  });

  test('delete parses a pending proposal response', () async {
    when(() => dio.delete('/products/entity/12')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'proposal_id': 8,
          'status': 'pending',
          'message': '删除提议已提交，待管理员审核',
        },
      ),
    );

    final result = await repository.deleteProduct(12);

    expect(result.pending, isTrue);
    expect(result.message, contains('待管理员审核'));
  });
  test('looks up a barcode product', () async {
    when(() => dio.get('/products/entity/barcode/123')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'found': true,
          'source': 'local',
          'product': {'id': 7, 'name': 'Milk'},
          'errors': [],
        },
      ),
    );

    final result = await repository.lookupBarcode('123');

    expect(result.found, isTrue);
    expect(result.product.id, 7);
  });

  test('looks up a barcode miss from a 404 response body', () async {
    final requestOptions = RequestOptions(path: '');
    when(() => dio.get('/products/entity/barcode/404')).thenThrow(
      DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {
            'found': false,
            'source': null,
            'product': {},
            'errors': ['not found'],
          },
        ),
      ),
    );

    final result = await repository.lookupBarcode('404');

    expect(result.found, isFalse);
    expect(result.errors, ['not found']);
  });
}

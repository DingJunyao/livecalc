import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/repositories/calc_scope_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late CalcScopeRepository repository;
  late MockApiClient mockClient;
  late MockDio mockDio;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repository = CalcScopeRepository(client: mockClient);
    registerFallbackValue(<String, dynamic>{});
  });

  Response<List<dynamic>> listResponse(List<dynamic> data) => Response(
        requestOptions: RequestOptions(path: ''),
        data: data,
        statusCode: 200,
      );

  test('listScopes 解析裸数组', () async {
    when(() => mockDio.get('/calc-scopes')).thenAnswer(
      (_) async => listResponse([
        {
          'id': 1,
          'name': '老家周边',
          'region_ids': [12, 34],
          'regions': [
            {'id': 12, 'name': '灵宝市', 'display_name': '灵宝市', 'level': 3},
          ],
          'is_default': true,
        },
      ]),
    );

    final scopes = await repository.listScopes();
    expect(scopes.length, 1);
    expect(scopes.first.name, '老家周边');
    expect(scopes.first.isDefault, isTrue);
  });

  test('createScope POST /calc-scopes 带 name+region_ids', () async {
    when(() => mockDio.post('/calc-scopes', data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'id': 9,
          'name': '两地组合',
          'region_ids': [1, 2],
          'regions': [],
          'is_default': false,
        },
        statusCode: 201,
      ),
    );

    final scope = await repository.createScope({
      'name': '两地组合',
      'region_ids': [1, 2],
    });

    expect(scope.id, 9);
    final body = verify(() =>
            mockDio.post('/calc-scopes', data: captureAny(named: 'data')))
        .captured
        .first as Map<String, dynamic>;
    expect(body['name'], '两地组合');
    expect(body['region_ids'], [1, 2]);
  });

  test('updateScope PUT /calc-scopes/{id}', () async {
    when(() => mockDio.put('/calc-scopes/3', data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'id': 3,
          'name': '改名',
          'region_ids': [5],
          'regions': [],
          'is_default': false,
        },
        statusCode: 200,
      ),
    );

    final scope = await repository.updateScope(3, {'name': '改名'});
    expect(scope.name, '改名');
    verify(() => mockDio.put('/calc-scopes/3', data: any(named: 'data')))
        .called(1);
  });

  test('deleteScope DELETE /calc-scopes/{id}', () async {
    when(() => mockDio.delete('/calc-scopes/4')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: {'ok': true},
        statusCode: 200,
      ),
    );

    await repository.deleteScope(4);
    verify(() => mockDio.delete('/calc-scopes/4')).called(1);
  });
}

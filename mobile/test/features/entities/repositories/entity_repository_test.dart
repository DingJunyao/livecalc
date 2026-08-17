import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/entities/repositories/entity_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient client;
  late MockDio dio;
  late EntityRepository repository;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    repository = EntityRepository(client: client);
  });

  test('non-admin unit create recognizes placeholder response as pending',
      () async {
    when(() => dio.post(
          '/entities/ingredient/5/units',
          data: any(named: 'data'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {'id': 0, 'unit_name': '个', 'is_default': false},
        ));

    final result = await repository.createUnit(
      'ingredient',
      5,
      unitName: '个',
      isAdmin: false,
    );

    expect(result.pending, isTrue);
    expect(result.value?.id, 0);
  });

  test('non-admin unit update is pending even when backend echoes old value',
      () async {
    when(() => dio.put(
          '/entities/ingredient/5/units/9',
          data: any(named: 'data'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {'id': 9, 'unit_name': '碗', 'is_default': false},
        ));

    final result = await repository.updateUnit(
      'ingredient',
      5,
      9,
      unitName: '碗',
      isAdmin: false,
    );

    expect(result.pending, isTrue);
    expect(result.value?.unitName, '碗');
  });

  test('delete detects proposal status embedded in message', () async {
    const message = '删除提议已提交（proposal_id=8, status=pending）';
    when(() => dio.delete('/entities/product/6/units/9')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: {'message': message},
      ),
    );

    final result = await repository.deleteUnit('product', 6, 9);

    expect(result.pending, isTrue);
    expect(result.message, message);
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/ingredients/repositories/ingredient_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late IngredientRepository repository;
  late MockApiClient mockClient;
  late MockDio mockDio;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repository = IngredientRepository(client: mockClient);
  });

  test('update sends null category id when category is cleared', () async {
    when(() => mockDio.put('/ingredients/7',
            data: any(named: 'data', that: isA<Map<String, dynamic>>())))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 200,
              data: {'id': 7, 'name': 'apple'},
            ));

    await repository.updateIngredient(
      7,
      name: 'apple',
      categoryId: null,
      aliases: const [],
    );

    final captured = verify(() => mockDio.put(
          '/ingredients/7',
          data: captureAny(named: 'data'),
        )).captured;
    expect(captured.single, containsPair('category_id', isNull));
  });
}

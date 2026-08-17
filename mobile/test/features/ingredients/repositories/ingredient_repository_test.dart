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
      isAdmin: true,
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

  test('non-admin update is pending even when backend echoes old value',
      () async {
    when(() => mockDio.put('/ingredients/7',
            data: any(named: 'data', that: isA<Map<String, dynamic>>())))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 200,
              data: {'id': 7, 'name': 'apple'},
            ));

    final result = await repository.updateIngredient(
      7,
      isAdmin: false,
      name: 'Apple',
      aliases: const [],
    );

    expect(result.pending, isTrue);
    expect(result.ingredient?.name, 'apple');
  });

  test('hierarchy requests two levels and parses expanded relations', () async {
    when(() => mockDio.get(
          '/ingredients/8/hierarchy',
          queryParameters: {'depth': 2},
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'parent_relations': [],
            'child_relations': [
              {
                'id': 1,
                'parent_id': 8,
                'parent_name': '猪肉',
                'child_id': 9,
                'child_name': '五花肉',
                'relation_type': 'contains',
                'strength': 80,
              }
            ],
            'expanded_relations': [
              {
                'ingredient_id': 9,
                'ingredient_name': '五花肉',
                'parent_relations': [],
                'child_relations': [
                  {
                    'id': 2,
                    'parent_id': 9,
                    'parent_name': '五花肉',
                    'child_id': 10,
                    'child_name': '去皮五花肉',
                    'relation_type': 'contains',
                    'strength': 70,
                  }
                ],
              }
            ],
          },
        ));

    final result = await repository.getHierarchy(8);

    expect(result.childRelations.single.childName, '五花肉');
    expect(result.expandedRelations.single.ingredientName, '五花肉');
    expect(
      result.expandedRelations.single.childRelations.single.childName,
      '去皮五花肉',
    );
  });

  test('latest prices are loaded through one batch request', () async {
    when(() => mockDio.get(
          '/nutrition/ingredients/latest-price/batch',
          queryParameters: {'ingredient_ids': '8,9'},
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {
            'items': {
              '8': {'average_price': 12.5, 'unit': '斤'},
              '9': {'average_price': null, 'unit': null},
            }
          },
        ));

    final result = await repository.getLatestPrices(const [8, 9]);

    expect(result[8]?.price, 12.5);
    expect(result[9]?.price, isNull);
    verify(() => mockDio.get(
          '/nutrition/ingredients/latest-price/batch',
          queryParameters: {'ingredient_ids': '8,9'},
        )).called(1);
    verifyNever(() => mockDio.get('/nutrition/ingredients/8/latest-price'));
    verifyNever(() => mockDio.get('/nutrition/ingredients/9/latest-price'));
  });

  test('non-admin hierarchy create recognizes placeholder as pending',
      () async {
    when(() => mockDio.post(
          '/ingredients/hierarchy',
          data: any(named: 'data'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {'id': 0, 'parent_id': 8, 'child_id': 9},
        ));

    final result = await repository.createHierarchyRelation(
      parentId: 8,
      childId: 9,
      relationType: 'contains',
      isAdmin: false,
    );

    expect(result.pending, isTrue);
  });
}

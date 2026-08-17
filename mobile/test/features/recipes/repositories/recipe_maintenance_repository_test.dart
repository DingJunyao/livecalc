import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/recipes/repositories/recipe_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient client;
  late MockDio dio;
  late RecipeRepository repository;
  late List<dynamic> payloads;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    payloads = [];
    when(() => client.dio).thenReturn(dio);
    repository = RecipeRepository(client: client);
  });

  test('recipe update sends only changed sections and preserves backend shape',
      () async {
    when(() => dio.put('/recipes/3', data: any(named: 'data'))).thenAnswer(
      (invocation) async {
        payloads.add(invocation.namedArguments[#data]);
        return Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'id': 3,
            'name': '黄金番茄炒蛋',
            'servings': 2,
            'ingredients': [],
            'cooking_steps': [],
            'tips': [],
          },
        );
      },
    );

    final result = await repository.updateRecipe(
      3,
      {
        'name': '黄金番茄炒蛋',
        'ingredients': [
          const RecipeIngredientInput(
            ingredientName: '鸡蛋',
            quantity: '2',
            unitId: 7,
            isOptional: false,
          ),
        ],
      },
    );

    expect(payloads.single, {
      'name': '黄金番茄炒蛋',
      'ingredients': [
        {
          'ingredient_name': '鸡蛋',
          'quantity': '2',
          'unit_id': 7,
          'is_optional': false,
        }
      ],
    });
    expect(result.pending, isFalse);
    expect(result.detail?.name, '黄金番茄炒蛋');
  });

  test('recipe update recognizes a pending proposal response', () async {
    when(() => dio.put('/recipes/3', data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: {
          'proposal_id': 99,
          'status': 'pending',
          'message': '编辑已提交，待管理员审核',
        },
      ),
    );

    final result = await repository.updateRecipe(3, {'name': '新名字'});

    expect(result.pending, isTrue);
    expect(result.message, contains('待管理员审核'));
    expect(result.detail, isNull);
  });
}
